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

def upload_files_from_list(files, prefix, user_id):
    urls = {}
    for f in files:
        key = generate_key(prefix, user_id, f['filename'])
        content = f['content'].read()
        url = upload_to_s3(content, key)
        urls[f['field_name']] = url
    return urls
