import logging
import pymysql
from helpers.auth import ok, fail
from helpers.db import get_conn

logger = logging.getLogger()

def sync_birthdate_from_kyc(cur, data, files, ts):
    """Backfill app_users.birth_date from app_kyc.birthdate for any user
    whose KYC birthdate doesn't match. Idempotent — safe to re-run."""
    target = (data.get('target_db') or 'universal_lgu_db').strip()
    # Open a FRESH connection (bypassing the module-level cache) so we
    # control sql_mode cleanly — cached warm-Lambda connections retain
    # the prior session's STRICT mode which blows up on empty dates.
    import pymysql as _pymysql
    import os as _os
    dst = _pymysql.connect(
        host=_os.getenv('DB_HOST'),
        user=_os.getenv('DB_USER'),
        password=_os.getenv('DB_PASSWORD'),
        database=target,
        charset='utf8mb4',
        autocommit=True,
        sql_mode='',
    )
    try:
        dcur = dst.cursor(pymysql.cursors.DictCursor)
        # Minimal flow: pull KYC birthdates alone, then UPDATE each user
        # by id. No JOIN on date columns so strict-mode comparisons can't
        # trip us up.
        dcur.execute("SET SESSION sql_mode = ''")
        dcur.execute(
            "SELECT user_id, birthdate FROM app_kyc "
            "WHERE birthdate IS NOT NULL AND birthdate <> '' "
            "ORDER BY submitted_at DESC"
        )
        seen = set()
        updated = 0
        for r in dcur.fetchall():
            uid = r['user_id']
            if uid in seen:
                continue
            seen.add(uid)
            bd = (r['birthdate'] or '').strip() if isinstance(
                r['birthdate'], str) else r['birthdate']
            if not bd:
                continue
            try:
                dcur.execute(
                    "UPDATE app_users SET birth_date=%s WHERE id=%s",
                    (bd, uid),
                )
                updated += dcur.rowcount
            except Exception as row_err:
                logger.error(f'skip user {uid} bd={bd!r}: {row_err}')
        updated = dcur.rowcount
        return ok({'status': True, 'users_updated': updated})
    except Exception as e:
        logger.error(f'sync_birthdate_from_kyc: {e}', exc_info=True)
        return fail(str(e), 500)
    finally:
        try: dst.close()
        except: pass


def ensure_medicine_needed_column(cur, data, files, ts):
    """Add `medicine_needed TEXT NULL` to app_social_services if missing."""
    target = (data.get('target_db') or 'universal_lgu_db').strip()
    dst = get_conn(target)
    try:
        dcur = dst.cursor(pymysql.cursors.DictCursor)
        dcur.execute("SHOW COLUMNS FROM app_social_services")
        cols = [r['Field'] for r in dcur.fetchall()]
        if 'medicine_needed' in cols:
            return ok({'status': True, 'added': False})
        dcur.execute(
            "ALTER TABLE app_social_services ADD COLUMN medicine_needed TEXT NULL"
        )
        return ok({'status': True, 'added': True})
    except Exception as e:
        logger.error(f'ensure_medicine_needed: {e}', exc_info=True)
        return fail(str(e), 500)
    finally:
        try: dst.close()
        except: pass


def check_app_users_columns(cur, data, files, ts):
    """Describe app_users columns — also ensures address+gender cols exist."""
    target = (data.get('target_db') or 'universal_lgu_db').strip()
    dst = get_conn(target)
    try:
        dcur = dst.cursor(pymysql.cursors.DictCursor)
        dcur.execute("SHOW COLUMNS FROM app_users")
        cols = [r['Field'] for r in dcur.fetchall()]
        # Ensure KYC address / gender columns exist.
        to_add = []
        if 'gender' not in cols: to_add.append("ADD COLUMN gender VARCHAR(20) NULL")
        if 'address' not in cols: to_add.append("ADD COLUMN address VARCHAR(255) NULL")
        if 'region' not in cols: to_add.append("ADD COLUMN region VARCHAR(120) NULL")
        if 'province' not in cols: to_add.append("ADD COLUMN province VARCHAR(120) NULL")
        if 'municipality' not in cols: to_add.append("ADD COLUMN municipality VARCHAR(120) NULL")
        if 'barangay' not in cols: to_add.append("ADD COLUMN barangay VARCHAR(120) NULL")
        added = []
        if to_add:
            dcur.execute(f"ALTER TABLE app_users {', '.join(to_add)}")
            added = [c.split('COLUMN ')[1].split(' ')[0] for c in to_add]
        return ok({'status': True, 'existing_columns': cols, 'added': added})
    except Exception as e:
        logger.error(f'check_app_users_columns: {e}', exc_info=True)
        return fail(str(e), 500)
    finally:
        try: dst.close()
        except: pass
