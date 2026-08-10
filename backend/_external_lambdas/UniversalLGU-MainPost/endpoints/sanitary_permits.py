"""CHO (City Health Office) sanitary permit endpoints — ez_permit Phase 2.

One table (app_cho_sanitary_permit) serves all sanitary application types; each
type submits only the fields it uses. Up to two documents are stored in
file_1 / file_2 (multipart field name `sanitary_file`).
"""
import logging
import json

from helpers.auth import ok, fail, require
from helpers.db import serialize_row, generate_number_id
from helpers.s3 import upload_to_s3, generate_key
from helpers.forms import insert_whitelisted

logger = logging.getLogger()

_TABLE = 'app_cho_sanitary_permit'

# Columns the app may set from form_data (whitelist; unknown keys ignored).
_COLUMNS = [
    'application_type', 'first_name', 'middle_name', 'last_name', 'age',
    'gender', 'barangay', 'name_of_establishment', 'address_of_establishment',
    'specify_establishment', 'schedule_inspection', 'contact_no',
    'occupation_designation', 'date_construction_septic', 'name_informant',
    'name_cadaver', 'name_of_funeral', 'nationality', 'name_cemetery',
    'cause_of_death', 'quantity', 'unit', 'specify_food_products',
    'place_transferred', 'date_transferred', 'name_client', 'water_source',
    'sampling_point', 'date_water_collection',
]
_INT = {'age'}
_DECIMAL = {'quantity'}
_DATE = {'schedule_inspection', 'date_construction_septic', 'date_transferred',
         'date_water_collection'}


def _load_form(data):
    raw = data.get('form_data') or '{}'
    try:
        return json.loads(raw) if isinstance(raw, str) else dict(raw)
    except Exception:
        raise ValueError('Invalid form_data JSON')


def submit_cho_sanitary(cur, data, files, ts):
    try:
        require(data, 'user_profile_id')
        user_id = data['user_profile_id']
        form = _load_form(data)

        app_number = generate_number_id(cur, _TABLE)

        # Up to two documents (field name `sanitary_file`) → file_1, file_2.
        urls = []
        for f in files or []:
            if f.get('field_name') != 'sanitary_file':
                continue
            f['content'].seek(0)
            key = generate_key(f'cho_sanitary/{user_id}', user_id,
                               f.get('filename') or 'sanitary')
            urls.append(upload_to_s3(f['content'].read(), key))

        system = {
            'application_number': app_number,
            'status': 'PENDING',
            'datetime_created': ts,
            'user_id': user_id,
            'file_1': urls[0] if len(urls) > 0 else None,
            'file_2': urls[1] if len(urls) > 1 else None,
        }
        insert_whitelisted(cur, _TABLE, form, _COLUMNS, system,
                           ints=_INT, decimals=_DECIMAL, dates=_DATE)

        return ok({
            'status': True,
            'message': 'Sanitary permit application submitted',
            'application_number': app_number,
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'submit_cho_sanitary error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def list_cho_sanitary(cur, data, files, ts):
    try:
        require(data, 'user_profile_id')
        cur.execute(f"""
            SELECT id, application_number, application_type,
                   name_of_establishment, status, datetime_created
            FROM {_TABLE}
            WHERE user_id=%s
            ORDER BY datetime_created DESC
        """, (data['user_profile_id'],))
        rows = cur.fetchall()
        return ok({
            'status': True,
            'data': {'items': [serialize_row(r) for r in rows], 'count': len(rows)},
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'list_cho_sanitary error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def get_cho_sanitary_detail(cur, data, files, ts):
    try:
        require(data, 'user_profile_id', 'application_number')
        cur.execute(
            f"SELECT * FROM {_TABLE} WHERE user_id=%s AND application_number=%s LIMIT 1",
            (data['user_profile_id'], data['application_number']))
        row = cur.fetchone()
        if not row:
            return fail('Application not found', 404)
        return ok({'status': True, 'data': serialize_row(row)})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'get_cho_sanitary_detail error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)
