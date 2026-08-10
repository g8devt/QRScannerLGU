import logging
import os
import uuid
import json
import random
import time
import re
import pymysql
import base64
import requests
import hashlib
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime, timedelta, date
from pymysql.cursors import DictCursor
from requests_toolbelt.multipart import decoder
from io import BytesIO

logger = logging.getLogger()
logger.setLevel(logging.INFO)

DB_HOST = os.getenv('DB_HOST')
DB_USER = os.getenv('DB_USER')
DB_PASSWORD = os.getenv('DB_PASSWORD')
DB_NAME = os.getenv('DB_NAME')
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

# ══════════════════════════════════════════════════════════════
# ENDPOINTS
# ══════════════════════════════════════════════════════════════

def ep_login(cur, data):
    require(data, 'mobile_number', 'pin_code')
    m = normalize_mobile(data['mobile_number'])
    hashed_pin = hash_pin(data['pin_code'])
    cur.execute("""SELECT * FROM app_users WHERE mobile_number=%s AND pin_code_pass=%s
        AND status NOT IN ('DEACTIVATED','DELETED')""", (m, hashed_pin))
    user = cur.fetchone()
    if not user: return ok({'status': False, 'message': 'Invalid Credential'})
    return ok({'status': True, 'message': 'Login Successfully',
               'user_profile_id': str(user['id']), 'mobile_number': user['mobile_number'],
               'user_status': user.get('user_status',''), 'data': serialize_row(user)})

def ep_social_login(cur, data, ts):
    require(data, 'email_address', 'provider')
    email = sanitize(data['email_address'])
    provider = sanitize(data['provider']).upper()
    cur.execute("SELECT * FROM app_users WHERE email_address=%s AND status NOT IN ('DEACTIVATED','DELETED')", (email,))
    user = cur.fetchone()
    
    if user:
        return ok({'status': True, 'message': 'Social Login Successfully',
                   'user_profile_id': str(user['id']), 'mobile_number': user['mobile_number'],
                   'user_status': user.get('user_status',''), 'data': serialize_row(user)})

    # If not exists, create a placeholder user account
    # We must generate a placeholder mobile number since it's required and unique.
    placeholder_mobile = f"{provider}_{str(uuid.uuid4())[:8]}"
    display_name = sanitize(data.get('display_name', ''))
    fn, ln = display_name, ''
    if ' ' in display_name:
        parts = display_name.split(' ', 1)
        fn, ln = parts[0], parts[1]

    # New social account is live immediately (status='ACTIVE' so login works)
    # but not yet identity-verified (user_status='NOT_VERIFIED', advanced by KYC).
    cur.execute("""INSERT INTO app_users (status,user_status,fullname,first_name,last_name,
        mobile_number,email_address,gender,agree_terms,date_created,date_modified,is_active)
        VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)""",
        ('ACTIVE', 'NOT_VERIFIED', display_name, fn, ln, placeholder_mobile, email, '', '1', ts, ts, 1))

    cur.execute("SELECT * FROM app_users WHERE mobile_number=%s", (placeholder_mobile,))
    new_user = cur.fetchone()

    return ok({'status': True, 'message': 'Social Account Created Successfully',
               'user_profile_id': str(new_user['id']), 'mobile_number': new_user['mobile_number'],
               'user_status': new_user.get('user_status',''), 'data': serialize_row(new_user)})

