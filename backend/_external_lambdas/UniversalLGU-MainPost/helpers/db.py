import os
import re
import random
import pymysql
from datetime import datetime, timedelta, date
from pymysql.cursors import DictCursor

DB_HOST = os.getenv('DB_HOST')
DB_USER = os.getenv('DB_USER')
DB_PASSWORD = os.getenv('DB_PASSWORD')
DB_NAME = os.getenv('DB_NAME')

# ── Dynamic (multi-tenant) DB selection ──────────────────────────────────────
# Tokens are always validated against AUTH_DB (the shared identity DB), while
# per-LGU data reads/writes go to the tenant DB named in each request's
# `db_name` field. To stop a client from pointing us at an arbitrary database
# on the host, `db_name` must be on ALLOWED_DBS — anything else is rejected.
#
# Both are env-overridable so we never have to redeploy code to add a tenant:
#   AUTH_DB_NAME  → default 'universal_lgu_db'
#   ALLOWED_DBS   → comma-separated list (defaults below already include cebu).
AUTH_DB = os.getenv('AUTH_DB_NAME', 'universal_lgu_db')

_DEFAULT_ALLOWED = 'universal_lgu_db,cebu_lgu_db,csjdm_lgu_db,bataan_db,district_6_db'
ALLOWED_DBS = {
    name.strip()
    for name in os.getenv('ALLOWED_DBS', _DEFAULT_ALLOWED).split(',')
    if name.strip()
}
# The auth DB is always reachable, regardless of the allowlist env override.
ALLOWED_DBS.add(AUTH_DB)


def resolve_tenant_db(db_name):
    """Pick the DB for data queries.

    Returns the validated tenant DB name. Falls back to ``AUTH_DB`` when no
    ``db_name`` was supplied (legacy callers). Raises ``ValueError`` when an
    unknown DB is requested so we never silently write to the wrong tenant.
    """
    if not db_name:
        return AUTH_DB
    if db_name not in ALLOWED_DBS:
        raise ValueError(f"Unknown database: {db_name}")
    return db_name

# Connection cache keyed by DB name. Lambda keeps the execution environment
# warm between invocations, so reusing the TCP + MySQL handshake (~150-400ms)
# is a massive win at scale. We ping() before returning to auto-reconnect
# on stale / closed connections.
_CONN_CACHE: dict = {}

def get_conn(db=None):
    key = db or DB_NAME
    cached = _CONN_CACHE.get(key)
    if cached is not None:
        try:
            cached.ping(reconnect=True)
            return cached
        except Exception:
            try:
                cached.close()
            except Exception:
                pass
            _CONN_CACHE.pop(key, None)
    fresh = pymysql.connect(
        host=DB_HOST, user=DB_USER, password=DB_PASSWORD,
        database=key, charset='utf8mb4', autocommit=True,
        # Keep sockets alive so idle connections don't get killed by the
        # NAT / LB after ~350s of silence.
        connect_timeout=5,
        read_timeout=25,
        write_timeout=25,
    )
    _CONN_CACHE[key] = fresh
    return fresh

def now_ph():
    return datetime.utcnow() + timedelta(hours=8)

def sanitize(val):
    if val is None:
        return None
    if isinstance(val, (datetime, date)):
        return val.strftime('%Y-%m-%d')
    if isinstance(val, str):
        val = val.strip()
        return val if val else None
    return val

def serialize_row(row):
    out = {}
    for k, v in row.items():
        if isinstance(v, (datetime, date)):
            out[k] = v.isoformat()
        elif isinstance(v, (int, float)):
            out[k] = str(v)
        elif v is None:
            out[k] = ''
        else:
            out[k] = v
    return out

def generate_number_id(cursor, table_name):
    while True:
        num_id = ''.join([str(random.randint(0, 9)) for _ in range(12)])
        cursor.execute(f"SELECT COUNT(*) AS c FROM {table_name} WHERE application_number=%s", (num_id,))
        if cursor.fetchone()['c'] == 0:
            return num_id
