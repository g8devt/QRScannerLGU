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

logger = logging.getLogger()


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
            """
            SELECT c.id, c.cvl_id, c.cvl_fullname, c.cvl_fname, c.cvl_mname,
                   c.cvl_lname, c.cvl_suffix, c.cvl_address, c.cvl_mun,
                   c.cvl_brgy, c.cvl_precinct_no, c.cvl_birthdate,
                   c.cvl_contact_no, c.cvl_email, c.cvl_gender, c.cvl_sector,
                   c.cvl_img_path, c.cvl_qr, q.qr_code AS cvl_qr_code
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
