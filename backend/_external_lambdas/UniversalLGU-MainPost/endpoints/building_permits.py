"""OBO (Office of the Building Official) building permit endpoints — ez_permit Phase 2.

One table (app_obo_building_permit) serves the building-permit application types,
distinguished by `transaction_type` (Unified / Civil-Structural / Excavation).
Signatures are sent as named multipart fields (one per signature column) and
stored as S3 URLs. List fields (form_ownership, scope_of_work,
use_character_occupancy) are stored as JSON strings.
"""
import logging
import json

from helpers.auth import ok, fail, require
from helpers.db import serialize_row, generate_number_id
from helpers.s3 import upload_to_s3, generate_key
from helpers.forms import insert_whitelisted

logger = logging.getLogger()

_TABLE = 'app_obo_building_permit'

_SIGNATURE_FIELDS = (
    'engineer_signature_planner', 'engineer_signature_supervisor',
    'owner_signature', 'lot_owner_signature',
)

# Columns the app may set from form_data (whitelist). Signature columns are NOT
# here — they come from uploaded files. System columns are added separately.
_COLUMNS = [
    'transaction_type', 'first_name', 'middle_name', 'last_name', 'tin',
    'contact_no', 'email', 'residence', 'zip_code', 'house_no', 'lot_no',
    'block_no', 'street', 'tct', 'tax_declaration', 'form_ownership',
    'scope_of_work', 'use_character_occupancy', 'region', 'province', 'city',
    'barangay', 'construction_location_region', 'construction_location_province',
    'construction_location_city', 'construction_location_barangay',
    'occupancy_classification', 'number_of_units', 'number_of_storeys',
    'height_of_building', 'total_floor_area', 'lot_area',
    'proposed_date_of_construction', 'expected_date_of_completion',
    'building_cost', 'electrical_cost', 'mechanical_cost', 'electronics_cost',
    'plumbing_cost', 'total_estimated_cost', 'cost_of_equipment_installed',
    'engineer_full_name_planner', 'engineer_address_planner',
    'engineer_validity_prc_planner', 'engineer_date_issued_ptr_planner',
    'engineer_issued_at_ptr_planner', 'engineer_tin_planner',
    'engineer_full_name_supervisor', 'engineer_address_supervisor',
    'engineer_validity_prc_supervisor', 'engineer_date_issued_ptr_supervisor',
    'engineer_issued_at_ptr_supervisor', 'engineer_tin_supervisor',
    'owner_full_name', 'owner_address', 'owner_government_id',
    'owner_date_issued_id', 'owner_place_issued_id', 'lot_owner_full_name',
    'lot_owner_address', 'lot_owner_government_id', 'lot_owner_date_issued_id',
    'lot_owner_place_issued_id',
]
_INT = {'number_of_units', 'number_of_storeys'}
_DECIMAL = {
    'height_of_building', 'total_floor_area', 'lot_area', 'building_cost',
    'electrical_cost', 'mechanical_cost', 'electronics_cost', 'plumbing_cost',
    'total_estimated_cost', 'cost_of_equipment_installed',
}
_DATE = {
    'proposed_date_of_construction', 'expected_date_of_completion',
    'engineer_date_issued_ptr_planner', 'engineer_date_issued_ptr_supervisor',
    'owner_date_issued_id', 'lot_owner_date_issued_id',
}
_LIST = {'form_ownership', 'scope_of_work', 'use_character_occupancy'}


def _load_form(data):
    raw = data.get('form_data') or '{}'
    try:
        return json.loads(raw) if isinstance(raw, str) else dict(raw)
    except Exception:
        raise ValueError('Invalid form_data JSON')


def submit_obo_building(cur, data, files, ts):
    try:
        require(data, 'user_profile_id')
        user_id = data['user_profile_id']
        form = _load_form(data)

        app_number = generate_number_id(cur, _TABLE)

        # Signatures: each named multipart field → its signature column (S3 URL).
        sig_cols = {}
        for f in files or []:
            fn = f.get('field_name')
            if fn not in _SIGNATURE_FIELDS:
                continue
            f['content'].seek(0)
            key = generate_key(f'obo_building/{user_id}', user_id,
                               f.get('filename') or fn)
            sig_cols[fn] = upload_to_s3(f['content'].read(), key)

        system = {
            'application_number': app_number,
            'status': 'PENDING',
            'datetime_created': ts,
            'datetime_updated': ts,
            'user_id': user_id,
        }
        system.update(sig_cols)

        insert_whitelisted(cur, _TABLE, form, _COLUMNS, system,
                           ints=_INT, decimals=_DECIMAL, dates=_DATE, lists=_LIST)

        return ok({
            'status': True,
            'message': 'Building permit application submitted',
            'application_number': app_number,
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'submit_obo_building error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def list_obo_building(cur, data, files, ts):
    try:
        require(data, 'user_profile_id')
        cur.execute(f"""
            SELECT id, application_number, transaction_type, status,
                   datetime_created
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
        logger.error(f'list_obo_building error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def get_obo_building_detail(cur, data, files, ts):
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
        logger.error(f'get_obo_building_detail error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)
