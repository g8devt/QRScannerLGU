"""
One-shot admin helpers. Meant to be invoked directly via `aws lambda invoke`
or routed through a temporary endpoint. REMOVE from ROUTES once the
migration is done.
"""
import logging
import pymysql

from helpers.auth import ok, fail
from helpers.db import get_conn

logger = logging.getLogger()


def sync_missing_columns(cur, data, files, ts):
    """For each table that exists in BOTH source_db and target_db, ALTER the
    target so any columns present in source but missing in target get added
    (preserving target's existing rows). Indexes/FKs are NOT touched.

    Params: source_db (default universal_lgu_db), target_db (default bataan_db).
    """
    source = (data.get('source_db') or 'universal_lgu_db').strip()
    target = (data.get('target_db') or 'bataan_db').strip()

    altered = []
    skipped_no_diff = []
    errors = []

    src = get_conn(source)
    dst = get_conn(target)
    try:
        src_cur = src.cursor(pymysql.cursors.DictCursor)
        dst_cur = dst.cursor(pymysql.cursors.DictCursor)

        src_cur.execute(
            "SELECT table_name AS t FROM information_schema.tables "
            "WHERE table_schema=%s AND table_type='BASE TABLE'", (source,))
        src_tables = {r['t'] for r in src_cur.fetchall()}

        dst_cur.execute(
            "SELECT table_name AS t FROM information_schema.tables "
            "WHERE table_schema=%s AND table_type='BASE TABLE'", (target,))
        dst_tables = {r['t'] for r in dst_cur.fetchall()}

        common = src_tables & dst_tables

        for t in sorted(common):
            try:
                src_cur.execute(
                    "SELECT column_name AS name, column_type AS coltype, "
                    "is_nullable AS nullable, column_default AS dflt, "
                    "extra AS extra, ordinal_position AS pos "
                    "FROM information_schema.columns "
                    "WHERE table_schema=%s AND table_name=%s "
                    "ORDER BY ordinal_position", (source, t))
                src_cols = src_cur.fetchall()

                dst_cur.execute(
                    "SELECT column_name AS name FROM information_schema.columns "
                    "WHERE table_schema=%s AND table_name=%s", (target, t))
                dst_col_names = {r['name'] for r in dst_cur.fetchall()}

                missing = [c for c in src_cols if c['name'] not in dst_col_names]
                if not missing:
                    skipped_no_diff.append(t)
                    continue

                added_here = []
                for col in missing:
                    null_clause = 'NULL' if col['nullable'] == 'YES' else 'NOT NULL'
                    # Defaults: CURRENT_TIMESTAMP / NULL / 0 / function calls
                    # must NOT be quoted; literals must be. Bare-token defaults
                    # are uppercased keywords or numeric literals.
                    default_clause = ''
                    raw_default = col['dflt']
                    if raw_default is not None:
                        if (
                            raw_default.upper() == 'CURRENT_TIMESTAMP'
                            or raw_default.upper().startswith('CURRENT_')
                            or raw_default.replace('.', '', 1).isdigit()
                            or raw_default == 'NULL'
                        ):
                            default_clause = f" DEFAULT {raw_default}"
                        else:
                            escaped = raw_default.replace("'", "''")
                            default_clause = f" DEFAULT '{escaped}'"
                    elif col['nullable'] == 'YES':
                        default_clause = ' DEFAULT NULL'
                    # `extra` may contain DEFAULT_GENERATED (info-schema marker
                    # noting the default came from a generation expression) —
                    # MySQL won't accept it as DDL syntax, so strip it.
                    extra_raw = (col['extra'] or '').strip()
                    extra_clean = ' '.join(
                        tok for tok in extra_raw.split()
                        if tok.upper() != 'DEFAULT_GENERATED'
                    )
                    extra_clause = f" {extra_clean}" if extra_clean else ''

                    sql = (
                        f"ALTER TABLE `{t}` ADD COLUMN `{col['name']}` "
                        f"{col['coltype']} {null_clause}{default_clause}{extra_clause}"
                    )
                    try:
                        dst_cur.execute(sql)
                        added_here.append(col['name'])
                    except Exception as col_e:
                        errors.append({
                            'table': t,
                            'column': col['name'],
                            'sql': sql,
                            'error': str(col_e),
                        })
                if added_here:
                    altered.append({'table': t, 'added': added_here})
            except Exception as e:
                logger.error(f'sync_missing_columns failed on {t}: {e}', exc_info=True)
                errors.append({'table': t, 'error': str(e)})

        dst.commit()
        return ok({
            'status': True,
            'source': source,
            'target': target,
            'altered_tables': len(altered),
            'altered': altered,
            'skipped_no_diff_count': len(skipped_no_diff),
            'errors': errors,
        })
    except Exception as e:
        logger.error(f'sync_missing_columns top-level: {e}', exc_info=True)
        return fail(f'Sync error: {e}', 500)
    finally:
        try: src.close()
        except Exception: pass
        try: dst.close()
        except Exception: pass


