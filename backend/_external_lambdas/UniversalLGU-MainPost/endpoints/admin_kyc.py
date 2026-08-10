import json
import logging
import os
import re
from helpers.auth import ok, fail, require
from helpers.db import sanitize, serialize_row
from helpers.s3 import upload_files_from_list
from helpers.rekognition import compare_faces
from helpers.gemini import scan_id_image
from helpers.pin import hash_pin
from helpers.ws import broadcast

logger = logging.getLogger()

# invite_token is interpolated directly into an S3 key path (helpers/s3.py's
# generate_key), so it must be restricted to a safe charset — otherwise a
# token containing '/' or '..' could relocate objects elsewhere in the bucket.
INVITE_TOKEN_RE = re.compile(r'^[A-Za-z0-9_-]{8,191}$')

# Only these four files are ever expected for an admin KYC submission — any
# other attached file is dropped before it reaches upload_files_from_list so
# a client can't smuggle unlimited extra uploads onto the bucket.
EXPECTED_FILE_FIELDS = {'id_front', 'id_back', 'selfie', 'signature'}


def merge_ocr_fields(front, back):
    merged = dict(front or {})
    for k, v in (back or {}).items():
        if not merged.get(k) and v:
            merged[k] = v
    return merged


def submit_admin_kyc(cur, data, files, ts):
    try:
        require(data, 'invite_token', 'first_name', 'last_name')
        invite_token = sanitize(data['invite_token'])
        if not invite_token or not INVITE_TOKEN_RE.match(invite_token):
            return fail('Invalid invite_token')
        first_name = sanitize(data['first_name'])
        middle_name = sanitize(data.get('middle_name', ''))
        last_name = sanitize(data['last_name'])

        # app_user_id is NEVER trusted from the client on this unauthenticated
        # endpoint — a client-supplied id would let anyone attach a KYC
        # submission (and, on staff approval, VERIFIED status + identity
        # data + enabled_features) to an arbitrary victim account. Instead it
        # is derived server-side from the invite_token already present in
        # this request: only an ACCEPTED invite (the citizen has already set
        # a PIN and created their app_users row via accept_invite_set_pin)
        # contributes an app_user_id. No invite, or an invite that is still
        # PENDING/EXPIRED/REVOKED, stores NULL — matching the coordinated
        # fix in _activate_app_user below (Finding #3), which independently
        # re-checks the invite is still ACCEPTED at approval time.
        cur.execute(
            "SELECT app_user_id FROM app_admin_invites WHERE token=%s AND status='ACCEPTED'",
            (invite_token,),
        )
        invite_row = cur.fetchone()
        app_user_id = invite_row['app_user_id'] if invite_row else None

        # Drop any file whose field_name isn't one of the four expected ones
        # before it ever reaches by_field or upload_files_from_list.
        files = [f for f in files if f.get('field_name') in EXPECTED_FILE_FIELDS]

        by_field = {}
        for f in files:
            f['content'].seek(0)
            by_field[f['field_name']] = f['content'].read()
            f['content'].seek(0)

        for required_field in ('id_front', 'id_back', 'selfie'):
            if not by_field.get(required_field):
                return fail(f'Missing {required_field} image')

        file_urls = upload_files_from_list(files, 'admin_kyc', invite_token)

        ocr_error = None
        front_fields, back_fields = {}, {}
        try:
            front_fields = scan_id_image(by_field['id_front'])
        except (ValueError, RuntimeError, OSError) as e:
            ocr_error = f'Front OCR failed: {e}'
        try:
            back_fields = scan_id_image(by_field['id_back'])
        except (ValueError, RuntimeError, OSError) as e:
            back_msg = f'Back OCR failed: {e}'
            ocr_error = f'{ocr_error}; {back_msg}' if ocr_error else back_msg

        merged_fields = merge_ocr_fields(front_fields, back_fields)
        ocr_raw_text = json.dumps({'front': front_fields, 'back': back_fields})

        # threshold=0 makes Rekognition always return the true similarity
        # score in FaceMatches (rather than dropping below-threshold matches
        # into the "no match" bucket), so staff always see a real percentage
        # for a borderline match. With threshold=0, status=False now only
        # occurs for a genuine failure — no face detected in either image, or
        # a Rekognition exception — never merely "didn't clear 60%".
        face_result = compare_faces(by_field['selfie'], by_field['id_front'], threshold=0)
        face_match_score = face_result.get('similarity') if face_result.get('status') else None
        face_error = None if face_result.get('status') else face_result.get('message')

        # Error strings (concatenated OCR failures, raw boto3 error text) can
        # exceed the VARCHAR(255) column width and abort the INSERT under
        # strict SQL mode — truncate right before use.
        if ocr_error:
            ocr_error = ocr_error[:255]
        if face_error:
            face_error = face_error[:255]

        cur.execute("""
            INSERT INTO app_admin_kyc_submissions (
                invite_token, first_name, middle_name, last_name,
                signature_url, id_front_url, id_back_url, selfie_url,
                ocr_raw_text, ocr_extracted_fields, ocr_error,
                face_match_score, face_error, app_user_id, status,
                created_at, updated_at
            ) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,'PENDING',%s,%s)
        """, (
            invite_token, first_name, middle_name, last_name,
            file_urls.get('signature'), file_urls.get('id_front'),
            file_urls.get('id_back'), file_urls.get('selfie'),
            ocr_raw_text, json.dumps(merged_fields), ocr_error,
            face_match_score, face_error, app_user_id, ts, ts,
        ))
        submission_id = cur.lastrowid

        endpoint_url = os.getenv('KYC_WS_ENDPOINT')
        if endpoint_url:
            try:
                broadcast(cur, endpoint_url, 'staff', {
                    'type': 'new_submission', 'submission_id': submission_id,
                })
            except Exception as e:
                logger.error(f"Failed to broadcast submission {submission_id}: {e}", exc_info=True)

        return ok({
            'status': True,
            'submission_id': submission_id,
            'face_match_score': face_match_score,
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"submit_admin_kyc error: {e}", exc_info=True)
        return fail(f'Server error: {str(e)}', 500)


def get_admin_kyc_status(cur, data, files, ts):
    try:
        require(data, 'invite_token')
        cur.execute("""
            SELECT id, status, rejection_reason, reviewed_at
            FROM app_admin_kyc_submissions WHERE invite_token=%s
            ORDER BY created_at DESC LIMIT 1
        """, (sanitize(data['invite_token']),))
        row = cur.fetchone()
        if not row:
            return ok({'status': True, 'kyc_status': 'NONE'})
        return ok({'status': True, 'kyc_status': row['status'], 'data': serialize_row(row)})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"get_admin_kyc_status error: {e}", exc_info=True)
        return fail(f'Server error: {str(e)}', 500)