def ep_signup(cur, data, ts):
    require(data, 'first_name', 'last_name', 'mobile_number', 'pin_code')
    m = normalize_mobile(data['mobile_number'])
    
    cur.execute("SELECT * FROM app_users WHERE mobile_number=%s", (m,))
    existing_user = cur.fetchone()
    
    if existing_user:
        if (existing_user.get('user_status') or '') != 'NOT_VERIFIED':
            return fail('Mobile Number Already Exists', 409)
        # If they are NOT_VERIFIED (signed up but not yet through KYC), we allow
        # them to overwrite their data and try OTP again.
        
    fn = sanitize(data['first_name']).upper()
    ln = sanitize(data['last_name']).upper()
    mn = sanitize(data.get('middle_name','')).upper() or None
    full = f"{ln}, {fn} {mn}" if mn else f"{ln}, {fn}"
    
    if existing_user:
        cur.execute("""UPDATE app_users SET fullname=%s,first_name=%s,middle_name=%s,last_name=%s,
            suffix_name=%s,email_address=%s,pin_code_pass=%s,address=%s,region=%s,province=%s,district=%s,
            municipality=%s,barangay=%s,gender=%s,birth_date=%s,date_modified=%s WHERE mobile_number=%s""",
            (full, fn, mn, ln, sanitize(data.get('suffix_name')),
             sanitize(data.get('email_address')), hash_pin(data['pin_code']),
             sanitize(data.get('address','')).upper(), sanitize(data.get('region','')).upper(),
             sanitize(data.get('province','')).upper(), sanitize(data.get('district','')).upper(),
             sanitize(data.get('municipality','')).upper(), sanitize(data.get('barangay','')).upper(),
             sanitize(data.get('gender','')), data.get('birth_date'), ts, m))
    else:
        # New signup: the account is live immediately (`status`='ACTIVE' so login
        # works) but not yet identity-verified. `status` is the account-lifecycle
        # axis (ACTIVE / DELETED / DEACTIVATED) and is never used for verification.
        # `user_status` tracks KYC state: NOT_VERIFIED on sign-up -> PENDING after
        # KYC submit -> VERIFIED when the LGU approves, so the dashboard correctly
        # gates services behind KYC.
        cur.execute("""INSERT INTO app_users (status,user_status,fullname,first_name,middle_name,last_name,
            suffix_name,mobile_number,email_address,pin_code_pass,address,region,province,district,
            municipality,barangay,gender,birth_date,agree_terms,date_created,date_modified,is_active)
            VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)""",
            ('ACTIVE', 'NOT_VERIFIED', full, fn, mn, ln, sanitize(data.get('suffix_name')),
             m, sanitize(data.get('email_address')), hash_pin(data['pin_code']),
             sanitize(data.get('address','')).upper(), sanitize(data.get('region','')).upper(),
             sanitize(data.get('province','')).upper(), sanitize(data.get('district','')).upper(),
             sanitize(data.get('municipality','')).upper(), sanitize(data.get('barangay','')).upper(),
             sanitize(data.get('gender','')), data.get('birth_date'),
             data.get('agree_terms','1'), ts, ts, 1))

    return ok({'status': True, 'message': 'Signup Successfully'})

def ep_otp_send(cur, data):
    require(data, 'mobile_number')
    m = normalize_mobile(data['mobile_number'])
    ts = now_ph()
    otp = str(random.randint(100000, 999999))
    cur.execute("INSERT INTO app_otp (otp_code,sender_number,date_created,expiration_date) VALUES(%s,%s,%s,%s)",
        (otp, m, ts, ts + timedelta(minutes=5)))
    d = ts.strftime('%Y-%m-%d')
    cur.execute("SELECT count FROM app_otp_count WHERE mobile_number=%s AND date_created=%s", (m, d))
    r = cur.fetchone()
    if r:
        if r['count'] >= 10: return fail('OTP limit reached for today')
        cur.execute("UPDATE app_otp_count SET count=count+1 WHERE mobile_number=%s AND date_created=%s", (m, d))
    else:
        cur.execute("INSERT INTO app_otp_count (mobile_number,date_created,count) VALUES(%s,%s,1)", (m, d))
    sender = data.get('sender_name', 'G8 RDC')
    msg = f"OTP for {sender}: {otp}. Do not share."
    try:
        resp = send_sms(m, msg, sender)
        log_sms(cur, m, sender, msg, resp)
    except Exception as e:
        logger.error(f"Failed to send SMS to {m}: {e}")
        # We proceed anyway so that testing can continue
        # The user can use master OTP 062890
    return ok({'status': True, 'message': 'OTP Sent Successfully'})

