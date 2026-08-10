import json
import re
import uuid
import logging
from datetime import time, timedelta
from helpers.auth import ok, fail, require
from helpers.db import sanitize, serialize_row, generate_number_id, now_ph
from helpers.parse import parse_form_data
from helpers.s3 import upload_files_from_list

logger = logging.getLogger()

# Dynamic appointment-slot policy (Bataan, Orani District Office). Actual
# capacity is admin-managed in `app_social_service_schedule_slots` (see the
# admin console, bataan_lgu_admin) — this file only bounds how far ahead a
# citizen can be booked and names where the appointment happens.
MAX_BOOKING_HORIZON_DAYS = 30  # proposed default; confirm with LGU alongside slot-seeding cadence
ONLINE_APPOINTMENT_LOCATION = 'Orani District Office (sa tabi ng simbahan)'


def _time_from_db(value):
    """pymysql returns MySQL `TIME` columns as `datetime.timedelta`, not
    `datetime.time` — MySQL TIME can hold values past 24h
    (-838:59:59..838:59:59), which `time` can't represent, so pymysql
    always uses `timedelta` regardless of the actual stored value. Convert
    back to a real `time` for anything that needs `.strftime()` or
    time-of-day semantics (our slot times are always well within 24h)."""
    if isinstance(value, timedelta):
        total_seconds = int(value.total_seconds())
        hours, remainder = divmod(total_seconds, 3600)
        minutes, seconds = divmod(remainder, 60)
        return time(hour=hours % 24, minute=minutes, second=seconds)
    return value


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


