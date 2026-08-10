import logging

from helpers.audit import record_audit_log
from helpers.auth import ok, fail
from helpers.db import serialize_row

logger = logging.getLogger()

# Global singleton config row — single source of truth for every user.
_SINGLETON_ID = 1

def _ensure_row(cur, ts):
    """Make sure row id=1 exists so GET/UPDATE always have something."""
    cur.execute(
        "INSERT IGNORE INTO app_service_toggles "
        "(id, social_services_enabled, job_application_enabled, "
        "business_permit_enabled, card_registration_enabled, updated_at) "
        "VALUES (%s, 1, 1, 1, 1, %s)",
        (_SINGLETON_ID, ts),
    )

def get_service_toggles(cur, data, files, ts):
    """
    Return the app-wide service toggle row. Creates a default row
    (all enabled) if missing so the client always gets a predictable
    shape. No user_id needed — toggles are global.
    """
    try:
        _ensure_row(cur, ts)
        cur.execute(
            "SELECT * FROM app_service_toggles WHERE id=%s LIMIT 1",
            (_SINGLETON_ID,),
        )
        row = cur.fetchone()
        return ok({'status': True, 'toggles': serialize_row(row)})
    except Exception as e:
        logger.error(f'get_service_toggles error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)

def update_service_toggles(cur, data, files, ts):
    """
    Admin update of the global service toggles. Accepts any subset of:
      social_services_enabled, job_application_enabled,
      business_permit_enabled, card_registration_enabled
    as '0'/'1' (or 'true'/'false', 'yes'/'no', 'on'/'off').
    """
    try:
        _ensure_row(cur, ts)

        updatable = [
            'social_services_enabled',
            'job_application_enabled',
            'business_permit_enabled',
            'card_registration_enabled',
        ]
        sets, params, changed = [], [], {}
        for col in updatable:
            if col in data:
                v = str(data[col]).strip().lower()
                bit = 1 if v in ('1', 'true', 'yes', 'on') else 0
                sets.append(f"{col}=%s")
                params.append(bit)
                changed[col] = bit

        if not sets:
            return fail('No toggle fields provided')

        sets.append("updated_at=%s")
        params.append(ts)
        params.append(_SINGLETON_ID)

        cur.execute(
            f"UPDATE app_service_toggles SET {', '.join(sets)} WHERE id=%s",
            tuple(params),
        )
        cur.execute(
            "SELECT * FROM app_service_toggles WHERE id=%s LIMIT 1",
            (_SINGLETON_ID,),
        )
        result = serialize_row(cur.fetchone())

        admin = data.get('_admin') or {}
        record_audit_log(cur, admin.get('id'), admin.get('role'), 'update_service_toggles',
                          'service_toggles', _SINGLETON_ID, changed, ts)

        return ok({'status': True, 'toggles': result})
    except Exception as e:
        logger.error(f'update_service_toggles error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)
