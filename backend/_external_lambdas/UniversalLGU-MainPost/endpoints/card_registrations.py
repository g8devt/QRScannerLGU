import logging
import json
import uuid
from datetime import datetime

from helpers.auth import ok, fail, require
from helpers.audit import record_audit_log
from helpers.db import sanitize, serialize_row
from helpers.forms import parse_int
from helpers.s3 import upload_to_s3, generate_key

logger = logging.getLogger()

_FILE_FIELDS = {
    'photo_url':      'photo',          # portrait for the card
    'signature_url':  'signature',
    'id_photo_url':   'id_photo',       # ID attachment
}

_CARD_REG_STATUSES = {'PENDING', 'UNDER_REVIEW', 'APPROVED', 'REJECTED'}

def _ref_number():
    return 'CR' + datetime.now().strftime('%Y%m%d') + uuid.uuid4().hex[:6].upper()

def _upload_files(files, user_id, ref):
    urls = {}
    by_field = {}
    for f in files:
        by_field.setdefault(f.get('field_name', ''), []).append(f)
    for col, mpf in _FILE_FIELDS.items():
        grouped = by_field.get(mpf, [])
        if not grouped:
            urls[col] = ''
            continue
        f = grouped[0]
        f['content'].seek(0)
        content = f['content'].read()
        key = generate_key(
            f'card_registrations/{user_id}/{ref}', user_id,
            f.get('filename') or mpf,
        )
        urls[col] = upload_to_s3(content, key)
    return urls

def submit_card_registration(cur, data, files, ts):
    try:
        require(data, 'user_profile_id')
        user_id = data['user_profile_id']
        raw = data.get('form_data') or '{}'
        try:
            form = json.loads(raw) if isinstance(raw, str) else dict(raw)
        except Exception:
            return fail('Invalid form_data JSON')

        for field in ('first_name', 'last_name', 'mobile', 'barangay',
                      'city_municipality', 'province'):
            if not (form.get(field) or '').strip():
                return fail(f'Missing required field: {field}')

        ref = _ref_number()
        urls = _upload_files(files, user_id, ref)

        cur.execute("""
            INSERT INTO app_card_registrations (
                user_id, reference_number,
                first_name, middle_name, last_name, suffix,
                mobile, email,
                residence_detail, barangay, city_municipality, province,
                region, zip_code,
                photo_url, signature_url, id_photo_url,
                status, date_submitted
            ) VALUES (
                %s, %s,
                %s, %s, %s, %s,
                %s, %s,
                %s, %s, %s, %s,
                %s, %s,
                %s, %s, %s,
                'PENDING', %s
            )
        """, (
            user_id, ref,
            sanitize(form.get('first_name')),
            sanitize(form.get('middle_name')),
            sanitize(form.get('last_name')),
            sanitize(form.get('suffix')),
            sanitize(form.get('mobile')),
            sanitize(form.get('email')),
            sanitize(form.get('residence_detail')),
            sanitize(form.get('barangay')),
            sanitize(form.get('city_municipality')),
            sanitize(form.get('province')),
            sanitize(form.get('region')),
            sanitize(form.get('zip_code')),
            urls.get('photo_url', ''),
            urls.get('signature_url', ''),
            urls.get('id_photo_url', ''),
            ts,
        ))

        return ok({
            'status': True,
            'message': 'Card registration submitted',
            'reference_number': ref,
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'submit_card_registration error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)

def get_card_registrations(cur, data, files, ts):
    try:
        require(data, 'user_profile_id')
        cur.execute("""
            SELECT id, reference_number, first_name, middle_name, last_name,
                   suffix, barangay, city_municipality, province,
                   status, card_number, remarks,
                   date_submitted, date_reviewed, date_approved
            FROM app_card_registrations
            WHERE user_id=%s
            ORDER BY date_submitted DESC
        """, (data['user_profile_id'],))
        rows = cur.fetchall()
        return ok({'status': True, 'registrations': [serialize_row(r) for r in rows]})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'get_card_registrations error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)

def get_card_registration_detail(cur, data, files, ts):
    try:
        require(data, 'user_profile_id', 'reference_number')
        cur.execute("""
            SELECT * FROM app_card_registrations
            WHERE user_id=%s AND reference_number=%s LIMIT 1
        """, (data['user_profile_id'], data['reference_number']))
        row = cur.fetchone()
        if not row:
            return fail('Registration not found', 404)
        return ok({'status': True, 'data': serialize_row(row)})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'get_card_registration_detail error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def admin_list_card_registrations(cur, data, files, ts):
    try:
        page = max(parse_int(data.get('page')) or 1, 1)
        limit = min(max(parse_int(data.get('limit')) or 20, 1), 100)
        offset = (page - 1) * limit
        status = (data.get('status') or '').strip().upper()

        where = []
        params = []
        if status and status != 'ALL':
            if status not in _CARD_REG_STATUSES:
                return fail(f'Invalid status: {status}')
            where.append('status=%s')
            params.append(status)
        clause = ('WHERE ' + ' AND '.join(where)) if where else ''

        cur.execute(f"""
            SELECT id, user_id, reference_number, first_name, middle_name, last_name,
                   suffix, barangay, city_municipality, province,
                   status, card_number, remarks,
                   date_submitted, date_reviewed, date_approved
            FROM app_card_registrations
            {clause}
            ORDER BY date_submitted DESC
            LIMIT %s OFFSET %s
        """, tuple(params + [limit + 1, offset]))
        rows = cur.fetchall() or []
        has_more = len(rows) > limit
        rows = rows[:limit]
        return ok({'status': True,
                   'data': {'items': [serialize_row(r) for r in rows],
                            'page': page, 'has_more': has_more}})
    except Exception as e:
        logger.error(f'admin_list_card_registrations error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def admin_review_card_registration(cur, data, files, ts):
    try:
        require(data, 'reference_number', 'decision')
        ref = data['reference_number']
        decision = (data['decision'] or '').strip().upper()
        if decision not in ('APPROVED', 'REJECTED'):
            return fail('Invalid decision')
        remarks = sanitize(data.get('remarks'))
        if decision == 'REJECTED' and not remarks:
            return fail('remarks is required when rejecting')
        card_number = sanitize(data.get('card_number'))
        if decision == 'APPROVED' and not card_number:
            return fail('card_number is required when approving')

        cur.execute(
            "SELECT id FROM app_card_registrations WHERE reference_number=%s",
            (ref,))
        if not cur.fetchone():
            return fail('Registration not found', 404)

        if decision == 'APPROVED':
            cur.execute("""
                UPDATE app_card_registrations
                   SET status=%s, remarks=%s, card_number=%s, date_reviewed=%s, date_approved=%s
                 WHERE reference_number=%s
            """, (decision, remarks, card_number, ts, ts, ref))
        else:
            cur.execute("""
                UPDATE app_card_registrations
                   SET status=%s, remarks=%s, date_reviewed=%s
                 WHERE reference_number=%s
            """, (decision, remarks, ts, ref))

        admin = data.get('_admin') or {}
        record_audit_log(cur, admin.get('id'), admin.get('role'),
                          'admin_review_card_registration', 'card_registration',
                          ref, {'decision': decision}, ts)

        return ok({'status': True, 'message': f'Registration {decision.lower()}'})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'admin_review_card_registration error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)
