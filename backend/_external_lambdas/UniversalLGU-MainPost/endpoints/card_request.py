"""Kabaka Smart Card link requests.

A user without an `assign_card` yet can ask staff to link an existing
Kabaka Smart Card to their profile. This creates a row in
`app_card_request` (type=REQUEST, status=PENDING) for staff to action —
distinct from `app_card_registrations`, which is a full new-card
application.
"""

import datetime
import logging
import re

from helpers.auth import ok, fail, require
from helpers.audit import record_audit_log
from helpers.db import sanitize, serialize_row
from helpers.forms import parse_int

logger = logging.getLogger()

# Idempotent, non-destructive supporting indexes for the new admin list
# endpoint's WHERE clauses. The dump's app_card_request DDL declares no
# indexes at all (and no PK/AUTO_INCREMENT — but request_card_link's own
# INSERT never supplies an id, so the live DB must already have that; see
# this module's design spec). This only ADDS indexes, never touches the
# PK, and no-ops if they already exist — safe regardless of live schema
# state, mirroring card_transactions.py's own _ensure_table/_ALTERS.
_INDEX_ALTERS = [
    ('idx_cardreq_status', """
        SET @c := (SELECT COUNT(*) FROM information_schema.STATISTICS
                   WHERE TABLE_SCHEMA = DATABASE()
                     AND TABLE_NAME = 'app_card_request'
                     AND INDEX_NAME = 'idx_cardreq_status')
    """, """
        SET @s := IF(@c = 0,
            'ALTER TABLE app_card_request ADD INDEX idx_cardreq_status (status)',
            'SELECT 1')
    """),
    ('idx_cardreq_user', """
        SET @c := (SELECT COUNT(*) FROM information_schema.STATISTICS
                   WHERE TABLE_SCHEMA = DATABASE()
                     AND TABLE_NAME = 'app_card_request'
                     AND INDEX_NAME = 'idx_cardreq_user')
    """, """
        SET @s := IF(@c = 0,
            'ALTER TABLE app_card_request ADD INDEX idx_cardreq_user (user_profile_id)',
            'SELECT 1')
    """),
]


def _ensure_indexes(cur):
    for _name, check_sql, set_sql in _INDEX_ALTERS:
        cur.execute(check_sql)
        cur.execute(set_sql)
        cur.execute("PREPARE stmt FROM @s")
        cur.execute("EXECUTE stmt")
        cur.execute("DEALLOCATE PREPARE stmt")


# app_card_request has no column to record why a request was declined —
# add one the same idempotent way _ensure_indexes adds indexes above, so
# the admin-supplied reason (shown to the citizen) has somewhere to land.
_COLUMN_ALTERS = [
    """
    SET @c := (SELECT COUNT(*) FROM information_schema.COLUMNS
               WHERE TABLE_SCHEMA = DATABASE()
                 AND TABLE_NAME = 'app_card_request'
                 AND COLUMN_NAME = 'decline_reason')
    """,
    """
    SET @s := IF(@c = 0,
        'ALTER TABLE app_card_request ADD COLUMN decline_reason TEXT NULL AFTER status',
        'SELECT 1')
    """,
    "PREPARE stmt FROM @s",
    "EXECUTE stmt",
    "DEALLOCATE PREPARE stmt",
]


def _ensure_columns(cur):
    for sql in _COLUMN_ALTERS:
        cur.execute(sql)


# app_qr_code's raw DDL declares no index on status; a search endpoint
# filtering WHERE status='AVAILABLE' AND qr_code LIKE ... wants one.
_QR_INDEX_ALTERS = [
    """
    SET @c := (SELECT COUNT(*) FROM information_schema.STATISTICS
               WHERE TABLE_SCHEMA = DATABASE()
                 AND TABLE_NAME = 'app_qr_code'
                 AND INDEX_NAME = 'idx_qrcode_status')
    """,
    """
    SET @s := IF(@c = 0,
        'ALTER TABLE app_qr_code ADD INDEX idx_qrcode_status (status)',
        'SELECT 1')
    """,
    "PREPARE stmt FROM @s",
    "EXECUTE stmt",
    "DEALLOCATE PREPARE stmt",
]


