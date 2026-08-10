import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import json
from unittest.mock import MagicMock

from helpers.scanner_auth_bataan import hash_scanner_password
from endpoints.scanner_auth_bataan import login_scanner_bataan


class HashScannerPasswordTest(unittest.TestCase):
    def test_same_password_hashes_the_same(self):
        self.assertEqual(hash_scanner_password('Secret123'), hash_scanner_password('Secret123'))

    def test_different_passwords_hash_differently(self):
        self.assertNotEqual(hash_scanner_password('Secret123'), hash_scanner_password('Other456'))

    def test_returns_hex_sha256_digest(self):
        result = hash_scanner_password('Secret123')
        self.assertEqual(len(result), 64)
        int(result, 16)  # raises ValueError if not valid hex


class LoginScannerBataanTest(unittest.TestCase):
    def _cur(self, fetchone_return):
        cur = MagicMock()
        cur.fetchone.return_value = fetchone_return
        return cur

    def test_missing_fields_returns_400(self):
        cur = self._cur(None)
        result = login_scanner_bataan(cur, {'username': 'staff1'}, [], '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 400)

    def test_no_matching_user_returns_400_invalid_credential(self):
        cur = self._cur(None)
        result = login_scanner_bataan(
            cur, {'username': 'staff1', 'password': 'wrongpass'}, [], '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 400)
        body = json.loads(result['body'])
        self.assertEqual(body['message'], 'Invalid Credential')

    def test_password_is_hashed_before_query(self):
        cur = self._cur(None)
        login_scanner_bataan(cur, {'username': 'staff1', 'password': 'Secret123'}, [], '2026-08-10 00:00:00')
        args, _ = cur.execute.call_args
        params = args[1]
        self.assertIn(hash_scanner_password('Secret123'), params)

    def test_valid_credentials_returns_200_with_user_data(self):
        cur = self._cur({
            'id': 7, 'username': 'staff1', 'password': hash_scanner_password('Secret123'),
            'user_status': 'VERIFIED', 'firstname': 'Juan', 'middlename': '',
            'lastname': 'Dela Cruz', 'suffix': '', 'gender': 'MALE',
            'birth_date': '1990-01-01', 'mobile_number': '09171234567',
            'email_address': 'staff1@example.com', 'is_active': 1,
        })
        result = login_scanner_bataan(
            cur, {'username': 'staff1', 'password': 'Secret123'}, [], '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 200)
        body = json.loads(result['body'])
        self.assertTrue(body['status'])
        self.assertEqual(body['user_profile_id'], '7')
        self.assertNotIn('password', body['data'])
