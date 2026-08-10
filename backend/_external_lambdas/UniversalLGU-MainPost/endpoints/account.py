import logging
from helpers.auth import ok, fail, require

logger = logging.getLogger()

# The `cur` passed in is a DictCursor against the tenant DB (district_6_db),
# which is where app_users and app_account_deletion_log live. The calling
# lambda already routed via db_name, so we use `cur` directly.

# ---------------------------------------------------------------------------
# Deletion-log schema
#
# Snapshots every identity field we have on the user at the moment of
# deletion. The goal is fraud detection: detect when the SAME PERSON
# re-registers with a new mobile number or email but the same card_id_no,
# same full name + birth_date, or same KYC selfie.
#
# The table is authoritative and append-only — a user who repeats the
# sign-up/delete cycle will produce one row per cycle. Match columns:
#
#   - mobile_number          (obvious)
#   - email_address          (obvious)
#   - card_id_no             (government ID — strongest signal)
#   - first_name+last_name+birth_date   (name + DOB composite)
#   - verification_profile_photo / card_id_picture   (for manual review)
#   - registration_id        (FCM token — device identifier)
#
# All fields nullable so the log survives partial data.
# ---------------------------------------------------------------------------

_DELETION_LOG_COLUMNS = [
    # (column_name, column_definition)
    ('id',                          'INT AUTO_INCREMENT PRIMARY KEY'),
    ('user_profile_id',             'INT DEFAULT NULL'),

    # Core contact
    ('mobile_number',               'VARCHAR(20) DEFAULT NULL'),
    ('email_address',               'VARCHAR(255) DEFAULT NULL'),

    # Identity
    ('fullname',                    'VARCHAR(255) DEFAULT NULL'),
    ('first_name',                  'VARCHAR(100) DEFAULT NULL'),
    ('middle_name',                 'VARCHAR(100) DEFAULT NULL'),
    ('last_name',                   'VARCHAR(100) DEFAULT NULL'),
    ('suffix_name',                 'VARCHAR(20) DEFAULT NULL'),
    ('gender',                      'VARCHAR(20) DEFAULT NULL'),
    ('birth_date',                  'DATE DEFAULT NULL'),
    ('place_of_birth',              'VARCHAR(255) DEFAULT NULL'),

    # Address
    ('address',                     'TEXT DEFAULT NULL'),
    ('region',                      'VARCHAR(100) DEFAULT NULL'),
    ('province',                    'VARCHAR(100) DEFAULT NULL'),
    ('district',                    'VARCHAR(100) DEFAULT NULL'),
    ('municipality',                'VARCHAR(100) DEFAULT NULL'),
    ('barangay',                    'VARCHAR(100) DEFAULT NULL'),

    # Government ID / KYC
    ('card_id',                     'VARCHAR(100) DEFAULT NULL'),
    ('card_id_type',                'VARCHAR(100) DEFAULT NULL'),
    ('card_id_no',                  'VARCHAR(100) DEFAULT NULL'),
    ('card_id_date_issued',         'VARCHAR(50) DEFAULT NULL'),
    ('card_id_first_name',          'VARCHAR(100) DEFAULT NULL'),
    ('card_id_last_name',           'VARCHAR(100) DEFAULT NULL'),
    ('card_id_middle_name',         'VARCHAR(100) DEFAULT NULL'),

    # Photo URLs (S3 keys — survive deletion, useful for manual review)
    ('profile_photo',               'VARCHAR(500) DEFAULT NULL'),
    ('verification_profile_photo',  'VARCHAR(500) DEFAULT NULL'),
    ('card_id_picture',             'VARCHAR(500) DEFAULT NULL'),
    ('user_signature_photo',        'VARCHAR(500) DEFAULT NULL'),

    # Account state at time of deletion
    ('user_status',                 'VARCHAR(50) DEFAULT NULL'),
    ('kyc_status',                  'VARCHAR(50) DEFAULT NULL'),
    ('registration_id',             'VARCHAR(500) DEFAULT NULL'),

    # Deletion metadata
    ('reason',                      "VARCHAR(100) DEFAULT 'user_initiated'"),
    ('app_version',                 'VARCHAR(50) DEFAULT NULL'),
    ('platform',                    'VARCHAR(50) DEFAULT NULL'),
    ('deleted_at_client',           'DATETIME DEFAULT NULL'),
    ('deleted_at_server',           'DATETIME DEFAULT CURRENT_TIMESTAMP'),
    ('ip_address',                  'VARCHAR(64) DEFAULT NULL'),
    ('date_account_created',        'DATETIME DEFAULT NULL'),
]