def _ensure_qr_indexes(cur):
    for sql in _QR_INDEX_ALTERS:
        cur.execute(sql)


_CARD_REQUEST_STATUSES = {'PENDING', 'APPROVED', 'DECLINED'}

_IMAGE_CONTENT_TYPES = {
    'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
    'webp': 'image/webp', 'gif': 'image/gif',
}


def _image_ext_and_type(filename):
    ext = (filename.rsplit('.', 1)[-1] if '.' in filename else 'jpg').lower()
    if ext not in _IMAGE_CONTENT_TYPES:
        ext = 'jpg'
    return ext, _IMAGE_CONTENT_TYPES[ext]


def _extract_selfie(files):
    """Pull the multipart `selfie` file (if any) from the request. Returns
    (content_bytes, ext, content_type) or None when no usable selfie was sent."""
    for f in files or []:
        if (f.get('field_name') or '').strip() == 'selfie':
            f['content'].seek(0)
            content = f['content'].read()
            if not content:
                return None
            ext, ctype = _image_ext_and_type(f.get('filename') or '')
            return content, ext, ctype
    return None


def _normalize_name_text(s):
    """Uppercase, strip anything but letters/spaces/commas, collapse
    whitespace, and tidy spacing around commas. Used to compare names
    tolerant of case and spacing differences without being permissive
    about anything else — this gates an automatic account-to-physical-
    card link, so a false positive (linking the wrong person's card) is
    far worse than a false negative (falling back to manual review)."""
    s = (s or '').upper()
    s = re.sub(r'[^A-Z,\s]', ' ', s)
    s = re.sub(r'\s+', ' ', s).strip()
    s = re.sub(r'\s*,\s*', ', ', s)
    return s


def _cvl_names_match(first_name, middle_name, last_name, cvl_fullname):
    """True only if `app_users`'s name matches `app_cvl_list.cvl_fullname`.

    `app_cvl_list.cvl_fname`/`cvl_mname`/`cvl_lname` are frequently blank
    even when `cvl_fullname` is populated (confirmed against live data),
    so per the CVL record we compare against its single `cvl_fullname`
    string rather than field-by-field. Live CVL data consistently uses
    "LASTNAME, FIRSTNAME MIDDLENAME" — so the `app_users` name is
    assembled the same way, tried both with and without the middle name
    to tolerate either side omitting it. Exact string equality only (no
    word-order/fuzzy matching) — see `_normalize_name_text`'s docstring
    for why.
    """
    cvl_norm = _normalize_name_text(cvl_fullname)
    if not cvl_norm:
        return False

    last_n = _normalize_name_text(last_name)
    first_n = _normalize_name_text(first_name)
    middle_n = _normalize_name_text(middle_name)
    if not last_n or not first_n:
        return False

    with_middle = _normalize_name_text(f'{last_n}, {first_n} {middle_n}')
    without_middle = _normalize_name_text(f'{last_n}, {first_n}')
    return cvl_norm in (with_middle, without_middle)


_CVL_BIRTHDATE_FORMATS = ('%Y-%m-%d', '%m/%d/%Y', '%Y/%m/%d', '%d/%m/%Y')


def _parse_cvl_birthdate(raw):
    """Parse `app_cvl_list.cvl_birthdate` (freeform varchar; live data is
    consistently ISO `YYYY-MM-DD`, with a couple of alternate formats
    tried defensively) into a `date`, or `None` if blank/unparseable —
    callers treat `None` the same as "no birthdate on file"."""
    raw = (raw or '').strip()
    if not raw:
        return None
    for fmt in _CVL_BIRTHDATE_FORMATS:
        try:
            return datetime.datetime.strptime(raw, fmt).date()
        except ValueError:
            continue
    return None


def _as_date(value):
    """Normalize a pymysql DATETIME/DATE column value (already a native
    `datetime`/`date` object, not a string) to a plain `date`."""
    if isinstance(value, datetime.datetime):
        return value.date()
    if isinstance(value, datetime.date):
        return value
    return None


