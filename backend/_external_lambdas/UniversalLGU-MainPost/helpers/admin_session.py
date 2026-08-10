import os
import jwt

# Read-only mirror of admin_auth/helpers/jwt_helper.py's verification side
# (same algorithm, same fail-closed minimum-secret-length posture). This
# Lambda never issues admin session tokens -- admin login happens entirely
# inside admin_auth -- so only verify_token's logic is duplicated here, not
# issue_token's. Duplicated rather than imported because admin_auth is a
# separate Lambda CodeUri; this mirrors the same cross-Lambda-duplication
# rationale already established for helpers/pin.py and helpers/mobile.py
# in this codebase.
JWT_ALGO = 'HS256'
MIN_SECRET_LENGTH = 32


def _secret():
    return os.getenv('JWT_SECRET', '')


def verify_admin_token(token):
    secret = _secret()
    if len(secret) < MIN_SECRET_LENGTH:
        # Fail closed: never attempt to verify against a weak/empty/missing
        # key -- treat it as "no valid session", same posture as the
        # admin_auth side.
        return None
    try:
        return jwt.decode(token, secret, algorithms=[JWT_ALGO])
    except jwt.PyJWTError:
        return None