# Columns copied verbatim from app_users.
_SNAPSHOT_FIELDS = [
    'mobile_number', 'email_address',
    'fullname', 'first_name', 'middle_name', 'last_name', 'suffix_name',
    'gender', 'birth_date', 'place_of_birth',
    'address', 'region', 'province', 'district', 'municipality', 'barangay',
    'card_id', 'card_id_type', 'card_id_no', 'card_id_date_issued',
    'card_id_first_name', 'card_id_last_name', 'card_id_middle_name',
    'profile_photo', 'verification_profile_photo',
    'card_id_picture', 'user_signature_photo',
    'user_status', 'registration_id', 'date_created',
]


def _ensure_deletion_log_schema(cur):
    """
    Create the table if missing, then ADD COLUMN for any field the
    running code knows about but the existing table doesn't (so an old
    table from the previous deploy gets upgraded in place).
    """
    try:
        cols_sql = ",\n  ".join(
            f"`{name}` {defn}" for name, defn in _DELETION_LOG_COLUMNS
        )
        cur.execute(
            f"CREATE TABLE IF NOT EXISTS `app_account_deletion_log` (\n  "
            f"{cols_sql},\n"
            "  INDEX `idx_mobile_number` (`mobile_number`),\n"
            "  INDEX `idx_email_address` (`email_address`),\n"
            "  INDEX `idx_card_id_no` (`card_id_no`),\n"
            "  INDEX `idx_user_profile_id` (`user_profile_id`),\n"
            "  INDEX `idx_deleted_at_server` (`deleted_at_server`),\n"
            "  INDEX `idx_name_dob` (`first_name`, `last_name`, `birth_date`)\n"
            ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"
        )

        cur.execute("SHOW COLUMNS FROM `app_account_deletion_log`")
        existing = set()
        for row in cur.fetchall():
            name = row.get('Field') if isinstance(row, dict) else row[0]
            if name:
                existing.add(name)
        for name, defn in _DELETION_LOG_COLUMNS:
            if name == 'id':
                continue
            if name in existing:
                continue
            try:
                cur.execute(
                    f"ALTER TABLE `app_account_deletion_log` "
                    f"ADD COLUMN `{name}` {defn}"
                )
            except Exception as e:
                logger.warning(f"ADD COLUMN {name} failed: {e}")
        # Ensure indexes on the match columns even if table pre-existed.
        for idx_name, idx_cols in [
            ('idx_email_address', '`email_address`'),
            ('idx_card_id_no', '`card_id_no`'),
            ('idx_name_dob', '`first_name`, `last_name`, `birth_date`'),
        ]:
            try:
                cur.execute(
                    f"ALTER TABLE `app_account_deletion_log` "
                    f"ADD INDEX `{idx_name}` ({idx_cols})"
                )
            except Exception:
                pass  # index probably already exists
    except Exception as e:
        logger.warning(f"ensure_deletion_log_schema: {e}")


def _fetch_user_snapshot(cur, user_profile_id):
    try:
        fields = ', '.join(f'`{f}`' for f in _SNAPSHOT_FIELDS)
        cur.execute(
            f"SELECT id, status, {fields} FROM app_users WHERE id=%s",
            (user_profile_id,),
        )
        return cur.fetchone() or {}
    except Exception as e:
        logger.warning(f"user snapshot lookup failed: {e}")
        return {}


def _latest_kyc_status(cur, user_profile_id):
    """Best-effort latest KYC status; swallow errors if the table is missing."""
    try:
        cur.execute(
            "SELECT status FROM app_kyc WHERE user_profile_id=%s "
            "ORDER BY id DESC LIMIT 1",
            (user_profile_id,),
        )
        row = cur.fetchone()
        if not row:
            return None
        return row.get('status') if isinstance(row, dict) else row[0]
    except Exception:
        return None