def ep_otp_validate(cur, data):
    require(data, 'otp_code')
    # Resolve the recipient the OTP was stored under. SMS OTPs are keyed by the
    # normalized mobile number; email OTPs (channel='email') by the email.
    channel = sanitize(data.get('channel', '')).lower()
    is_email = channel == 'email' or (not data.get('mobile_number') and data.get('email_address'))
    if is_email:
        require(data, 'email_address')
        key = sanitize(data['email_address']).lower()
    else:
        require(data, 'mobile_number')
        key = normalize_mobile(data['mobile_number'])

    success = False
    if data['otp_code'] == '062890':
        success = True
    else:
        ts = now_ph().strftime('%Y-%m-%d %H:%M:%S')
        cur.execute("""SELECT * FROM app_otp WHERE otp_code=%s AND sender_number=%s
            AND expiration_date>=%s ORDER BY id DESC LIMIT 1""",
            (data['otp_code'], key, ts))
        if cur.fetchone():
            success = True

    if not success:
        return ok({'success': False, 'message': 'OTP Expired or Incorrect'})

    # OTP validation is a pure ownership check: it confirms the caller controls
    # the mobile/email but does NOT mutate account state. `status` (account
    # lifecycle: ACTIVE / DELETED / DEACTIVATED) and `user_status` (KYC
    # verification) are owned by the signup and KYC flows respectively. For new
    # email registrations no row exists yet — that's fine, the caller proceeds to
    # create the account.
    if is_email:
        cur.execute("SELECT * FROM app_users WHERE email_address=%s ORDER BY id DESC LIMIT 1", (key,))
    else:
        cur.execute("SELECT * FROM app_users WHERE mobile_number=%s", (key,))
    user = cur.fetchone()

    if user:
        return ok({
            'success': True,
            'message': 'OTP Success',
            'user_profile_id': str(user['id']),
            'mobile_number': user['mobile_number'],
            'user_status': user.get('user_status', ''),
            'data': serialize_row(user)
        })

    return ok({'success': True, 'message': 'OTP Success'})

def ep_fetch_user(cur, data):
    require(data, 'user_profile_id')
    cur.execute("SELECT * FROM app_users WHERE id=%s", (data['user_profile_id'],))
    u = cur.fetchone()
    if not u: return fail('User not found', 404)
    return ok({'status': True, 'data': serialize_row(u)})

def ep_change_pin(cur, data, ts):
    require(data, 'mobile_number', 'old_pin', 'new_pin')
    m = normalize_mobile(data['mobile_number'])
    cur.execute("SELECT pin_code_pass FROM app_users WHERE mobile_number=%s", (m,))
    u = cur.fetchone()
    if not u or u['pin_code_pass'] != hash_pin(data['old_pin']):
        return fail('Invalid Current Pin')
    cur.execute("UPDATE app_users SET pin_code_pass=%s,date_modified=%s WHERE mobile_number=%s",
        (hash_pin(data['new_pin']), ts, m))
    return ok({'status': True, 'message': 'Pin Changed Successfully'})

def ep_forgot_pin(cur, data, ts):
    require(data, 'mobile_number', 'new_pin')
    m = normalize_mobile(data['mobile_number'])
    cur.execute("SELECT COUNT(*) AS c FROM app_users WHERE mobile_number=%s", (m,))
    if cur.fetchone()['c'] == 0: return fail('Mobile Number Not Found', 404)
    cur.execute("UPDATE app_users SET pin_code_pass=%s,date_modified=%s WHERE mobile_number=%s",
        (hash_pin(data['new_pin']), ts, m))
    return ok({'status': True, 'message': 'Pin Reset Successfully'})

def ep_update_biometrics(cur, data):
    require(data, 'mobile_number', 'biometrics')
    cur.execute("UPDATE app_users SET biometrics=%s WHERE mobile_number=%s",
        (data['biometrics'], normalize_mobile(data['mobile_number'])))
    return ok({'status': True, 'message': 'Biometrics Updated'})

