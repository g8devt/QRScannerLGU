"""Kabaka Smart Card link requests.

A user without an `assign_card` yet can ask staff to link an existing
Kabaka Smart Card to their profile. This creates a row in
`app_card_request` (type=REQUEST, status=PENDING) for staff to action —
distinct from `app_card_registrations`, which is a full new-card
application.
"""

import logging

from helpers.auth import ok, fail, require
from helpers.audit import record_audit_log
from helpers.db import serialize_row
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


_CARD_REQUEST_STATUSES = {'PENDING', 'APPROVED', 'DECLINED'}


def request_card_link(cur, data, files, ts):
    """Create a PENDING link request for the caller, or return the existing one.

    Requires `user_profile_id`. Responds with `{status, status: 'PENDING'}`.
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

        cur.execute("""
            INSERT INTO app_card_request (
                type, date_requested, verify_photo, status, card_id, user_profile_id
            ) VALUES (
                'REQUEST', %s, NULL, 'PENDING', NULL, %s
            )
        """, (ts, user_id))

        return ok({'status': True, 'request_status': 'PENDING'})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'request_card_link error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def get_card_request_status(cur, data, files, ts):
    """Return the caller's most recent card-link request status, or 'NONE'."""
    try:
        require(data, 'user_profile_id')
        cur.execute("""
            SELECT status FROM app_card_request
            WHERE user_profile_id=%s
            ORDER BY date_requested DESC
            LIMIT 1
        """, (data['user_profile_id'],))
        row = cur.fetchone()
        return ok({'status': True, 'request_status': row['status'] if row else 'NONE'})
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

        where = []
        params = []
        if status and status != 'ALL':
            if status not in _CARD_REQUEST_STATUSES:
                return fail(f'Invalid status: {status}')
            where.append('r.status=%s')
            params.append(status)
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
        return ok({'status': True,
                   'data': {'items': [serialize_row(r) for r in rows],
                            'page': page, 'has_more': has_more}})
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

        admin = data.get('_admin') or {}
        user_profile_id = existing['user_profile_id']

        if decision == 'DECLINED':
            cur.execute("""
                UPDATE app_card_request
                   SET status='DECLINED', date_declined=%s
                 WHERE id=%s AND status='PENDING'
            """, (ts, request_id))
            if cur.rowcount == 0:
                # Lost a race between the SELECT above and this UPDATE.
                return fail('Card request already reviewed', 409)

            record_audit_log(cur, admin.get('id'), admin.get('role'),
                              'admin_review_card_request', 'card_request',
                              request_id, {'decision': 'DECLINED'}, ts)
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
        # This spans four writes across three tables (app_card_request
        # claim, app_qr_code claim, app_users assignment, app_card_request
        # stamp) under autocommit with no implicit transaction, so wrap the
        # whole sequence in an explicit one: a genuine exception between the
        # app_qr_code claim and the final stamp would otherwise leave a card
        # permanently USED with nothing to show for it. The "no card
        # available" and "lost the race for this card" outcomes below are
        # NOT exceptions — they're deliberate business outcomes whose
        # compensating "put it back to PENDING" write must commit normally,
        # like any other successful path, so both still flow to commit().
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
