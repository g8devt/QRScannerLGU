import logging
import os
import json
import re
import requests
import hashlib
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime, timedelta, date
import pymysql
from pymysql.cursors import DictCursor
from requests_toolbelt.multipart import decoder
from io import BytesIO
import base64

logger = logging.getLogger()
logger.setLevel(logging.INFO)

DB_HOST = os.getenv('DB_HOST')
DB_USER = os.getenv('DB_USER')
DB_PASSWORD = os.getenv('DB_PASSWORD')
DB_NAME = os.getenv('DB_NAME')

# ── Tenant DB allowlist ──────────────────────────────────────
# Mirrors universal_main_post/helpers/db.py's resolve_tenant_db: a client
# supplies `db_name` on every request, and it must be validated BEFORE any
# connection is opened, or a malformed/unexpected value would let the caller
# point this Lambda at an arbitrary database on the host. Applies equally to
# the original endpoints and the Cebu Mobile App's "_cebu" endpoints -- both
# sets of routes go through the same `resolve_db_name()` call in
# lambda_handler before `check_token`/`get_conn` ever run.
#
# Env-overridable so a new tenant can be added without a redeploy:
#   ALLOWED_DBS   → comma-separated list (defaults below already include cebu).
_DEFAULT_ALLOWED = 'universal_lgu_db,cebu_lgu_db,csjdm_lgu_db,bataan_db,district_6_db'
ALLOWED_DBS = {
    name.strip()
    for name in os.getenv('ALLOWED_DBS', _DEFAULT_ALLOWED).split(',')
    if name.strip()
}
# This Lambda's own configured default DB is always reachable, even if an
# ALLOWED_DBS override on this deployment's env doesn't happen to list it.
if DB_NAME:
    ALLOWED_DBS.add(DB_NAME)


def resolve_db_name(db_name):
    """Validate the caller-supplied db_name before any connection is opened.

    Falls back to DB_NAME when no db_name was supplied (legacy callers).
    Raises ValueError for anything not in ALLOWED_DBS so we never silently
    connect to an unexpected/arbitrary database.
    """
    resolved = db_name or DB_NAME
    if not resolved:
        raise ValueError('Missing db_name')
    if resolved not in ALLOWED_DBS:
        raise ValueError(f'Unknown database: {resolved}')
    return resolved

SMS_URL = os.getenv('SYNERMAXX_SMS_URL')
SMS_KEY = os.getenv('SYNERMAXX_APPKEY')
# Email OTP via SMTP (ported from the UniversalLoginPost `otp_send_email_aws`,
# which uses AWS WorkMail SMTP). The "From"/login mailbox is selected by the
# request's `sender_name`: "g8corp" sends from no-reply@g8research.com, anything
# else from no-reply@g8research.com. Credentials default to the values from
# the reference function but can be overridden via env so they're never required
# in the request body:
#   SMTP_HOST            (default smtp.mail.us-east-1.awsapps.com)
#   SMTP_PORT            (default 465, implicit SSL)
#   SMTP_PASSWORD        the shared WorkMail password (required; set in env)
#   SMTP_USER_G8CORP     "From"/login mailbox when sender_name == 'g8corp'
#   SMTP_USER_DEFAULT    "From"/login mailbox otherwise
SMTP_HOST = os.getenv('SMTP_HOST', 'smtp.mail.us-east-1.awsapps.com')
SMTP_PORT = int(os.getenv('SMTP_PORT', '465'))
SMTP_PASSWORD = os.getenv('SMTP_PASSWORD')
SMTP_USER_G8CORP = os.getenv('SMTP_USER_G8CORP', 'no-reply@g8research.com')
SMTP_USER_DEFAULT = os.getenv('SMTP_USER_DEFAULT', 'no-reply@g8research.com')

def smtp_user_for(sender_name):
    """Select the WorkMail mailbox to authenticate/send as, mirroring
    `otp_send_email_aws`: the g8research mailbox for 'g8corp', else the
    e-notary mailbox."""
    return SMTP_USER_G8CORP if sender_name == 'g8corp' else SMTP_USER_DEFAULT

# ── Helpers ──────────────────────────────────────────────────
# Reuse DB connections across warm invocations. On cold start we pay the
# handshake once; every warm call (95%+ of prod traffic) reuses the socket.
_CONN_CACHE = {}

def get_conn(db=None):
    key = db or DB_NAME
    cached = _CONN_CACHE.get(key)
    if cached is not None:
        try:
            cached.ping(reconnect=True)
            return cached
        except Exception:
            try: cached.close()
            except Exception: pass
            _CONN_CACHE.pop(key, None)
    fresh = pymysql.connect(
        host=DB_HOST, user=DB_USER, password=DB_PASSWORD,
        database=key, charset='utf8mb4', autocommit=True,
        connect_timeout=5, read_timeout=25, write_timeout=25,
    )
    _CONN_CACHE[key] = fresh
    return fresh

