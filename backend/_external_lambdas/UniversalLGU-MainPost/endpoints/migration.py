"""
One-shot migration: district_6_db  →  bataan_db

Registers two callable endpoints:
  migrate_check   — dry-run: reports which tables/columns are missing in bataan_db
  migrate_run     — executes the schema sync + data copy (idempotent, INSERT IGNORE)

Invoke via `aws lambda invoke` or temporarily add to ROUTES in lambda_function.py:
  'migrate_check': migration.migrate_check,
  'migrate_run':   migration.migrate_run,

Remove from ROUTES once the migration is confirmed complete.
"""

import logging
import pymysql
from pymysql.cursors import DictCursor

from helpers.auth import ok, fail
from helpers.db import get_conn

logger = logging.getLogger()

SOURCE_DB = 'district_6_db'
TARGET_DB = 'bataan_db'

# Tables that must exist in bataan_db (all tables the app endpoints touch).
# These are the authoritative names — if district_6_db has them, they will
# be copied; otherwise the app DDL already defines the schema inline.
REQUIRED_TABLES = [
    'app_users',
    'app_kyc',
    'app_social_services',
    'app_social_services_family',
    'app_card_registrations',
    'app_business_permits',
    'app_incident_reports',
    'app_job_postings',
    'app_job_applications',
    'app_applicant_profiles',
    'app_legal_consultations',
    'app_legal_consultation_history',
    'app_service_toggles',
    'app_user_preferences',
    'app_profile_update_requests',
    'app_account_deletion_log',
    'app_paymongo_sessions',
    'app_user_operations_tbl',
    'app_locations',
]

# Tables that hold reference/lookup data that should be copied from source
# even if they already exist in the target (static data that the source admin
# maintains).
REFERENCE_TABLES = {'app_locations', 'app_job_postings'}

# Tables that hold per-LGU application data — copy only if target is empty.
DATA_TABLES = REQUIRED_TABLES  # all are checked for emptiness before copy


def _get_src_dst():
    src = get_conn(SOURCE_DB)
    dst = get_conn(TARGET_DB)
    return src, dst


def _table_exists(cur, db, table):
    cur.execute(
        "SELECT COUNT(*) AS c FROM information_schema.tables "
        "WHERE table_schema=%s AND table_name=%s",
        (db, table),
    )
    row = cur.fetchone()
    val = row.get('c') if row.get('c') is not None else row.get('C', 0)
    return val > 0


def _get_columns(cur, db, table):
    cur.execute(
        "SELECT column_name, column_type, is_nullable, column_default, extra "
        "FROM information_schema.columns "
        "WHERE table_schema=%s AND table_name=%s ORDER BY ordinal_position",
        (db, table),
    )
    # Normalize keys to lowercase — information_schema returns UPPER case keys
    # on some MySQL versions regardless of how columns are named in the SELECT.
    rows = [{k.lower(): v for k, v in r.items()} for r in cur.fetchall()]
    return {r['column_name']: r for r in rows}


def migrate_check(cur, data, files, ts):
    """
    Dry-run: compare district_6_db vs bataan_db.
    Returns:
      - missing_tables: tables present in source but absent in target
      - missing_columns: per-table columns present in source but absent in target
      - row_counts: row count in source vs target for each table
    """
    src, dst = _get_src_dst()
    try:
        sc = src.cursor(DictCursor)
        dc = dst.cursor(DictCursor)

        # All tables in source
        sc.execute("SHOW TABLES")
        col = f'Tables_in_{SOURCE_DB}'
        src_tables = {r[col] for r in sc.fetchall()}

        # All tables in target
        dc.execute("SHOW TABLES")
        col2 = f'Tables_in_{TARGET_DB}'
        dst_tables = {r[col2] for r in dc.fetchall()}

        missing_tables = sorted(src_tables - dst_tables)
        missing_columns = {}
        row_counts = {}

        for t in sorted(src_tables):
            # Column diff
            src_cols = _get_columns(sc, SOURCE_DB, t)
            if t in dst_tables:
                dst_cols = _get_columns(dc, TARGET_DB, t)
                missing = sorted(set(src_cols) - set(dst_cols))
                if missing:
                    missing_columns[t] = missing
            # Row counts
            sc.execute(f"SELECT COUNT(*) AS c FROM `{SOURCE_DB}`.`{t}`")
            src_count = sc.fetchone()['c']
            dst_count = 0
            if t in dst_tables:
                dc.execute(f"SELECT COUNT(*) AS c FROM `{TARGET_DB}`.`{t}`")
                dst_count = dc.fetchone()['c']
            row_counts[t] = {'source': src_count, 'target': dst_count}

        return ok({
            'status': True,
            'source': SOURCE_DB,
            'target': TARGET_DB,
            'missing_tables': missing_tables,
            'missing_columns': missing_columns,
            'row_counts': row_counts,
        })
    except Exception as e:
        logger.error(f'migrate_check error: {e}', exc_info=True)
        return fail(f'Check error: {e}', 500)
    finally:
        try: src.close()
        except Exception: pass
        try: dst.close()
        except Exception: pass