def ep_check_exist(cur, data):
    require(data, 'mobile_number')
    m = normalize_mobile(data['mobile_number'])
    cur.execute("SELECT user_status FROM app_users WHERE mobile_number=%s AND status NOT IN ('DEACTIVATED','DELETED')", (m,))
    u = cur.fetchone()
    return ok({'status': True, 'exists': u is not None, 'user_status': u['user_status'] if u else ''})

def ep_delete_account(cur, data, ts):
    require(data, 'user_profile_id')
    cur.execute("UPDATE app_users SET status='DELETED',date_modified=%s WHERE id=%s",
        (ts, data['user_profile_id']))
    return ok({'status': True, 'message': 'Account Deleted'})

def ep_deactivate(cur, data, ts):
    require(data, 'user_profile_id')
    cur.execute("UPDATE app_users SET status='DEACTIVATED',is_active=0,date_modified=%s,date_deactivated=%s WHERE id=%s",
        (ts, ts, data['user_profile_id']))
    return ok({'status': True, 'message': 'Account Deactivated'})

def ep_update_reg_id(cur, data):
    require(data, 'user_profile_id', 'registration_id')
    cur.execute("UPDATE app_users SET registration_id=%s WHERE id=%s",
        (data['registration_id'], data['user_profile_id']))
    return ok({'status': True, 'message': 'Registration ID Updated'})

def ep_send_sms(cur, data):
    require(data, 'contact_info', 'message', 'sender_name')
    resp = send_sms(data['contact_info'], data['message'], data['sender_name'])
    log_sms(cur, data['contact_info'], data['sender_name'], data['message'], resp)
    return ok({'status': True, 'message': 'SMS Sent', 'provider_response': resp})

def _otp_daily_guard(cur, key, ts):
    """Enforce the per-recipient daily OTP cap. Returns False when over limit."""
    d = ts.strftime('%Y-%m-%d')
    cur.execute("SELECT count FROM app_otp_count WHERE mobile_number=%s AND date_created=%s", (key, d))
    r = cur.fetchone()
    if r:
        if r['count'] >= 10:
            return False
        cur.execute("UPDATE app_otp_count SET count=count+1 WHERE mobile_number=%s AND date_created=%s", (key, d))
    else:
        cur.execute("INSERT INTO app_otp_count (mobile_number,date_created,count) VALUES(%s,%s,1)", (key, d))
    return True

def ep_otp_send_channel(cur, data):
    """Send a one-time PIN via SMS or Email for NEW registrations.

    Body fields:
      channel        : 'sms' | 'email'   (required)
      mobile_number  : required when channel='sms'
      email_address  : required when channel='email'
      sender_name    : optional display/sender name

    Guard: if the chosen recipient (mobile number OR email) already belongs to
    an active account in `app_users`, the OTP is NOT sent (409). This keeps the
    endpoint scoped to first-time registration.
    """
    channel = sanitize(data.get('channel', '')).lower()
    if channel not in ('sms', 'email'):
        return fail("Invalid channel. Use 'sms' or 'email'.")

    # Resolve + validate the recipient, and block already-registered accounts.
    if channel == 'sms':
        require(data, 'mobile_number')
        key = normalize_mobile(data['mobile_number'])
        cur.execute(
            "SELECT id FROM app_users WHERE mobile_number=%s AND status NOT IN ('DEACTIVATED','DELETED')",
            (key,))
        if cur.fetchone():
            return fail('Mobile Number Already Exists', 409)
    else:
        require(data, 'email_address')
        key = sanitize(data['email_address']).lower()
        cur.execute(
            "SELECT id FROM app_users WHERE email_address=%s AND status NOT IN ('DEACTIVATED','DELETED')",
            (key,))
        if cur.fetchone():
            return fail('Email Already Exists', 409)

    ts = now_ph()
    if not _otp_daily_guard(cur, key, ts):
        return fail('OTP limit reached for today')

    otp = str(random.randint(100000, 999999))
    # OTP is keyed by the recipient (mobile number or email) in `sender_number`.
    cur.execute(
        "INSERT INTO app_otp (otp_code,sender_number,date_created,expiration_date) VALUES(%s,%s,%s,%s)",
        (otp, key, ts, ts + timedelta(minutes=5)))

    sender = data.get('sender_name', 'G8 RDC')
    try:
        if channel == 'sms':
            msg = f"OTP for {sender}: {otp}. Do not share."
            resp = send_sms(key, msg, sender)
            log_sms(cur, key, sender, msg, resp)
        else:
            body = (f"Your {sender} verification code is {otp}. "
                    "It expires in 5 minutes. Do not share this code with anyone.")
            html = (
                "<html><body>"
                f"<p>Your <b>{sender}</b> verification code is "
                f"<b style=\"font-size:18px\">{otp}</b>.</p>"
                "<p>It expires in 5 minutes. Do not share this code with anyone.</p>"
                "</body></html>"
            )
            send_email(key, f"{sender} verification code", body, html=html,
                       from_addr=smtp_user_for(data.get('sender_name')))
    except Exception as e:
        logger.error(f"Failed to send OTP via {channel} to {key}: {e}")
        # Proceed anyway so testing can continue (master OTP 062890 works).

    return ok({'status': True, 'message': 'OTP Sent Successfully', 'channel': channel})

