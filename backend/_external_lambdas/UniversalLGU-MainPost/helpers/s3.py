import os
import logging
import uuid
import boto3

logger = logging.getLogger()
s3 = boto3.client('s3')
BUCKET = os.getenv('S3_BUCKET_NAME', 'universal-lgu-uploads')

def upload_to_s3(file_content, key, content_type='image/jpeg'):
    s3.put_object(Bucket=BUCKET, Key=key, Body=file_content, ContentType=content_type)
    url = f"https://{BUCKET}.s3.amazonaws.com/{key}"
    logger.info(f"Uploaded to S3: {url}")
    return url

def generate_key(prefix, user_id, filename):
    ext = filename.rsplit('.', 1)[-1] if '.' in filename else 'jpg'
    unique = uuid.uuid4().hex[:8]
    name = filename.rsplit('.', 1)[0] if '.' in filename else filename
    return f"{prefix}/{user_id}/{name}_{unique}.{ext}"

# Social Services (bataan) uploads accept PDFs alongside images, but every
# upload used to go through with a hardcoded image/jpeg Content-Type — a PDF
# saved that way fails to open in a browser, since the browser trusts the
# header over the actual bytes. content_type_for_filename() + the optional
# resolver below let a caller opt into correct per-file MIME detection
# without changing upload_to_s3's own default or any other caller's
# behavior (CVL, KYC keep calling upload_files_from_list with no resolver).
CONTENT_TYPES = {
    'pdf':  'application/pdf',
    'jpg':  'image/jpeg',
    'jpeg': 'image/jpeg',
    'png':  'image/png',
    'gif':  'image/gif',
    'webp': 'image/webp',
    'bmp':  'image/bmp',
}


def content_type_for_filename(filename, default='image/jpeg'):
    """Map a filename's extension to its real MIME type. Falls back to
    `default` (matches upload_to_s3's own default) for anything not in
    CONTENT_TYPES, so unknown extensions behave exactly as before."""
    ext = filename.rsplit('.', 1)[-1].lower() if '.' in filename else ''
    return CONTENT_TYPES.get(ext, default)


def upload_files_from_list(files, prefix, user_id, content_type_resolver=None):
    """content_type_resolver: optional callable(filename) -> mime type.
    When omitted, behavior is unchanged (upload_to_s3's image/jpeg default)."""
    urls = {}
    for f in files:
        key = generate_key(prefix, user_id, f['filename'])
        content = f['content'].read()
        if content_type_resolver is not None:
            url = upload_to_s3(content, key, content_type=content_type_resolver(f['filename']))
        else:
            url = upload_to_s3(content, key)
        urls[f['field_name']] = url
    return urls