# Any table whose name starts with one of these prefixes in marilao_db
# will be mirrored (schema only, no data) into the target DB.
_BUSINESS_PREFIXES = (
    'app_business',
    'business_',
    'app_bp',
    'app_permits',
)

def mirror_business_schema(cur, data, files, ts):
    """
    Copy the CREATE TABLE statements for every table matching
    _BUSINESS_PREFIXES from marilao_db into `target_db` (default
    `universal_lgu_db`). Does not copy rows — schema only.
    Returns a report of what was created vs. already present.
    """
    target = (data.get('target_db') or 'universal_lgu_db').strip()
    source = (data.get('source_db') or 'marilao_db').strip()

    created = []
    skipped = []
    errors = []

    src = get_conn(source)
    dst = get_conn(target)
    try:
        src_cur = src.cursor(pymysql.cursors.DictCursor)
        dst_cur = dst.cursor(pymysql.cursors.DictCursor)

        src_cur.execute("SHOW TABLES")
        col = f'Tables_in_{source}'
        rows = src_cur.fetchall()
        all_tables = [r[col] for r in rows]
        business_tables = [
            t for t in all_tables
            if any(t.startswith(p) for p in _BUSINESS_PREFIXES)
        ]

        for t in business_tables:
            try:
                src_cur.execute(f"SHOW CREATE TABLE `{t}`")
                create_row = src_cur.fetchone()
                ddl = create_row.get('Create Table') or create_row.get('Create View')
                if not ddl:
                    errors.append({'table': t, 'error': 'no DDL returned'})
                    continue

                # Drop any fully-qualified DB references so the statement
                # executes against the target DB context.
                ddl = ddl.replace(f'`{source}`.', '').replace(f'{source}.', '')

                # Check if target already has this table.
                dst_cur.execute(
                    "SELECT COUNT(*) AS c FROM information_schema.tables "
                    "WHERE table_schema=%s AND table_name=%s",
                    (target, t),
                )
                if dst_cur.fetchone()['c'] > 0:
                    skipped.append(t)
                    continue

                dst_cur.execute(ddl)
                created.append(t)
            except Exception as e:
                logger.error(f'Mirror failed for {t}: {e}', exc_info=True)
                errors.append({'table': t, 'error': str(e)})

        return ok({
            'status': True,
            'source': source,
            'target': target,
            'found': business_tables,
            'created': created,
            'skipped_existing': skipped,
            'errors': errors,
        })
    except Exception as e:
        logger.error(f'mirror_business_schema top-level: {e}', exc_info=True)
        return fail(f'Mirror error: {e}', 500)
    finally:
        try: src.close()
        except Exception: pass
        try: dst.close()
        except Exception: pass


