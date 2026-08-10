"""Permit inspection endpoints — ez_permit Phase 3.

Department inspectors work a per-department worklist of active permits and
submit inspections (photo + GPS + decision). One row per (permit, department)
in app_permit_inspections, upserted on submit.
"""
import logging

from helpers.auth import ok, fail, require
from helpers.db import serialize_row
from helpers.s3 import upload_to_s3, generate_key
from helpers.forms import parse_decimal

logger = logging.getLogger()

_TABLE = 'app_permit_inspections'
_DEPARTMENTS = {
    'MENRO', 'ENGINEERING', 'ZONING', 'ASSESSOR', 'BFP', 'TREASURY', 'SANITARY',
}
_APPROVALS = {'INSPECTED', 'FOR_COMPLIANCE', 'DENIED'}
# Permit statuses an inspector still acts on.
_ACTIVE = ('PENDING', 'UNDER_REVIEW')


def _require_department(data):
    dept = (data.get('department') or '').strip().upper()
    if dept not in _DEPARTMENTS:
        raise ValueError('Invalid department')
    return dept


def fetch_inspector_worklist(cur, data, files, ts):
    try:
        dept = _require_department(data)
        search = (data.get('search') or '').strip()

        sql = f"""
            SELECT p.application_number, p.business_name, p.owner_fname,
                   p.owner_lname, p.address_line, p.barangay, p.municipality,
                   p.province, p.status AS permit_status, p.date_submitted,
                   COALESCE(i.status, 'SCHEDULED') AS inspection_status,
                   i.datetime_updated AS inspected_at
            FROM app_business_permits p
            LEFT JOIN {_TABLE} i
                   ON i.application_number = p.application_number
                  AND i.department = %s
            WHERE p.status IN ('PENDING','UNDER_REVIEW')
        """
        params = [dept]
        if search:
            sql += " AND (p.business_name LIKE %s OR p.application_number LIKE %s)"
            like = f'%{search}%'
            params += [like, like]
        sql += " ORDER BY p.date_submitted DESC"
        cur.execute(sql, tuple(params))
        rows = cur.fetchall()

        stats = {'total': len(rows), 'inspected': 0, 'for_compliance': 0,
                 'scheduled': 0}
        for r in rows:
            st = (r.get('inspection_status') or 'SCHEDULED').upper()
            if st == 'INSPECTED':
                stats['inspected'] += 1
            elif st == 'FOR_COMPLIANCE':
                stats['for_compliance'] += 1
            else:
                stats['scheduled'] += 1

        return ok({
            'status': True,
            'data': {'items': [serialize_row(r) for r in rows], 'stats': stats},
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'fetch_inspector_worklist error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def submit_inspection(cur, data, files, ts):
    try:
        require(data, 'user_profile_id', 'application_number', 'approval')
        dept = _require_department(data)
        user_id = data['user_profile_id']
        app_number = data['application_number']
        approval = (data['approval'] or '').strip().upper()
        if approval not in _APPROVALS:
            return fail('Invalid approval value')

        photo_url = None
        for f in files or []:
            if f.get('field_name') != 'inspection_photo':
                continue
            f['content'].seek(0)
            key = generate_key(f'permit_inspections/{app_number}', user_id,
                               f.get('filename') or 'inspection')
            photo_url = upload_to_s3(f['content'].read(), key)
            break

        cur.execute(f"""
            INSERT INTO {_TABLE} (
                application_number, department, status, remarks,
                inspection_photo_url, latitude, longitude, geo_tagging,
                inspected_by, datetime_created, datetime_updated
            ) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
            ON DUPLICATE KEY UPDATE
                status=VALUES(status),
                remarks=VALUES(remarks),
                inspection_photo_url=COALESCE(VALUES(inspection_photo_url), inspection_photo_url),
                latitude=VALUES(latitude),
                longitude=VALUES(longitude),
                geo_tagging=VALUES(geo_tagging),
                inspected_by=VALUES(inspected_by),
                datetime_updated=VALUES(datetime_updated)
        """, (
            app_number, dept, approval,
            (data.get('remarks') or '').strip() or None,
            photo_url,
            parse_decimal(data.get('latitude')),
            parse_decimal(data.get('longitude')),
            (data.get('geo_tagging') or '').strip() or None,
            user_id, ts, ts,
        ))

        return ok({'status': True, 'message': 'Inspection submitted'})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'submit_inspection error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def get_inspection_detail(cur, data, files, ts):
    try:
        require(data, 'application_number')
        cur.execute(
            f"SELECT * FROM {_TABLE} WHERE application_number=%s ORDER BY department",
            (data['application_number'],))
        rows = cur.fetchall()
        return ok({
            'status': True,
            'data': {'items': [serialize_row(r) for r in rows]},
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'get_inspection_detail error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)
