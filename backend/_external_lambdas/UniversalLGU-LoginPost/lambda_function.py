import logging
import uuid
import random
from datetime import timedelta
from pymysql.cursors import DictCursor
from helpers import (
    DB_NAME,
    get_conn, ok, fail, require, sanitize, normalize_mobile, now_ph,
    serialize_row, hash_pin, check_token, send_sms, log_sms, send_email,
    smtp_user_for, parse_event, resolve_db_name,
)
# Cebu Mobile App: separate implementation module (not aliases) for every
# endpoint the Cebu Mobile App calls with a "_cebu" suffix -- see
# docs/mobile-app-endpoints.md for the full endpoint mapping.
import cebu_auth

logger = logging.getLogger()
logger.setLevel(logging.INFO)

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

# Cebu Mobile App: "_cebu"-suffixed endpoints, each routed to its OWN
# implementation in cebu_auth.py -- NOT an alias back to the original
# handler. Editing cebu_auth.py never affects the sibling original
# functions above and vice versa; this is true implementation isolation,
# not a routing shortcut. Original endpoint names above are untouched.
# Keep in sync with docs/mobile-app-endpoints.md. change_pin_code_pass,
# update_registration_id, signup_email_validation, and send_sms_synermaxx
# are intentionally NOT duplicated here -- the mobile app doesn't call them.
CEBU_ROUTES = {
    'login_cebu': cebu_auth.ep_login_cebu,
    'social_login_cebu': cebu_auth.ep_social_login_cebu,
    'sign_up_cebu': cebu_auth.ep_signup_cebu,
    'sign_up2_cebu': cebu_auth.ep_signup_cebu,
    'otp_send_cebu': cebu_auth.ep_otp_send_cebu,
    'otp_validation_cebu': cebu_auth.ep_otp_validate_cebu,
    'otp_send_channel_cebu': cebu_auth.ep_otp_send_channel_cebu,
    'fetch_user_cebu': cebu_auth.ep_fetch_user_cebu,
    'change_pin_cebu': cebu_auth.ep_change_pin_cebu,
    'forgot_pin_cebu': cebu_auth.ep_forgot_pin_cebu,
    'update_biometrics_cebu': cebu_auth.ep_update_biometrics_cebu,
    'check_user_exist_cebu': cebu_auth.ep_check_exist_cebu,
    'delete_account_cebu': cebu_auth.ep_delete_account_cebu,
    'deactivate_cebu': cebu_auth.ep_deactivate_cebu,
    'login_validation_cebu': cebu_auth.login_validation_cebu,
}
ROUTES.update(CEBU_ROUTES)

NEEDS_TS = {'sign_up','sign_up2','social_login','change_pin','change_pin_code_pass','forgot_pin',
            'delete_account','deactivate',
            'sign_up_cebu','sign_up2_cebu','social_login_cebu','change_pin_cebu','forgot_pin_cebu',
            'delete_account_cebu','deactivate_cebu'}

def lambda_handler(event, context):
    try:
        data, files = parse_event(event)
        endpoint = data.get('endpoint')
        token = data.get('token')
        db_name = data.get('db_name', DB_NAME)
        if not endpoint or not token:
            return fail('Missing endpoint or token')
        # Validate db_name against the tenant allowlist BEFORE opening any
        # DB connection (same fail-closed pattern as universal_main_post's
        # resolve_tenant_db) -- applies identically to the original
        # endpoints and the Cebu Mobile App's "_cebu" ones.
        db_name = resolve_db_name(db_name)
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