def migrate_run(cur, data, files, ts):
    """
    Executes schema sync + data copy from district_6_db → bataan_db.

    Steps:
      1. For every table in source that is missing from target: CREATE it (copy DDL).
      2. For every table in both: ALTER target to add any missing columns.
      3. Copy rows using INSERT IGNORE (safe to re-run; won't duplicate).
         - Reference tables (app_locations, app_job_postings): always copy.
         - Data tables: copy only if target has 0 rows (don't overwrite existing data).

    Params (optional form fields):
      force_data  — 'true' to copy data even if target table already has rows
    """
    force_data = (data.get('force_data') or '').strip().lower() == 'true'

    src, dst = _get_src_dst()
    created_tables = []
    altered_tables = []
    data_copied = {}
    skipped_data = []
    errors = []

    try:
        sc = src.cursor(DictCursor)
        dc = dst.cursor(DictCursor)

        sc.execute("SHOW TABLES")
        col = f'Tables_in_{SOURCE_DB}'
        src_tables = [r[col] for r in sc.fetchall()]

        dc.execute("SET FOREIGN_KEY_CHECKS=0")
        dc.execute("SET UNIQUE_CHECKS=0")
        dc.execute("SET SESSION sql_mode=''")

        # ── Step 1 & 2: Schema sync ──────────────────────────────────────
        for t in src_tables:
            try:
                sc.execute(f"SHOW CREATE TABLE `{t}`")
                create_row = sc.fetchone()
                ddl = create_row.get('Create Table')
                if not ddl:
                    continue  # skip views

                ddl_clean = (
                    ddl
                    .replace(f'`{SOURCE_DB}`.', '')
                    .replace(f'{SOURCE_DB}.', '')
                )

                if not _table_exists(dc, TARGET_DB, t):
                    # Create missing table
                    dc.execute(ddl_clean)
                    created_tables.append(t)
                else:
                    # Add any missing columns
                    src_cols = _get_columns(sc, SOURCE_DB, t)
                    dst_col_names = set(_get_columns(dc, TARGET_DB, t).keys())
                    added = []
                    for col_name, col_info in src_cols.items():
                        if col_name in dst_col_names:
                            continue
                        null_clause = 'NULL' if col_info['is_nullable'] == 'YES' else 'NOT NULL'
                        raw_default = col_info['column_default']
                        default_clause = ''
                        if raw_default is not None:
                            upper = str(raw_default).upper()
                            if (upper == 'CURRENT_TIMESTAMP'
                                    or upper.startswith('CURRENT_')
                                    or str(raw_default).replace('.', '', 1).isdigit()
                                    or upper == 'NULL'):
                                default_clause = f' DEFAULT {raw_default}'
                            else:
                                escaped = str(raw_default).replace("'", "''")
                                default_clause = f" DEFAULT '{escaped}'"
                        elif col_info['is_nullable'] == 'YES':
                            default_clause = ' DEFAULT NULL'
                        extra_raw = (col_info['extra'] or '').strip()
                        extra_clean = ' '.join(
                            tok for tok in extra_raw.split()
                            if tok.upper() != 'DEFAULT_GENERATED'
                        )
                        extra_clause = f' {extra_clean}' if extra_clean else ''
                        alter_sql = (
                            f"ALTER TABLE `{t}` ADD COLUMN `{col_name}` "
                            f"{col_info['column_type']} {null_clause}"
                            f"{default_clause}{extra_clause}"
                        )
                        try:
                            dc.execute(alter_sql)
                            added.append(col_name)
                        except Exception as col_e:
                            errors.append({
                                'table': t, 'column': col_name,
                                'error': str(col_e),
                            })
                    if added:
                        altered_tables.append({'table': t, 'added': added})

            except Exception as e:
                logger.error(f'Schema sync failed for {t}: {e}', exc_info=True)
                errors.append({'table': t, 'phase': 'schema', 'error': str(e)})

        # ── Step 3: Data copy ────────────────────────────────────────────
        for t in src_tables:
            try:
                if not _table_exists(dc, TARGET_DB, t):
                    continue  # schema failed; skip

                # Decide whether to copy
                is_ref = t in REFERENCE_TABLES
                if not force_data and not is_ref:
                    dc.execute(f"SELECT COUNT(*) AS c FROM `{TARGET_DB}`.`{t}`")
                    if dc.fetchone()['c'] > 0:
                        skipped_data.append(t)
                        continue

                sc.execute(f"SELECT * FROM `{SOURCE_DB}`.`{t}`")
                rows = sc.fetchall()
                if not rows:
                    data_copied[t] = 0
                    continue

                cols = list(rows[0].keys())
                col_list = ', '.join(f'`{c}`' for c in cols)
                placeholders = ', '.join(['%s'] * len(cols))
                stmt = (
                    f"INSERT IGNORE INTO `{TARGET_DB}`.`{t}` ({col_list}) "
                    f"VALUES ({placeholders})"
                )
                batch_size = 500
                total = 0
                batch = []
                for r in rows:
                    batch.append([r[c] for c in cols])
                    if len(batch) >= batch_size:
                        dc.executemany(stmt, batch)
                        total += len(batch)
                        batch = []
                if batch:
                    dc.executemany(stmt, batch)
                    total += len(batch)
                data_copied[t] = total

            except Exception as e:
                logger.error(f'Data copy failed for {t}: {e}', exc_info=True)
                errors.append({'table': t, 'phase': 'data', 'error': str(e)})

        dc.execute("SET FOREIGN_KEY_CHECKS=1")
        dc.execute("SET UNIQUE_CHECKS=1")

        return ok({
            'status': True,
            'source': SOURCE_DB,
            'target': TARGET_DB,
            'created_tables': created_tables,
            'altered_tables': altered_tables,
            'data_copied': data_copied,
            'skipped_data_nonempty': skipped_data,
            'errors': errors,
        })

    except Exception as e:
        logger.error(f'migrate_run top-level error: {e}', exc_info=True)
        return fail(f'Migration error: {e}', 500)
    finally:
        try: src.close()
        except Exception: pass
        try: dst.close()
        except Exception: pass
