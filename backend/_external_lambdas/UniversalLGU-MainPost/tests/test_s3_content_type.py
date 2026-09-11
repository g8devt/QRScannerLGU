import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import helpers.s3 as s3helper
from helpers.s3 import content_type_for_filename, upload_files_from_list


class _FakeFile:
    """Stands in for the file-like object upload_files_from_list reads."""

    def __init__(self, data=b'fake-bytes'):
        self._data = data

    def read(self):
        return self._data


def _files(filename):
    return [{'field_name': 'attachment', 'filename': filename, 'content': _FakeFile()}]


class ContentTypeForFilenameTest(unittest.TestCase):
    """Pure mapping tests for the new extension -> MIME detector."""

    def test_pdf_maps_to_application_pdf(self):
        self.assertEqual(content_type_for_filename('license.pdf'), 'application/pdf')

    def test_jpg_and_jpeg_map_to_image_jpeg(self):
        self.assertEqual(content_type_for_filename('photo.jpg'), 'image/jpeg')
        self.assertEqual(content_type_for_filename('photo.jpeg'), 'image/jpeg')

    def test_png_maps_to_image_png(self):
        self.assertEqual(content_type_for_filename('scan.png'), 'image/png')

    def test_unknown_extension_falls_back_to_default(self):
        self.assertEqual(content_type_for_filename('file.docx'), 'image/jpeg')

    def test_no_extension_falls_back_to_default(self):
        self.assertEqual(content_type_for_filename('noext'), 'image/jpeg')

    def test_uppercase_extension_is_case_insensitive(self):
        self.assertEqual(content_type_for_filename('DOCUMENT.PDF'), 'application/pdf')

    def test_custom_default_is_honored_for_unknown_extension(self):
        self.assertEqual(
            content_type_for_filename('file.docx', default='application/octet-stream'),
            'application/octet-stream',
        )


class UploadFilesFromListWithoutResolverTest(unittest.TestCase):
    """CVL/KYC-style calls omit content_type_resolver entirely — this must
    stay byte-for-byte the pre-fix behavior."""

    @patch.object(s3helper, 'upload_to_s3')
    def test_no_resolver_calls_upload_to_s3_with_no_content_type_override(self, mock_upload):
        mock_upload.return_value = 'https://example.com/cvl/x.pdf'

        upload_files_from_list(_files('license.pdf'), 'cvl', 'user1')

        mock_upload.assert_called_once()
        _, kwargs = mock_upload.call_args
        self.assertNotIn('content_type', kwargs)

    @patch.object(s3helper, 's3')
    def test_no_resolver_actually_uploads_as_image_jpeg(self, mock_s3_client):
        """End-to-end through the real upload_to_s3 (only the boto3 client is
        mocked) — confirms the final ContentType sent to S3 is unchanged."""
        upload_files_from_list(_files('license.pdf'), 'kyc', 'user1')

        mock_s3_client.put_object.assert_called_once()
        _, kwargs = mock_s3_client.put_object.call_args
        self.assertEqual(kwargs['ContentType'], 'image/jpeg')


class UploadFilesFromListWithResolverTest(unittest.TestCase):
    """Social Services call sites opt in via content_type_resolver."""

    @patch.object(s3helper, 'upload_to_s3')
    def test_resolver_sends_detected_pdf_mime_to_upload_to_s3(self, mock_upload):
        mock_upload.return_value = 'https://example.com/social_services/x.pdf'

        upload_files_from_list(
            _files('license.pdf'), 'social_services/123', 'user1',
            content_type_resolver=content_type_for_filename,
        )

        mock_upload.assert_called_once()
        _, kwargs = mock_upload.call_args
        self.assertEqual(kwargs.get('content_type'), 'application/pdf')

    @patch.object(s3helper, 'upload_to_s3')
    def test_resolver_sends_detected_image_mime_to_upload_to_s3(self, mock_upload):
        mock_upload.return_value = 'https://example.com/social_services/x.jpg'

        upload_files_from_list(
            _files('photo.jpg'), 'social_services/123', 'user1',
            content_type_resolver=content_type_for_filename,
        )

        mock_upload.assert_called_once()
        _, kwargs = mock_upload.call_args
        self.assertEqual(kwargs.get('content_type'), 'image/jpeg')

    @patch.object(s3helper, 's3')
    def test_resolver_actually_uploads_pdf_as_application_pdf(self, mock_s3_client):
        """End-to-end through the real upload_to_s3 — confirms the fix reaches
        the actual S3 put_object call for a PDF attachment."""
        upload_files_from_list(
            _files('license.pdf'), 'social_services/123', 'user1',
            content_type_resolver=content_type_for_filename,
        )

        mock_s3_client.put_object.assert_called_once()
        _, kwargs = mock_s3_client.put_object.call_args
        self.assertEqual(kwargs['ContentType'], 'application/pdf')


if __name__ == '__main__':
    unittest.main()
