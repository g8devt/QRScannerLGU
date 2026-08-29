import json
import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from endpoints.cvl_records_bataan import (
    find_cvl_by_qr_bataan,
    get_cvl_by_id_bataan,
    get_cvl_filter_options_bataan,
    remove_cvl_qr_bataan,
    search_cvl_by_name_bataan,
    update_cvl_info_bataan,
    update_cvl_photo_bataan,
)


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
    def test_upload_key_does_not_duplicate_record_id(self, mock_upload):
        # Regression: this used to pass f'cvl/{record_id}' as the prefix
        # *and* record_id again as user_id, embedding it twice in the S3
        # key (cvl/162876/162876/...) and padding the resulting URL past
        # cvl_img_path's column width, which MySQL then silently
        # truncated instead of erroring.
        mock_upload.return_value = {'cvl_photo': 'https://bucket.s3.amazonaws.com/cvl/1/photo_abcd1234.jpg'}
        cur = MagicMock()
        cur.fetchone.return_value = {'id': 1}
        files = _photo_files()
        update_cvl_photo_bataan(cur, {'id': 1}, files, '2026-08-25 00:00:00')

        mock_upload.assert_called_once_with(files, 'cvl', 1)

    @patch('endpoints.cvl_records_bataan.upload_files_from_list')
    def test_url_exceeding_column_width_fails_loudly_without_saving(self, mock_upload):
        # This is the actual bug this endpoint used to have: a URL past
        # cvl_img_path's column width got silently truncated by MySQL
        # instead of erroring. Now it must fail the request outright and
        # never reach the UPDATE at all.
        too_long_url = 'https://bucket.s3.amazonaws.com/' + ('a' * 500) + '.jpg'
        mock_upload.return_value = {'cvl_photo': too_long_url}
        cur = MagicMock()
        cur.fetchone.return_value = {'id': 1}
        result = update_cvl_photo_bataan(cur, {'id': 1}, _photo_files(), '2026-08-25 00:00:00')

        self.assertEqual(result['statusCode'], 500)
        update_calls = [
            c for c in cur.execute.call_args_list if 'UPDATE' in c.args[0]
        ]
        self.assertEqual(update_calls, [])

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


class GetCvlByIdBataanTest(unittest.TestCase):
    def test_missing_id_returns_400(self):
        cur = MagicMock()
        result = get_cvl_by_id_bataan(cur, {}, [], '2026-08-26 00:00:00')
        self.assertEqual(result['statusCode'], 400)

    def test_not_found_returns_404(self):
        cur = MagicMock()
        cur.fetchone.return_value = None
        result = get_cvl_by_id_bataan(cur, {'id': 999}, [], '2026-08-26 00:00:00')
        self.assertEqual(result['statusCode'], 404)

    def test_found_returns_200_with_data_even_without_qr(self):
        row = {
            'id': 1, 'cvl_id': 'CVL-0001', 'cvl_fullname': 'Juan Dela Cruz',
            'cvl_fname': 'Juan', 'cvl_mname': '', 'cvl_lname': 'Dela Cruz',
            'cvl_suffix': None, 'cvl_address': '123 Rizal St', 'cvl_mun': 'Balanga',
            'cvl_brgy': 'Poblacion', 'cvl_precinct_no': '0001A',
            'cvl_birthdate': '1990-01-01', 'cvl_contact_no': '09171234567',
            'cvl_email': 'juan@example.com', 'cvl_gender': 'Male',
            'cvl_sector': 'PWD', 'cvl_img_path': None, 'cvl_qr': None,
            'cvl_qr_code': None,
        }
        cur = MagicMock()
        cur.fetchone.return_value = row
        result = get_cvl_by_id_bataan(cur, {'id': 1}, [], '2026-08-26 00:00:00')
        self.assertEqual(result['statusCode'], 200)
        body = json.loads(result['body'])
        self.assertEqual(body['data']['cvl_fullname'], 'Juan Dela Cruz')
        self.assertEqual(body['data']['cvl_qr_code'], '')

        args, _ = cur.execute.call_args
        self.assertEqual(args[1], (1,))

    def test_db_error_returns_500(self):
        cur = MagicMock()
        cur.execute.side_effect = RuntimeError('connection lost')
        result = get_cvl_by_id_bataan(cur, {'id': 1}, [], '2026-08-26 00:00:00')
        self.assertEqual(result['statusCode'], 500)


