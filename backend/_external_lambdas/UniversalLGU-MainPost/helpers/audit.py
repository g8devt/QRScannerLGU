import json
import logging

logger = logging.getLogger()


def record_audit_log(cur, admin_id, admin_role, action, target_type, target_id, details, ts):
    try:
        cur.execute("""
            INSERT INTO app_admin_audit_log (
                admin_id, admin_role, action, target_type, target_id, details, created_at
            ) VALUES (%s, %s, %s, %s, %s, %s, %s)
        """, (
            admin_id, admin_role, action, target_type,
            str(target_id) if target_id is not None else None,
            json.dumps(details) if details is not None else None,
            ts,
        ))
    except Exception as e:
        logger.error(f'record_audit_log failed for action={action}: {e}', exc_info=True)
