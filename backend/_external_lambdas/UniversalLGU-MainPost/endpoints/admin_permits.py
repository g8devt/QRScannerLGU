"""Admin console endpoints — ez_permit Phase 4.

Municipal admins review ALL permits (not user-scoped), act on them, verify a
permit by QR, view geo-tagged permits on a map, and approve/reject Link Business
requests. Reuses app_business_permits, app_business_link_requests (Phase 1) and
app_permit_inspections (Phase 3) — no new tables.
"""
import logging
import uuid

from helpers.auth import ok, fail, require
from helpers.db import sanitize, serialize_row
from helpers.forms import parse_int
from helpers.audit import record_audit_log

logger = logging.getLogger()


def _new_app_number(ts):
    return 'BP' + ts.strftime('%Y%m%d') + uuid.uuid4().hex[:6].upper()


def fetch_all_permits(cur, data, files, ts):
    try:
        page = max(parse_int(data.get('page')) or 1, 1)
        limit = min(max(parse_int(data.get('limit')) or 20, 1), 100)
        offset = (page - 1) * limit
        search = (data.get('search') or '').strip()
        status = (data.get('status') or '').strip().upper()

        where = []
        params = []
        if status and status != 'ALL':
            where.append("status=%s")
            params.append(status)
        if search:
            where.append("(business_name LIKE %s OR application_number LIKE %s "
                         "OR permit_number LIKE %s)")
            like = f'%{search}%'
            params += [like, like, like]
        clause = ('WHERE ' + ' AND '.join(where)) if where else ''

        cur.execute(f"""
            SELECT id, application_number, application_type, business_name,
                   owner_fname, owner_lname, status, permit_number, date_submitted
            FROM app_business_permits
            {clause}
            ORDER BY date_submitted DESC
            LIMIT %s OFFSET %s
        """, tuple(params + [limit + 1, offset]))
        rows = cur.fetchall()
        has_more = len(rows) > limit
        rows = rows[:limit]
        return ok({
            'status': True,
            'data': {
                'items': [serialize_row(r) for r in rows],
                'page': page,
                'has_more': has_more,
            },
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'fetch_all_permits error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def fetch_permit_status_counts(cur, data, files, ts):
    try:
        search = (data.get('search') or '').strip()
        params = []
        clause = ''
        if search:
            clause = ("WHERE business_name LIKE %s OR application_number LIKE %s "
                      "OR permit_number LIKE %s")
            like = f'%{search}%'
            params = [like, like, like]
        cur.execute(
            f"SELECT status, COUNT(*) AS c FROM app_business_permits {clause} "
            f"GROUP BY status", tuple(params))
        counts = {}
        total = 0
        for r in cur.fetchall():
            st = (r.get('status') or '').upper()
            c = int(r.get('c') or 0)
            counts[st] = c
            total += c
        counts['ALL'] = total
        return ok({'status': True, 'data': counts})
    except Exception as e:
        logger.error(f'fetch_permit_status_counts error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def admin_review_permit(cur, data, files, ts):
    try:
        require(data, 'application_number', 'decision')
        app_number = data['application_number']
        decision = (data['decision'] or '').strip().upper()
        if decision not in ('APPROVED', 'REJECTED'):
            return fail('Invalid decision')
        remarks = sanitize(data.get('remarks'))

        if decision == 'APPROVED':
            cur.execute("""
                UPDATE app_business_permits
                   SET status='APPROVED', remarks=%s, permit_number=%s,
                       date_reviewed=%s, date_approved=%s
                 WHERE application_number=%s
            """, (remarks, sanitize(data.get('permit_number')), ts, ts, app_number))
        else:
            cur.execute("""
                UPDATE app_business_permits
                   SET status='REJECTED', remarks=%s, date_reviewed=%s
                 WHERE application_number=%s
            """, (remarks, ts, app_number))

        admin = data.get('_admin') or {}
        record_audit_log(cur, admin.get('id'), admin.get('role'), 'admin_review_permit',
                          'permit', app_number, {'decision': decision}, ts)

        return ok({'status': True, 'message': f'Permit {decision.lower()}'})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'admin_review_permit error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def verify_permit_qr(cur, data, files, ts):
    try:
        require(data, 'code')
        code = (data['code'] or '').strip()
        cur.execute("""
            SELECT application_number, application_type, business_name,
                   trade_name, business_type, owner_fname, owner_lname,
                   address_line, barangay, municipality, province,
                   status, permit_number
            FROM app_business_permits
            WHERE permit_number=%s OR application_number=%s
            LIMIT 1
        """, (code, code))
        row = cur.fetchone()
        if not row:
            return ok({'status': True, 'data': {'found': False}})
        return ok({'status': True,
                   'data': {'found': True, 'data': serialize_row(row)}})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'verify_permit_qr error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def fetch_permit_map(cur, data, files, ts):
    try:
        cur.execute("""
            SELECT p.application_number, p.business_name, p.status,
                   MAX(i.latitude)  AS latitude,
                   MAX(i.longitude) AS longitude
            FROM app_business_permits p
            JOIN app_permit_inspections i
                 ON i.application_number = p.application_number
            WHERE i.latitude IS NOT NULL AND i.longitude IS NOT NULL
            GROUP BY p.application_number, p.business_name, p.status
        """)
        rows = cur.fetchall()
        return ok({'status': True,
                   'data': {'items': [serialize_row(r) for r in rows]}})
    except Exception as e:
        logger.error(f'fetch_permit_map error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def admin_list_business_links(cur, data, files, ts):
    try:
        status = (data.get('status') or 'PENDING').strip().upper()
        params = []
        clause = ''
        if status and status != 'ALL':
            clause = 'WHERE status=%s'
            params = [status]
        cur.execute(f"""
            SELECT id, user_id, business_permit_no, photo_url, status, remarks,
                   reviewed_by, created_at, updated_at
            FROM app_business_link_requests
            {clause}
            ORDER BY created_at DESC
        """, tuple(params))
        rows = cur.fetchall()
        return ok({'status': True,
                   'data': {'items': [serialize_row(r) for r in rows]}})
    except Exception as e:
        logger.error(f'admin_list_business_links error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def admin_review_business_link(cur, data, files, ts):
    try:
        require(data, 'request_id', 'decision')
        decision = (data['decision'] or '').strip().upper()
        if decision not in ('APPROVE', 'REJECT'):
            return fail('Invalid decision')

        cur.execute(
            "SELECT id, user_id, business_permit_no FROM app_business_link_requests "
            "WHERE id=%s LIMIT 1", (data['request_id'],))
        req = cur.fetchone()
        if not req:
            return fail('Link request not found', 404)

        new_status = 'APPROVED' if decision == 'APPROVE' else 'REJECTED'
        cur.execute("""
            UPDATE app_business_link_requests
               SET status=%s, reviewed_by=%s, remarks=%s, updated_at=%s
             WHERE id=%s
        """, (new_status, sanitize(data.get('admin_id')),
              sanitize(data.get('remarks')), ts, data['request_id']))

        result = {'request_id': str(data['request_id'])}
        if decision == 'APPROVE':
            # Materialize an APPROVED permit for the requester so it appears in
            # their "My Businesses". Owner/address are placeholders (unknown from
            # the link request); business_name is admin-supplied.
            app_number = _new_app_number(ts)
            biz_name = sanitize(data.get('business_name')) or '(Linked Business)'
            cur.execute("""
                INSERT INTO app_business_permits (
                    user_id, application_number, application_type, business_name,
                    owner_fname, owner_lname, owner_mobile,
                    address_line, barangay, municipality, province,
                    status, permit_number, date_submitted, date_approved
                ) VALUES (%s,%s,'NEW',%s,'-','-','-','-','-','-','-',
                          'APPROVED',%s,%s,%s)
            """, (req['user_id'], app_number, biz_name,
                  req.get('business_permit_no') or '', ts, ts))
            result['application_number'] = app_number

        admin = data.get('_admin') or {}
        record_audit_log(cur, admin.get('id'), admin.get('role'), 'admin_review_business_link',
                          'business_link', data['request_id'], {'decision': new_status}, ts)

        return ok({'status': True,
                   'message': f'Link request {new_status.lower()}',
                   'data': result})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'admin_review_business_link error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)
