"""Legal Consultation endpoints — Bataan branch.

Schema lives in migration 011_bataan_legal_consultations.sql.
Status flow: SUBMITTED → UNDER_REVIEW → SCHEDULED → RESOLVED.
"""
import logging
from helpers.auth import ok, fail, require
from helpers.db import sanitize, serialize_row, generate_number_id

logger = logging.getLogger()

VALID_CONTACT_METHODS = {'SMS', 'EMAIL', 'CALL'}


def submit_legal_consultation(cur, data, files, ts):
    try:
        require(data, 'user_profile_id')
        user_id = data['user_profile_id']

        full_name = sanitize(data.get('full_name'))
        contact_method = (data.get('contact_method') or 'SMS').upper()
        contact_value = sanitize(data.get('contact_value'))
        concern = sanitize(data.get('concern'))

        if not full_name:
            return fail('full_name is required')
        if contact_method not in VALID_CONTACT_METHODS:
            return fail(f'contact_method must be one of {sorted(VALID_CONTACT_METHODS)}')
        if not contact_value:
            return fail('contact_value is required')
        if not concern:
            return fail('concern is required')

        app_number = generate_number_id(cur, 'app_legal_consultations')

        cur.execute("""
            INSERT INTO app_legal_consultations
                (user_id, application_number, full_name, contact_method,
                 contact_value, concern, status, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, 'SUBMITTED', %s, %s)
        """, (user_id, app_number, full_name, contact_method,
              contact_value, concern, ts, ts))

        consultation_id = cur.lastrowid

        cur.execute("""
            INSERT INTO app_legal_consultation_history
                (consultation_id, status, note, actor, created_at)
            VALUES (%s, 'SUBMITTED', %s, %s, %s)
        """, (consultation_id, 'Application submitted via mobile app.',
              user_id, ts))

        return ok({
            'status': True,
            'message': 'Legal consultation request submitted.',
            'application_number': app_number,
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"submit_legal_consultation error: {e}", exc_info=True)
        return fail(f'Server error: {str(e)}', 500)


def list_my_legal_consultations(cur, data, files, ts):
    try:
        require(data, 'user_profile_id')
        cur.execute("""
            SELECT id, application_number, full_name, contact_method,
                   contact_value, concern, status, scheduled_at,
                   resolution_notes, created_at, updated_at
            FROM app_legal_consultations
            WHERE user_id = %s
            ORDER BY created_at DESC
        """, (data['user_profile_id'],))
        rows = [serialize_row(r) for r in cur.fetchall()]
        return ok({'status': True, 'consultations': rows})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"list_my_legal_consultations error: {e}", exc_info=True)
        return fail(f'Server error: {str(e)}', 500)


def get_legal_consultation_detail(cur, data, files, ts):
    try:
        require(data, 'user_profile_id')
        require(data, 'application_number')
        cur.execute("""
            SELECT id, application_number, full_name, contact_method,
                   contact_value, concern, status, scheduled_at,
                   resolution_notes, created_at, updated_at
            FROM app_legal_consultations
            WHERE user_id = %s AND application_number = %s
            LIMIT 1
        """, (data['user_profile_id'], data['application_number']))
        row = cur.fetchone()
        if not row:
            return fail('Consultation not found', 404)
        consultation_id = row['id']

        cur.execute("""
            SELECT status, note, actor, created_at
            FROM app_legal_consultation_history
            WHERE consultation_id = %s
            ORDER BY created_at ASC
        """, (consultation_id,))
        history = [serialize_row(h) for h in cur.fetchall()]

        return ok({
            'status': True,
            'consultation': serialize_row(row),
            'history': history,
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"get_legal_consultation_detail error: {e}", exc_info=True)
        return fail(f'Server error: {str(e)}', 500)