class UpdateCvlInfoBataanTest(unittest.TestCase):
    def test_missing_id_returns_400(self):
        cur = MagicMock()
        result = update_cvl_info_bataan(cur, {}, [], '2026-08-26 00:00:00')
        self.assertEqual(result['statusCode'], 400)

    def test_record_not_found_returns_404(self):
        cur = MagicMock()
        cur.fetchone.return_value = None
        result = update_cvl_info_bataan(
            cur, {'id': 999, 'contact_no': '09171234567'}, [], '2026-08-26 00:00:00'
        )
        self.assertEqual(result['statusCode'], 404)

    def test_no_fields_returns_400(self):
        cur = MagicMock()
        cur.fetchone.return_value = {'id': 1}
        result = update_cvl_info_bataan(cur, {'id': 1}, [], '2026-08-26 00:00:00')
        self.assertEqual(result['statusCode'], 400)

    def test_success_updates_only_provided_fields(self):
        cur = MagicMock()
        cur.fetchone.side_effect = [
            {'id': 1},
            {'cvl_contact_no': '09171234567', 'cvl_email': '', 'cvl_gender': 'Male'},
        ]
        result = update_cvl_info_bataan(
            cur,
            {'id': 1, 'contact_no': '09171234567', 'gender': 'Male'},
            [],
            '2026-08-26 00:00:00',
        )
        self.assertEqual(result['statusCode'], 200)
        body = json.loads(result['body'])
        self.assertEqual(body['data']['cvl_contact_no'], '09171234567')
        self.assertEqual(body['data']['cvl_gender'], 'Male')

        update_sql, update_params = cur.execute.call_args_list[1].args
        self.assertIn('cvl_contact_no=%s', update_sql)
        self.assertIn('cvl_gender=%s', update_sql)
        self.assertNotIn('cvl_email=%s', update_sql)
        self.assertEqual(update_params[-1], 1)

    def test_db_error_returns_500(self):
        cur = MagicMock()
        cur.execute.side_effect = RuntimeError('connection lost')
        result = update_cvl_info_bataan(
            cur, {'id': 1, 'email': 'a@b.com'}, [], '2026-08-26 00:00:00'
        )
        self.assertEqual(result['statusCode'], 500)


class RemoveCvlQrBataanTest(unittest.TestCase):
    def test_missing_id_returns_400(self):
        cur = MagicMock()
        result = remove_cvl_qr_bataan(cur, {}, [], '2026-08-26 00:00:00')
        self.assertEqual(result['statusCode'], 400)

    def test_record_not_found_returns_404(self):
        cur = MagicMock()
        cur.fetchone.return_value = None
        result = remove_cvl_qr_bataan(cur, {'id': 999}, [], '2026-08-26 00:00:00')
        self.assertEqual(result['statusCode'], 404)

    def test_no_qr_assigned_returns_409(self):
        cur = MagicMock()
        cur.fetchone.return_value = {'id': 1, 'cvl_qr': None}
        result = remove_cvl_qr_bataan(cur, {'id': 1}, [], '2026-08-26 00:00:00')
        self.assertEqual(result['statusCode'], 409)
        body = json.loads(result['body'])
        self.assertEqual(body['message'], 'This record has no QR code assigned.')

    def test_success_frees_qr_and_clears_record(self):
        cur = MagicMock()
        cur.fetchone.return_value = {'id': 1, 'cvl_qr': 42}
        result = remove_cvl_qr_bataan(cur, {'id': 1}, [], '2026-08-26 00:00:00')
        self.assertEqual(result['statusCode'], 200)
        body = json.loads(result['body'])
        self.assertEqual(body['data']['id'], 1)

        update_calls = cur.execute.call_args_list[1:]
        self.assertIn("SET status='AVAILABLE'", update_calls[0].args[0])
        self.assertEqual(update_calls[0].args[1], ('2026-08-26 00:00:00', 42))
        self.assertIn('SET cvl_qr=NULL', update_calls[1].args[0])
        self.assertEqual(update_calls[1].args[1], ('2026-08-26 00:00:00', 1))

    def test_db_error_returns_500(self):
        cur = MagicMock()
        cur.execute.side_effect = RuntimeError('connection lost')
        result = remove_cvl_qr_bataan(cur, {'id': 1}, [], '2026-08-26 00:00:00')
        self.assertEqual(result['statusCode'], 500)


