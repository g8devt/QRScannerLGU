import logging
from helpers.auth import ok, fail, require
from helpers.db import sanitize, serialize_row
from helpers.s3 import upload_files_from_list
from helpers.rekognition import compare_faces
from helpers.gemini import scan_id_image

logger = logging.getLogger()

def scan_id(cur, data, files, ts):
    """
    AI-powered OCR: sends the uploaded ID photo to Gemini 2.5 Flash and
    returns the extracted first/middle/last name, suffix, and birthdate.
    Expects one file with field_name='gov_id_front'.
    """
    try:
        id_file = next(
            (f for f in files if f['field_name'] == 'gov_id_front'),
            None,
        )
        if not id_file:
            return fail('Missing gov_id_front image')

        id_file['content'].seek(0)
        image_bytes = id_file['content'].read()
        id_file['content'].seek(0)

        mime = id_file.get('content_type') or 'image/jpeg'
        result = scan_id_image(image_bytes, mime_type=mime)
        return ok({'status': True, 'data': result})
    except ValueError as e:
        return fail(str(e))
    except RuntimeError as e:
        logger.error(f"scan_id runtime error: {e}")
        return fail(f'Scan failed: {str(e)}', 500)
    except Exception as e:
        logger.error(f"scan_id error: {e}", exc_info=True)
        return fail(f'Server error: {str(e)}', 500)

def submit_kyc(cur, data, files, ts):
    try:
        require(data, 'user_profile_id', 'gov_id_type', 'birthdate', 'civil_status')
        user_id = data['user_profile_id']

        cur.execute("SELECT id, user_status FROM app_users WHERE id=%s", (user_id,))
        user = cur.fetchone()
        if not user:
            return fail('User not found', 404)

        file_urls = upload_files_from_list(files, 'kyc', user_id)

        similarity_score = None
        face_bytes = None
        id_bytes = None
        for f in files:
            f['content'].seek(0)
            if f['field_name'] == 'face_picture':
                face_bytes = f['content'].read()
                f['content'].seek(0)
            elif f['field_name'] == 'gov_id_front':
                id_bytes = f['content'].read()
                f['content'].seek(0)

        if face_bytes and id_bytes:
            face_result = compare_faces(face_bytes, id_bytes)
            similarity_score = face_result.get('similarity', 0)
            logger.info(f"Face comparison result: {face_result}")

        cur.execute("""
            INSERT INTO app_kyc (
                user_id, signature_image, face_picture,
                gov_id_front, gov_id_back, gov_id_type,
                birthdate, civil_status, face_similarity_score,
                status, submitted_at
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            user_id, file_urls.get('signature_image'), file_urls.get('face_picture'),
            file_urls.get('gov_id_front'), file_urls.get('gov_id_back'),
            sanitize(data.get('gov_id_type')), sanitize(data.get('birthdate')),
            sanitize(data.get('civil_status')), similarity_score, 'PENDING', ts,
        ))

        # Also capture the name as it appears on the ID (user types it during
        # KYC to match the printed card exactly). Stored on app_users in the
        # card_id_* columns AND used to update the main first/middle/last so
        # post-KYC displays match the verified identity. Address + gender
        # come from the Gemini-extracted ID scan so the user's profile gets
        # auto-populated on first KYC.
        card_fn = sanitize(data.get('card_id_first_name') or '')
        card_mn = sanitize(data.get('card_id_middle_name') or '')
        card_ln = sanitize(data.get('card_id_last_name') or '')
        card_sx = sanitize(data.get('card_id_suffix_name') or '')

        gender       = sanitize(data.get('gender'))
        address_line = sanitize(data.get('address_line'))
        region       = sanitize(data.get('region'))
        province     = sanitize(data.get('province'))
        municipality = sanitize(data.get('municipality'))
        barangay     = sanitize(data.get('barangay'))

        # Build dynamic SET clause so we don't overwrite columns the user
        # didn't explicitly send, AND only touch columns that exist on
        # app_users. Skip any UPDATE if every field is blank.
        sets = [
            "profile_photo=%s", "user_status='PENDING'",
            "date_modified=%s", "date_pending=%s",
        ]
        params = [file_urls.get('face_picture'), ts, ts]

        if card_fn or card_ln:
            fullname = ' '.join(
                p for p in [card_fn, card_mn, card_ln, card_sx] if p
            ).strip()
            sets += [
                "card_id_first_name=%s", "card_id_middle_name=%s",
                "card_id_last_name=%s",
                "first_name=%s", "middle_name=%s", "last_name=%s",
                "suffix_name=%s", "fullname=%s",
            ]
            params += [card_fn, card_mn, card_ln,
                       card_fn, card_mn, card_ln, card_sx, fullname]

        # app_users holds the canonical profile; KYC is the source of
        # truth for identity fields so we push the verified values in
        # even if app_users had different data from signup.
        optional = [
            ('gender', gender),
            ('birth_date', sanitize(data.get('birthdate'))),
            ('civil_status', sanitize(data.get('civil_status'))),
            ('address', address_line),
            ('region', region),
            ('province', province),
            ('municipality', municipality),
            ('barangay', barangay),
        ]
        for col, val in optional:
            if val:
                sets.append(f"{col}=%s")
                params.append(val)

        params.append(user_id)
        cur.execute(
            f"UPDATE app_users SET {', '.join(sets)} WHERE id=%s",
            tuple(params),
        )

        return ok({'status': True, 'message': 'KYC submitted successfully', 'face_similarity_score': similarity_score})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"submit_kyc error: {e}", exc_info=True)
        return fail(f'Server error: {str(e)}', 500)

def get_kyc_status(cur, data, files, ts):
    try:
        require(data, 'user_profile_id')
        cur.execute("""
            SELECT id, gov_id_type, birthdate, civil_status,
                   face_similarity_score, status, submitted_at, verified_at, remarks
            FROM app_kyc WHERE user_id=%s ORDER BY submitted_at DESC LIMIT 1
        """, (data['user_profile_id'],))
        kyc = cur.fetchone()
        if not kyc:
            return ok({'status': True, 'kyc_status': 'NONE', 'message': 'No KYC submission found'})
        return ok({'status': True, 'kyc_status': kyc['status'], 'data': serialize_row(kyc)})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"get_kyc_status error: {e}", exc_info=True)
        return fail(f'Server error: {str(e)}', 500)
