import logging
from helpers.auth import ok, fail, require
from helpers.db import sanitize

logger = logging.getLogger()


def _parse_version(value):
    """Parse a 'major.minor.patch' string into a comparable int tuple.
    Non-numeric or missing segments become 0, so '1.9' < '1.10.0'
    compares correctly instead of falling back to string ordering."""
    parts = []
    for segment in str(value or '0').strip().split('.'):
        digits = ''.join(ch for ch in segment if ch.isdigit())
        parts.append(int(digits) if digits else 0)
    while len(parts) < 3:
        parts.append(0)
    return tuple(parts[:3])


def check_app_version_bataan(cur, data, files, ts):
    """Compare the main citizen app's installed version against the latest
    ACTIVE app_version row for app_code=MAIN_APP, so the splash flow can
    offer an optional update before Login. Never blocks Login on its own -
    callers should treat any failure response as 'no update available'."""
    try:
        require(data, 'os_type', 'current_version')
        os_type = sanitize(data['os_type']).upper()
        current_version = sanitize(data['current_version'])

        cur.execute(
            "SELECT version FROM app_version "
            "WHERE app_code='MAIN_APP' AND os_type=%s AND is_active='ACTIVE' "
            "ORDER BY id DESC LIMIT 1",
            (os_type,),
        )
        row = cur.fetchone()
        if not row:
            return ok({'status': True, 'update_required': False})

        latest_version = row['version'] if isinstance(row, dict) else row[0]

        update_required = _parse_version(current_version) < _parse_version(latest_version)
        return ok({
            'status': True,
            'update_required': update_required,
            'latest_version': latest_version,
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"check_app_version_bataan error: {e}", exc_info=True)
        return fail('Server error', 500)
