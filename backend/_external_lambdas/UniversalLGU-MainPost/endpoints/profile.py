import json
import logging
from helpers.auth import ok, fail, require
from helpers.db import sanitize, serialize_row, generate_number_id

logger = logging.getLogger()

ALLOWED_FIELDS = [
    'first_name', 'middle_name', 'last_name', 'suffix_name',
    'email_address', 'gender', 'birth_date',
    'address', 'region', 'province', 'district', 'municipality', 'barangay',
]

def get_user_profile(cur, data, files, ts):
    """Return the full app_users row for the signed-in user.
    Uses relaxed sql_mode + CAST-to-CHAR on date columns to survive
    legacy rows with invalid DATE values like '' or '0000-00-00'."""
    try:
        require(data, 'user_profile_id')
        try:
            cur.execute("SET SESSION sql_mode = ''")
        except Exception:
            pass
        cur.execute(
            "SELECT id, status, user_status, user_type, fullname, "
            "first_name, middle_name, last_name, suffix_name, "
            "mobile_number, email_address, address, region, province, "
            "district, municipality, barangay, gender, "
            "CAST(birth_date AS CHAR) AS birth_date, "
            "profile_photo, card_id_first_name, card_id_middle_name, "
            "card_id_last_name, card_id_type, card_id_no "
            "FROM app_users WHERE id=%s",
            (data['user_profile_id'],))
        row = cur.fetchone()
        if not row:
            return fail('User not found', 404)
        return ok({'status': True, 'data': serialize_row(row)})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'get_user_profile: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def request_profile_update(cur, data, files, ts):
    try:
        require(data, 'user_profile_id', 'updates')
        user_id = data['user_profile_id']

        cur.execute("SELECT * FROM app_users WHERE id=%s", (user_id,))
        user = cur.fetchone()
        if not user:
            return fail('User not found', 404)

        updates = json.loads(data['updates']) if isinstance(data['updates'], str) else data['updates']
        if not isinstance(updates, list) or len(updates) == 0:
            return fail('Updates must be a non-empty array')

        inserted = 0
        for item in updates:
            field_name = item.get('field_name', '')
            requested_value = item.get('requested_value', '')
            if field_name not in ALLOWED_FIELDS:
                continue
            current_value = user.get(field_name, '')
            cur.execute("""
                INSERT INTO app_profile_update_requests
                    (user_id, field_name, current_value, requested_value, status, requested_at)
                VALUES (%s, %s, %s, %s, 'PENDING', %s)
            """, (user_id, field_name, current_value, sanitize(requested_value), ts))
            inserted += 1

        if inserted == 0:
            return fail('No valid fields to update')

        return ok({'status': True, 'message': f'{inserted} update request(s) submitted', 'count': inserted})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"request_profile_update error: {e}", exc_info=True)
        return fail(f'Server error: {str(e)}', 500)

def get_profile_update_requests(cur, data, files, ts):
    try:
        require(data, 'user_profile_id')
        cur.execute("""
            SELECT id, field_name, current_value, requested_value,
                   status, admin_remarks, requested_at, reviewed_at
            FROM app_profile_update_requests
            WHERE user_id=%s ORDER BY requested_at DESC
        """, (data['user_profile_id'],))
        rows = cur.fetchall()
        return ok({
            'status': True,
            'requests': [serialize_row(r) for r in rows],
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"get_profile_update_requests error: {e}", exc_info=True)
        return fail(f'Server error: {str(e)}', 500)
