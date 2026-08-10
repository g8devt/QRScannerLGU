import hashlib

# Must exactly match functions/login_post/lambda_function.py::hash_pin —
# same static salt, same algorithm — since that separate Lambda verifies
# against the same app_users.pin_code_pass column this writes to. login_post
# is a different CodeUri and can't be imported across function boundaries,
# so this is a deliberate, minimal duplication (same rationale as the
# existing per-function db.py duplication in kyc_ws/ and admin_auth/).
_PIN_SALT = "LGU_SUPER_SECURE_SALT_2026"


def hash_pin(pin):
    return hashlib.sha256((str(pin) + _PIN_SALT).encode('utf-8')).hexdigest()
