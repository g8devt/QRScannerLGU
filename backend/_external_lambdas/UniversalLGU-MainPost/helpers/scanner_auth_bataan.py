import hashlib

# Static-salt SHA-256 hash for app_users_scanner.password. Mirrors
# helpers/pin.py's hash_pin, but uses its own salt constant since this is a
# distinct credential domain (scanner-staff username/password, not the
# citizen app's mobile+PIN).
_SCANNER_PASSWORD_SALT = "LGU_SCANNER_BATAAN_SALT_2026"


def hash_scanner_password(password):
    return hashlib.sha256((str(password) + _SCANNER_PASSWORD_SALT).encode('utf-8')).hexdigest()