def request_card_link(cur, data, files, ts):
    """Create a link request for the caller, or return the existing one.

    Requires `user_profile_id`. An optional `qr_code` — the payload the
    citizen scanned off their physical card — is resolved through
    `app_cvl_list` (joined on `cvl_qr = app_qr_code.id`), the same table
    the scanner app's `find_cvl_by_qr_bataan` uses; a `qr_code` that
    doesn't match any row, or whose CVL record isn't `cvl_status =
    'ACTIVE'`, fails the request outright (re-validating what the client
    already gated before letting the user scan/verify at all).
    `app_cvl_list` is read-only here — never written to.

    When the CVL record's name matches the caller's `app_users` name
    (see `_cvl_names_match`) AND both sides have a parseable birthdate
    that also matches, the request is auto-linked immediately:
    `app_users.assign_card` — ONLY that column, nothing else on
    `app_users` — is atomically set to the resolved card id (guarded by
    `assign_card IS NULL` so a race against this same account can't
    double-write), with the request recorded as `APPROVED`.
    `app_qr_code` is never written here — its `status` already went
    AVAILABLE→USED in `set_cvl_qr_bataan` when staff tied this QR to the
    CVL record, independent of any citizen ever claiming it, so it's not
    a meaningful signal for this flow. Any other outcome (name mismatch,
    birthdate mismatch, either birthdate missing/unparseable, or this
    exact card already assigned to a *different* `app_users` row —
    possible only if two accounts share the CVL record's exact
    name+birthdate) records the same request as `PENDING` for staff to
    review manually, per the existing `admin_review_card_request`
    mechanism — never a new one.

    A `selfie` file is uploaded to S3 and stored as `verify_photo` when
    present — the caller must capture one before submitting the request.
    Responds with `{status, request_status: 'APPROVED'|'PENDING', card_id}`
    (`card_id` present whenever a card was resolved from `qr_code`,
    regardless of whether it was auto-linked).
    """
    try:
        require(data, 'user_profile_id')
        user_id = data['user_profile_id']

        cur.execute("""
            SELECT id FROM app_card_request
            WHERE user_profile_id=%s AND status='PENDING'
            LIMIT 1
        """, (user_id,))
        if cur.fetchone():
            return ok({'status': True, 'request_status': 'PENDING'})

        cur.execute(
            "SELECT assign_card, first_name, middle_name, last_name, "
            "birth_date FROM app_users WHERE id=%s LIMIT 1",
            (user_id,),
        )
        user_row = cur.fetchone()
        if not user_row:
            return fail('User not found', 404)
        if user_row.get('assign_card'):
            # Mirrors admin_review_card_request's own guard — nothing in
            # this codebase ever puts an app_qr_code row back to
            # AVAILABLE, so a second link would orphan the current card.
            return fail('You already have a card assigned', 409)

        card_id = None
        cvl_row = None
        qr_code = (data.get('qr_code') or '').strip()
        if qr_code:
            cur.execute(
                """
                SELECT c.cvl_fullname, c.cvl_birthdate, c.cvl_status, q.id AS card_id
                FROM app_cvl_list c
                INNER JOIN app_qr_code q ON q.id = c.cvl_qr
                WHERE q.qr_code = %s
                LIMIT 1
                """,
                (qr_code,),
            )
            cvl_row = cur.fetchone()
            if not cvl_row:
                return fail('QR code not found', 404)
            if (cvl_row.get('cvl_status') or '').strip().upper() != 'ACTIVE':
                return fail('This card is not active', 409)
            card_id = cvl_row['card_id']

        # Identity verification — only ever unlocks auto-link; any
        # uncertainty (mismatch, or a missing/unparseable birthdate on
        # either side) falls through to the PENDING path below.
        auto_link = False
        if cvl_row is not None:
            names_match = _cvl_names_match(
                user_row.get('first_name'), user_row.get('middle_name'),
                user_row.get('last_name'), cvl_row.get('cvl_fullname'),
            )
            if names_match:
                app_bd = _as_date(user_row.get('birth_date'))
                cvl_bd = _parse_cvl_birthdate(cvl_row.get('cvl_birthdate'))
                auto_link = app_bd is not None and cvl_bd is not None and app_bd == cvl_bd

        verify_photo = None
        selfie = _extract_selfie(files)
        if selfie is not None:
            import uuid
            from helpers.s3 import upload_to_s3
            content, ext, ctype = selfie
            unique = uuid.uuid4().hex[:8]
            verify_photo = upload_to_s3(
                content, f"card_request/link/{user_id}_{unique}.{ext}",
                content_type=ctype)

        if auto_link:
            # app_qr_code is intentionally NEVER written here — its `status`
            # already went AVAILABLE→USED in set_cvl_qr_bataan the moment
            # staff tied this QR to the CVL record, well before any citizen
            # scan; app_cvl_list (already validated ACTIVE above) is the
            # source of truth for whether this QR/card is a legitimate,
            # linkable one. The only integrity risk this feature itself can
            # introduce is the SAME card_id ending up on two DIFFERENT
            # app_users rows (only possible if two accounts happen to share
            # this CVL record's exact name+birthdate) — guarded by the two
            # checks below instead, both scoped to app_users, under an
            # explicit transaction so the guard-check and the write can't
            # race each other.
            cur.connection.begin()
            try:
                cur.execute(
                    "SELECT id FROM app_users WHERE assign_card=%s AND id!=%s LIMIT 1",
                    (card_id, user_id),
                )
                claimed_by_other = cur.fetchone() is not None

                claimed = False
                if not claimed_by_other:
                    # ONLY assign_card is ever written on app_users here —
                    # scoped by `assign_card IS NULL` so a second concurrent
                    # request from this same account can't double-write.
                    cur.execute(
                        "UPDATE app_users SET assign_card=%s "
                        "WHERE id=%s AND assign_card IS NULL",
                        (card_id, user_id),
                    )
                    claimed = cur.rowcount > 0
                    if claimed:
                        cur.execute("""
                            INSERT INTO app_card_request (
                                type, date_requested, date_approved, verify_photo,
                                status, card_id, user_profile_id
                            ) VALUES (
                                'REQUEST', %s, %s, %s, 'APPROVED', %s, %s
                            )
                        """, (ts, ts, verify_photo, card_id, user_id))
                cur.connection.commit()
            except Exception:
                cur.connection.rollback()
                raise

            if claimed:
                return ok({'status': True, 'request_status': 'APPROVED',
                           'card_id': card_id})
            # Already claimed by another app_users row, or this account
            # raced itself — record it PENDING instead, same as any other
            # unresolved-identity outcome.
            auto_link = False

        cur.execute("""
            INSERT INTO app_card_request (
                type, date_requested, verify_photo, status, card_id, user_profile_id
            ) VALUES (
                'REQUEST', %s, %s, 'PENDING', %s, %s
            )
        """, (ts, verify_photo, card_id, user_id))

        resp = {'status': True, 'request_status': 'PENDING'}
        if card_id is not None:
            resp['card_id'] = card_id
        return ok(resp)
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'request_card_link error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def get_card_request_status(cur, data, files, ts):
    """Return the caller's card-link state.

    `app_users.assign_card` is checked first and takes priority whenever
    set: it's the actual source of truth for "does this citizen have a
    card linked", and can end up set (via auto-link, or a staff approval
    made against an older request) while a *newer*, unrelated
    `app_card_request` row still sits PENDING — reporting that row's
    status alone would then contradict reality (card already linked, but
    the app shows "pending"). Falls back to the caller's most recent
    `app_card_request` row's status (or `NONE`) only when no card is
    assigned yet — including that row's `decline_reason` when its status
    is a rejected one, so the app can show why. `admin_review_card_request`
    in this file only ever writes `'DECLINED'`, but some existing rows
    carry `'REJECTED'` instead (a legacy/external value — no code path
    here produces it) — both are treated as the same rejected state for
    `decline_reason` purposes, the raw stored value is returned as-is in
    `request_status` either way (never rewritten), so the client can
    recognize both without this endpoint silently normalizing history.
    Naturally scoped to only the latest request: an older
    DECLINED/REJECTED row's reason never leaks in once a newer request
    (PENDING/APPROVED/DECLINED/REJECTED) exists, since `ORDER BY
    date_requested DESC LIMIT 1` only ever looks at the single latest row.
    Responds with `{status, request_status, card_id, decline_reason}`
    (`card_id` present only when `assign_card` is set; `decline_reason`
    present only when the latest request is DECLINED/REJECTED and has one).
    """
    try:
        require(data, 'user_profile_id')
        user_id = data['user_profile_id']

        cur.execute(
            "SELECT assign_card FROM app_users WHERE id=%s LIMIT 1",
            (user_id,),
        )
        user_row = cur.fetchone()
        if user_row and user_row.get('assign_card'):
            return ok({'status': True, 'request_status': 'APPROVED',
                       'card_id': user_row['assign_card']})

        _ensure_columns(cur)
        cur.execute("""
            SELECT status, decline_reason FROM app_card_request
            WHERE user_profile_id=%s
            ORDER BY date_requested DESC
            LIMIT 1
        """, (user_id,))
        row = cur.fetchone()
        resp = {'status': True, 'request_status': row['status'] if row else 'NONE'}
        if row and row['status'] in ('DECLINED', 'REJECTED') and row.get('decline_reason'):
            resp['decline_reason'] = row['decline_reason']
        return ok(resp)
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'get_card_request_status error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def admin_list_card_requests(cur, data, files, ts):
    try:
        page = max(parse_int(data.get('page')) or 1, 1)
        limit = min(max(parse_int(data.get('limit')) or 20, 1), 100)
        offset = (page - 1) * limit
        status = (data.get('status') or '').strip().upper()
        search = sanitize(data.get('search'))
        date_from = sanitize(data.get('date_from'))
        date_to = sanitize(data.get('date_to'))

        where = []
        params = []
        if status and status != 'ALL':
            if status not in _CARD_REQUEST_STATUSES:
                return fail(f'Invalid status: {status}')
            where.append('r.status=%s')
            params.append(status)
        if search:
            like = f'%{search}%'
            where.append(
                '(u.first_name LIKE %s OR u.last_name LIKE %s OR u.mobile_number LIKE %s)'
            )
            params += [like, like, like]
        if date_from:
            where.append('r.date_requested >= %s')
            params.append(date_from)
        if date_to:
            where.append('r.date_requested <= %s')
            params.append(f'{date_to} 23:59:59')
        clause = ('WHERE ' + ' AND '.join(where)) if where else ''

        # Validation passed — only now touch the DB (ensure indexes exist,
        # then run the real query), so an invalid status never issues any
        # SQL at all (matches every other admin_list_* endpoint's
        # validate-before-querying discipline).
        _ensure_indexes(cur)

        cur.execute(f"""
            SELECT r.id, r.type, r.date_requested, r.date_approved, r.date_declined,
                   r.verify_photo, r.status, r.card_id, r.user_profile_id,
                   u.first_name, u.last_name, u.mobile_number
            FROM app_card_request r
            LEFT JOIN app_users u ON u.id = r.user_profile_id
            {clause}
            ORDER BY r.date_requested DESC, r.id DESC
            LIMIT %s OFFSET %s
        """, tuple(params + [limit + 1, offset]))
        rows = cur.fetchall() or []
        has_more = len(rows) > limit
        rows = rows[:limit]

        cur.execute("SELECT status, COUNT(*) AS c FROM app_card_request GROUP BY status")
        raw_counts = {row['status']: row['c'] for row in cur.fetchall()}
        stat_counts = {s: raw_counts.get(s, 0) for s in _CARD_REQUEST_STATUSES}
        # Sum raw_counts directly (not stat_counts) so legacy rows with a
        # NULL/unrecognized status — e.g. pre-dating this table's status
        # column being populated — still count toward ALL.
        stat_counts['ALL'] = sum(raw_counts.values())

        return ok({'status': True,
                   'data': {'items': [serialize_row(r) for r in rows],
                            'page': page, 'has_more': has_more,
                            'counts': stat_counts}})
    except Exception as e:
        logger.error(f'admin_list_card_requests error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def admin_review_card_request(cur, data, files, ts):
    try:
        require(data, 'id', 'decision')
        request_id = data['id']
        decision = (data['decision'] or '').strip().upper()
        if decision not in ('APPROVED', 'DECLINED'):
            return fail('Invalid decision')

        # Fetch once up front: this both answers the 404/409 checks AND
        # supplies user_profile_id for the APPROVED path, so there is no
        # separate lookup or reliance on the caller re-sending it.
        cur.execute(
            "SELECT r.id, r.status, r.card_id, r.user_profile_id, u.assign_card "
            "FROM app_card_request r LEFT JOIN app_users u ON u.id = r.user_profile_id "
            "WHERE r.id=%s",
            (request_id,),
        )
        existing = cur.fetchone()
        if not existing:
            return fail('Card request not found', 404)
        if existing['status'] != 'PENDING':
            return fail('Card request already reviewed', 409)

        admin = data.get('_admin') or {}
        user_profile_id = existing['user_profile_id']
        scanned_card_id = existing.get('card_id')

        if decision == 'DECLINED':
            reason = sanitize(data.get('reason') or '') or ''
            if len(reason) < 10:
                return fail('reason must be at least 10 characters when rejecting a request')

            _ensure_columns(cur)
            cur.execute("""
                UPDATE app_card_request
                   SET status='DECLINED', date_declined=%s, decline_reason=%s
                 WHERE id=%s AND status='PENDING'
            """, (ts, reason, request_id))
            if cur.rowcount == 0:
                # Lost a race between the SELECT above and this UPDATE.
                return fail('Card request already reviewed', 409)

            record_audit_log(cur, admin.get('id'), admin.get('role'),
                              'admin_review_card_request', 'card_request',
                              request_id, {'decision': 'DECLINED', 'reason': reason}, ts)
            return ok({'status': True, 'message': 'Card request declined'})

        # Guard against clobbering an existing card assignment: nothing in
        # this codebase ever puts an app_qr_code row back to AVAILABLE, so
        # blindly overwriting assign_card here would orphan the user's
        # current card permanently as status='USED' with no owner. Checked
        # up front, before any write, using the assign_card fetched
        # alongside the request row above.
        if existing.get('assign_card'):
            return fail('User already has a card assigned', 409)

        # APPROVED: claim the request first (status only — date_approved is
        # stamped together with card_id once a card is actually assigned,
        # so a single UPDATE carries both facts instead of splitting them
        # across two writes).
        #
        # For a citizen-scanned card (scanned_card_id set), this is 3 writes
        # across 2 tables (app_card_request claim, app_users assignment,
        # app_card_request stamp) — app_qr_code is never touched, see the
        # scanned_card_id branch below. For a staff-picked pool card (no
        # scanned_card_id), it's 4 writes across 3 tables, the app_qr_code
        # claim included. Either way this runs under autocommit with no
        # implicit transaction, so wrap the whole sequence in an explicit
        # one: a genuine exception partway through would otherwise leave a
        # card permanently USED (pool path) or the request claimed with
        # nothing to show for it. The "no card available" and "lost the
        # race for this card" outcomes below are NOT exceptions — they're
        # deliberate business outcomes whose compensating "put it back to
        # PENDING" write must commit normally, like any other successful
        # path, so both still flow to commit().
        cur.connection.begin()
        try:
            cur.execute("""
                UPDATE app_card_request
                   SET status='APPROVED'
                 WHERE id=%s AND status='PENDING'
            """, (request_id,))
            if cur.rowcount == 0:
                cur.connection.commit()
                return fail('Card request already reviewed', 409)

            if scanned_card_id:
                # The citizen already scanned a specific physical card,
                # resolved through app_cvl_list at request_card_link time —
                # that table (already ACTIVE-gated then) is the source of
                # truth for whether this card is legitimate, NOT
                # app_qr_code.status: that already went AVAILABLE->USED in
                # set_cvl_qr_bataan the moment staff tied the QR to the CVL
                # record, independent of any citizen ever claiming it, so
                # it's never AVAILABLE by the time a request reaches here.
                # app_qr_code is intentionally never written in this branch.
                card_id = scanned_card_id
                cur.execute(
                    "SELECT id FROM app_users WHERE assign_card=%s AND id!=%s LIMIT 1",
                    (card_id, user_profile_id),
                )
                if cur.fetchone():
                    # This exact card is already linked to a different
                    # account (only possible via a name+birthdate collision
                    # at auto-link time, or a data anomaly) — don't silently
                    # reassign it. Roll the claim back to PENDING so staff
                    # can investigate instead of approving blindly.
                    cur.execute("""
                        UPDATE app_card_request SET status='PENDING' WHERE id=%s
                    """, (request_id,))
                    cur.connection.commit()
                    return fail('This card is already linked to a different account', 409)
            else:
                cur.execute("""
                    SELECT id FROM app_qr_code WHERE status='AVAILABLE' ORDER BY id ASC LIMIT 1
                """)
                available = cur.fetchone()
                if not available:
                    # Roll the request claim back to PENDING — nothing was actually assigned.
                    cur.execute("""
                        UPDATE app_card_request SET status='PENDING' WHERE id=%s
                    """, (request_id,))
                    cur.connection.commit()
                    return fail('No available cards to assign', 409)

                card_id = available['id']
                cur.execute("""
                    UPDATE app_qr_code
                       SET status='USED', date_assigned=%s, date_updated=%s
                     WHERE id=%s AND status='AVAILABLE'
                """, (ts, ts, card_id))
                if cur.rowcount == 0:
                    # Lost a race for this exact card to another approval; roll the
                    # request claim back to PENDING so it can be retried.
                    cur.execute("""
                        UPDATE app_card_request SET status='PENDING' WHERE id=%s
                    """, (request_id,))
                    cur.connection.commit()
                    return fail('The selected card was just claimed by another request; please retry', 409)

            cur.execute("""
                UPDATE app_users SET assign_card=%s WHERE id=%s
            """, (card_id, user_profile_id))
            if cur.rowcount == 0:
                # user_profile_id doesn't match a real row (stale/deleted
                # account) — the UPDATE silently no-opped. Don't let the
                # flow continue on to mark the card USED and the request
                # APPROVED with nobody actually assigned; abort the whole
                # transaction so the qr_code and request claims above are
                # undone too.
                raise Exception(f'app_users update matched no row for id={user_profile_id}')

            cur.execute("""
                UPDATE app_card_request SET card_id=%s, date_approved=%s WHERE id=%s
            """, (card_id, ts, request_id))

            cur.connection.commit()
        except Exception:
            cur.connection.rollback()
            raise

        record_audit_log(cur, admin.get('id'), admin.get('role'),
                          'admin_review_card_request', 'card_request',
                          request_id, {'decision': 'APPROVED', 'card_id': card_id}, ts)
        return ok({'status': True, 'message': 'Card request approved', 'card_id': card_id})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'admin_review_card_request error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def admin_get_card_request_detail(cur, data, files, ts):
    """Return a card request joined with the requesting user's profile fields
    for the admin detail page (name, contact info, address, account status)."""
    try:
        require(data, 'id')
        request_id = data['id']

        _ensure_columns(cur)
        cur.execute("""
            SELECT r.id, r.type, r.date_requested, r.date_approved, r.date_declined,
                   r.verify_photo, r.status, r.decline_reason, r.card_id, r.user_profile_id,
                   u.fullname, u.first_name, u.last_name, u.email_address, u.mobile_number,
                   u.gender, u.birth_date, u.address, u.user_status, u.assign_card,
                   q.qr_code AS assigned_qr_code
            FROM app_card_request r
            LEFT JOIN app_users u ON u.id = r.user_profile_id
            LEFT JOIN app_qr_code q ON q.id = r.card_id
            WHERE r.id=%s
        """, (request_id,))
        row = cur.fetchone()
        if not row:
            return fail('Card request not found', 404)

        return ok({'status': True, 'data': serialize_row(row)})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'admin_get_card_request_detail error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def admin_search_qr_codes(cur, data, files, ts):
    """Search AVAILABLE app_qr_code rows by qr_code substring for the
    "Search available QR codes" picker. Empty search returns the oldest
    available codes first, matching the auto-assign order used elsewhere."""
    try:
        _ensure_qr_indexes(cur)

        search = sanitize(data.get('search'))
        limit = min(max(parse_int(data.get('limit')) or 50, 1), 100)

        where = "status='AVAILABLE'"
        params = []
        if search:
            where += " AND qr_code LIKE %s"
            params.append(f'%{search}%')

        cur.execute(f"""
            SELECT id, qr_code FROM app_qr_code
            WHERE {where}
            ORDER BY id ASC
            LIMIT %s
        """, tuple(params + [limit]))
        rows = cur.fetchall() or []

        return ok({'status': True, 'data': {'items': [serialize_row(r) for r in rows]}})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'admin_search_qr_codes error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def admin_assign_card(cur, data, files, ts):
    """Manually assign an admin-chosen app_qr_code to a PENDING card request,
    the counterpart to admin_review_card_request's auto-assign APPROVED path."""
    try:
        require(data, 'id', 'qr_code_id')
        request_id = data['id']
        qr_code_id = data['qr_code_id']

        cur.execute(
            "SELECT r.id, r.status, r.user_profile_id, u.assign_card "
            "FROM app_card_request r LEFT JOIN app_users u ON u.id = r.user_profile_id "
            "WHERE r.id=%s",
            (request_id,),
        )
        existing = cur.fetchone()
        if not existing:
            return fail('Card request not found', 404)
        if existing['status'] != 'PENDING':
            return fail('Card request already reviewed', 409)
        if existing.get('assign_card'):
            return fail('User already has a card assigned', 409)

        admin = data.get('_admin') or {}
        user_profile_id = existing['user_profile_id']

        # Same claim-then-stamp sequence as admin_review_card_request's
        # APPROVED path, wrapped in an explicit transaction for the same
        # reason: a failure between claiming the QR code and stamping the
        # request must not leave a card USED with nothing to show for it.
        cur.connection.begin()
        try:
            cur.execute("""
                UPDATE app_card_request
                   SET status='APPROVED'
                 WHERE id=%s AND status='PENDING'
            """, (request_id,))
            if cur.rowcount == 0:
                cur.connection.commit()
                return fail('Card request already reviewed', 409)

            cur.execute("""
                UPDATE app_qr_code
                   SET status='USED', date_assigned=%s, date_updated=%s
                 WHERE id=%s AND status='AVAILABLE'
            """, (ts, ts, qr_code_id))
            if cur.rowcount == 0:
                cur.execute("""
                    UPDATE app_card_request SET status='PENDING' WHERE id=%s
                """, (request_id,))
                cur.connection.commit()
                return fail('The selected QR code is no longer available', 409)

            cur.execute("""
                UPDATE app_users SET assign_card=%s WHERE id=%s
            """, (qr_code_id, user_profile_id))
            if cur.rowcount == 0:
                raise Exception(f'app_users update matched no row for id={user_profile_id}')

            cur.execute("""
                UPDATE app_card_request SET card_id=%s, date_approved=%s WHERE id=%s
            """, (qr_code_id, ts, request_id))

            cur.connection.commit()
        except Exception:
            cur.connection.rollback()
            raise

        record_audit_log(cur, admin.get('id'), admin.get('role'),
                          'admin_assign_card', 'card_request',
                          request_id, {'qr_code_id': qr_code_id}, ts)
        return ok({'status': True, 'message': 'Card assigned', 'card_id': qr_code_id})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'admin_assign_card error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)