_APP_BUSINESS_PERMITS_DDL = """
CREATE TABLE IF NOT EXISTS app_business_permits (
    id                  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id             BIGINT UNSIGNED NOT NULL,
    application_number  VARCHAR(32)  NOT NULL UNIQUE,
    application_type    ENUM('NEW','RENEWAL','CLOSURE') NOT NULL DEFAULT 'NEW',
    business_name       VARCHAR(255) NOT NULL,
    trade_name          VARCHAR(255) NULL,
    business_type       VARCHAR(80)  NULL,
    tin_number          VARCHAR(40)  NULL,
    registration_number VARCHAR(80)  NULL,
    capitalization      DECIMAL(14,2) NULL,
    owner_fname         VARCHAR(100) NOT NULL,
    owner_mname         VARCHAR(100) NULL,
    owner_lname         VARCHAR(100) NOT NULL,
    owner_suffix        VARCHAR(20)  NULL,
    owner_mobile        VARCHAR(32)  NOT NULL,
    owner_email         VARCHAR(150) NULL,
    address_line        VARCHAR(255) NOT NULL,
    barangay            VARCHAR(100) NOT NULL,
    municipality        VARCHAR(100) NOT NULL,
    province            VARCHAR(100) NOT NULL,
    zip_code            VARCHAR(20)  NULL,
    line_of_business    TEXT NULL,
    num_employees       INT UNSIGNED NULL,
    operating_hours     VARCHAR(120) NULL,
    has_signage         TINYINT(1) DEFAULT 0,
    has_parking         TINYINT(1) DEFAULT 0,
    doc_dti_sec         TEXT NULL,
    doc_barangay        TEXT NULL,
    doc_lease           TEXT NULL,
    doc_fire_permit     TEXT NULL,
    doc_sanitary        TEXT NULL,
    doc_other           TEXT NULL,
    status              ENUM('PENDING','UNDER_REVIEW','APPROVED','REJECTED','CLOSED')
                        NOT NULL DEFAULT 'PENDING',
    remarks             TEXT NULL,
    permit_number       VARCHAR(80) NULL,
    date_submitted      DATETIME NOT NULL,
    date_reviewed       DATETIME NULL,
    date_approved       DATETIME NULL,
    date_modified       DATETIME NULL,
    INDEX idx_bp_user (user_id),
    INDEX idx_bp_status (status),
    INDEX idx_bp_appnum (application_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
"""

def replace_single_table(cur, data, files, ts):
    """
    Drop `table` in target_db and recopy schema + data from source_db.
    One-shot fix for tables whose schemas drifted between databases.
    Params: table (required), source_db, target_db.
    """
    table = (data.get('table') or '').strip()
    if not table:
        return fail('Missing table')
    source = (data.get('source_db') or 'district_6_db').strip()
    target = (data.get('target_db') or 'universal_lgu_db').strip()

    src = get_conn(source)
    dst = get_conn(target)
    try:
        src_cur = src.cursor(pymysql.cursors.DictCursor)
        dst_cur = dst.cursor(pymysql.cursors.DictCursor)

        src_cur.execute(f"SHOW CREATE TABLE `{table}`")
        create_row = src_cur.fetchone()
        ddl = (create_row.get('Create Table') or '').replace(
            f'`{source}`.', '').replace(f'{source}.', '')
        if not ddl:
            return fail(f'Table {table} has no DDL in {source}', 404)

        dst_cur.execute("SET FOREIGN_KEY_CHECKS=0")
        dst_cur.execute(f"DROP TABLE IF EXISTS `{table}`")
        dst_cur.execute(ddl)

        src_cur.execute(f"SELECT * FROM `{source}`.`{table}`")
        rows = src_cur.fetchall()
        total = 0
        if rows:
            cols = list(rows[0].keys())
            stmt = (f"INSERT INTO `{table}` "
                    f"({', '.join(f'`{c}`' for c in cols)}) "
                    f"VALUES ({', '.join(['%s'] * len(cols))})")
            batch = []
            for r in rows:
                batch.append([r[c] for c in cols])
                if len(batch) >= 500:
                    dst_cur.executemany(stmt, batch)
                    total += len(batch)
                    batch = []
            if batch:
                dst_cur.executemany(stmt, batch)
                total += len(batch)
        dst_cur.execute("SET FOREIGN_KEY_CHECKS=1")

        return ok({
            'status': True,
            'table': table,
            'source': source,
            'target': target,
            'rows_copied': total,
        })
    except Exception as e:
        logger.error(f'replace_single_table {table}: {e}', exc_info=True)
        return fail(f'Replace error: {e}', 500)
    finally:
        try: src.close()
        except: pass
        try: dst.close()
        except: pass


