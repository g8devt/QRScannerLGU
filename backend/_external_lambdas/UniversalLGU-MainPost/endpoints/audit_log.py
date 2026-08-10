import json
import logging

from helpers.auth import ok, fail
from helpers.db import serialize_row
from helpers.forms import parse_int

logger = logging.getLogger()

_KNOWN_ACTIONS = {
    'review_admin_kyc', 'admin_review_permit', 'admin_review_business_link',
    'admin_update_incident_status', 'admin_assess_permit',
    'create_staff', 'update_staff_permissions', 'deactivate_staff',
    'create_invite', 'revoke_invite',
    'admin_update_destination', 'upload_tourism_images',
    'admin_update_social_service_status', 'admin_review_birth_registration',
    'admin_review_card_registration', 'update_service_toggles',
    'admin_review_job_posting', 'admin_review_card_request',
    'admin_send_notification', 'admin_delete_notification',
    'update_kyc_status',
}
_KNOWN_TARGET_TYPES = {
    'kyc_submission', 'permit', 'business_link', 'incident_report',
    'staff', 'invite', 'destination', 'social_service', 'birth_registration',
    'card_registration', 'service_toggles', 'job_posting', 'card_request',
    'notification', 'kyc',
}


def admin_list_audit_log(cur, data, files, ts):
    try:
        page = max(parse_int(data.get('page')) or 1, 1)
        limit = min(max(parse_int(data.get('limit')) or 20, 1), 100)
        offset = (page - 1) * limit
        action = (data.get('action') or '').strip()
        target_type = (data.get('target_type') or '').strip()

        where = []
        params = []
        if action and action != 'ALL':
            if action not in _KNOWN_ACTIONS:
                return fail(f'Invalid action: {action}')
            where.append('a.action=%s')
            params.append(action)
        if target_type and target_type != 'ALL':
            if target_type not in _KNOWN_TARGET_TYPES:
                return fail(f'Invalid target_type: {target_type}')
            where.append('a.target_type=%s')
            params.append(target_type)
        clause = ('WHERE ' + ' AND '.join(where)) if where else ''

        cur.execute(f"""
            SELECT a.id, a.admin_id, a.admin_role, a.action, a.target_type,
                   a.target_id, a.details, a.created_at,
                   m.name AS admin_name, m.email AS admin_email
            FROM app_admin_audit_log a
            LEFT JOIN app_admins m ON m.id = a.admin_id
            {clause}
            ORDER BY a.created_at DESC
            LIMIT %s OFFSET %s
        """, tuple(params + [limit + 1, offset]))
        rows = cur.fetchall() or []
        has_more = len(rows) > limit
        rows = rows[:limit]
        out = []
        for r in rows:
            r = dict(r) if not isinstance(r, dict) else r
            raw = r.get('details')
            if isinstance(raw, str) and raw:
                try:
                    r['details'] = json.loads(raw)
                except Exception:
                    r['details'] = None
            out.append(serialize_row(r))
        return ok({'status': True,
                   'data': {'items': out, 'page': page, 'has_more': has_more}})
    except Exception as e:
        logger.error(f'admin_list_audit_log error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)
