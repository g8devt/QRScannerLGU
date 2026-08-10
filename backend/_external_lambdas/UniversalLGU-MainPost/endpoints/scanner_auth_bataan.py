import logging
from helpers.auth import ok, fail, require
from helpers.db import sanitize, serialize_row
from helpers.scanner_auth_bataan import hash_scanner_password

logger = logging.getLogger()


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
            "SELECT * FROM app_users_scanner WHERE LOWER(username)=LOWER(%s) "
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
        return fail(f'Server error: {e}', 500)