def mirror_full_db(cur, data, files, ts):
    """
    Copy every table (schema + data) from `source_db` into `target_db`.
    - Skips tables that already exist in the target unless overwrite=true.
    - Data is copied in batches with `INSERT IGNORE` so it's safe to rerun
      even if some rows already landed earlier.
    Params (form fields):
      source_db  — default 'district_6_db'
      target_db  — default 'universal_lgu_db'
      overwrite  — 'true' to DROP+CREATE target tables before copy
    """
    source = (data.get('source_db') or 'district_6_db').strip()
    target = (data.get('target_db') or 'universal_lgu_db').strip()
    overwrite = (data.get('overwrite') or '').strip().lower() == 'true'

    created = []
    skipped = []
    rows_copied = {}
    errors = []

    src = get_conn(source)
    dst = get_conn(target)
    try:
        src_cur = src.cursor(pymysql.cursors.DictCursor)
        dst_cur = dst.cursor(pymysql.cursors.DictCursor)

        src_cur.execute("SHOW TABLES")
        col = f'Tables_in_{source}'
        tables = [r[col] for r in src_cur.fetchall()]

        # Temporarily relax FK + unique checks on target so we can copy
        # tables in any order without tripping constraints.
        dst_cur.execute("SET FOREIGN_KEY_CHECKS=0")
        dst_cur.execute("SET UNIQUE_CHECKS=0")

        for t in tables:
            try:
                # Skip views (they have no rows to copy in the useful sense).
                src_cur.execute(f"SHOW CREATE TABLE `{t}`")
                create_row = src_cur.fetchone()
                ddl = create_row.get('Create Table')
                if not ddl:
                    # view; recreate view definition only
                    view_ddl = create_row.get('Create View') or ''
                    if view_ddl:
                        view_ddl = view_ddl.replace(
                            f'`{source}`.', '').replace(f'{source}.', '')
                        try:
                            if overwrite:
                                dst_cur.execute(f"DROP VIEW IF EXISTS `{t}`")
                            dst_cur.execute(view_ddl)
                            created.append(t + ' (view)')
                        except Exception as ve:
                            errors.append({'table': t, 'error': str(ve)})
                    continue

                ddl = ddl.replace(f'`{source}`.', '').replace(f'{source}.', '')

                dst_cur.execute(
                    "SELECT COUNT(*) AS c FROM information_schema.tables "
                    "WHERE table_schema=%s AND table_name=%s",
                    (target, t),
                )
                exists = dst_cur.fetchone()['c'] > 0

                if exists and not overwrite:
                    skipped.append(t)
                else:
                    if exists and overwrite:
                        dst_cur.execute(f"DROP TABLE IF EXISTS `{t}`")
                    dst_cur.execute(ddl)
                    created.append(t)

                # Copy data in chunks of 500 using INSERT IGNORE.
                src_cur.execute(f"SELECT * FROM `{source}`.`{t}`")
                rows = src_cur.fetchall()
                if not rows:
                    rows_copied[t] = 0
                    continue

                cols = list(rows[0].keys())
                col_list = ', '.join(f'`{c}`' for c in cols)
                placeholder = ', '.join(['%s'] * len(cols))
                stmt = (f"INSERT IGNORE INTO `{t}` ({col_list}) "
                        f"VALUES ({placeholder})")

                batch = []
                total = 0
                for r in rows:
                    batch.append([r[c] for c in cols])
                    if len(batch) >= 500:
                        dst_cur.executemany(stmt, batch)
                        total += len(batch)
                        batch = []
                if batch:
                    dst_cur.executemany(stmt, batch)
                    total += len(batch)
                rows_copied[t] = total
            except Exception as e:
                logger.error(f'Mirror failed for {t}: {e}', exc_info=True)
                errors.append({'table': t, 'error': str(e)})

        dst_cur.execute("SET FOREIGN_KEY_CHECKS=1")
        dst_cur.execute("SET UNIQUE_CHECKS=1")

        return ok({
            'status': True,
            'source': source,
            'target': target,
            'overwrite': overwrite,
            'tables_seen': len(tables),
            'created': created,
            'skipped_existing': skipped,
            'rows_copied': rows_copied,
            'errors': errors,
        })
    except Exception as e:
        logger.error(f'mirror_full_db top-level: {e}', exc_info=True)
        return fail(f'Mirror error: {e}', 500)
    finally:
        try: src.close()
        except Exception: pass
        try: dst.close()
        except Exception: pass



_APP_SERVICE_TOGGLES_DDL = """
CREATE TABLE IF NOT EXISTS app_service_toggles (
    id                         TINYINT UNSIGNED PRIMARY KEY,  -- always 1
    social_services_enabled    TINYINT(1) NOT NULL DEFAULT 1,
    job_application_enabled    TINYINT(1) NOT NULL DEFAULT 1,
    business_permit_enabled    TINYINT(1) NOT NULL DEFAULT 1,
    card_registration_enabled  TINYINT(1) NOT NULL DEFAULT 1,
    updated_at                 DATETIME NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
"""

