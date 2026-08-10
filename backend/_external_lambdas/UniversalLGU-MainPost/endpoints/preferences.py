import json
import logging
from helpers.auth import ok, fail, require

logger = logging.getLogger()

# Preferences live in district_6_db (tenant DB). One row per user, JSON blob
# for forward-compatibility — adding a new preference key requires no schema
# change. Keys are lowercase snake_case and must match the Flutter constants
# in PreferencesService.

_PREFS_TABLE_DDL = """
CREATE TABLE IF NOT EXISTS `app_user_preferences` (
  `user_profile_id` INT NOT NULL PRIMARY KEY,
  `prefs_json`      JSON NOT NULL,
  `date_created`    DATETIME DEFAULT CURRENT_TIMESTAMP,
  `date_modified`   DATETIME DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
"""

_DEFAULTS = {
    'notifications_enabled': True,
    'biometric_enabled': False,
    'dark_mode_enabled': False,
}


def _ensure_table(cur):
    try:
        cur.execute(_PREFS_TABLE_DDL)
    except Exception as e:
        logger.warning(f"ensure prefs table: {e}")


def _load_prefs(cur, user_profile_id):
    cur.execute(
        "SELECT prefs_json FROM app_user_preferences WHERE user_profile_id=%s",
        (user_profile_id,),
    )
    row = cur.fetchone()
    if not row:
        return dict(_DEFAULTS)
    raw = row.get('prefs_json') if isinstance(row, dict) else row[0]
    if isinstance(raw, (bytes, bytearray)):
        raw = raw.decode('utf-8')
    if isinstance(raw, str):
        try:
            data = json.loads(raw)
        except Exception:
            data = {}
    elif isinstance(raw, dict):
        data = raw
    else:
        data = {}
    merged = dict(_DEFAULTS)
    for k, v in data.items():
        if isinstance(v, bool):
            merged[k] = v
        elif isinstance(v, (int, float)):
            merged[k] = bool(v)
    return merged


def get_user_preferences(cur, data, files, ts):
    try:
        require(data, 'user_profile_id')
        user_profile_id = data['user_profile_id']
        _ensure_table(cur)
        prefs = _load_prefs(cur, user_profile_id)
        return ok({'status': 'success', 'data': prefs})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"get_user_preferences error: {e}", exc_info=True)
        return fail(f'Server error: {e}', 500)


def update_user_preferences(cur, data, files, ts):
    """
    Partial update — caller sends `prefs_json` with only the keys that
    changed. Unknown keys are ignored to keep the stored shape clean.
    """
    try:
        require(data, 'user_profile_id', 'prefs_json')
        user_profile_id = data['user_profile_id']
        _ensure_table(cur)

        try:
            incoming = json.loads(data['prefs_json'])
        except Exception:
            return fail('Invalid prefs_json')
        if not isinstance(incoming, dict):
            return fail('prefs_json must be an object')

        current = _load_prefs(cur, user_profile_id)
        for k, v in incoming.items():
            if k not in _DEFAULTS:
                continue
            if isinstance(v, bool):
                current[k] = v
            elif isinstance(v, (int, float)):
                current[k] = bool(v)

        blob = json.dumps(current)
        cur.execute(
            "INSERT INTO app_user_preferences (user_profile_id, prefs_json) "
            "VALUES (%s, %s) "
            "ON DUPLICATE KEY UPDATE prefs_json=VALUES(prefs_json), "
            "                          date_modified=NOW()",
            (user_profile_id, blob),
        )
        cur.connection.commit()
        return ok({'status': 'success', 'data': current})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"update_user_preferences error: {e}", exc_info=True)
        return fail(f'Server error: {e}', 500)
