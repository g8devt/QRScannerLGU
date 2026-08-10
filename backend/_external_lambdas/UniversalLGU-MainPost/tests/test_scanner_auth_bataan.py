import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from helpers.scanner_auth_bataan import hash_scanner_password


class HashScannerPasswordTest(unittest.TestCase):
    def test_same_password_hashes_the_same(self):
        self.assertEqual(hash_scanner_password('Secret123'), hash_scanner_password('Secret123'))

    def test_different_passwords_hash_differently(self):
        self.assertNotEqual(hash_scanner_password('Secret123'), hash_scanner_password('Other456'))

    def test_returns_hex_sha256_digest(self):
        result = hash_scanner_password('Secret123')
        self.assertEqual(len(result), 64)
        int(result, 16)  # raises ValueError if not valid hex