def verify_invite_token(cur, data, files, ts):
    try:
        require(data, 'token')
        token = sanitize(data['token'])
        cur.execute("""
            SELECT id, mobile_number, status,
                   (status='PENDING' AND expires_at < %s) AS is_expired
            FROM app_admin_invites WHERE token=%s
        """, (ts, token))
        invite = cur.fetchone()
        if not invite:
            return fail('Invite not found', 404)

        if invite['is_expired']:
            cur.execute(
                "UPDATE app_admin_invites SET status='EXPIRED' WHERE id=%s",
                (invite['id'],),
            )
            return fail('Invite is expired', 410)

        if invite['status'] != 'PENDING':
            return fail(f"Invite is {invite['status'].lower()}", 410)

        return ok({'status': True, 'mobile_number': invite['mobile_number']})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"verify_invite_token error: {e}", exc_info=True)
        return fail(f'Server error: {str(e)}', 500)


def accept_invite_set_pin(cur, data, files, ts):
    try:
        require(data, 'token', 'pin_code')
        token = sanitize(data['token'])
        pin_code = str(data['pin_code'])

        cur.execute("""
            SELECT id, mobile_number, permissions, status,
                   (status='PENDING' AND expires_at < %s) AS is_expired
            FROM app_admin_invites WHERE token=%s
        """, (ts, token))
        invite = cur.fetchone()
        if not invite:
            return fail('Invite not found', 404)

        if invite['is_expired']:
            cur.execute(
                "UPDATE app_admin_invites SET status='EXPIRED' WHERE id=%s",
                (invite['id'],),
            )
            return fail('Invite is expired', 410)

        if invite['status'] != 'PENDING':
            return fail(f"Invite is {invite['status'].lower()}", 410)

        mobile = invite['mobile_number']
        cur.execute("SELECT id FROM app_users WHERE mobile_number=%s", (mobile,))
        if cur.fetchone():
            return fail('This number already has an account', 409)

        # Claim the invite atomically FIRST (PENDING -> ACCEPTED only ever
        # succeeds once). Only after winning this claim do we create the
        # app_users row — this ordering (claim, then create, then link)
        # means a replayed/concurrent accept request can't create two
        # app_users rows for one invite: the loser sees rowcount==0 here
        # and stops before ever touching app_users.
        cur.execute(
            "UPDATE app_admin_invites SET status='ACCEPTED' WHERE id=%s AND status='PENDING'",
            (invite['id'],),
        )
        if cur.rowcount == 0:
            return fail('Invite was already accepted', 409)

        cur.execute("""
            INSERT INTO app_users (
                status, user_status, mobile_number, pin_code_pass,
                date_created, date_modified, is_active
            ) VALUES ('ACTIVE', 'NOT_VERIFIED', %s, %s, %s, %s, 1)
        """, (mobile, hash_pin(pin_code), ts, ts))
        app_user_id = cur.lastrowid

        cur.execute(
            "UPDATE app_admin_invites SET app_user_id=%s WHERE id=%s",
            (app_user_id, invite['id']),
        )

        return ok({'status': True, 'user_profile_id': app_user_id})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"accept_invite_set_pin error: {e}", exc_info=True)
        return fail(f'Server error: {str(e)}', 500)
