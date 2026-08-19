import json
import re
import uuid
import logging
from datetime import date, time, timedelta
from helpers.auth import ok, fail, require
from helpers.audit import record_audit_log
from helpers.db import sanitize, serialize_row, generate_number_id, now_ph
from helpers.forms import parse_int
from helpers.parse import parse_form_data
from helpers.s3 import upload_files_from_list

logger = logging.getLogger()

# Online-submission appointment policy (Bataan, Orani District Office).
ONLINE_DAILY_CAP = 50
ONLINE_PER_HOUR_CAP = 10
ONLINE_WINDOW_START_HOUR = 9   # 9:00 AM
ONLINE_WINDOW_END_HOUR = 15    # 3:00 PM (exclusive)
ONLINE_SLOT_MINUTES = 60 // ONLINE_PER_HOUR_CAP  # 6-minute slots
# Same-day submissions are only accepted up to this hour (Philippine
# time). Past it, the allocator rolls to the next weekday even if
# today still has free slots — applicants who submit late at night
# get booked for tomorrow morning instead of an already-passed time.
ONLINE_DAILY_CUTOFF_HOUR = 17  # 5:00 PM
ONLINE_APPOINTMENT_LOCATION = 'Orani District Office (sa tabi ng simbahan)'

_SOCIAL_SERVICES_ADMIN_STATUSES = {'REVIEWED', 'APPROVED', 'DECLINED', 'RELEASED', 'CLAIMED'}
_SOCIAL_SERVICES_ALL_STATUSES = _SOCIAL_SERVICES_ADMIN_STATUSES | {'PENDING', 'SCHEDULED'}
_STATUS_DATE_COLUMNS = {
    'REVIEWED': 'date_reviewed',
    'APPROVED': 'date_approved',
    'DECLINED': 'date_declined',
    'RELEASED': 'date_released',
    'CLAIMED': 'date_claimed',
}


def _has_appointment_columns(cur):
    """
    True when this tenant's `app_social_services` table has been migrated
    to include the online-appointment columns. Lets the shared lambda
    keep serving tenants that haven't run migration 024 yet — submissions
    just skip the appointment-tracking fields for them.
    """
    cur.execute(
        """
        SELECT COUNT(*) AS c
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'app_social_services'
          AND COLUMN_NAME = 'submission_method'
        """
    )
    row = cur.fetchone()
    return bool(row and row.get('c'))


def _has_beneficiary_name_column(cur):
    """True when migration 025 (beneficiary_name) is applied."""
    cur.execute(
        """
        SELECT COUNT(*) AS c
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'app_social_services'
          AND COLUMN_NAME = 'beneficiary_name'
        """
    )
    row = cur.fetchone()
    return bool(row and row.get('c'))


def _has_qr_code_column(cur):
    """True when this tenant's `app_social_services` table has a `qr_code`
    column to hold the auto-scheduled appointment's QR token."""
    cur.execute(
        """
        SELECT COUNT(*) AS c
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'app_social_services'
          AND COLUMN_NAME = 'qr_code'
        """
    )
    row = cur.fetchone()
    return bool(row and row.get('c'))


def _has_civil_status_column(cur):
    """True when migration 028 (requested_for_civil_status) is applied."""
    cur.execute(
        """
        SELECT COUNT(*) AS c
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'app_social_services'
          AND COLUMN_NAME = 'requested_for_civil_status'
        """
    )
    row = cur.fetchone()
    return bool(row and row.get('c'))


def _has_educ_year_level_column(cur):
    """True when migration 029 (educ_year_level, educ_is_scholar) is applied."""
    cur.execute(
        """
        SELECT COUNT(*) AS c
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'app_social_services'
          AND COLUMN_NAME = 'educ_year_level'
        """
    )
    row = cur.fetchone()
    return bool(row and row.get('c'))


def _generate_qr_code(cur, row_id):
    """Build a unique QR token for an auto-scheduled application, e.g.
    `SS-000023-C5E24E83F104`:

      - `SS`         : social-services namespace prefix
      - `000023`     : the row's auto-increment id, zero-padded to 6 digits
      - 12 hex chars : random uppercase suffix guaranteeing uniqueness

    The random suffix is re-rolled until the full code is unique within
    this tenant's `app_social_services.qr_code` column.
    """
    seq = f'{int(row_id):06d}'
    while True:
        suffix = uuid.uuid4().hex[:12].upper()
        code = f'SS-{seq}-{suffix}'
        cur.execute(
            "SELECT COUNT(*) AS c FROM app_social_services WHERE qr_code=%s",
            (code,),
        )
        if cur.fetchone()['c'] == 0:
            return code


# How far forward we will roll an Online appointment when the current
# day is full. 14 calendar days is a generous fortnight that still
# bounds the search if every day is somehow booked (very unlikely in
# practice but keeps the loop safe).
ONLINE_MAX_DAYS_AHEAD = 14


