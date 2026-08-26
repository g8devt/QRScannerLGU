"""CVL (civil registry / voter list) record lookup by QR code.

Read-only lookup for the scanner app's staff-facing "Check CVL Record"
flow. Mirrors the join and match logic already used by
`bataan_lgu_admin`'s `EMS/api/find_cvl_by_qr.php` (a separate PHP-session
codebase, not called by this app) — `app_cvl_list.cvl_qr` is a foreign key
into `app_qr_code.id`; `app_qr_code.qr_code` holds the human-readable
`QR-xxxxx` string printed/encoded on the physical code.
"""

import logging
import re

from helpers.auth import ok, fail, require
from helpers.db import serialize_row
from helpers.s3 import upload_files_from_list

logger = logging.getLogger()

# Shared by every endpoint in this module that returns a full CVL record
# (as opposed to the lightweight rows `search_cvl_by_name_bataan` returns
# for its results list) — keeps the two SELECTs from drifting apart.
_CVL_DETAIL_COLUMNS = """
    c.id, c.cvl_id, c.cvl_fullname, c.cvl_fname, c.cvl_mname,
    c.cvl_lname, c.cvl_suffix, c.cvl_address, c.cvl_mun,
    c.cvl_brgy, c.cvl_precinct_no, c.cvl_birthdate,
    c.cvl_contact_no, c.cvl_email, c.cvl_gender, c.cvl_sector,
    c.cvl_img_path, c.cvl_qr, q.qr_code AS cvl_qr_code
"""


def _numeric_suffix(value):
    """Strips everything but digits, e.g. 'QR-00042' -> '00042'."""
    return re.sub(r'\D+', '', value)


