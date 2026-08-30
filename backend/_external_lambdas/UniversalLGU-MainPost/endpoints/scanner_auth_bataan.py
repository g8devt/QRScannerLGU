import logging
from helpers.auth import ok, fail, require
from helpers.db import sanitize, serialize_row
from helpers.scanner_auth_bataan import hash_scanner_password

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


def check_app_version_scanner_bataan(cur, data, files, ts):
    """Compare the scanner app's installed version against the latest
    ACTIVE app_version row for app_code=SCANNER, so AuthGate can block
    staff on an outdated build before they reach login."""
    try:
        require(data, 'os_type', 'current_version')
        os_type = sanitize(data['os_type']).upper()
        current_version = sanitize(data['current_version'])

        cur.execute(
            "SELECT version, url FROM app_version "
            "WHERE app_code='SCANNER' AND os_type=%s AND is_active='ACTIVE' "
            "ORDER BY id DESC LIMIT 1",
            (os_type,),
        )
        row = cur.fetchone()
        if not row:
            return ok({'status': True, 'update_required': False})

        latest_version = row['version'] if isinstance(row, dict) else row[0]
        url = row['url'] if isinstance(row, dict) else row[1]

        update_required = _parse_version(current_version) < _parse_version(latest_version)
        return ok({
            'status': True,
            'update_required': update_required,
            'latest_version': latest_version,
            'url': url if update_required else None,
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"check_app_version_scanner_bataan error: {e}", exc_info=True)
        return fail('Server error', 500)


def login_scanner_bataan(cur, data, files, ts):
    """Authenticate scanner-app staff against app_users_scanner by
    username/password (distinct from the citizen app_users mobile+PIN
    login)."""
    try:
        require(data, 'username', 'password')
        username = sanitize(data['username'])
        if not username:
            return fail('Invalid Credential')
        hashed = hash_scanner_password(data['password'])

        cur.execute(
            "SELECT * FROM app_users_scanner WHERE username=%s "
            "AND password=%s AND is_active=1 AND user_status != 'DEACTIVATED'",
            (username, hashed),
        )
        user = cur.fetchone()
        if not user:
            return fail('Invalid Credential')

        row = serialize_row(user)
        row.pop('password', None)
        return ok({
            'status': True,
            'message': 'Login Successfully',
            'user_profile_id': str(user['id']),
            'username': user['username'],
            'user_status': user.get('user_status', ''),
            'data': row,
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"login_scanner_bataan error: {e}", exc_info=True)
        return fail('Server error', 500)
