import hmac
import logging
from helpers.auth import ok, fail, require
from helpers.db import sanitize, serialize_row
from helpers.scanner_auth_bataan import hash_scanner_password

logger = logging.getLogger()


def login_scanner_bataan(cur, data, files, ts):
    """Authenticate scanner-app staff against app_users_scanner by
    username/password (distinct from the citizen app_users mobile+PIN
    login).

    Always responds 200 with a `login_status` discriminant --
    'SUCCESS' | 'INVALID_CREDENTIAL' | 'INACTIVE' | 'DEACTIVATED' -- instead
    of using fail()/non-200 for a wrong password or a blocked account,
    mirroring check_scanner_status_bataan's pattern so the app can tell
    each outcome apart cleanly. The `fail()` path is reserved for missing
    params or an unexpected server error.

    SECURITY: the account's is_active/user_status is only ever inspected
    -- let alone revealed -- AFTER the submitted password has been
    verified correct for that username. A wrong password (for any
    account, active or not) always resolves to INVALID_CREDENTIAL,
    exactly as before this change. This intentionally reveals
    inactive/deactivated status to a caller who already knows the correct
    password (a deliberate, requested tradeoff for this controlled staff
    roster, so legitimate staff are told why they're locked out), but
    never to a caller who doesn't -- so this can't become an
    unauthenticated account-status oracle."""
    try:
        require(data, 'username', 'password')
        username = sanitize(data['username'])
        if not username:
            return ok({'status': True, 'login_status': 'INVALID_CREDENTIAL'})
        hashed = hash_scanner_password(data['password'])

        cur.execute("SELECT * FROM app_users_scanner WHERE username=%s", (username,))
        user = cur.fetchone()
        if not user or not hmac.compare_digest(user['password'], hashed):
            return ok({'status': True, 'login_status': 'INVALID_CREDENTIAL'})

        user_status = (user.get('user_status') or '').strip()
        is_active = bool(user.get('is_active'))
        if user_status == 'DEACTIVATED':
            # Takes priority over INACTIVE when both apply -- DEACTIVATED
            # is the more specific admin action.
            return ok({'status': True, 'login_status': 'DEACTIVATED'})
        if not is_active:
            return ok({'status': True, 'login_status': 'INACTIVE'})

        row = serialize_row(user)
        row.pop('password', None)
        return ok({
            'status': True,
            'login_status': 'SUCCESS',
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


def check_scanner_status_bataan(cur, data, files, ts):
    """Revalidates an existing scanner-app session against the current
    app_users_scanner row. Backs the app's auto-login/Remember Me flow so
    a cached local session can never grant access after an admin
    deactivates the account -- the app must call this on every launch and
    treat only `is_valid: true` as permission to enter.

    Always responds 200 with `is_valid` (including when no matching row
    exists, or the account is inactive/deactivated) -- callers must NOT
    treat `is_valid: false` as a network/server error, only as "this
    account may no longer access the app". The `fail()` path here is
    reserved for a missing `user_profile_id` or an unexpected server
    error, both of which the caller should treat as a revalidation
    failure distinct from a confirmed rejection (fail closed, but don't
    show 'Account Inactive' for those)."""
    try:
        require(data, 'user_profile_id')
        user_profile_id = sanitize(data['user_profile_id'])

        cur.execute(
            "SELECT is_active, user_status FROM app_users_scanner WHERE id=%s LIMIT 1",
            (user_profile_id,),
        )
        row = cur.fetchone()
        if not row:
            return ok({'status': True, 'is_valid': False})

        is_active = row['is_active'] if isinstance(row, dict) else row[0]
        user_status = row['user_status'] if isinstance(row, dict) else row[1]
        is_valid = bool(is_active) and (user_status or '').strip() != 'DEACTIVATED'
        return ok({'status': True, 'is_valid': is_valid})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"check_scanner_status_bataan error: {e}", exc_info=True)
        return fail('Server error', 500)


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
