import json
import sys
import unittest
from io import BytesIO
from pathlib import Path
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from endpoints.social_services_bataan import verify_qr_bataan, submit_claim_bataan


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


def _claim_files():
    return [
        {'filename': 'front.jpg', 'content': BytesIO(b'a'), 'field_name': 'claimant_id_front'},
        {'filename': 'back.jpg', 'content': BytesIO(b'b'), 'field_name': 'claimant_id_back'},
        {'filename': 'sig.jpg', 'content': BytesIO(b'c'), 'field_name': 'claimant_signature'},
        {'filename': 'face.jpg', 'content': BytesIO(b'd'), 'field_name': 'claimant_face_photo'},
    ]


class SubmitClaimBataanTest(unittest.TestCase):
    def _base_data(self, claimant_type='SELF'):
        return {
            'id': '1', 'claimant_type': claimant_type,
            'claimant_id_type': "Driver's License", 'claimant_id_number': '123',
        }

    def test_missing_files_returns_400(self):
        cur = MagicMock()
        result = submit_claim_bataan(cur, self._base_data(), [], '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 400)

    def test_representative_without_name_returns_400(self):
        cur = MagicMock()
        result = submit_claim_bataan(
            cur, self._base_data(claimant_type='REPRESENTATIVE'), _claim_files(), '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 400)

    def test_application_not_found_returns_404(self):
        cur = MagicMock()
        cur.fetchone.return_value = None
        result = submit_claim_bataan(cur, self._base_data(), _claim_files(), '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 404)

    def test_not_eligible_status_returns_409(self):
        cur = MagicMock()
        cur.fetchone.return_value = {'status': 'PENDING'}
        result = submit_claim_bataan(cur, self._base_data(), _claim_files(), '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 409)

    @patch('endpoints.social_services_bataan.upload_files_from_list')
    def test_already_claimed_race_returns_409(self, mock_upload):
        mock_upload.return_value = {
            'claimant_id_front': 'url1', 'claimant_id_back': 'url2',
            'claimant_signature': 'url3', 'claimant_face_photo': 'url4',
        }
        cur = MagicMock()
        cur.fetchone.side_effect = [{'status': 'APPROVED'}, {'c': 1}]
        cur.rowcount = 0
        result = submit_claim_bataan(cur, self._base_data(), _claim_files(), '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 409)

    @patch('endpoints.social_services_bataan.upload_files_from_list')
    def test_success_returns_200(self, mock_upload):
        mock_upload.return_value = {
            'claimant_id_front': 'url1', 'claimant_id_back': 'url2',
            'claimant_signature': 'url3', 'claimant_face_photo': 'url4',
        }
        cur = MagicMock()
        cur.fetchone.side_effect = [{'status': 'APPROVED'}, {'c': 1}]
        cur.rowcount = 1
        result = submit_claim_bataan(cur, self._base_data(), _claim_files(), '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 200)


if __name__ == '__main__':
    unittest.main()