def find_cvl_by_qr_bataan(cur, data, files, ts):
    """Looks up `app_cvl_list` by a scanned QR value.

    Requires `qr_code` — the raw value decoded off the scanned QR (may be
    the full `QR-xxxxx` string, its bare numeric suffix, or the
    `app_qr_code.id` itself if the scanned value is purely numeric).
    Responds with `{status, data}` on a match, or a 404 `fail(...)` with
    a fixed human-readable message when nothing matches.
    """
    try:
        require(data, 'qr_code')
        raw_value = (data.get('qr_code') or '').strip()
        if not raw_value:
            return fail('Missing qr_code')

        numeric_value = _numeric_suffix(raw_value)
        is_numeric = raw_value.isdigit()
        numeric_id = int(raw_value) if is_numeric else 0

        cur.execute(
            f"""
            SELECT {_CVL_DETAIL_COLUMNS}
            FROM app_cvl_list c
            INNER JOIN app_qr_code q ON q.id = c.cvl_qr
            WHERE q.qr_code = %s
               OR (%s != '' AND REPLACE(q.qr_code, 'QR-', '') = %s)
               OR (%s = 1 AND q.id = %s)
            ORDER BY
                CASE
                    WHEN q.qr_code = %s THEN 1
                    WHEN %s != '' AND REPLACE(q.qr_code, 'QR-', '') = %s THEN 2
                    WHEN %s = 1 AND q.id = %s THEN 3
                    ELSE 4
                END
            LIMIT 1
            """,
            (
                raw_value, numeric_value, numeric_value, 1 if is_numeric else 0, numeric_id,
                raw_value, numeric_value, numeric_value, 1 if is_numeric else 0, numeric_id,
            ),
        )
        row = cur.fetchone()
        if not row:
            return fail('No CVL record was found for this QR code.', 404)

        return ok({'status': True, 'data': serialize_row(row)})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'find_cvl_by_qr_bataan error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def update_cvl_photo_bataan(cur, data, files, ts):
    """Replaces a CVL record's photo (`cvl_img_path`).

    The only write this module performs — everything else on this record
    stays read-only from the app, per the design spec. Requires `id` (the
    `app_cvl_list` primary key, from a prior `find_cvl_by_qr_bataan` call)
    and a `cvl_photo` file. Uploads to S3 (mirrors the pattern in
    `social_services_bataan.submit_claim_bataan`) and overwrites
    `cvl_img_path` with the resulting URL — a fresh upload each time, no
    reuse of the previous file. Responds with `{status, data: {cvl_img_path}}`
    on success, or a 404 `fail(...)` if the record doesn't exist.
    """
    try:
        require(data, 'id')
        record_id = data['id']

        provided_fields = {f['field_name'] for f in files}
        if 'cvl_photo' not in provided_fields:
            return fail('Missing: cvl_photo')

        cur.execute('SELECT id FROM app_cvl_list WHERE id=%s LIMIT 1', (record_id,))
        if not cur.fetchone():
            return fail('CVL record not found', 404)

        updated_by = (data.get('updated_by') or '').strip() or 'MOBILE_SCANNER'

        file_urls = upload_files_from_list(files, f'cvl/{record_id}', record_id)
        new_url = file_urls.get('cvl_photo')
        if not new_url:
            return fail('Photo upload failed', 500)

        cur.execute(
            """
            UPDATE app_cvl_list
            SET cvl_img_path=%s, cvl_updated_by=%s, cvl_last_date_updated=%s
            WHERE id=%s
            """,
            (new_url, updated_by, ts, record_id),
        )

        return ok({'status': True, 'data': {'cvl_img_path': new_url}})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'update_cvl_photo_bataan error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def get_cvl_by_id_bataan(cur, data, files, ts):
    """Looks up a single `app_cvl_list` record by its primary key.

    Used by the search flow: `search_cvl_by_name_bataan` returns
    lightweight rows, and tapping one calls this to load the full detail
    view. Unlike `find_cvl_by_qr_bataan`, this `LEFT JOIN`s
    `app_qr_code` — a record with no QR assigned yet is still a valid
    result here (search intentionally surfaces those; scanning obviously
    can't).
    """
    try:
        require(data, 'id')
        record_id = data['id']

        cur.execute(
            f"""
            SELECT {_CVL_DETAIL_COLUMNS}
            FROM app_cvl_list c
            LEFT JOIN app_qr_code q ON q.id = c.cvl_qr
            WHERE c.id = %s
            LIMIT 1
            """,
            (record_id,),
        )
        row = cur.fetchone()
        if not row:
            return fail('CVL record not found', 404)

        return ok({'status': True, 'data': serialize_row(row)})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'get_cvl_by_id_bataan error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def set_cvl_qr_bataan(cur, data, files, ts):
    """Assigns a freshly-scanned QR code to a CVL record — the "Search CVL
    Record" list's Set QR action.

    Requires `id` (the `app_cvl_list` primary key) and `qr_code` (the raw
    scanned value, e.g. `QR-00042`). Rejects with a 404/409 `fail(...)`
    (never a 500) for every expected case: the record doesn't exist, it
    already has a QR assigned, the code isn't registered in
    `app_qr_code`, or that code is already in use — so the app can show
    each as a specific, actionable message instead of a generic error.

    The claim itself is done as a single conditional `UPDATE ... WHERE
    status='AVAILABLE'`, not a SELECT-then-UPDATE — with `autocommit`
    (see `helpers.db.get_conn`) and no explicit transaction, a
    SELECT-then-UPDATE would leave a window for two staff members
    scanning the same code at once to both pass the check. Checking
    `cur.rowcount` after the conditional UPDATE is what actually
    prevents that: only one of two racing requests can move the row from
    AVAILABLE to USED.

    Responds with `{status, data: {cvl_qr_code}}` on success — the same
    `cvl_qr_code` field name `find_cvl_by_qr_bataan` /
    `search_cvl_by_name_bataan` use for the joined `app_qr_code.qr_code`.
    """
    try:
        require(data, 'id', 'qr_code')
        record_id = data['id']
        qr_code = (data.get('qr_code') or '').strip()
        if not qr_code:
            return fail('Missing qr_code')

        cur.execute(
            'SELECT id, cvl_qr FROM app_cvl_list WHERE id=%s LIMIT 1',
            (record_id,),
        )
        record = cur.fetchone()
        if not record:
            return fail('CVL record not found', 404)
        if record['cvl_qr']:
            return fail('This record already has a QR code assigned.', 409)

        cur.execute(
            'SELECT id, status FROM app_qr_code WHERE qr_code=%s LIMIT 1',
            (qr_code,),
        )
        qr_row = cur.fetchone()
        if not qr_row:
            return fail('This QR code is not registered.', 404)
        if qr_row['status'] != 'AVAILABLE':
            return fail('This QR code is already in use.', 409)

        cur.execute(
            "UPDATE app_qr_code SET status='USED', date_updated=%s "
            "WHERE id=%s AND status='AVAILABLE'",
            (ts, qr_row['id']),
        )
        if cur.rowcount != 1:
            # Lost the race to another request between the SELECT above
            # and this UPDATE — the code is spoken for either way.
            return fail('This QR code is already in use.', 409)

        cur.execute(
            'UPDATE app_cvl_list SET cvl_qr=%s, cvl_last_date_updated=%s WHERE id=%s',
            (qr_row['id'], ts, record_id),
        )

        return ok({'status': True, 'data': {'cvl_qr_code': qr_code}})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'set_cvl_qr_bataan error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


