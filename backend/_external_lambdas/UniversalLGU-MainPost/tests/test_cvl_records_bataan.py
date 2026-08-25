import json
import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from endpoints.cvl_records_bataan import find_cvl_by_qr_bataan


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


if __name__ == '__main__':
    unittest.main()