def _slot_for_day(cur, day, method):
    """
    Returns the first free 6-minute slot on `day` between 9am and 3pm
    for the given submission `method` ('ONLINE' or 'IN_PERSON') where
    neither the daily cap nor the per-hour cap has been reached, or
    `None` if the day is full. ONLINE and IN_PERSON each get their own
    independent pool so a busy walk-in day doesn't block online
    booking and vice versa. Returns `(slot_or_none, day_total, per_hour)`
    so the caller can log diagnostics.
    """
    # Dump the actual rows the allocator sees for this day so we can
    # diagnose mismatches between "what we expect" and "what counts".
    try:
        cur.execute(
            """
            SELECT id, user_id, application_number, status,
                   submission_method, appointment_date, appointment_time
            FROM app_social_services
            WHERE appointment_date = %s
            ORDER BY appointment_time
            """,
            (day,),
        )
        same_day_rows = cur.fetchall()
        logger.info(
            '[slot_for_day] day=%s method=%s rows_for_day=%d details=%s',
            day, method, len(same_day_rows), same_day_rows,
        )
    except Exception as e:
        logger.warning('[slot_for_day] row dump failed: %s', e)

    cur.execute(
        """
        SELECT HOUR(appointment_time) AS h, COUNT(*) AS c
        FROM app_social_services
        WHERE submission_method = %s
          AND appointment_date = %s
        GROUP BY HOUR(appointment_time)
        """,
        (method, day),
    )
    per_hour = {row['h']: row['c'] for row in cur.fetchall()}
    day_total = sum(per_hour.values())
    if day_total >= ONLINE_DAILY_CAP:
        return None, day_total, per_hour
    for hour in range(ONLINE_WINDOW_START_HOUR, ONLINE_WINDOW_END_HOUR):
        used_in_hour = per_hour.get(hour, 0)
        if used_in_hour < ONLINE_PER_HOUR_CAP:
            minute = used_in_hour * ONLINE_SLOT_MINUTES
            return time(hour=hour, minute=minute), day_total, per_hour
    return None, day_total, per_hour


def _allocate_slot(cur, start_date, method):
    """
    Find the first available appointment slot for `method`
    ('ONLINE' or 'IN_PERSON') starting from `start_date`. Rolls
    forward day-by-day, skipping weekends, up to ONLINE_MAX_DAYS_AHEAD.

    Returns (appointment_date, appointment_time, error_message). On
    success error_message is None; on exhaustion both date and time
    are None and error_message explains the situation.
    """
    # Also log the DB's idea of "today" so we can spot timezone drift
    # between the Lambda runtime (UTC) and the database (often Asia/Manila).
    try:
        cur.execute(
            "SELECT CURDATE() AS db_today, DATABASE() AS db_name, "
            "@@global.time_zone AS gtz, @@session.time_zone AS stz"
        )
        tz_row = cur.fetchone() or {}
        logger.info(
            '[allocate_slot] method=%s lambda_today=%s db_today=%s db_name=%s '
            'db_global_tz=%s db_session_tz=%s',
            method,
            start_date,
            tz_row.get('db_today'),
            tz_row.get('db_name'),
            tz_row.get('gtz'),
            tz_row.get('stz'),
        )
    except Exception as e:
        logger.warning('[allocate_slot] tz probe failed: %s', e)

    for offset in range(ONLINE_MAX_DAYS_AHEAD + 1):
        candidate = start_date + timedelta(days=offset)
        # Skip Saturday (5) and Sunday (6).
        if candidate.weekday() >= 5:
            logger.info(
                '[allocate_slot] skip weekend %s (wd=%s)',
                candidate, candidate.weekday(),
            )
            continue
        slot, day_total, per_hour = _slot_for_day(cur, candidate, method)
        logger.info(
            '[allocate_slot] method=%s candidate=%s day_total=%s/%s '
            'per_hour=%s slot=%s',
            method, candidate, day_total, ONLINE_DAILY_CAP, per_hour, slot,
        )
        if slot is not None:
            return candidate, slot, None
    label = 'Online' if method == 'ONLINE' else 'In Person'
    return None, None, (
        f'{label} appointment slots are full for the next '
        f'{ONLINE_MAX_DAYS_AHEAD} days. Please try again later.'
    )

