import json
import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from endpoints.social_services_bataan import verify_qr_bataan


class VerifyQrBataanTest(unittest.TestCase):
    def _cur(self, fetchone_return):
        cur = MagicMock()
        cur.fetchone.return_value = fetchone_return
        return cur

    def test_qr_not_found_returns_404(self):
        cur = self._cur(None)
        result = verify_qr_bataan(cur, {'qr_code': 'SS-000001-ABC'}, [], '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 404)

    def test_already_claimed_returns_409(self):
        cur = self._cur({'id': 1, 'status': 'CLAIMED', 'date_claimed': '2026-08-01'})
        result = verify_qr_bataan(cur, {'qr_code': 'SS-000001-ABC'}, [], '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 409)

    def test_not_yet_eligible_status_returns_409(self):
        cur = self._cur({'id': 1, 'status': 'PENDING', 'date_claimed': None})
        result = verify_qr_bataan(cur, {'qr_code': 'SS-000001-ABC'}, [], '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 409)

    def test_approved_status_returns_200_with_data(self):
        cur = self._cur({
            'id': 1, 'application_number': 'SS-000001', 'beneficiary_name': 'Juan',
            'status': 'APPROVED', 'requested_for_fname': 'Juan', 'requested_for_mname': '',
            'requested_for_lname': 'Dela Cruz', 'date_approved': '2026-08-05',
            'date_released': None, 'date_claimed': None,
        })
        result = verify_qr_bataan(cur, {'qr_code': 'SS-000001-ABC'}, [], '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 200)
        body = json.loads(result['body'])
        self.assertEqual(body['data']['application_number'], 'SS-000001')

    def test_missing_qr_code_returns_400(self):
        cur = self._cur(None)
        result = verify_qr_bataan(cur, {}, [], '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 400)


if __name__ == '__main__':
    unittest.main()