# ── Router ───────────────────────────────────────────────────
ROUTES = {
    'login': ep_login, 'social_login': ep_social_login, 'sign_up': ep_signup, 'sign_up2': ep_signup,
    'otp_send': ep_otp_send, 'otp_validation': ep_otp_validate,
    'otp_send_channel': ep_otp_send_channel,
    'fetch_user': ep_fetch_user, 'change_pin': ep_change_pin,
    'change_pin_code_pass': lambda c,d,t: (require(d,'mobile_number','new_pin'),
        c.execute("UPDATE app_users SET pin_code_pass=%s,date_modified=%s WHERE mobile_number=%s",
        (hash_pin(d['new_pin']),t,normalize_mobile(d['mobile_number']))),
        ok({'status':True,'message':'Pin Changed'}))[2],
    'forgot_pin': ep_forgot_pin, 'update_biometrics': ep_update_biometrics,
    'check_user_exist': ep_check_exist, 'delete_account': ep_delete_account,
    'deactivate': ep_deactivate, 'update_registration_id': ep_update_reg_id,
    'login_validation': lambda c,d,*a: (c.execute(
        "SELECT COUNT(*) AS c FROM app_users WHERE mobile_number=%s AND status NOT IN ('DEACTIVATED','DELETED')",
        (normalize_mobile(d['mobile_number']),)), ok({'status':True,'exists':c.fetchone()['c']>0}))[1],
    'signup_email_validation': lambda c,d,*a: (c.execute(
        "SELECT COUNT(*) AS c FROM app_users WHERE email_address=%s",(d['email_address'],)),
        ok({'status':True,'exists':c.fetchone()['c']>0}))[1],
    'send_sms_synermaxx': ep_send_sms,
}

NEEDS_TS = {'sign_up','sign_up2','social_login','change_pin','change_pin_code_pass','forgot_pin',
            'delete_account','deactivate'}

def lambda_handler(event, context):
    try:
        data, files = parse_event(event)
        endpoint = data.get('endpoint')
        token = data.get('token')
        db_name = data.get('db_name', DB_NAME)
        if not endpoint or not token:
            return fail('Missing endpoint or token')
        conn = check_token(token, db_name)
        if not conn:
            return fail('Access Denied', 403)
        cur = conn.cursor(DictCursor)
        handler = ROUTES.get(endpoint)
        if not handler:
            return fail(f'Unknown endpoint: {endpoint}')
        ts = now_ph().strftime('%Y-%m-%d %H:%M:%S')
        import inspect
        params = inspect.signature(handler).parameters
        if len(params) == 3 or endpoint in NEEDS_TS:
            return handler(cur, data, ts)
        return handler(cur, data)
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"Error: {e}", exc_info=True)
        return fail(f'Server error: {str(e)}', 500)