def submit_social_service(cur, data, files, ts):
    try:
        require(data, 'user_profile_id')
        user_id = data['user_profile_id']

        cur.execute("SELECT status FROM app_kyc WHERE user_id=%s ORDER BY submitted_at DESC LIMIT 1", (user_id,))
        kyc = cur.fetchone()
        if not kyc or kyc['status'] != 'VERIFIED':
            return fail('KYC verification required before submitting social services', 403)

        form = parse_form_data(data)
        require(form, 'service_type')

        # Submission method (IN_PERSON | ONLINE). ONLINE submissions get a
        # date+time+location auto-assigned at Orani District Office.
        submission_method = str(
            form.get('submission_method') or 'IN_PERSON'
        ).strip().upper()
        if submission_method not in ('IN_PERSON', 'ONLINE'):
            submission_method = 'IN_PERSON'
        logger.info(
            '[submit_social_service] user_id=%s service_type=%s '
            'submission_method=%s raw_form_method=%r',
            user_id, form.get('service_type'),
            submission_method, form.get('submission_method'),
        )

        has_appt_cols = _has_appointment_columns(cur)

        appointment_date = None
        appointment_time = None
        appointment_location = None
        if has_appt_cols and submission_method in ('ONLINE', 'IN_PERSON'):
            # Both submission methods now book a real slot. They each
            # have their own independent pool (per the submission_method
            # filter inside _slot_for_day), so a busy walk-in day
            # doesn't block online booking and vice versa. Either may
            # roll forward to the next weekday if today is full.
            now_local = now_ph()
            search_start = now_local.date()
            # Past the daily cutoff, skip today entirely — there's no
            # point assigning an in-day slot that's already passed.
            past_cutoff = now_local.hour >= ONLINE_DAILY_CUTOFF_HOUR
            if past_cutoff:
                search_start = search_start + timedelta(days=1)
            logger.info(
                '[submit_social_service] now_ph=%s cutoff_hour=%s '
                'past_cutoff=%s search_start=%s',
                now_local.isoformat(), ONLINE_DAILY_CUTOFF_HOUR,
                past_cutoff, search_start,
            )
            slot_date, slot_time, slot_err = _allocate_slot(
                cur, search_start, submission_method,
            )
            if slot_err:
                return fail(slot_err, 409)
            appointment_date = slot_date
            appointment_time = slot_time
            appointment_location = ONLINE_APPOINTMENT_LOCATION
        elif submission_method == 'ONLINE' and not has_appt_cols:
            return fail(
                'Online submission is not configured for this LGU. '
                'Please choose In Person.',
                409,
            )

        app_number = generate_number_id(cur, 'app_social_services')
        file_urls = upload_files_from_list(files, f'social_services/{app_number}', user_id)

        # Mobile forms send `help_for` with MYSELF/OTHERS; admin portal
        # and legacy callers send `applying_for`. Accept either.
        raw_applying = (
            form.get('applying_for')
            or form.get('help_for')
            or ''
        )
        if str(raw_applying).strip().lower() in (
            'self', 'myself', 'pang sarili', 'pang_sarili',
        ):
            applying_for = 'SELF'
        else:
            applying_for = 'OTHER'

        family_json = None
        family_members = []
        raw_family = form.get('family_composition')
        if raw_family:
            if isinstance(raw_family, str):
                corrected = re.sub(r"'", '"', raw_family)
                try:
                    parsed = json.loads(corrected)
                    family_members = parsed if isinstance(parsed, list) else [parsed]
                except json.JSONDecodeError:
                    logger.error(f"Invalid family_composition JSON: {raw_family}")
            elif isinstance(raw_family, list):
                family_members = raw_family
            elif isinstance(raw_family, dict):
                family_members = [raw_family]
            family_json = json.dumps(family_members)

        birthdate = form.get('birth_date') or form.get('dob') or form.get('birthdate')
        contact = (
            form.get('contact_number')
            or form.get('mobile_number')
            or form.get('phone')
        )
        municipality = form.get('city') or form.get('municipality')
        zipcode = form.get('zip_code') or form.get('zipcode')
        address = form.get('residence') or form.get('address')
        relationship = (
            form.get('relationship')
            or form.get('beneficiary_relationship')
        )
        brief_description = (
            form.get('needs_description')
            or form.get('brief_description')
            or form.get('description')
        )

        # Whenever the auto-scheduler booked a concrete appointment slot
        # (now the case for both ONLINE and IN_PERSON submissions), the
        # application starts life in the SCHEDULED state with
        # date_scheduled stamped to the booking moment — the applicant
        # doesn't need to wait for staff to mark it scheduled. Only when
        # no slot was allocated does it fall back to PENDING.
        if appointment_date is not None:
            initial_status = 'SCHEDULED'
            date_scheduled = ts
        else:
            initial_status = 'PENDING'
            date_scheduled = None

        base_cols = [
            'user_id', 'application_number', 'service_type', 'requested_for', 'requested_for_relation',
            'assistance_type', 'brief_description',
            'requested_for_fname', 'requested_for_mname', 'requested_for_lname',
            'requested_for_birthdate', 'requested_for_gender', 'requested_for_contact', 'requested_for_email',
            'requested_for_region', 'requested_for_province', 'requested_for_municipality',
            'requested_for_barangay', 'requested_for_address', 'requested_for_zipcode', 'preferred_contact',
            'educ_school_name', 'educ_grade_level', 'educ_course', 'educ_school_sector',
            'educ_school_id_number', 'educ_school_address',
            'tribal_membership', 'disability', 'other_financial_assistance',
            'other_financial_assistance_type_1', 'other_financial_assistance_agency_1',
            'other_financial_assistance_type_2', 'other_financial_assistance_agency_2',
            'service_sub_category', 'deceased_fullname', 'deceased_birthdate', 'deceased_deathdate',
            'family_composition', 'amount', 'medicine_needed',
            'date_requested', 'status', 'requested_from',
            'photo_2x2', 'photo_signature', 'image_verification',
            'date_scheduled',
        ]
        base_vals = [
            user_id, app_number, sanitize(form.get('service_type')), applying_for,
            sanitize(relationship), sanitize(form.get('assistance_type')),
            sanitize(brief_description),
            sanitize(form.get('first_name')), sanitize(form.get('middle_name')), sanitize(form.get('last_name')),
            birthdate, sanitize(form.get('gender')), sanitize(contact), sanitize(form.get('email')),
            sanitize(form.get('region')), sanitize(form.get('province')), sanitize(municipality),
            sanitize(form.get('barangay')), sanitize(address), sanitize(zipcode),
            sanitize(form.get('preferred_contact')),
            sanitize(form.get('school_name')), sanitize(form.get('grade_level')), sanitize(form.get('course')),
            sanitize(form.get('school_sector')), sanitize(form.get('school_id_number')),
            sanitize(form.get('school_address')),
            sanitize(form.get('tribal')), sanitize(form.get('disability')),
            sanitize(form.get('other_financial_assistance')),
            sanitize(form.get('other_financial_assistance_type_1')),
            sanitize(form.get('other_financial_assistance_agency_1')),
            sanitize(form.get('other_financial_assistance_type_2')),
            sanitize(form.get('other_financial_assistance_agency_2')),
            sanitize(form.get('service_sub_category')),
            sanitize(form.get('deceased_fullname')), sanitize(form.get('deceased_birthdate')),
            sanitize(form.get('deceased_deathdate')),
            family_json, form.get('amount'),
            sanitize(form.get('medicine_needed')),
            ts, initial_status, 'MOBILE',
            file_urls.get('photo_2x2'), file_urls.get('photo_signature'), file_urls.get('image_verification'),
            date_scheduled,
        ]
        if has_appt_cols:
            base_cols.extend([
                'submission_method', 'appointment_date',
                'appointment_time', 'appointment_location',
            ])
            base_vals.extend([
                submission_method, appointment_date,
                appointment_time, appointment_location,
            ])

        # Mobile clients post each supporting document as `upload_file_N`
        # (1..8) with a sibling `upload_file_N_type` label inside the
        # JSON form_data. `upload_files_from_list` already pushed the
        # binaries to S3 keyed by field name — here we persist the
        # resulting URLs and labels onto the row so the detail view can
        # render them later. Without this loop the files reach S3 but
        # the DB has no reference to them.
        for n in range(1, 9):
            url_col = f'upload_file_{n}'
            type_col = f'upload_file_{n}_type'
            url = file_urls.get(url_col)
            label = form.get(type_col)
            if url:
                base_cols.append(url_col)
                base_vals.append(url)
            if label:
                base_cols.append(type_col)
                # Column is VARCHAR(255) after migration 026; raw label
                # fits even for the longest requirement string.
                base_vals.append(sanitize(str(label)))

        # Beneficiary name — only meaningful when filing for someone else.
        if _has_beneficiary_name_column(cur):
            beneficiary_name = form.get('beneficiary_name') or ''
            if applying_for == 'SELF':
                beneficiary_name = ''  # MYSELF: applicant is beneficiary
            base_cols.append('beneficiary_name')
            base_vals.append(sanitize(beneficiary_name))

        if _has_civil_status_column(cur):
            base_cols.append('requested_for_civil_status')
            base_vals.append(sanitize(form.get('civil_status')))

        if _has_educ_year_level_column(cur):
            base_cols.extend(['educ_year_level', 'educ_is_scholar'])
            base_vals.extend([
                sanitize(form.get('year_level')),
                sanitize(form.get('is_scholar')),
            ])

        cols_sql = ', '.join(base_cols)
        placeholders = ', '.join(['%s'] * len(base_vals))
        cur.execute(
            f'INSERT INTO app_social_services ({cols_sql}) VALUES ({placeholders})',
            tuple(base_vals),
        )
        social_services_id = cur.lastrowid

        # Auto-scheduled applications get a unique QR token stamped onto the
        # row so the appointment can be scanned/verified on arrival. Only
        # applications that actually booked a slot (SCHEDULED) get one;
        # PENDING fall-backs don't have an appointment to scan yet.
        qr_code = None
        if initial_status == 'SCHEDULED' and _has_qr_code_column(cur):
            qr_code = _generate_qr_code(cur, social_services_id)
            cur.execute(
                "UPDATE app_social_services SET qr_code=%s WHERE id=%s",
                (qr_code, social_services_id),
            )
            logger.info(
                '[submit_social_service] generated qr_code=%s for id=%s '
                'app_number=%s',
                qr_code, social_services_id, app_number,
            )

        try:
            cur.execute(
                "SELECT DATABASE() AS db_name, COUNT(*) AS today_online "
                "FROM app_social_services "
                "WHERE submission_method='ONLINE' AND appointment_date=%s",
                (appointment_date if appointment_date else date.today(),),
            )
            verify = cur.fetchone() or {}
            logger.info(
                '[submit_social_service] INSERTED id=%s app_number=%s '
                'submission_method=%s appointment_date=%s appointment_time=%s '
                'verify_db_name=%s today_online_count_now=%s',
                social_services_id, app_number, submission_method,
                appointment_date, appointment_time,
                verify.get('db_name'), verify.get('today_online'),
            )
        except Exception as e:
            logger.warning('[submit_social_service] post-insert verify failed: %s', e)

        for member in family_members:
            cur.execute("""
                INSERT INTO app_social_services_family (
                    user_id, social_services_id, name, birthdate, relationship,
                    skill_occupation, birthplace, civl_status, est_income, gender, highest_educ
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                user_id, social_services_id,
                sanitize(member.get('fullname') or member.get('name')),
                member.get('birthdate') or member.get('dob'),
                sanitize(member.get('relation') or member.get('relationship')),
                sanitize(member.get('occupation') or member.get('skill_occupation')),
                sanitize(member.get('birthplace') or member.get('place_of_birth')),
                sanitize(member.get('civil_status')),
                sanitize(member.get('income') or member.get('monthly_income') or member.get('est_income')),
                sanitize(member.get('gender')),
                sanitize(member.get('education') or member.get('highest_education') or member.get('highest_educ')),
            ))

        response = {
            'status': True,
            'message': 'Social service application submitted successfully',
            'application_number': app_number,
            'submission_method': submission_method,
            'application_status': initial_status,
            'qr_code': qr_code,
        }
        if submission_method in ('ONLINE', 'IN_PERSON') and appointment_date:
            # `rescheduled` flags that the booking rolled past today —
            # either because today's cap was reached OR because the
            # applicant submitted past ONLINE_DAILY_CUTOFF_HOUR.
            # Compared against Manila-local "today" so the flag is
            # correct from the user's perspective regardless of where
            # the Lambda is running.
            today_iso = now_ph().date()
            response['appointment'] = {
                'date': appointment_date.isoformat() if appointment_date else None,
                'time': appointment_time.strftime('%H:%M') if appointment_time else None,
                'location': appointment_location,
                'rescheduled': (
                    appointment_date is not None
                    and appointment_date != today_iso
                ),
                'requested_date': today_iso.isoformat(),
            }
        return ok(response)
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"submit_social_service error: {e}", exc_info=True)
        return fail(f'Server error: {str(e)}', 500)

def get_social_services(cur, data, files, ts):
    try:
        require(data, 'user_profile_id')
        appt_cols = (
            ', submission_method, appointment_date, '
            'appointment_time, appointment_location'
            if _has_appointment_columns(cur) else ''
        )
        bene_col = (
            ', beneficiary_name'
            if _has_beneficiary_name_column(cur) else ''
        )
        civil_status_col = (
            ', requested_for_civil_status'
            if _has_civil_status_column(cur) else ''
        )
        educ_year_level_col = (
            ', educ_year_level, educ_is_scholar'
            if _has_educ_year_level_column(cur) else ''
        )
        cur.execute(f"""
            SELECT id, application_number, service_type, service_sub_category,
                   status, date_requested, date_reviewed, date_approved,
                   date_scheduled, date_released, date_claimed, date_declined,
                   qr_code,
                   requested_for, requested_for_relation,
                   assistance_type, brief_description, medicine_needed,
                   requested_for_fname, requested_for_mname, requested_for_lname,
                   requested_for_birthdate, requested_for_gender,
                   requested_for_contact, requested_for_email,
                   requested_for_region, requested_for_province,
                   requested_for_municipality, requested_for_barangay,
                   requested_for_address, requested_for_zipcode,
                   preferred_contact,
                   amount, claimed_amount,
                   deceased_fullname, deceased_birthdate, deceased_deathdate,
                   educ_school_name, educ_grade_level, educ_course,
                   educ_school_sector, educ_school_id_number,
                   educ_school_address,
                   tribal_membership, disability,
                   other_financial_assistance,
                   other_financial_assistance_type_1,
                   other_financial_assistance_agency_1,
                   other_financial_assistance_type_2,
                   other_financial_assistance_agency_2,
                   photo_2x2, photo_signature, image_verification,
                   upload_file_1, upload_file_1_type,
                   upload_file_2, upload_file_2_type,
                   upload_file_3, upload_file_3_type,
                   upload_file_4, upload_file_4_type,
                   upload_file_5, upload_file_5_type,
                   upload_file_6, upload_file_6_type,
                   upload_file_7, upload_file_7_type,
                   upload_file_8, upload_file_8_type
                   {bene_col}{civil_status_col}{educ_year_level_col}{appt_cols}
            FROM app_social_services WHERE user_id=%s ORDER BY date_requested DESC
        """, (data['user_profile_id'],))
        rows = cur.fetchall()
        applications = [serialize_row(r) for r in rows]
        return ok({'status': True, 'applications': applications})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"get_social_services error: {e}", exc_info=True)
        return fail(f'Server error: {str(e)}', 500)

def admin_list_social_services(cur, data, files, ts):
    try:
        page = max(parse_int(data.get('page')) or 1, 1)
        limit = min(max(parse_int(data.get('limit')) or 20, 1), 100)
        offset = (page - 1) * limit
        status = (data.get('status') or '').strip().upper()
        service_type = sanitize(data.get('service_type'))
        requested_from = (data.get('requested_from') or '').strip().upper()
        search = sanitize(data.get('search'))
        date_from = sanitize(data.get('date_from'))
        date_to = sanitize(data.get('date_to'))

        where = []
        params = []
        if status and status != 'ALL':
            if status not in _SOCIAL_SERVICES_ALL_STATUSES:
                return fail(f'Invalid status: {status}')
            where.append('status=%s')
            params.append(status)
        if service_type and service_type != 'ALL':
            where.append('service_type=%s')
            params.append(service_type)
        if requested_from and requested_from != 'ALL':
            if requested_from not in _SOCIAL_SERVICES_REQUESTED_FROM:
                return fail(f'Invalid requested_from: {requested_from}')
            where.append('requested_from=%s')
            params.append(requested_from)
        if search:
            like = f'%{search}%'
            where.append(
                '(application_number LIKE %s OR requested_for_fname LIKE %s '
                'OR requested_for_lname LIKE %s)'
            )
            params += [like, like, like]
        if date_from:
            where.append('date_requested >= %s')
            params.append(date_from)
        if date_to:
            where.append('date_requested <= %s')
            params.append(f'{date_to} 23:59:59')
        clause = ('WHERE ' + ' AND '.join(where)) if where else ''

        cur.execute(f"""
            SELECT id, application_number, user_id, service_type, service_sub_category,
                   assistance_type, status, requested_for, requested_for_fname,
                   requested_for_lname, amount, requested_from, date_requested, date_reviewed,
                   date_approved, date_declined, date_released, date_claimed
            FROM app_social_services
            {clause}
            ORDER BY date_requested DESC
            LIMIT %s OFFSET %s
        """, tuple(params + [limit + 1, offset]))
        rows = cur.fetchall() or []
        has_more = len(rows) > limit
        rows = rows[:limit]

        cur.execute("SELECT status, COUNT(*) AS c FROM app_social_services GROUP BY status")
        raw_counts = {row['status']: row['c'] for row in cur.fetchall()}
        stat_counts = {s: raw_counts.get(s, 0) for s in _SOCIAL_SERVICES_ALL_STATUSES}
        stat_counts['ALL'] = sum(stat_counts.values())

        return ok({'status': True,
                   'data': {'items': [serialize_row(r) for r in rows],
                            'page': page, 'has_more': has_more,
                            'counts': stat_counts}})
    except Exception as e:
        logger.error(f'admin_list_social_services error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


_SOCIAL_SERVICE_TYPES = {
    'MEDICAL ASSISTANCE', 'EDUCATIONAL ASSISTANCE',
    'BURIAL ASSISTANCE', 'LIVELIHOOD ASSISTANCE',
}

# `requested_from` only ever takes one of these two values: a citizen
# submission via the mobile app, or a staff-entered walk-in record
# created from the admin console.
_SOCIAL_SERVICES_REQUESTED_FROM = {'MOBILE', 'WALK-IN'}


def admin_get_social_service_detail(cur, data, files, ts):
    try:
        require(data, 'id')
        app_id = data['id']

        appt_cols = (
            ', submission_method, appointment_date, '
            'appointment_time, appointment_location'
            if _has_appointment_columns(cur) else ''
        )
        bene_col = (
            ', beneficiary_name'
            if _has_beneficiary_name_column(cur) else ''
        )
        civil_status_col = (
            ', requested_for_civil_status'
            if _has_civil_status_column(cur) else ''
        )
        educ_year_level_col = (
            ', educ_year_level, educ_is_scholar'
            if _has_educ_year_level_column(cur) else ''
        )
        qr_col = ', qr_code' if _has_qr_code_column(cur) else ''

        cur.execute(f"""
            SELECT id, application_number, user_id, service_type, service_sub_category,
                   status, date_requested, date_reviewed, date_approved,
                   date_scheduled, date_released, date_claimed, date_declined,
                   requested_for, requested_for_relation,
                   assistance_type, brief_description, medicine_needed,
                   requested_for_fname, requested_for_mname, requested_for_lname,
                   requested_for_birthdate, requested_for_gender,
                   requested_for_contact, requested_for_email,
                   requested_for_region, requested_for_province,
                   requested_for_municipality, requested_for_barangay,
                   requested_for_address, requested_for_zipcode,
                   preferred_contact,
                   amount, claimed_amount,
                   deceased_fullname, deceased_birthdate, deceased_deathdate,
                   educ_school_name, educ_grade_level, educ_course,
                   educ_school_sector, educ_school_id_number,
                   educ_school_address,
                   tribal_membership, disability,
                   other_financial_assistance,
                   other_financial_assistance_type_1,
                   other_financial_assistance_agency_1,
                   other_financial_assistance_type_2,
                   other_financial_assistance_agency_2,
                   photo_2x2, photo_signature, image_verification,
                   upload_file_1, upload_file_1_type,
                   upload_file_2, upload_file_2_type,
                   upload_file_3, upload_file_3_type,
                   upload_file_4, upload_file_4_type,
                   upload_file_5, upload_file_5_type,
                   upload_file_6, upload_file_6_type,
                   upload_file_7, upload_file_7_type,
                   upload_file_8, upload_file_8_type
                   {bene_col}{civil_status_col}{educ_year_level_col}{appt_cols}{qr_col}
            FROM app_social_services WHERE id=%s
        """, (app_id,))
        row = cur.fetchone()
        if not row:
            return fail('Application not found', 404)

        cur.execute("""
            SELECT id, name, birthdate, relationship, skill_occupation,
                   gender, birthplace, civl_status, highest_educ, est_income
            FROM app_social_services_family
            WHERE social_services_id=%s
        """, (app_id,))
        family = cur.fetchall() or []

        cur.execute("""
            SELECT id, application_number, service_type, assistance_type,
                   status, amount, date_requested
            FROM app_social_services
            WHERE user_id=%s
            ORDER BY date_requested DESC
        """, (row['user_id'],))
        history = cur.fetchall() or []

        detail = serialize_row(row)
        detail['family'] = [serialize_row(m) for m in family]
        detail['history'] = [serialize_row(h) for h in history]
        return ok({'status': True, 'data': detail})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'admin_get_social_service_detail error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def admin_create_social_service(cur, data, files, ts):
    """
    Staff-entered walk-in application. Unlike `submit_social_service`
    (mobile), this skips the KYC-verified gate and appointment
    auto-scheduling -- the citizen is physically at the counter, so
    there's no identity check or online-slot booking to do. Always
    lands as PENDING with no linked user account (user_id NULL) since
    walk-ins may not have a mobile account at all.
    """
    try:
        form = parse_form_data(data)
        require(form, 'service_type')
        service_type = (form.get('service_type') or '').strip().upper()
        if service_type not in _SOCIAL_SERVICE_TYPES:
            return fail(f'Invalid service type: {service_type}')

        app_number = generate_number_id(cur, 'app_social_services')

        applying_for = 'OTHER' if str(form.get('help_for') or '').strip().upper() == 'OTHERS' else 'SELF'

        base_cols = [
            'application_number', 'service_type', 'requested_for', 'requested_for_relation',
            'assistance_type', 'brief_description',
            'requested_for_fname', 'requested_for_mname', 'requested_for_lname',
            'requested_for_birthdate', 'requested_for_gender', 'requested_for_contact', 'requested_for_email',
            'requested_for_region', 'requested_for_province', 'requested_for_municipality',
            'requested_for_barangay', 'requested_for_address', 'requested_for_zipcode',
            'educ_school_name', 'educ_grade_level', 'educ_course', 'educ_school_sector',
            'educ_school_id_number', 'educ_school_address',
            'tribal_membership', 'disability', 'other_financial_assistance',
            'other_financial_assistance_type_1', 'other_financial_assistance_agency_1',
            'other_financial_assistance_type_2', 'other_financial_assistance_agency_2',
            'deceased_fullname', 'deceased_birthdate', 'deceased_deathdate',
            'amount', 'medicine_needed',
            'date_requested', 'status', 'requested_from',
        ]
        base_vals = [
            app_number, service_type, applying_for,
            sanitize(form.get('beneficiary_relationship')), sanitize(form.get('assistance_type')),
            sanitize(form.get('description')),
            sanitize(form.get('first_name')), sanitize(form.get('middle_name')), sanitize(form.get('last_name')),
            sanitize(form.get('birthdate')), sanitize(form.get('gender')),
            sanitize(form.get('phone')), sanitize(form.get('email')),
            sanitize(form.get('region')), sanitize(form.get('province')), sanitize(form.get('municipality')),
            sanitize(form.get('barangay')), sanitize(form.get('address')), sanitize(form.get('zipcode')),
            sanitize(form.get('school_name')), sanitize(form.get('grade_level')), sanitize(form.get('course')),
            sanitize(form.get('school_sector')), sanitize(form.get('school_id_number')),
            sanitize(form.get('school_address')),
            sanitize(form.get('tribal')), sanitize(form.get('disability')),
            sanitize(form.get('other_financial_assistance')),
            sanitize(form.get('other_financial_assistance_type_1')),
            sanitize(form.get('other_financial_assistance_agency_1')),
            sanitize(form.get('other_financial_assistance_type_2')),
            sanitize(form.get('other_financial_assistance_agency_2')),
            sanitize(form.get('deceased_fullname')), sanitize(form.get('deceased_birthdate')),
            sanitize(form.get('deceased_deathdate')),
            form.get('amount') or None, sanitize(form.get('medicine_needed')),
            ts, 'PENDING', 'WALK-IN',
        ]

        if _has_beneficiary_name_column(cur):
            base_cols.append('beneficiary_name')
            base_vals.append(sanitize(form.get('beneficiary_name')))

        cols_sql = ', '.join(base_cols)
        placeholders = ', '.join(['%s'] * len(base_vals))
        cur.execute(
            f'INSERT INTO app_social_services ({cols_sql}) VALUES ({placeholders})',
            tuple(base_vals),
        )
        social_services_id = cur.lastrowid

        qr_code = None
        if _has_qr_code_column(cur):
            qr_code = _generate_qr_code(cur, social_services_id)
            cur.execute(
                "UPDATE app_social_services SET qr_code=%s WHERE id=%s",
                (qr_code, social_services_id),
            )

        admin = data.get('_admin') or {}
        record_audit_log(cur, admin.get('id'), admin.get('role'),
                          'admin_create_social_service', 'social_service',
                          social_services_id, {'application_number': app_number, 'service_type': service_type}, ts)

        return ok({'status': True, 'id': str(social_services_id), 'application_number': app_number, 'qr_code': qr_code})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'admin_create_social_service error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def admin_delete_social_service(cur, data, files, ts):
    try:
        require(data, 'id')
        app_id = data['id']

        cur.execute("SELECT application_number FROM app_social_services WHERE id=%s", (app_id,))
        row = cur.fetchone()
        if not row:
            return fail('Application not found', 404)

        cur.execute("DELETE FROM app_social_services_family WHERE social_services_id=%s", (app_id,))
        cur.execute("DELETE FROM app_social_services WHERE id=%s", (app_id,))

        admin = data.get('_admin') or {}
        record_audit_log(cur, admin.get('id'), admin.get('role'),
                          'admin_delete_social_service', 'social_service',
                          app_id, {'application_number': row['application_number']}, ts)

        return ok({'status': True, 'id': str(app_id)})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'admin_delete_social_service error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def admin_update_social_service_type(cur, data, files, ts):
    try:
        require(data, 'id', 'service_type')
        app_id = data['id']
        service_type = (data['service_type'] or '').strip().upper()
        if service_type not in _SOCIAL_SERVICE_TYPES:
            return fail(f'Invalid service type: {service_type}')

        cur.execute("SELECT id FROM app_social_services WHERE id=%s", (app_id,))
        if not cur.fetchone():
            return fail('Application not found', 404)

        cur.execute(
            "UPDATE app_social_services SET service_type=%s WHERE id=%s",
            (service_type, app_id))

        admin = data.get('_admin') or {}
        record_audit_log(cur, admin.get('id'), admin.get('role'),
                          'admin_update_social_service_type', 'social_service',
                          app_id, {'service_type': service_type}, ts)

        return ok({'status': True, 'id': str(app_id), 'service_type': service_type})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'admin_update_social_service_type error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def admin_update_social_service_status(cur, data, files, ts):
    try:
        require(data, 'id', 'status')
        app_id = data['id']
        status = (data['status'] or '').strip().upper()
        if status not in _SOCIAL_SERVICES_ADMIN_STATUSES:
            return fail(f'Invalid status: {status}')

        cur.execute("SELECT id FROM app_social_services WHERE id=%s", (app_id,))
        if not cur.fetchone():
            return fail('Application not found', 404)

        date_col = _STATUS_DATE_COLUMNS[status]
        cur.execute(
            f"UPDATE app_social_services SET status=%s, {date_col}=%s WHERE id=%s",
            (status, ts, app_id))

        admin = data.get('_admin') or {}
        record_audit_log(cur, admin.get('id'), admin.get('role'),
                          'admin_update_social_service_status', 'social_service',
                          app_id, {'status': status}, ts)

        return ok({'status': True, 'id': str(app_id), 'status_value': status})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'admin_update_social_service_status error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)