def log_account_deletion(cur, data, files, ts):
    """
    Log an account deletion and soft-delete the user.

    Snapshots ALL identity fields (name, DOB, card_id_no, address, KYC photo
    URLs, etc.) into app_account_deletion_log so fraud review can match
    repeat offenders even if they sign up again with a new mobile/email.
    """
    try:
        require(data, 'user_profile_id')
        user_profile_id = data['user_profile_id']
        reason = (data.get('reason') or 'user_initiated')[:100]
        app_version = (data.get('app_version') or '')[:50]
        platform = (data.get('platform') or '')[:50]
        deleted_at_client = data.get('deleted_at') or None
        ip_address = data.get('ip_address') or None

        _ensure_deletion_log_schema(cur)
        snapshot = _fetch_user_snapshot(cur, user_profile_id)
        kyc_status = _latest_kyc_status(cur, user_profile_id)

        def g(k):
            return snapshot.get(k)

        cur.execute(
            """
            INSERT INTO app_account_deletion_log (
                user_profile_id,
                mobile_number, email_address,
                fullname, first_name, middle_name, last_name, suffix_name,
                gender, birth_date, place_of_birth,
                address, region, province, district, municipality, barangay,
                card_id, card_id_type, card_id_no, card_id_date_issued,
                card_id_first_name, card_id_last_name, card_id_middle_name,
                profile_photo, verification_profile_photo,
                card_id_picture, user_signature_photo,
                user_status, kyc_status, registration_id,
                reason, app_version, platform,
                deleted_at_client, ip_address, date_account_created
            ) VALUES (
                %s,
                %s, %s,
                %s, %s, %s, %s, %s,
                %s, %s, %s,
                %s, %s, %s, %s, %s, %s,
                %s, %s, %s, %s,
                %s, %s, %s,
                %s, %s,
                %s, %s,
                %s, %s, %s,
                %s, %s, %s,
                %s, %s, %s
            )
            """,
            (
                user_profile_id,
                g('mobile_number'), g('email_address'),
                g('fullname'), g('first_name'), g('middle_name'),
                g('last_name'), g('suffix_name'),
                g('gender'), g('birth_date'), g('place_of_birth'),
                g('address'), g('region'), g('province'),
                g('district'), g('municipality'), g('barangay'),
                g('card_id'), g('card_id_type'), g('card_id_no'),
                g('card_id_date_issued'),
                g('card_id_first_name'), g('card_id_last_name'),
                g('card_id_middle_name'),
                g('profile_photo'), g('verification_profile_photo'),
                g('card_id_picture'), g('user_signature_photo'),
                g('user_status'), kyc_status, g('registration_id'),
                reason, app_version, platform,
                deleted_at_client, ip_address, g('date_created'),
            ),
        )

        cur.execute(
            "UPDATE app_users "
            "SET status='DELETED', is_active=0, "
            "    registration_id=NULL, date_deactivated=NOW(), "
            "    date_modified=NOW() "
            "WHERE id=%s",
            (user_profile_id,),
        )

        # Abuse signals — count prior deletions across every identity axis we
        # have. The client gets these so support/admin tooling can flag a
        # returning user on their NEXT signup attempt.
        matches = {'mobile_number': 0, 'email_address': 0, 'card_id_no': 0,
                   'name_dob': 0}

        def _count(sql, params):
            try:
                cur.execute(sql, params)
                row = cur.fetchone()
                if not row:
                    return 0
                return row.get('c', 0) if isinstance(row, dict) else row[0]
            except Exception:
                return 0

        if g('mobile_number'):
            matches['mobile_number'] = _count(
                "SELECT COUNT(*) AS c FROM app_account_deletion_log "
                "WHERE mobile_number=%s",
                (g('mobile_number'),),
            )
        if g('email_address'):
            matches['email_address'] = _count(
                "SELECT COUNT(*) AS c FROM app_account_deletion_log "
                "WHERE email_address=%s",
                (g('email_address'),),
            )
        if g('card_id_no'):
            matches['card_id_no'] = _count(
                "SELECT COUNT(*) AS c FROM app_account_deletion_log "
                "WHERE card_id_no=%s",
                (g('card_id_no'),),
            )
        if g('first_name') and g('last_name') and g('birth_date'):
            matches['name_dob'] = _count(
                "SELECT COUNT(*) AS c FROM app_account_deletion_log "
                "WHERE first_name=%s AND last_name=%s AND birth_date=%s",
                (g('first_name'), g('last_name'), g('birth_date')),
            )

        cur.connection.commit()

        return ok({
            'status': 'success',
            'message': 'Account deletion logged.',
            'repeat_deletions': matches,
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"log_account_deletion error: {e}", exc_info=True)
        return fail(f'Server error: {e}', 500)


def register_fcm_token(cur, data, files, ts):
    """Store the caller's FCM registration token on app_users.registration_id."""
    try:
        require(data, 'user_profile_id', 'fcm_token')
        user_profile_id = data['user_profile_id']
        token = data['fcm_token']

        cur.execute(
            "UPDATE app_users SET registration_id=%s, date_modified=NOW() "
            "WHERE id=%s",
            (token, user_profile_id),
        )
        cur.connection.commit()
        return ok({'status': 'success', 'message': 'FCM token registered.'})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"register_fcm_token error: {e}", exc_info=True)
        return fail(f'Server error: {e}', 500)


def unregister_fcm_token(cur, data, files, ts):
    """Clear the caller's FCM token so they stop receiving push."""
    try:
        require(data, 'user_profile_id')
        user_profile_id = data['user_profile_id']

        cur.execute(
            "UPDATE app_users SET registration_id=NULL, date_modified=NOW() "
            "WHERE id=%s",
            (user_profile_id,),
        )
        cur.connection.commit()
        return ok({'status': 'success', 'message': 'FCM token unregistered.'})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"unregister_fcm_token error: {e}", exc_info=True)
        return fail(f'Server error: {e}', 500)
