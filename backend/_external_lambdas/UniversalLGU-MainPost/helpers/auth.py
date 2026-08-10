import json
from pymysql.cursors import DictCursor
from .db import get_conn

def ok(data, code=200):
    return {'statusCode': code, 'body': json.dumps(data, default=str),
            'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'}}

def fail(msg, code=400):
    return ok({'status': False, 'message': msg}, code)

def require(data, *keys):
    missing = [k for k in keys if not data.get(k)]
    if missing:
        raise ValueError(f"Missing: {', '.join(missing)}")

def check_token(token, db):
    conn = get_conn(db)
    cur = conn.cursor(DictCursor)
    cur.execute("SELECT value FROM app_user_operations_tbl WHERE value_type='token'")
    for row in cur.fetchall():
        if token[13:] == row['value']:
            return conn
    conn.close()
    return None