def create_app_service_toggles(cur, data, files, ts):
    """Create the single-row global service toggles table and seed row id=1."""
    target = (data.get('target_db') or 'universal_lgu_db').strip()
    dst = get_conn(target)
    try:
        dcur = dst.cursor(pymysql.cursors.DictCursor)
        dcur.execute(_APP_SERVICE_TOGGLES_DDL)
        # Seed the singleton row if missing.
        dcur.execute(
            "INSERT IGNORE INTO app_service_toggles "
            "(id, social_services_enabled, job_application_enabled, "
            "business_permit_enabled, card_registration_enabled, updated_at) "
            "VALUES (1, 1, 1, 1, 1, %s)",
            (ts,),
        )
        dcur.execute(
            "SELECT COUNT(*) AS c FROM information_schema.tables "
            "WHERE table_schema=%s AND table_name='app_service_toggles'",
            (target,),
        )
        return ok({
            'status': True,
            'target': target,
            'table': 'app_service_toggles',
            'exists': dcur.fetchone()['c'] > 0,
        })
    except Exception as e:
        logger.error(f'create_app_service_toggles: {e}', exc_info=True)
        return fail(f'Create error: {e}', 500)
    finally:
        try: dst.close()
        except Exception: pass


_APP_CARD_REGISTRATIONS_DDL = """
CREATE TABLE IF NOT EXISTS app_card_registrations (
    id                  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id             BIGINT UNSIGNED NOT NULL,
    reference_number    VARCHAR(32)  NOT NULL UNIQUE,
    first_name          VARCHAR(100) NOT NULL,
    middle_name         VARCHAR(100) NULL,
    last_name           VARCHAR(100) NOT NULL,
    suffix              VARCHAR(20)  NULL,
    mobile              VARCHAR(32)  NOT NULL,
    email               VARCHAR(150) NULL,
    residence_detail    VARCHAR(255) NULL,
    barangay            VARCHAR(100) NOT NULL,
    city_municipality   VARCHAR(100) NOT NULL,
    province            VARCHAR(100) NOT NULL,
    region              VARCHAR(100) NULL,
    zip_code            VARCHAR(20)  NULL,
    photo_url           TEXT NULL,
    signature_url       TEXT NULL,
    id_photo_url        TEXT NULL,
    status              ENUM('PENDING','UNDER_REVIEW','APPROVED','REJECTED')
                        NOT NULL DEFAULT 'PENDING',
    card_number         VARCHAR(80)  NULL,
    remarks             TEXT NULL,
    date_submitted      DATETIME NOT NULL,
    date_reviewed       DATETIME NULL,
    date_approved       DATETIME NULL,
    date_modified       DATETIME NULL,
    INDEX idx_card_user (user_id),
    INDEX idx_card_status (status),
    INDEX idx_card_ref (reference_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
"""

def create_app_card_registrations(cur, data, files, ts):
    """Create the `app_card_registrations` table in `target_db`."""
    target = (data.get('target_db') or 'universal_lgu_db').strip()
    dst = get_conn(target)
    try:
        dcur = dst.cursor(pymysql.cursors.DictCursor)
        dcur.execute(_APP_CARD_REGISTRATIONS_DDL)
        dcur.execute(
            "SELECT COUNT(*) AS c FROM information_schema.tables "
            "WHERE table_schema=%s AND table_name='app_card_registrations'",
            (target,),
        )
        exists = dcur.fetchone()['c'] > 0
        return ok({
            'status': True,
            'target': target,
            'table': 'app_card_registrations',
            'exists': exists,
        })
    except Exception as e:
        logger.error(f'create_app_card_registrations: {e}', exc_info=True)
        return fail(f'Create error: {e}', 500)
    finally:
        try: dst.close()
        except Exception: pass


def create_app_business_permits(cur, data, files, ts):
    """Create the new `app_business_permits` table in `target_db`."""
    target = (data.get('target_db') or 'universal_lgu_db').strip()
    dst = get_conn(target)
    try:
        dcur = dst.cursor(pymysql.cursors.DictCursor)
        dcur.execute(_APP_BUSINESS_PERMITS_DDL)
        dcur.execute(
            "SELECT COUNT(*) AS c FROM information_schema.tables "
            "WHERE table_schema=%s AND table_name='app_business_permits'",
            (target,),
        )
        exists = dcur.fetchone()['c'] > 0
        return ok({
            'status': True,
            'target': target,
            'table': 'app_business_permits',
            'exists': exists,
        })
    except Exception as e:
        logger.error(f'create_app_business_permits: {e}', exc_info=True)
        return fail(f'Create error: {e}', 500)
    finally:
        try: dst.close()
        except Exception: pass
