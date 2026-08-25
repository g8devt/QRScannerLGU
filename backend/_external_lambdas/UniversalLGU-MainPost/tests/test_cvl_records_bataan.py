import json
import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from endpoints.cvl_records_bataan import find_cvl_by_qr_bataan, update_cvl_photo_bataan


def _photo_files():
    return [{'field_name': 'cvl_photo', 'filename': 'photo.jpg', 'content': MagicMock()}]


class FindCvlByQrBataanTest(unittest.TestCase):
    def _cur(self, fetchone_return):
        cur = MagicMock()
        cur.fetchone.return_value = fetchone_return
        return cur

    def test_missing_qr_code_returns_400(self):
        cur = self._cur(None)
        result = find_cvl_by_qr_bataan(cur, {}, [], '2026-08-25 00:00:00')
        self.assertEqual(result['statusCode'], 400)

    def test_no_match_returns_404_with_exact_message(self):
        cur = self._cur(None)
        result = find_cvl_by_qr_bataan(cur, {'qr_code': 'QR-99999'}, [], '2026-08-25 00:00:00')
        self.assertEqual(result['statusCode'], 404)
        body = json.loads(result['body'])
        self.assertEqual(body['message'], 'No CVL record was found for this QR code.')

    def test_match_by_full_qr_code_returns_200_with_data(self):
        row = {
            'id': 1, 'cvl_id': 'CVL-0001', 'cvl_fullname': 'Juan Dela Cruz',
            'cvl_fname': 'Juan', 'cvl_mname': '', 'cvl_lname': 'Dela Cruz',
            'cvl_suffix': None, 'cvl_address': '123 Rizal St', 'cvl_mun': 'Balanga',
            'cvl_brgy': 'Poblacion', 'cvl_precinct_no': '0001A',
            'cvl_birthdate': '1990-01-01', 'cvl_contact_no': '09171234567',
            'cvl_email': 'juan@example.com', 'cvl_gender': 'Male',
            'cvl_sector': 'PWD', 'cvl_img_path': None, 'cvl_qr': 42,
            'cvl_qr_code': 'QR-00042',
        }
        cur = self._cur(row)
        result = find_cvl_by_qr_bataan(cur, {'qr_code': 'QR-00042'}, [], '2026-08-25 00:00:00')
        self.assertEqual(result['statusCode'], 200)
        body = json.loads(result['body'])
        self.assertEqual(body['data']['cvl_fullname'], 'Juan Dela Cruz')
        self.assertEqual(body['data']['cvl_qr_code'], 'QR-00042')

        args, _ = cur.execute.call_args
        params = args[1]
        self.assertEqual(
            params,
            ('QR-00042', '00042', '00042', 0, 0, 'QR-00042', '00042', '00042', 0, 0),
        )

    def test_match_by_numeric_id_returns_200(self):
        row = {
            'id': 1, 'cvl_id': 'CVL-0001', 'cvl_fullname': 'Juan Dela Cruz',
            'cvl_fname': 'Juan', 'cvl_mname': '', 'cvl_lname': 'Dela Cruz',
            'cvl_suffix': None, 'cvl_address': '123 Rizal St', 'cvl_mun': 'Balanga',
            'cvl_brgy': 'Poblacion', 'cvl_precinct_no': '0001A',
            'cvl_birthdate': '1990-01-01', 'cvl_contact_no': '09171234567',
            'cvl_email': 'juan@example.com', 'cvl_gender': 'Male',
            'cvl_sector': 'PWD', 'cvl_img_path': None, 'cvl_qr': 42,
            'cvl_qr_code': 'QR-00042',
        }
        cur = self._cur(row)
        result = find_cvl_by_qr_bataan(cur, {'qr_code': '42'}, [], '2026-08-25 00:00:00')
        self.assertEqual(result['statusCode'], 200)

        args, _ = cur.execute.call_args
        params = args[1]
        self.assertEqual(
            params,
            ('42', '42', '42', 1, 42, '42', '42', '42', 1, 42),
        )

    def test_db_error_returns_500(self):
        cur = MagicMock()
        cur.execute.side_effect = RuntimeError('connection lost')
        result = find_cvl_by_qr_bataan(cur, {'qr_code': 'QR-00042'}, [], '2026-08-25 00:00:00')
        self.assertEqual(result['statusCode'], 500)


class UpdateCvlPhotoBataanTest(unittest.TestCase):
    def test_missing_id_returns_400(self):
        cur = MagicMock()
        result = update_cvl_photo_bataan(cur, {}, _photo_files(), '2026-08-25 00:00:00')
        self.assertEqual(result['statusCode'], 400)

    def test_missing_photo_file_returns_400(self):
        cur = MagicMock()
        result = update_cvl_photo_bataan(cur, {'id': 1}, [], '2026-08-25 00:00:00')
        self.assertEqual(result['statusCode'], 400)

    def test_record_not_found_returns_404(self):
        cur = MagicMock()
        cur.fetchone.return_value = None
        result = update_cvl_photo_bataan(cur, {'id': 999}, _photo_files(), '2026-08-25 00:00:00')
        self.assertEqual(result['statusCode'], 404)

    @patch('endpoints.cvl_records_bataan.upload_files_from_list')
    def test_success_returns_200_with_new_url(self, mock_upload):
        mock_upload.return_value = {'cvl_photo': 'https://bucket.s3.amazonaws.com/cvl/1/photo_abcd1234.jpg'}
        cur = MagicMock()
        cur.fetchone.return_value = {'id': 1}
        result = update_cvl_photo_bataan(
            cur, {'id': 1, 'updated_by': 'jdoe'}, _photo_files(), '2026-08-25 00:00:00',
        )
        self.assertEqual(result['statusCode'], 200)
        body = json.loads(result['body'])
        self.assertEqual(body['data']['cvl_img_path'], 'https://bucket.s3.amazonaws.com/cvl/1/photo_abcd1234.jpg')

        update_call = cur.execute.call_args_list[-1]
        args, _ = update_call
        params = args[1]
        self.assertEqual(
            params,
            ('https://bucket.s3.amazonaws.com/cvl/1/photo_abcd1234.jpg', 'jdoe', '2026-08-25 00:00:00', 1),
        )

    @patch('endpoints.cvl_records_bataan.upload_files_from_list')
    def test_missing_updated_by_falls_back_to_mobile_scanner(self, mock_upload):
        mock_upload.return_value = {'cvl_photo': 'https://bucket.s3.amazonaws.com/cvl/1/photo_abcd1234.jpg'}
        cur = MagicMock()
        cur.fetchone.return_value = {'id': 1}
        update_cvl_photo_bataan(cur, {'id': 1}, _photo_files(), '2026-08-25 00:00:00')

        update_call = cur.execute.call_args_list[-1]
        args, _ = update_call
        params = args[1]
        self.assertEqual(params[1], 'MOBILE_SCANNER')

    def test_db_error_returns_500(self):
        cur = MagicMock()
        cur.execute.side_effect = RuntimeError('connection lost')
        result = update_cvl_photo_bataan(cur, {'id': 1}, _photo_files(), '2026-08-25 00:00:00')
        self.assertEqual(result['statusCode'], 500)


if __name__ == '__main__':
    unittest.main()
