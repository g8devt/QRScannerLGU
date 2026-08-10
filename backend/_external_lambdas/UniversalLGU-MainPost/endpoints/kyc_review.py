import logging
from helpers.auth import ok, fail, require
from helpers.db import sanitize, serialize_row
from helpers.audit import record_audit_log

logger = logging.getLogger()

VALID_STATUSES = ('PENDING', 'VERIFIED', 'RECOMPLIANCE', 'REJECTED')


def list_kyc_queue(cur, data, files, ts):
    try:
        status = sanitize(data.get('status'))
        if status:
            status = status.upper()
            if status not in VALID_STATUSES and status != 'ALL':
                return fail('Invalid status filter')

        search = sanitize(data.get('search'))
        date_from = sanitize(data.get('date_from'))
        date_to = sanitize(data.get('date_to'))

        where = []
        params = []
        if status and status != 'ALL':
            where.append('k.status=%s')
            params.append(status)
        if search:
            like = f'%{search}%'
            where.append('(u.fullname LIKE %s OR u.email_address LIKE %s OR u.mobile_number LIKE %s)')
            params += [like, like, like]
        if date_from:
            where.append('k.submitted_at >= %s')
            params.append(date_from)
        if date_to:
            where.append('k.submitted_at <= %s')
            params.append(f'{date_to} 23:59:59')

        where_sql = f"WHERE {' AND '.join(where)}" if where else ''
        cur.execute(f"""
            SELECT k.id, k.user_id, u.fullname, u.email_address, u.mobile_number,
                   k.gov_id_type, k.status, k.submitted_at, k.verified_at,
                   k.reviewed_by, k.face_similarity_score
            FROM app_kyc k
            JOIN app_users u ON u.id = k.user_id
            {where_sql}
            ORDER BY k.submitted_at DESC
        """, tuple(params))
        rows = cur.fetchall()

        cur.execute("SELECT status, COUNT(*) AS c FROM app_kyc GROUP BY status")
        raw_counts = {row['status']: row['c'] for row in cur.fetchall()}
        stat_counts = {s: raw_counts.get(s, 0) for s in VALID_STATUSES}
        stat_counts['ALL'] = sum(stat_counts.values())

        return ok({
            'status': True,
            'items': [serialize_row(r) for r in rows],
            'counts': stat_counts,
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"list_kyc_queue error: {e}", exc_info=True)
        return fail(f'Server error: {str(e)}', 500)


def get_kyc_detail(cur, data, files, ts):
    try:
        require(data, 'kyc_id')
        cur.execute("""
            SELECT k.id, k.user_id, u.fullname, u.email_address, u.mobile_number,
                   k.signature_image, k.face_picture, k.gov_id_front, k.gov_id_back,
                   k.gov_id_type, k.birthdate, k.civil_status, k.face_similarity_score,
                   k.status, k.submitted_at, k.verified_at, k.reviewed_by,
                   k.remarks, k.recompliance_items
            FROM app_kyc k
            JOIN app_users u ON u.id = k.user_id
            WHERE k.id=%s
        """, (data['kyc_id'],))
        row = cur.fetchone()
        if not row:
            return fail('KYC submission not found', 404)
        return ok({'status': True, 'data': serialize_row(row)})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"get_kyc_detail error: {e}", exc_info=True)
        return fail(f'Server error: {str(e)}', 500)


STATUS_TO_USER_STATUS = {
    'VERIFIED': 'VERIFIED',
    'RECOMPLIANCE': 'RECOMPLIANCE',
    'REJECTED': 'REJECTED',
}


def update_kyc_status(cur, data, files, ts):
    try:
        require(data, 'kyc_id', 'status')
        new_status = sanitize(data['status']).upper()
        if new_status not in STATUS_TO_USER_STATUS:
            return fail('status must be VERIFIED, RECOMPLIANCE, or REJECTED')

        reason = sanitize(data.get('reason') or '') or ''
        if new_status in ('RECOMPLIANCE', 'REJECTED') and len(reason) < 10:
            return fail('reason must be at least 10 characters when sending back for recompliance or rejecting')

        kyc_id = data['kyc_id']
        cur.execute("SELECT user_id FROM app_kyc WHERE id=%s", (kyc_id,))
        kyc = cur.fetchone()
        if not kyc:
            return fail('KYC submission not found', 404)

        admin = data.get('_admin') or {}
        reviewed_by = 'Unknown'
        if admin.get('id'):
            cur.execute("SELECT name FROM app_admins WHERE id=%s", (admin['id'],))
            admin_row = cur.fetchone()
            if admin_row and admin_row.get('name'):
                reviewed_by = admin_row['name']

        sets = ["status=%s", "reviewed_by=%s"]
        params = [new_status, reviewed_by]
        if new_status == 'VERIFIED':
            sets.append("verified_at=%s")
            params.append(ts)
        if new_status in ('RECOMPLIANCE', 'REJECTED'):
            sets.append("remarks=%s")
            params.append(reason)
        params.append(kyc_id)
        cur.execute(f"UPDATE app_kyc SET {', '.join(sets)} WHERE id=%s", tuple(params))

        user_status = STATUS_TO_USER_STATUS[new_status]
        user_sets = ["user_status=%s", "date_modified=%s"]
        user_params = [user_status, ts]
        if new_status == 'VERIFIED':
            user_sets.append("date_verified=%s")
            user_params.append(ts)
        user_params.append(kyc['user_id'])
        cur.execute(f"UPDATE app_users SET {', '.join(user_sets)} WHERE id=%s", tuple(user_params))

        record_audit_log(cur, admin.get('id'), admin.get('role'), 'update_kyc_status',
                          'kyc', kyc_id, {'status': new_status, 'reason': reason or None}, ts)

        return ok({'status': True, 'kyc_id': kyc_id, 'new_status': new_status})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"update_kyc_status error: {e}", exc_info=True)
        return fail(f'Server error: {str(e)}', 500)