def ok(data, code=200):
    return {'statusCode': code, 'body': json.dumps(data, default=str),
            'headers': {'Content-Type':'application/json','Access-Control-Allow-Origin':'*'}}

def fail(msg, code=400):
    return ok({'status': False, 'message': msg}, code)

def require(data, *keys):
    missing = [k for k in keys if not data.get(k)]
    if missing:
        raise ValueError(f"Missing: {', '.join(missing)}")

def sanitize(val):
    if not val: return val
    return re.sub(r'[<>"\';]', '', str(val).strip())

def normalize_mobile(m):
    m = re.sub(r'[\s\-\+]', '', str(m))
    if m.startswith('63') and len(m) == 12: return '0' + m[2:]
    if m.startswith('9') and len(m) == 10: return '0' + m
    if m.startswith('09') and len(m) == 11: return m
    raise ValueError(f"Invalid mobile: {m}")

def now_ph():
    return datetime.utcnow() + timedelta(hours=8)

def serialize_row(row):
    out = {}
    for k, v in row.items():
        if isinstance(v, (datetime, date)): out[k] = v.isoformat()
        elif isinstance(v, (int, float)): out[k] = str(v)
        elif v is None: out[k] = ''
        else: out[k] = v
    return out

def hash_pin(pin):
    salt = "LGU_SUPER_SECURE_SALT_2026"
    return hashlib.sha256((str(pin) + salt).encode('utf-8')).hexdigest()

# ── Auth ─────────────────────────────────────────────────────
def check_token(token, db):
    conn = get_conn(db)
    cur = conn.cursor(DictCursor)
    cur.execute("SELECT value FROM app_user_operations_tbl WHERE value_type='token'")
    for row in cur.fetchall():
        if token[13:] == row['value']:
            return conn
    conn.close()
    return None

# ── SMS ──────────────────────────────────────────────────────
def send_sms(mobile, message, sender):
    if not SMS_KEY: raise ValueError("SMS key not configured")
    mobile = normalize_mobile(mobile)
    resp = requests.post(SMS_URL, headers={
        'Content-Type':'application/json','appkey': SMS_KEY
    }, json={'mobilenum': mobile, 'originator': sender, 'fullmesg': message, 'format':'json'}, timeout=15)
    data = resp.json()
    if data.get('code') == 200 and str(data.get('status','')).upper() == 'ACK':
        return data
    raise Exception(f"SMS failed: {data}")

def log_sms(cur, mobile, sender, msg, resp):
    cur.execute("""INSERT INTO sms_outbox (mobilenum,originator,message,provider_code,
        provider_status,transid,provider_response_json,date_created)
        VALUES(%s,%s,%s,%s,%s,%s,CAST(%s AS JSON),%s)""",
        (mobile, sender, msg, resp.get('code'), resp.get('status'),
         resp.get('transid'), json.dumps(resp), now_ph()))

# ── Email (SMTP) ─────────────────────────────────────────────
# Ported from the UniversalLoginPost `otp_send_email_aws`: a MIME multipart
# (plain + HTML) message sent over AWS WorkMail implicit-SSL SMTP. The login/From
# mailbox is chosen per request via `smtp_user_for(sender_name)`; the password is
# read from env (see top of file) rather than the request body.
def send_email(to_addr, subject, body, html=None, from_addr=None):
    from_addr = from_addr or SMTP_USER_DEFAULT
    if not from_addr or not SMTP_PASSWORD:
        raise ValueError("SMTP credentials not configured")
    message = MIMEMultipart("alternative")
    message["Subject"] = subject
    message["From"] = from_addr
    message["To"] = to_addr
    message.attach(MIMEText(body, "plain"))
    message.attach(MIMEText(html or f"<html><body>{body}</body></html>", "html"))
    server = smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT)
    try:
        server.login(from_addr, SMTP_PASSWORD)
        server.sendmail(from_addr, to_addr, message.as_string())
    finally:
        try:
            server.quit()
        except Exception:
            pass

# ── Parse Request ────────────────────────────────────────────
def parse_event(event):
    body = event.get('body','')
    headers = event.get('headers',{})
    ct = headers.get('Content-Type') or headers.get('content-type','')
    raw = base64.b64decode(body) if event.get('isBase64Encoded') else body.encode('utf-8')
    parts = decoder.MultipartDecoder(raw, ct)
    data, files = {}, []
    for p in parts.parts:
        cd = p.headers.get(b'Content-Disposition', b'').decode()
        if 'filename' in cd:
            fn = cd.split('filename=')[1].strip('"')
            files.append({'filename': fn, 'content': BytesIO(p.content),
                          'field_name': cd.split('name=')[1].split(';')[0].strip('"')})
        else:
            name = cd.split('name=')[1].strip('"')
            data[name] = p.content.decode('utf-8')
    return data, files
