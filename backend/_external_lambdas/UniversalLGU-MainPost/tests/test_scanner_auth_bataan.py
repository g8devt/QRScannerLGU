import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import json
from unittest.mock import MagicMock

from helpers.scanner_auth_bataan import hash_scanner_password
from endpoints.scanner_auth_bataan import login_scanner_bataan, check_scanner_status_bataan


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

    def _row(self, password='Secret123', user_status='VERIFIED', is_active=1):
        return {
            'id': 7, 'username': 'staff1', 'password': hash_scanner_password(password),
            'user_status': user_status, 'firstname': 'Juan', 'middlename': '',
            'lastname': 'Dela Cruz', 'suffix': '', 'gender': 'MALE',
            'birth_date': '1990-01-01', 'mobile_number': '09171234567',
            'email_address': 'staff1@example.com', 'is_active': is_active,
        }

    def test_missing_fields_returns_400(self):
        cur = self._cur(None)
        result = login_scanner_bataan(cur, {'username': 'staff1'}, [], '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 400)

    def test_unknown_username_returns_200_invalid_credential(self):
        cur = self._cur(None)
        result = login_scanner_bataan(
            cur, {'username': 'staff1', 'password': 'wrongpass'}, [], '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 200)
        body = json.loads(result['body'])
        self.assertTrue(body['status'])
        self.assertEqual(body['login_status'], 'INVALID_CREDENTIAL')

    def test_query_only_filters_by_username_not_password_or_status(self):
        # Status must never be inspected before the password is verified --
        # verified separately below (wrong password on an inactive account
        # still returns INVALID_CREDENTIAL, never a status outcome).
        cur = self._cur(None)
        login_scanner_bataan(cur, {'username': 'staff1', 'password': 'Secret123'}, [], '2026-08-10 00:00:00')
        args, _ = cur.execute.call_args
        self.assertEqual(args[1], ('staff1',))

    def test_wrong_password_on_an_active_account_returns_invalid_credential(self):
        cur = self._cur(self._row(password='Secret123'))
        result = login_scanner_bataan(
            cur, {'username': 'staff1', 'password': 'WrongPass'}, [], '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 200)
        body = json.loads(result['body'])
        self.assertEqual(body['login_status'], 'INVALID_CREDENTIAL')

    def test_wrong_password_on_an_inactive_account_still_returns_invalid_credential(self):
        # The security-critical case: status must NEVER be revealed to a
        # caller who doesn't already know the correct password.
        cur = self._cur(self._row(password='Secret123', is_active=0))
        result = login_scanner_bataan(
            cur, {'username': 'staff1', 'password': 'WrongPass'}, [], '2026-08-10 00:00:00')
        body = json.loads(result['body'])
        self.assertEqual(body['login_status'], 'INVALID_CREDENTIAL')

    def test_wrong_password_on_a_deactivated_account_still_returns_invalid_credential(self):
        cur = self._cur(self._row(password='Secret123', user_status='DEACTIVATED'))
        result = login_scanner_bataan(
            cur, {'username': 'staff1', 'password': 'WrongPass'}, [], '2026-08-10 00:00:00')
        body = json.loads(result['body'])
        self.assertEqual(body['login_status'], 'INVALID_CREDENTIAL')

    def test_active_and_not_deactivated_returns_success_with_user_data(self):
        cur = self._cur(self._row(is_active=1, user_status='VERIFIED'))
        result = login_scanner_bataan(
            cur, {'username': 'staff1', 'password': 'Secret123'}, [], '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 200)
        body = json.loads(result['body'])
        self.assertTrue(body['status'])
        self.assertEqual(body['login_status'], 'SUCCESS')
        self.assertEqual(body['user_profile_id'], '7')
        self.assertNotIn('password', body['data'])

    def test_inactive_and_not_deactivated_returns_inactive(self):
        cur = self._cur(self._row(is_active=0, user_status='VERIFIED'))
        result = login_scanner_bataan(
            cur, {'username': 'staff1', 'password': 'Secret123'}, [], '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 200)
        body = json.loads(result['body'])
        self.assertEqual(body['login_status'], 'INACTIVE')
        self.assertNotIn('data', body)

    def test_active_and_deactivated_returns_deactivated(self):
        cur = self._cur(self._row(is_active=1, user_status='DEACTIVATED'))
        result = login_scanner_bataan(
            cur, {'username': 'staff1', 'password': 'Secret123'}, [], '2026-08-10 00:00:00')
        body = json.loads(result['body'])
        self.assertEqual(body['login_status'], 'DEACTIVATED')

    def test_inactive_and_deactivated_returns_deactivated(self):
        cur = self._cur(self._row(is_active=0, user_status='DEACTIVATED'))
        result = login_scanner_bataan(
            cur, {'username': 'staff1', 'password': 'Secret123'}, [], '2026-08-10 00:00:00')
        body = json.loads(result['body'])
        self.assertEqual(body['login_status'], 'DEACTIVATED')


class CheckScannerStatusBataanTest(unittest.TestCase):
    def _cur(self, fetchone_return):
        cur = MagicMock()
        cur.fetchone.return_value = fetchone_return
        return cur

    def test_missing_user_profile_id_returns_400(self):
        cur = self._cur(None)
        result = check_scanner_status_bataan(cur, {}, [], '2026-09-09 00:00:00')
        self.assertEqual(result['statusCode'], 400)

    def test_active_and_not_deactivated_is_valid(self):
        cur = self._cur({'is_active': 1, 'user_status': 'VERIFIED'})
        result = check_scanner_status_bataan(
            cur, {'user_profile_id': '7'}, [], '2026-09-09 00:00:00')
        self.assertEqual(result['statusCode'], 200)
        body = json.loads(result['body'])
        self.assertTrue(body['status'])
        self.assertTrue(body['is_valid'])

    def test_inactive_and_not_deactivated_is_invalid_with_inactive_reason(self):
        cur = self._cur({'is_active': 0, 'user_status': 'VERIFIED'})
        result = check_scanner_status_bataan(
            cur, {'user_profile_id': '7'}, [], '2026-09-09 00:00:00')
        self.assertEqual(result['statusCode'], 200)
        body = json.loads(result['body'])
        self.assertTrue(body['status'])
        self.assertFalse(body['is_valid'])
        self.assertEqual(body['reason'], 'INACTIVE')

    def test_active_and_deactivated_is_invalid_with_deactivated_reason(self):
        cur = self._cur({'is_active': 1, 'user_status': 'DEACTIVATED'})
        result = check_scanner_status_bataan(
            cur, {'user_profile_id': '7'}, [], '2026-09-09 00:00:00')
        body = json.loads(result['body'])
        self.assertTrue(body['status'])
        self.assertFalse(body['is_valid'])
        self.assertEqual(body['reason'], 'DEACTIVATED')

    def test_inactive_and_deactivated_is_invalid_with_deactivated_reason(self):
        # DEACTIVATED takes priority over INACTIVE when both apply, same
        # as login_scanner_bataan.
        cur = self._cur({'is_active': 0, 'user_status': 'DEACTIVATED'})
        result = check_scanner_status_bataan(
            cur, {'user_profile_id': '7'}, [], '2026-09-09 00:00:00')
        body = json.loads(result['body'])
        self.assertTrue(body['status'])
        self.assertFalse(body['is_valid'])
        self.assertEqual(body['reason'], 'DEACTIVATED')

    def test_valid_response_has_no_reason_field(self):
        cur = self._cur({'is_active': 1, 'user_status': 'VERIFIED'})
        result = check_scanner_status_bataan(
            cur, {'user_profile_id': '7'}, [], '2026-09-09 00:00:00')
        body = json.loads(result['body'])
        self.assertNotIn('reason', body)

    def test_user_not_found_is_invalid_with_inactive_reason_not_an_error(self):
        cur = self._cur(None)
        result = check_scanner_status_bataan(
            cur, {'user_profile_id': '999'}, [], '2026-09-09 00:00:00')
        self.assertEqual(result['statusCode'], 200)
        body = json.loads(result['body'])
        self.assertTrue(body['status'])
        self.assertFalse(body['is_valid'])
        self.assertEqual(body['reason'], 'INACTIVE')

    def test_queries_by_the_given_user_profile_id(self):
        cur = self._cur({'is_active': 1, 'user_status': 'VERIFIED'})
        check_scanner_status_bataan(
            cur, {'user_profile_id': '7'}, [], '2026-09-09 00:00:00')
        args, _ = cur.execute.call_args
        params = args[1]
        self.assertIn('7', params)
