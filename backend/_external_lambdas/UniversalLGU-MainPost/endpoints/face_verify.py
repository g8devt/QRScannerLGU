"""
Verifies a live selfie against the user's stored KYC face.
Used to decide whether the applicant is the KYC-registered person
(so they can apply as "Self") or someone else (filing on behalf).
"""
import logging
import os
import re
from urllib.parse import urlparse, unquote

import boto3

from helpers.auth import ok, fail, require

logger = logging.getLogger()
_rekognition = boto3.client('rekognition')
_s3 = boto3.client('s3')
_BUCKET = os.getenv('S3_BUCKET_NAME', 'universal-lgu-uploads')

def _load_kyc_bytes(url: str) -> bytes:
    """
    Fetch the KYC photo from S3. The `face_picture` column stores a
    public-style URL (https://<bucket>.s3.amazonaws.com/<key> or
    https://<bucket>.s3.<region>.amazonaws.com/<key>) — we parse it to
    get the object key and pull bytes directly via IAM-authenticated
    `get_object`, which works even from inside a VPC without a NAT.
    """
    parsed = urlparse(url)
    # Handle virtual-hosted style: bucket is the leading subdomain.
    host = parsed.netloc
    path = unquote(parsed.path.lstrip('/'))
    bucket = _BUCKET
    key = path
    m = re.match(r'^([^.]+)\.s3[.-]', host)
    if m:
        bucket = m.group(1)
    # Handle path-style: s3.amazonaws.com/<bucket>/<key>
    elif host.startswith('s3') and '/' in path:
        parts = path.split('/', 1)
        bucket, key = parts[0], parts[1]
    obj = _s3.get_object(Bucket=bucket, Key=key)
    return obj['Body'].read()

# 70% similarity is strict enough to reject siblings / lookalikes while
# tolerating lighting / age changes between the KYC photo and live selfie.
_MATCH_THRESHOLD = 70

def verify_face_match(cur, data, files, ts):
    try:
        require(data, 'user_profile_id')
        user_id = data['user_profile_id']

        # Pull the stored KYC face URL from the DB.
        cur.execute(
            "SELECT face_picture FROM app_kyc WHERE user_id=%s "
            "ORDER BY submitted_at DESC LIMIT 1",
            (user_id,),
        )
        row = cur.fetchone()
        if not row or not row.get('face_picture'):
            return fail('No KYC face on file — please complete KYC first.', 400)
        kyc_url = row['face_picture']

        selfie = next(
            (f for f in files if f['field_name'] == 'selfie'),
            None,
        )
        if not selfie:
            return fail('Missing selfie upload', 400)

        selfie['content'].seek(0)
        selfie_bytes = selfie['content'].read()

        # Fetch the stored KYC face directly from S3 via boto3 so this
        # works from inside a VPC with no internet egress.
        try:
            kyc_bytes = _load_kyc_bytes(kyc_url)
        except Exception as e:
            logger.error(f'Failed to fetch KYC face from {kyc_url}: {e}',
                         exc_info=True)
            return fail('Could not load your KYC photo', 500)

        try:
            res = _rekognition.compare_faces(
                SourceImage={'Bytes': selfie_bytes},
                TargetImage={'Bytes': kyc_bytes},
                SimilarityThreshold=_MATCH_THRESHOLD,
            )
        except Exception as e:
            logger.error(f'Rekognition compare_faces failed: {e}')
            return fail('Face comparison failed — try again', 500)

        matches = res.get('FaceMatches') or []
        similarity = 0.0
        if matches:
            similarity = round(
                max(m.get('Similarity', 0) for m in matches), 2)

        return ok({
            'status': True,
            'match': similarity >= _MATCH_THRESHOLD,
            'similarity': similarity,
            'threshold': _MATCH_THRESHOLD,
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'verify_face_match: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)