_SEARCH_PAGE_SIZE = 25


def search_cvl_by_name_bataan(cur, data, files, ts):
    """Searches `app_cvl_list` by full name for the scanner app's staff-
    facing "Search CVL Record" flow (a separate entry point from
    scanning a QR).

    Requires `name`, at least 2 characters after trimming. Mirrors
    `bataan_lgu_admin`'s `EMS/index.php` search logic: each whitespace-
    separated keyword of 3+ alphanumeric characters becomes a `+word*`
    fulltext boolean-mode term (prefix match, via the `ft_cvl_fullname`
    index); if any keyword is shorter than that, the whole search falls
    back to `LIKE '%word%'` per keyword instead (fulltext's default
    minimum indexed word length would silently drop short words).
    `LEFT JOIN`s `app_qr_code` so records with no QR assigned yet still
    show up. Paginated: optional `offset` (default 0) skips that many
    matches, ordered by name; each page holds up to 25 rows. Fetches one
    extra row past the page size to detect whether another page exists,
    rather than inferring it from a full page (which would misreport a
    result count that's an exact multiple of the page size as final).
    Responds with `{status, data: {results, has_more}}` — `results` is a
    list of lightweight rows (id, name, location, QR code if any), not
    the full record; `has_more` is true when another page of matches
    exists beyond this one.
    """
    try:
        require(data, 'name')
        raw_term = (data.get('name') or '').strip()
        if len(raw_term) < 2:
            return fail('Enter at least 2 characters to search')

        try:
            offset = int(data.get('offset') or 0)
        except (TypeError, ValueError):
            return fail('Invalid offset')
        if offset < 0:
            return fail('Invalid offset')

        keywords = [k for k in re.split(r'\s+', raw_term) if k]

        fulltext_terms = []
        can_use_fulltext = True
        for keyword in keywords:
            normalized = re.sub(r'[^0-9A-Za-z]+', '', keyword)
            if len(normalized) < 3:
                can_use_fulltext = False
                break
            fulltext_terms.append(f'+{normalized}*')

        if can_use_fulltext and fulltext_terms:
            where_clause = 'MATCH(c.cvl_fullname) AGAINST (%s IN BOOLEAN MODE)'
            params = [' '.join(fulltext_terms)]
        else:
            conditions = []
            params = []
            for keyword in keywords:
                conditions.append('c.cvl_fullname LIKE %s')
                params.append(f'%{keyword}%')
            where_clause = ' AND '.join(conditions)

        cur.execute(
            f"""
            SELECT c.id, c.cvl_fullname, c.cvl_mun, c.cvl_brgy,
                   q.qr_code AS cvl_qr_code
            FROM app_cvl_list c
            LEFT JOIN app_qr_code q ON q.id = c.cvl_qr
            WHERE {where_clause}
            ORDER BY c.cvl_fullname
            LIMIT {_SEARCH_PAGE_SIZE + 1} OFFSET %s
            """,
            tuple(params) + (offset,),
        )
        rows = cur.fetchall()
        has_more = len(rows) > _SEARCH_PAGE_SIZE
        rows = rows[:_SEARCH_PAGE_SIZE]

        return ok({
            'status': True,
            'data': {
                'results': [serialize_row(r) for r in rows],
                'has_more': has_more,
            },
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'search_cvl_by_name_bataan error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)