def _has_schedule_slot_column(cur):
    """True when migration 030 (schedule_slot_id) is applied — i.e. this
    tenant has real admin-managed appointment slots to book against."""
    cur.execute(
        """
        SELECT COUNT(*) AS c
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'app_social_services'
          AND COLUMN_NAME = 'schedule_slot_id'
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


def _reserve_slot_and_insert(cur, base_cols, base_vals, submission_method, ts):
    """
    Atomically claim the earliest available appointment slot from
    `app_social_service_schedule_slots` and insert the application row in
    the SAME transaction as the row lock. The lock has to still be held
    when the row that claims the seat is inserted — otherwise two
    concurrent requests can both see room on a slot and both insert,
    overbooking it. Both ONLINE and IN_PERSON draw from one shared pool
    (no per-method split — matches the admin console's own scheduling,
    which doesn't distinguish submission method either).

    `base_cols`/`base_vals` must NOT already include `status`,
    `date_scheduled`, `submission_method`, `appointment_date`,
    `appointment_time`, `appointment_location`, or `schedule_slot_id` —
    this function appends those once it knows which slot won.

    All "today"/horizon comparisons are bound Python parameters
    (`now_ph()`), never MySQL date functions (`CURDATE()`/`NOW()`), so the
    connection's session timezone can never desync this from Manila time.

    Returns (social_services_id, appointment_date, appointment_time,
    error_message). On success the first two are set and error_message is
    None; on exhaustion social_services_id/appointment_date/appointment_time
    are None and error_message explains why — distinguishing "no slots
    configured at all" (an ops gap) from "slots exist but are full".
    """
    now_local = now_ph()
    today = now_local.date()
    current_time = now_local.time()
    horizon_end = today + timedelta(days=MAX_BOOKING_HORIZON_DAYS)

    conn = cur.connection
    prior_autocommit = conn.get_autocommit()
    conn.autocommit(False)
    committed = False
    try:
        # Read-only candidate list — no lock yet. Excludes slot_times that
        # have already passed today so nobody gets booked into an earlier
        # time slot on the day they're submitting.
        cur.execute(
            """
            SELECT id, slot_date, slot_time, total_slots
            FROM app_social_service_schedule_slots
            WHERE status='ACTIVE'
              AND slot_date >= %s AND slot_date <= %s
              AND (slot_date > %s OR slot_time > %s)
            ORDER BY slot_date, slot_time
            """,
            (today, horizon_end, today, current_time),
        )
        candidates = cur.fetchall()
        # pymysql hands back TIME columns as timedelta — normalize to a
        # real time now so nothing downstream (the INSERT, the response's
        # .strftime()) has to know about that quirk.
        for cand in candidates:
            cand['slot_time'] = _time_from_db(cand['slot_time'])
        logger.info(
            '[_reserve_slot_and_insert] method=%s today=%s horizon_end=%s '
            'candidates=%d',
            submission_method, today, horizon_end, len(candidates),
        )

        if not candidates:
            logger.error(
                '[_reserve_slot_and_insert] zero ACTIVE slots from %s '
                'through %s — slot seeding has lapsed', today, horizon_end,
            )
            return None, None, None, (
                'Online/walk-in appointment scheduling is temporarily '
                'unavailable. Please try again later or visit the office '
                'directly.'
            )

        for cand in candidates:
            cur.execute(
                "SELECT id, total_slots FROM app_social_service_schedule_slots "
                "WHERE id=%s FOR UPDATE",
                (cand['id'],),
            )
            locked = cur.fetchone()
            if not locked:
                conn.rollback()
                continue

            cur.execute(
                "SELECT COUNT(*) AS c FROM app_social_services "
                "WHERE schedule_slot_id=%s AND status IN ('SCHEDULED','CLAIMED')",
                (locked['id'],),
            )
            booked = cur.fetchone()['c']
            if booked >= locked['total_slots']:
                conn.rollback()
                continue

            final_cols = base_cols + [
                'status', 'date_scheduled', 'submission_method',
                'appointment_date', 'appointment_time', 'appointment_location',
                'schedule_slot_id',
            ]
            final_vals = base_vals + [
                'SCHEDULED', ts, submission_method,
                cand['slot_date'], cand['slot_time'], ONLINE_APPOINTMENT_LOCATION,
                cand['id'],
            ]
            cols_sql = ', '.join(final_cols)
            placeholders = ', '.join(['%s'] * len(final_vals))
            cur.execute(
                f'INSERT INTO app_social_services ({cols_sql}) VALUES ({placeholders})',
                tuple(final_vals),
            )
            new_id = cur.lastrowid
            conn.commit()
            committed = True
            logger.info(
                '[_reserve_slot_and_insert] claimed slot_id=%s date=%s time=%s '
                'for new id=%s', cand['id'], cand['slot_date'], cand['slot_time'],
                new_id,
            )
            return new_id, cand['slot_date'], cand['slot_time'], None

        return None, None, None, (
            f'Appointment slots are full for the next '
            f'{MAX_BOOKING_HORIZON_DAYS} days. Please try again later.'
        )
    finally:
        if not committed:
            try:
                conn.rollback()
            except Exception:
                pass
        conn.autocommit(prior_autocommit)


def submit_social_service_bataan(cur, data, files, ts):
    try:
        require(data, 'user_profile_id')
        user_id = data['user_profile_id']

        cur.execute("SELECT status FROM app_kyc WHERE user_id=%s ORDER BY submitted_at DESC LIMIT 1", (user_id,))
        kyc = cur.fetchone()
        if not kyc or kyc['status'] != 'VERIFIED':
            return fail('KYC verification required before submitting social services', 403)

        form = parse_form_data(data)
        require(form, 'service_type')

        # Submission method (IN_PERSON | ONLINE). Both draw appointments
        # from the same admin-managed schedule-slot pool below — there is
        # no separate capacity per method.
        submission_method = str(
            form.get('submission_method') or 'IN_PERSON'
        ).strip().upper()
        if submission_method not in ('IN_PERSON', 'ONLINE'):
            submission_method = 'IN_PERSON'
        logger.info(
            '[submit_social_service_bataan] user_id=%s service_type=%s '
            'submission_method=%s raw_form_method=%r',
            user_id, form.get('service_type'),
            submission_method, form.get('submission_method'),
        )

        has_appt_cols = _has_appointment_columns(cur)
        has_slot_col = _has_schedule_slot_column(cur)
        slot_infra_ready = has_appt_cols and has_slot_col

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

        # Static columns only — deliberately excludes `status`,
        # `date_scheduled`, `submission_method`, `appointment_date`,
        # `appointment_time`, `appointment_location`, and
        # `schedule_slot_id`. Those depend on which appointment slot (if
        # any) ends up winning below, so they're appended at insert time,
        # inside the same transaction as the slot lock when one is used.
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
            'date_requested', 'requested_from',
            'photo_2x2', 'photo_signature', 'image_verification',
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
            ts, 'MOBILE',
            file_urls.get('photo_2x2'), file_urls.get('photo_signature'), file_urls.get('image_verification'),
        ]

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

        appointment_date = None
        appointment_time = None
        appointment_location = None

        if slot_infra_ready and submission_method in ('ONLINE', 'IN_PERSON'):
            social_services_id, appointment_date, appointment_time, slot_err = (
                _reserve_slot_and_insert(cur, base_cols, base_vals, submission_method, ts)
            )
            if slot_err:
                return fail(slot_err, 409)
            appointment_location = ONLINE_APPOINTMENT_LOCATION
        elif submission_method == 'ONLINE' and not slot_infra_ready:
            return fail(
                'Online submission is not configured for this LGU. '
                'Please choose In Person.',
                409,
            )
        else:
            # No schedule-slot infra on this tenant yet (migration 030 not
            # applied) — fall back to a plain PENDING application with no
            # appointment, same as before this feature existed.
            final_cols = base_cols + ['status', 'date_scheduled']
            final_vals = base_vals + ['PENDING', None]
            if has_appt_cols:
                final_cols += [
                    'submission_method', 'appointment_date',
                    'appointment_time', 'appointment_location',
                ]
                final_vals += [submission_method, None, None, None]
            cols_sql = ', '.join(final_cols)
            placeholders = ', '.join(['%s'] * len(final_vals))
            cur.execute(
                f'INSERT INTO app_social_services ({cols_sql}) VALUES ({placeholders})',
                tuple(final_vals),
            )
            social_services_id = cur.lastrowid

        initial_status = 'SCHEDULED' if appointment_date is not None else 'PENDING'

        # ── Everything past this point is best-effort. ──────────────────
        # `social_services_id` is already committed — a real appointment
        # slot may already be claimed. From here on, nothing is allowed to
        # turn that into a reported failure: if the app were told "500"
        # after the booking already succeeded, the citizen would retry and
        # double-book themselves, or a staff member would see a booked
        # slot nobody knows exists. Each side-effect below is isolated in
        # its own try/except so one failing (QR code, the diagnostic log,
        # one bad family-member row) can't take the whole response down —
        # it's logged and skipped instead.

        # Auto-scheduled applications get a unique QR token stamped onto the
        # row so the appointment can be scanned/verified on arrival. Only
        # applications that actually booked a slot (SCHEDULED) get one;
        # PENDING fall-backs don't have an appointment to scan yet.
        qr_code = None
        try:
            if initial_status == 'SCHEDULED' and _has_qr_code_column(cur):
                qr_code = _generate_qr_code(cur, social_services_id)
                cur.execute(
                    "UPDATE app_social_services SET qr_code=%s WHERE id=%s",
                    (qr_code, social_services_id),
                )
                logger.info(
                    '[submit_social_service_bataan] generated qr_code=%s for id=%s '
                    'app_number=%s',
                    qr_code, social_services_id, app_number,
                )
        except Exception as e:
            logger.error(
                '[submit_social_service_bataan] QR generation failed for '
                'already-committed id=%s app_number=%s: %s',
                social_services_id, app_number, e, exc_info=True,
            )
            qr_code = None

        try:
            cur.execute(
                "SELECT DATABASE() AS db_name, COUNT(*) AS today_online "
                "FROM app_social_services "
                "WHERE submission_method='ONLINE' AND appointment_date=%s",
                (appointment_date if appointment_date else now_ph().date(),),
            )
            verify = cur.fetchone() or {}
            logger.info(
                '[submit_social_service_bataan] INSERTED id=%s app_number=%s '
                'submission_method=%s appointment_date=%s appointment_time=%s '
                'verify_db_name=%s today_online_count_now=%s',
                social_services_id, app_number, submission_method,
                appointment_date, appointment_time,
                verify.get('db_name'), verify.get('today_online'),
            )
        except Exception as e:
            logger.warning('[submit_social_service_bataan] post-insert verify failed: %s', e)

        for member in family_members:
            try:
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
            except Exception as e:
                logger.error(
                    '[submit_social_service_bataan] family member insert failed for '
                    'already-committed id=%s member=%r: %s',
                    social_services_id, member, e, exc_info=True,
                )
                # Keep going — the remaining family members and the
                # response itself still matter even if one row is bad.

        try:
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
                # the earliest slot with room may not be today, either because
                # today's slots are full or because it's already past every
                # remaining slot_time today. Compared against Manila-local
                # "today" so the flag is correct from the user's perspective
                # regardless of where the Lambda is running.
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
        except Exception as e:
            # The booking is already committed — this can only be a bug in
            # formatting the response, never a reason to tell the citizen
            # their submission failed. Fall back to the minimal payload
            # that can't fail to build.
            logger.error(
                '[submit_social_service_bataan] response build failed for '
                'already-committed id=%s app_number=%s: %s',
                social_services_id, app_number, e, exc_info=True,
            )
            return ok({
                'status': True,
                'message': 'Social service application submitted successfully',
                'application_number': app_number,
                'submission_method': submission_method,
                'application_status': initial_status,
                'qr_code': qr_code,
            })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"submit_social_service_bataan error: {e}", exc_info=True)
        return fail(f'Server error: {str(e)}', 500)

def get_social_services_bataan(cur, data, files, ts):
    try:
        require(data, 'user_profile_id')
        appt_cols = (
            ', submission_method, appointment_date, '
            'appointment_time, appointment_location'
            if _has_appointment_columns(cur) else ''
        )
        slot_col = (
            ', schedule_slot_id'
            if _has_schedule_slot_column(cur) else ''
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
                   other_financial_assistance_agency_2{bene_col}{civil_status_col}{educ_year_level_col}{appt_cols}{slot_col}
            FROM app_social_services WHERE user_id=%s ORDER BY date_requested DESC
        """, (data['user_profile_id'],))
        rows = cur.fetchall()
        applications = [serialize_row(r) for r in rows]
        return ok({'status': True, 'applications': applications})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"get_social_services_bataan error: {e}", exc_info=True)
        return fail(f'Server error: {str(e)}', 500)