class SearchCvlByNameBataanTest(unittest.TestCase):
    def test_missing_name_returns_400(self):
        cur = MagicMock()
        result = search_cvl_by_name_bataan(cur, {}, [], '2026-08-26 00:00:00')
        self.assertEqual(result['statusCode'], 400)

    def test_single_character_name_returns_400(self):
        cur = MagicMock()
        result = search_cvl_by_name_bataan(cur, {'name': 'j'}, [], '2026-08-26 00:00:00')
        self.assertEqual(result['statusCode'], 400)

    def test_long_keyword_uses_fulltext_boolean_mode(self):
        cur = MagicMock()
        cur.fetchall.return_value = []
        search_cvl_by_name_bataan(cur, {'name': 'Juan Cruz'}, [], '2026-08-26 00:00:00')

        args, _ = cur.execute.call_args
        sql, params = args
        self.assertIn('MATCH(c.cvl_fullname) AGAINST', sql)
        self.assertIn('IN BOOLEAN MODE', sql)
        self.assertEqual(params, ('+Juan* +Cruz*', 0))

    def test_short_keyword_falls_back_to_like(self):
        cur = MagicMock()
        cur.fetchall.return_value = []
        search_cvl_by_name_bataan(cur, {'name': 'Jo'}, [], '2026-08-26 00:00:00')

        args, _ = cur.execute.call_args
        sql, params = args
        self.assertNotIn('MATCH(', sql)
        self.assertIn('LIKE %s', sql)
        self.assertEqual(params, ('%Jo%', 0))

    def test_success_returns_results_and_has_more_flag(self):
        rows = [
            {'id': 1, 'cvl_fullname': 'Juan Cruz', 'cvl_mun': 'Balanga', 'cvl_brgy': 'Poblacion', 'cvl_qr_code': 'QR-00001'},
            {'id': 2, 'cvl_fullname': 'Juana Cruz', 'cvl_mun': 'Balanga', 'cvl_brgy': 'Doña Francisca', 'cvl_qr_code': None},
        ]
        cur = MagicMock()
        cur.fetchall.return_value = rows
        result = search_cvl_by_name_bataan(cur, {'name': 'Juan Cruz'}, [], '2026-08-26 00:00:00')
        self.assertEqual(result['statusCode'], 200)
        body = json.loads(result['body'])
        self.assertEqual(len(body['data']['results']), 2)
        self.assertEqual(body['data']['results'][0]['cvl_fullname'], 'Juan Cruz')
        self.assertEqual(body['data']['results'][1]['cvl_qr_code'], '')
        self.assertFalse(body['data']['has_more'])

        args, _ = cur.execute.call_args
        sql, params = args
        self.assertIn('LIMIT 26 OFFSET %s', sql)
        self.assertEqual(params[-1], 0)

    def test_26th_row_sets_has_more_true_and_is_trimmed(self):
        rows = [
            {'id': i, 'cvl_fullname': f'Person {i}', 'cvl_mun': 'Balanga', 'cvl_brgy': 'Poblacion', 'cvl_qr_code': None}
            for i in range(26)
        ]
        cur = MagicMock()
        cur.fetchall.return_value = rows
        result = search_cvl_by_name_bataan(cur, {'name': 'Person'}, [], '2026-08-26 00:00:00')
        body = json.loads(result['body'])
        self.assertTrue(body['data']['has_more'])
        self.assertEqual(len(body['data']['results']), 25)

    def test_exactly_25_results_sets_has_more_false(self):
        rows = [
            {'id': i, 'cvl_fullname': f'Person {i}', 'cvl_mun': 'Balanga', 'cvl_brgy': 'Poblacion', 'cvl_qr_code': None}
            for i in range(25)
        ]
        cur = MagicMock()
        cur.fetchall.return_value = rows
        result = search_cvl_by_name_bataan(cur, {'name': 'Person'}, [], '2026-08-26 00:00:00')
        body = json.loads(result['body'])
        self.assertFalse(body['data']['has_more'])

    def test_offset_is_passed_through_to_query(self):
        cur = MagicMock()
        cur.fetchall.return_value = []
        search_cvl_by_name_bataan(cur, {'name': 'Juan', 'offset': 25}, [], '2026-08-26 00:00:00')

        args, _ = cur.execute.call_args
        _, params = args
        self.assertEqual(params[-1], 25)

    def test_negative_offset_returns_400(self):
        cur = MagicMock()
        result = search_cvl_by_name_bataan(cur, {'name': 'Juan', 'offset': -1}, [], '2026-08-26 00:00:00')
        self.assertEqual(result['statusCode'], 400)

    def test_non_numeric_offset_returns_400(self):
        cur = MagicMock()
        result = search_cvl_by_name_bataan(cur, {'name': 'Juan', 'offset': 'abc'}, [], '2026-08-26 00:00:00')
        self.assertEqual(result['statusCode'], 400)

    def test_db_error_returns_500(self):
        cur = MagicMock()
        cur.execute.side_effect = RuntimeError('connection lost')
        result = search_cvl_by_name_bataan(cur, {'name': 'Juan'}, [], '2026-08-26 00:00:00')
        self.assertEqual(result['statusCode'], 500)

    def test_no_name_and_no_filters_returns_400(self):
        cur = MagicMock()
        result = search_cvl_by_name_bataan(cur, {}, [], '2026-08-26 00:00:00')
        self.assertEqual(result['statusCode'], 400)

    def test_filter_only_with_no_name_still_searches(self):
        cur = MagicMock()
        cur.fetchall.return_value = []
        result = search_cvl_by_name_bataan(
            cur, {'mun': 'Balanga'}, [], '2026-08-26 00:00:00'
        )
        self.assertEqual(result['statusCode'], 200)

        args, _ = cur.execute.call_args
        sql, params = args
        self.assertIn('c.cvl_mun = %s', sql)
        self.assertNotIn('MATCH(', sql)
        self.assertEqual(params, ('Balanga', 0))

    def test_exact_match_filters_are_and_ed_together(self):
        cur = MagicMock()
        cur.fetchall.return_value = []
        search_cvl_by_name_bataan(
            cur,
            {
                'mun': 'Balanga',
                'brgy': 'Poblacion',
                'precinct': '0001A',
                'position_code': 'LEADER',
                'leader': 'Barangay Captain',
                'secondary_position': 'SUPPORTER',
                'sector': 'PWD',
            },
            [],
            '2026-08-26 00:00:00',
        )

        args, _ = cur.execute.call_args
        sql, params = args
        for column in (
            'c.cvl_mun = %s', 'c.cvl_brgy = %s', 'c.cvl_precinct_no = %s',
            'c.cvl_position_code = %s', 'c.cvl_leader = %s',
            'c.cvl_secondary_position = %s', 'c.cvl_sector = %s',
        ):
            self.assertIn(column, sql)
        self.assertEqual(
            params,
            ('Balanga', 'Poblacion', '0001A', 'LEADER', 'Barangay Captain', 'SUPPORTER', 'PWD', 0),
        )

    def test_has_photo_yes_filters_non_empty_img_path(self):
        cur = MagicMock()
        cur.fetchall.return_value = []
        search_cvl_by_name_bataan(cur, {'mun': 'Balanga', 'has_photo': '1'}, [], '2026-08-26 00:00:00')

        args, _ = cur.execute.call_args
        sql, _ = args
        self.assertIn("c.cvl_img_path IS NOT NULL AND c.cvl_img_path != ''", sql)

    def test_has_photo_no_filters_empty_img_path(self):
        cur = MagicMock()
        cur.fetchall.return_value = []
        search_cvl_by_name_bataan(cur, {'mun': 'Balanga', 'has_photo': '0'}, [], '2026-08-26 00:00:00')

        args, _ = cur.execute.call_args
        sql, _ = args
        self.assertIn("(c.cvl_img_path IS NULL OR c.cvl_img_path = '')", sql)

    def test_has_card_yes_filters_qr_assigned(self):
        cur = MagicMock()
        cur.fetchall.return_value = []
        search_cvl_by_name_bataan(cur, {'mun': 'Balanga', 'has_card': '1'}, [], '2026-08-26 00:00:00')

        args, _ = cur.execute.call_args
        sql, _ = args
        self.assertIn('c.cvl_qr IS NOT NULL', sql)

    def test_has_card_no_filters_qr_unassigned(self):
        cur = MagicMock()
        cur.fetchall.return_value = []
        search_cvl_by_name_bataan(cur, {'mun': 'Balanga', 'has_card': '0'}, [], '2026-08-26 00:00:00')

        args, _ = cur.execute.call_args
        sql, _ = args
        self.assertIn('c.cvl_qr IS NULL', sql)

    def test_name_and_filters_combine_with_and(self):
        cur = MagicMock()
        cur.fetchall.return_value = []
        search_cvl_by_name_bataan(
            cur, {'name': 'Juan Cruz', 'mun': 'Balanga'}, [], '2026-08-26 00:00:00'
        )

        args, _ = cur.execute.call_args
        sql, params = args
        self.assertIn('c.cvl_mun = %s', sql)
        self.assertIn('MATCH(c.cvl_fullname) AGAINST', sql)
        self.assertEqual(params, ('Balanga', '+Juan* +Cruz*', 0))


class GetCvlFilterOptionsBataanTest(unittest.TestCase):
    def test_returns_distinct_values_per_column(self):
        cur = MagicMock()
        cur.fetchall.side_effect = [
            [{'v': 'Balanga'}, {'v': 'Mariveles'}],
            [{'v': 'Poblacion'}],
            [{'v': '0001A'}],
        ]
        result = get_cvl_filter_options_bataan(cur, {}, [], '2026-08-26 00:00:00')
        self.assertEqual(result['statusCode'], 200)
        body = json.loads(result['body'])
        self.assertEqual(body['data']['mun'], ['Balanga', 'Mariveles'])
        self.assertEqual(body['data']['brgy'], ['Poblacion'])
        self.assertEqual(body['data']['precinct'], ['0001A'])
        self.assertEqual(cur.execute.call_count, 3)

    def test_db_error_returns_500(self):
        cur = MagicMock()
        cur.execute.side_effect = RuntimeError('connection lost')
        result = get_cvl_filter_options_bataan(cur, {}, [], '2026-08-26 00:00:00')
        self.assertEqual(result['statusCode'], 500)


if __name__ == '__main__':
    unittest.main()
