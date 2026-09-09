import hashlib
import hmac
import os
import binascii

_ALGO = 'pbkdf2_sha256'
_ITERATIONS = 200_000


def hash_password(plain_password):
    salt = os.urandom(16)
    dk = hashlib.pbkdf2_hmac('sha256', plain_password.encode('utf-8'), salt, _ITERATIONS)
    return f"{_ALGO}${_ITERATIONS}${binascii.hexlify(salt).decode()}${binascii.hexlify(dk).decode()}"


def verify_password(plain_password, stored_hash):
    try:
        algo, iterations_str, salt_hex, hash_hex = stored_hash.split('$')
        if algo != _ALGO:
            return False
        iterations = int(iterations_str)
        salt = binascii.unhexlify(salt_hex)
        expected = binascii.unhexlify(hash_hex)
    except (ValueError, AttributeError, binascii.Error):
        return False
    actual = hashlib.pbkdf2_hmac('sha256', plain_password.encode('utf-8'), salt, iterations)
    return hmac.compare_digest(actual, expected)
