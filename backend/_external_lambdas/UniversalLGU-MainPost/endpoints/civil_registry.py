import logging
import json
import uuid
from datetime import datetime

from helpers.auth import ok, fail, require
from helpers.audit import record_audit_log
from helpers.db import sanitize, serialize_row
from helpers.s3 import upload_to_s3, generate_key

logger = logging.getLogger()

# Multipart field name == DB column name for every document slot on this form
# (unlike business_permits.py, no category-to-column remapping is needed).
_FILE_COLUMNS = [
    'mother_valid_id',
    'father_valid_id',
    'marriage_certificate',
    'affidavit_of_acknowledgment',
    'ausf_document',
    'informant_valid_id',
    'affidavit_of_delayed_registration',
    'supporting_documents',
    'psa_negative_certification',
]

# NOT NULL columns in app_birth_registrations, keyed by the same names the
# Flutter form_data JSON sends.
_REQUIRED_FIELDS = (
    'child_first_name', 'child_last_name', 'child_sex', 'child_dob',
    'birth_place_hospital', 'birth_place_region', 'birth_place_province',
    'birth_place_city', 'birth_place_barangay',
    'birth_type', 'birth_order',
    'mother_first_name', 'mother_last_name',
    'father_first_name', 'father_last_name',
    'parents_married',
    'attendant_type', 'attendant_first_name', 'attendant_last_name',
    'informant_first_name', 'informant_last_name', 'informant_relationship',
    'informant_phone',
    'registration_type',
)

_BIRTH_REG_STATUSES = {'PENDING', 'APPROVED', 'DECLINED'}


def _new_app_number():
    return 'BC' + datetime.now().strftime('%Y%m%d') + uuid.uuid4().hex[:6].upper()


def _parse_int(v):
    if v in (None, ''):
        return None
    try:
        return int(v)
    except Exception:
        return None


def _parse_date(v):
    """Flutter sends dates as 'MM/DD/YYYY'; MySQL DATE columns need
    'YYYY-MM-DD'. Returns None on empty/unparseable input rather than
    raising, since several date fields are optional (mother/father DOB)."""
    if not v:
        return None
    try:
        return datetime.strptime(str(v).strip(), '%m/%d/%Y').strftime('%Y-%m-%d')
    except Exception:
        return None


def _parse_json_obj(raw, default):
    if not raw:
        return default
    if not isinstance(raw, str):
        return raw
    try:
        return json.loads(raw)
    except Exception:
        return default


def _upload_files(files, user_id, app_number):
    """Group uploaded multipart files by field name (== DB column) and
    upload each to S3. Returns {column: comma_joined_urls}."""
    urls = {col: '' for col in _FILE_COLUMNS}
    by_field = {}
    for f in files:
        fn = f.get('field_name', '')
        by_field.setdefault(fn, []).append(f)

    for col in _FILE_COLUMNS:
        uploaded = []
        for f in by_field.get(col, []):
            f['content'].seek(0)
            content = f['content'].read()
            key = generate_key(
                f'birth_registrations/{user_id}/{app_number}', user_id,
                f.get('filename') or col,
            )
            uploaded.append(upload_to_s3(content, key))
        urls[col] = ','.join(uploaded)
    return urls


def _upload_named_files(files, prefix, user_id):
    """Upload each multipart file part, grouped by its field_name. Returns
    {field_name: [s3_url, ...]}. Used for drafts, where categories may be
    partial (not every column uploaded yet)."""
    grouped = {}
    for f in files or []:
        cat = f.get('field_name') or 'other'
        f['content'].seek(0)
        content = f['content'].read()
        key = generate_key(prefix, user_id, f.get('filename') or cat)
        url = upload_to_s3(content, key)
        grouped.setdefault(cat, []).append(url)
    return grouped


def _merge_existing_files(file_urls, existing_raw):
    """Merge already-uploaded document URLs (from a resumed draft) into
    file_urls in place. existing_raw is a JSON string
    {column_name: [url, ...]}."""
    existing = _parse_json_obj(existing_raw, {})
    if not isinstance(existing, dict):
        return
    for col, urls in existing.items():
        if col not in _FILE_COLUMNS or not isinstance(urls, list):
            continue
        keep = [u for u in urls if u]
        if not keep:
            continue
        current = file_urls.get(col) or ''
        file_urls[col] = ','.join(keep + ([current] if current else []))


def submit_birth_registration(cur, data, files, ts):
    try:
        require(data, 'user_profile_id')
        user_id = data['user_profile_id']

        raw = data.get('form_data') or '{}'
        try:
            form = json.loads(raw) if isinstance(raw, str) else dict(raw)
        except Exception:
            return fail('Invalid form_data JSON')

        for field in _REQUIRED_FIELDS:
            if not str(form.get(field) or '').strip():
                return fail(f'Missing required field: {field}')

        app_number = _new_app_number()
        file_urls = _upload_files(files, user_id, app_number)
        _merge_existing_files(file_urls, data.get('existing_files'))

        cur.execute("""
            INSERT INTO app_birth_registrations (
                user_id, application_number,
                child_first_name, child_middle_name, child_last_name, child_suffix,
                child_sex, child_dob, child_time_of_birth, child_weight_grams,
                birth_place_hospital, birth_place_region, birth_place_province,
                birth_place_city, birth_place_barangay,
                birth_type, multiple_birth_order, birth_order,
                mother_first_name, mother_middle_name, mother_last_name,
                mother_dob, mother_age_at_birth, mother_citizenship, mother_religion,
                mother_occupation, mother_children_born_alive, mother_children_living,
                mother_children_dead, mother_country, mother_region, mother_province,
                mother_city, mother_barangay, mother_residence,
                father_first_name, father_middle_name, father_last_name,
                father_dob, father_age_at_birth, father_citizenship, father_religion,
                father_occupation, father_country, father_region, father_province,
                father_city, father_barangay, father_residence,
                parents_married, marriage_date, marriage_place, child_uses_father_surname,
                attendant_type, attendant_first_name, attendant_middle_name,
                attendant_last_name, attendant_title, attendant_license_no, attendant_address,
                informant_first_name, informant_middle_name, informant_last_name,
                informant_relationship, informant_title, informant_address,
                informant_phone, informant_email,
                registration_type, reason_for_delay,
                mother_valid_id, father_valid_id, marriage_certificate,
                affidavit_of_acknowledgment, ausf_document, informant_valid_id,
                affidavit_of_delayed_registration, supporting_documents,
                psa_negative_certification,
                status, date_submitted
            ) VALUES (
                %s, %s,
                %s, %s, %s, %s,
                %s, %s, %s, %s,
                %s, %s, %s,
                %s, %s,
                %s, %s, %s,
                %s, %s, %s,
                %s, %s, %s, %s,
                %s, %s, %s,
                %s, %s, %s, %s,
                %s, %s, %s,
                %s, %s, %s,
                %s, %s, %s, %s,
                %s, %s, %s, %s,
                %s, %s, %s,
                %s, %s, %s, %s,
                %s, %s, %s,
                %s, %s, %s, %s,
                %s, %s, %s,
                %s, %s, %s,
                %s, %s,
                %s, %s,
                %s, %s, %s,
                %s, %s, %s,
                %s, %s,
                %s,
                'PENDING', %s
            )
        """, (
            user_id, app_number,
            sanitize(form.get('child_first_name')), sanitize(form.get('child_middle_name')),
            sanitize(form.get('child_last_name')), sanitize(form.get('child_suffix')),
            sanitize(form.get('child_sex')), _parse_date(form.get('child_dob')),
            sanitize(form.get('child_time_of_birth')), _parse_int(form.get('child_weight_grams')),
            sanitize(form.get('birth_place_hospital')), sanitize(form.get('birth_place_region')),
            sanitize(form.get('birth_place_province')), sanitize(form.get('birth_place_city')),
            sanitize(form.get('birth_place_barangay')),
            sanitize(form.get('birth_type')), sanitize(form.get('multiple_birth_order')),
            sanitize(form.get('birth_order')),
            sanitize(form.get('mother_first_name')), sanitize(form.get('mother_middle_name')),
            sanitize(form.get('mother_last_name')), _parse_date(form.get('mother_dob')),
            _parse_int(form.get('mother_age_at_birth')), sanitize(form.get('mother_citizenship')),
            sanitize(form.get('mother_religion')), sanitize(form.get('mother_occupation')),
            _parse_int(form.get('mother_children_born_alive')),
            _parse_int(form.get('mother_children_living')),
            _parse_int(form.get('mother_children_dead')),
            sanitize(form.get('mother_country')), sanitize(form.get('mother_region')),
            sanitize(form.get('mother_province')), sanitize(form.get('mother_city')),
            sanitize(form.get('mother_barangay')), sanitize(form.get('mother_residence')),
            sanitize(form.get('father_first_name')), sanitize(form.get('father_middle_name')),
            sanitize(form.get('father_last_name')), _parse_date(form.get('father_dob')),
            _parse_int(form.get('father_age_at_birth')), sanitize(form.get('father_citizenship')),
            sanitize(form.get('father_religion')), sanitize(form.get('father_occupation')),
            sanitize(form.get('father_country')), sanitize(form.get('father_region')),
            sanitize(form.get('father_province')), sanitize(form.get('father_city')),
            sanitize(form.get('father_barangay')), sanitize(form.get('father_residence')),
            sanitize(form.get('parents_married')), _parse_date(form.get('marriage_date')),
            sanitize(form.get('marriage_place')), sanitize(form.get('child_uses_father_surname')),
            sanitize(form.get('attendant_type')), sanitize(form.get('attendant_first_name')),
            sanitize(form.get('attendant_middle_name')), sanitize(form.get('attendant_last_name')),
            sanitize(form.get('attendant_title')), sanitize(form.get('attendant_license_no')),
            sanitize(form.get('attendant_address')),
            sanitize(form.get('informant_first_name')), sanitize(form.get('informant_middle_name')),
            sanitize(form.get('informant_last_name')), sanitize(form.get('informant_relationship')),
            sanitize(form.get('informant_title')), sanitize(form.get('informant_address')),
            sanitize(form.get('informant_phone')), sanitize(form.get('informant_email')),
            sanitize(form.get('registration_type')), sanitize(form.get('reason_for_delay')),
            file_urls['mother_valid_id'], file_urls['father_valid_id'],
            file_urls['marriage_certificate'], file_urls['affidavit_of_acknowledgment'],
            file_urls['ausf_document'], file_urls['informant_valid_id'],
            file_urls['affidavit_of_delayed_registration'], file_urls['supporting_documents'],
            file_urls['psa_negative_certification'],
            ts,
        ))

        draft_id = (data.get('draft_id') or '').strip()
        if draft_id:
            cur.execute(
                "DELETE FROM app_birth_registration_drafts WHERE id=%s AND user_id=%s",
                (draft_id, user_id),
            )

        return ok({
            'status': True,
            'message': 'Birth registration application submitted',
            'application_number': app_number,
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'submit_birth_registration error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def get_birth_registrations(cur, data, files, ts):
    try:
        require(data, 'user_profile_id')
        cur.execute("""
            SELECT id, application_number, child_first_name, child_middle_name,
                   child_last_name, child_sex, child_dob, status, remarks,
                   date_submitted, date_reviewed, date_approved
            FROM app_birth_registrations
            WHERE user_id=%s
            ORDER BY date_submitted DESC
        """, (data['user_profile_id'],))
        rows = cur.fetchall()
        return ok({
            'status': True,
            'applications': [serialize_row(r) for r in rows],
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'get_birth_registrations error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def get_birth_registration_detail(cur, data, files, ts):
    try:
        require(data, 'user_profile_id', 'application_number')
        cur.execute("""
            SELECT * FROM app_birth_registrations
            WHERE user_id=%s AND application_number=%s
            LIMIT 1
        """, (data['user_profile_id'], data['application_number']))
        row = cur.fetchone()
        if not row:
            return fail('Application not found', 404)
        return ok({'status': True, 'data': serialize_row(row)})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'get_birth_registration_detail error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def admin_list_birth_registrations(cur, data, files, ts):
    try:
        page = max(_parse_int(data.get('page')) or 1, 1)
        limit = min(max(_parse_int(data.get('limit')) or 20, 1), 100)
        offset = (page - 1) * limit
        status = (data.get('status') or '').strip().upper()

        where = []
        params = []
        if status and status != 'ALL':
            if status not in _BIRTH_REG_STATUSES:
                return fail(f'Invalid status: {status}')
            where.append('status=%s')
            params.append(status)
        clause = ('WHERE ' + ' AND '.join(where)) if where else ''

        cur.execute(f"""
            SELECT id, user_id, application_number, child_first_name, child_middle_name,
                   child_last_name, child_sex, child_dob, status, remarks,
                   date_submitted, date_reviewed, date_approved
            FROM app_birth_registrations
            {clause}
            ORDER BY date_submitted DESC
            LIMIT %s OFFSET %s
        """, tuple(params + [limit + 1, offset]))
        rows = cur.fetchall() or []
        has_more = len(rows) > limit
        rows = rows[:limit]
        return ok({'status': True,
                   'data': {'items': [serialize_row(r) for r in rows],
                            'page': page, 'has_more': has_more}})
    except Exception as e:
        logger.error(f'admin_list_birth_registrations error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def admin_review_birth_registration(cur, data, files, ts):
    try:
        require(data, 'application_number', 'decision')
        app_number = data['application_number']
        decision = (data['decision'] or '').strip().upper()
        if decision not in ('APPROVED', 'DECLINED'):
            return fail('Invalid decision')
        remarks = sanitize(data.get('remarks'))
        if decision == 'DECLINED' and not remarks:
            return fail('remarks is required when declining')

        cur.execute(
            "SELECT id FROM app_birth_registrations WHERE application_number=%s",
            (app_number,))
        if not cur.fetchone():
            return fail('Application not found', 404)

        if decision == 'APPROVED':
            cur.execute("""
                UPDATE app_birth_registrations
                   SET status=%s, remarks=%s, date_reviewed=%s, date_approved=%s
                 WHERE application_number=%s
            """, (decision, remarks, ts, ts, app_number))
        else:
            cur.execute("""
                UPDATE app_birth_registrations
                   SET status=%s, remarks=%s, date_reviewed=%s
                 WHERE application_number=%s
            """, (decision, remarks, ts, app_number))

        admin = data.get('_admin') or {}
        record_audit_log(cur, admin.get('id'), admin.get('role'),
                          'admin_review_birth_registration', 'birth_registration',
                          app_number, {'decision': decision}, ts)

        return ok({'status': True, 'message': f'Application {decision.lower()}'})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'admin_review_birth_registration error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def save_birth_registration_draft(cur, data, files, ts):
    try:
        require(data, 'user_profile_id')
        user_id = data['user_profile_id']
        draft_id = (data.get('draft_id') or '').strip()
        current_step = _parse_int(data.get('current_step')) or 0
        child_name = sanitize(data.get('child_name'))
        form_data = data.get('form_data') or '{}'

        kept = _parse_json_obj(data.get('kept_files'), {})
        if not isinstance(kept, dict):
            kept = {}
        new_urls = _upload_named_files(
            files, f'birth_registration_drafts/{user_id}', user_id)
        for cat, urls in new_urls.items():
            kept.setdefault(cat, []).extend(urls)
        files_json = json.dumps(kept)

        if draft_id:
            cur.execute(
                "SELECT id FROM app_birth_registration_drafts WHERE id=%s AND user_id=%s LIMIT 1",
                (draft_id, user_id),
            )
            if not cur.fetchone():
                return fail('Draft not found', 404)
            cur.execute("""
                UPDATE app_birth_registration_drafts
                   SET child_name=%s, current_step=%s, form_data=%s,
                       files=%s, updated_at=%s
                 WHERE id=%s AND user_id=%s
            """, (child_name, current_step, form_data, files_json, ts,
                  draft_id, user_id))
        else:
            cur.execute("""
                INSERT INTO app_birth_registration_drafts (
                    user_id, child_name, current_step, form_data, files,
                    status, created_at, updated_at
                ) VALUES (%s, %s, %s, %s, %s, 'draft', %s, %s)
            """, (user_id, child_name, current_step, form_data, files_json,
                  ts, ts))
            draft_id = cur.lastrowid

        return ok({
            'status': True,
            'message': 'Draft saved',
            'data': {'draft_id': str(draft_id), 'files': kept},
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'save_birth_registration_draft error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def list_birth_registration_drafts(cur, data, files, ts):
    try:
        require(data, 'user_profile_id')
        cur.execute("""
            SELECT id, child_name, current_step, created_at, updated_at
            FROM app_birth_registration_drafts
            WHERE user_id=%s AND status='draft'
            ORDER BY updated_at DESC
        """, (data['user_profile_id'],))
        rows = cur.fetchall()
        return ok({
            'status': True,
            'data': {
                'items': [serialize_row(r) for r in rows],
                'count': len(rows),
            },
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'list_birth_registration_drafts error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def get_birth_registration_draft(cur, data, files, ts):
    try:
        require(data, 'user_profile_id', 'draft_id')
        cur.execute("""
            SELECT id, child_name, current_step, form_data, files,
                   created_at, updated_at
            FROM app_birth_registration_drafts
            WHERE id=%s AND user_id=%s
            LIMIT 1
        """, (data['draft_id'], data['user_profile_id']))
        row = cur.fetchone()
        if not row:
            return fail('Draft not found', 404)
        return ok({
            'status': True,
            'data': {
                'id': str(row['id']),
                'child_name': row.get('child_name') or '',
                'current_step': row.get('current_step') or 0,
                'form_data': _parse_json_obj(row.get('form_data'), {}),
                'files': _parse_json_obj(row.get('files'), {}),
            },
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'get_birth_registration_draft error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def delete_birth_registration_draft(cur, data, files, ts):
    try:
        require(data, 'user_profile_id', 'draft_id')
        cur.execute(
            "DELETE FROM app_birth_registration_drafts WHERE id=%s AND user_id=%s",
            (data['draft_id'], data['user_profile_id']),
        )
        return ok({'status': True, 'message': 'Draft deleted'})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'delete_birth_registration_draft error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


# ===== Marriage License Application =====

_ML_DOCUMENT_TYPES = [
    'psa_birth_certificate', 'cenomar', 'valid_id_front', 'valid_id_back', 'id_photo',
    'barangay_certificate_residency', 'cedula', 'pmoc_certificate',
    'parental_consent', 'parental_advice', 'guardianship_document',
    'death_certificate', 'annulment_decree', 'certificate_of_finality',
    'psa_annotated_marriage_certificate', 'certificate_legal_capacity',
    'passport_bio_page', 'acr_i_card_or_visa', 'divorce_decree',
    'ph_judicial_recognition', 'joint_affidavit_cohabitation',
    'affidavit_publication', 'affidavit_discrepancy',
    'groom_signature', 'bride_signature',
]

_ML_PARTY_REQUIRED_FIELDS = (
    'first_name', 'last_name', 'dob', 'birth_country', 'citizenship', 'religion',
    'mobile_number', 'email',
)

_ML_PARENT_REQUIRED_FIELDS = ('first_name', 'last_name', 'citizenship')

_ML_CONSENT_REQUIRED_FIELDS = (
    'type', 'first_name', 'last_name', 'relationship', 'citizenship',
    'residence_region', 'residence_province', 'residence_city',
    'residence_barangay', 'residence_street_house',
)

_ML_VALID_CIVIL_STATUS = {'SINGLE', 'WIDOWED', 'ANNULLED', 'DIVORCED'}
_ML_VALID_CEREMONY_TYPES = {'CIVIL', 'RELIGIOUS', 'TRIBAL'}
_ML_VALID_CONSENT_TYPES = {'CONSENT', 'ADVICE'}
_ML_VALID_CONSENT_RELATIONSHIPS = {'FATHER', 'MOTHER', 'GUARDIAN', 'LEGAL_AUTHORITY'}


def _ml_new_app_number():
    return 'ML' + datetime.now().strftime('%Y%m%d') + uuid.uuid4().hex[:6].upper()


def _ml_compute_age(dob_str):
    """dob_str is 'YYYY-MM-DD' (already normalized by _parse_date). Returns
    None if unparseable so the caller can fail validation explicitly rather
    than silently accepting an invalid age."""
    if not dob_str:
        return None
    try:
        dob = datetime.strptime(dob_str, '%Y-%m-%d').date()
    except Exception:
        return None
    today = datetime.now().date()
    age = today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))
    return age


def _ml_upload_documents(files, user_id, app_number):
    """Uploads every multipart file part to S3, keyed by its
    '{document_type}__{role}' field_name. Returns a list of
    (document_type, role, url) tuples ready for insertion into
    app_marriage_license_documents."""
    out = []
    for f in files or []:
        field = f.get('field_name', '')
        if '__' not in field:
            continue
        doc_type, role = field.split('__', 1)
        if doc_type not in _ML_DOCUMENT_TYPES or role not in ('GROOM', 'BRIDE', 'SHARED'):
            continue
        f['content'].seek(0)
        content = f['content'].read()
        key = generate_key(
            f'marriage_license/{user_id}/{app_number}', user_id,
            f.get('filename') or doc_type,
        )
        url = upload_to_s3(content, key)
        out.append((doc_type, role, url))
    return out


def _ml_validate_party(party, label):
    for field in _ML_PARTY_REQUIRED_FIELDS:
        if not str(party.get(field) or '').strip():
            raise ValueError(f'{label}: missing required field {field}')


def _ml_validate_parent(parent, label):
    for field in _ML_PARENT_REQUIRED_FIELDS:
        if not str(parent.get(field) or '').strip():
            raise ValueError(f'{label}: missing required field {field}')


def _ml_validate_consent(consent, label):
    for field in _ML_CONSENT_REQUIRED_FIELDS:
        if not str(consent.get(field) or '').strip():
            raise ValueError(f'{label}: missing required field {field}')


def submit_marriage_license_application(cur, data, files, ts):
    try:
        require(data, 'user_profile_id')
        user_id = data['user_profile_id']

        raw = data.get('form_data') or '{}'
        try:
            form = json.loads(raw) if isinstance(raw, str) else dict(raw)
        except Exception:
            return fail('Invalid form_data JSON')

        parties = form.get('parties') or {}
        groom = parties.get('groom') or {}
        bride = parties.get('bride') or {}
        _ml_validate_party(groom, 'Groom')
        _ml_validate_party(bride, 'Bride')

        groom_dob = _parse_date(groom.get('dob'))
        bride_dob = _parse_date(bride.get('dob'))
        if not groom_dob:
            return fail('Groom: invalid or missing date of birth')
        if not bride_dob:
            return fail('Bride: invalid or missing date of birth')
        groom_age = _ml_compute_age(groom_dob)
        bride_age = _ml_compute_age(bride_dob)
        if groom_age is None or groom_age < 18:
            return fail('Groom does not meet the minimum age of 18 to apply')
        if bride_age is None or bride_age < 18:
            return fail('Bride does not meet the minimum age of 18 to apply')

        same_person = (
            groom.get('first_name', '').strip().lower() == bride.get('first_name', '').strip().lower()
            and groom.get('last_name', '').strip().lower() == bride.get('last_name', '').strip().lower()
            and groom_dob == bride_dob
        )
        if same_person:
            return fail('Groom and bride cannot be the same person')

        parents = form.get('parents') or {}
        for key, label in (
            ('groom_father', 'Groom\'s father'), ('groom_mother', "Groom's mother"),
            ('bride_father', "Bride's father"), ('bride_mother', "Bride's mother"),
        ):
            _ml_validate_parent(parents.get(key) or {}, label)

        consents = form.get('consents') or {}
        for role, age in (('groom', groom_age), ('bride', bride_age)):
            consent = consents.get(role)
            if age < 25:
                if not consent:
                    return fail(f'{role.capitalize()} requires parental consent/advice for their age')
                _ml_validate_consent(consent, f'{role.capitalize()} consent/advice')

        for role in ('groom', 'bride'):
            consent = consents.get(role)
            if not consent:
                continue
            consent_type = sanitize(consent.get('type'))
            if consent_type not in _ML_VALID_CONSENT_TYPES:
                return fail(f'{role.capitalize()} consent: invalid type')
            consent_relationship = sanitize(consent.get('relationship'))
            if consent_relationship not in _ML_VALID_CONSENT_RELATIONSHIPS:
                return fail(f'{role.capitalize()} consent: invalid relationship')

        civil_status_groom = sanitize(form.get('civil_status_groom'))
        civil_status_bride = sanitize(form.get('civil_status_bride'))
        if civil_status_groom not in _ML_VALID_CIVIL_STATUS:
            return fail('Groom: invalid civil status')
        if civil_status_bride not in _ML_VALID_CIVIL_STATUS:
            return fail('Bride: invalid civil status')
        if civil_status_groom == 'DIVORCED' and not bool(form.get('foreign_national_groom')):
            return fail('Groom: Divorced status requires foreign national status')
        if civil_status_bride == 'DIVORCED' and not bool(form.get('foreign_national_bride')):
            return fail('Bride: Divorced status requires foreign national status')
        if civil_status_groom != 'SINGLE' and not (groom.get('prev_marriage') or {}).get('former_spouse'):
            return fail('Groom: previous marriage details are required for a non-Single civil status')
        if civil_status_bride != 'SINGLE' and not (bride.get('prev_marriage') or {}).get('former_spouse'):
            return fail('Bride: previous marriage details are required for a non-Single civil status')

        md = form.get('marriage_details') or {}
        wedding_date = _parse_date(md.get('wedding_date'))
        if not wedding_date:
            return fail('Marriage details: invalid or missing wedding date')
        for f in ('venue_name', 'venue_region', 'venue_province', 'venue_city',
                  'venue_barangay', 'venue_street'):
            if not str(md.get(f) or '').strip():
                return fail(f'Marriage details: missing required field {f}')
        if sanitize(md.get('ceremony_type')) not in _ML_VALID_CEREMONY_TYPES:
            return fail('Marriage details: invalid ceremony type')

        decl = form.get('declarations') or {}
        if not (decl.get('truthfulness') and decl.get('data_privacy') and decl.get('personal_appearance')):
            return fail('All declarations must be acknowledged before submission')

        app_number = _ml_new_app_number()
        parties_related = bool(form.get('parties_related'))
        relationship_degree = sanitize(form.get('relationship_degree'))
        flagged = parties_related

        cur.execute("""
            INSERT INTO app_marriage_license_applications (
                user_id, application_number,
                civil_status_groom, civil_status_bride,
                foreign_national_groom, foreign_national_bride, article_34_cohabitation,
                parties_related, relationship_degree,
                ceremony_type, wedding_date, venue_name, venue_region, venue_province,
                venue_city, venue_barangay, venue_street,
                solemnizing_officer_name, solemnizing_officer_registry_no, expected_guests,
                declaration_truthfulness, declaration_data_privacy, declaration_personal_appearance,
                status, flagged_for_review, date_submitted
            ) VALUES (
                %s, %s,
                %s, %s,
                %s, %s, %s,
                %s, %s,
                %s, %s, %s, %s, %s,
                %s, %s, %s,
                %s, %s, %s,
                %s, %s, %s,
                'PENDING', %s, %s
            )
        """, (
            user_id, app_number,
            civil_status_groom, civil_status_bride,
            bool(form.get('foreign_national_groom')), bool(form.get('foreign_national_bride')),
            bool(form.get('article_34_cohabitation')),
            parties_related, relationship_degree,
            sanitize(md.get('ceremony_type')), wedding_date, sanitize(md.get('venue_name')),
            sanitize(md.get('venue_region')), sanitize(md.get('venue_province')),
            sanitize(md.get('venue_city')), sanitize(md.get('venue_barangay')),
            sanitize(md.get('venue_street')),
            sanitize(md.get('solemnizing_officer_name')), sanitize(md.get('solemnizing_officer_registry_no')),
            _parse_int(md.get('expected_guests')),
            bool(decl.get('truthfulness')), bool(decl.get('data_privacy')),
            bool(decl.get('personal_appearance')),
            flagged, ts,
        ))
        application_id = cur.lastrowid

        for role, party, age in (('GROOM', groom, groom_age), ('BRIDE', bride, bride_age)):
            pm = party.get('prev_marriage') or {}
            cur.execute("""
                INSERT INTO app_marriage_license_parties (
                    application_id, role, first_name, middle_name, last_name, suffix,
                    dob, computed_age, birth_country, birth_region, birth_province,
                    birth_city, birth_barangay, birth_foreign_city_state,
                    citizenship, religion, height_cm, distinguishing_marks,
                    residence_region, residence_province, residence_city, residence_barangay,
                    residence_street, residence_house_no, residence_zip, residence_foreign_address,
                    mobile_number, email, alt_contact_person, alt_contact_number,
                    prev_marriage_former_spouse, prev_marriage_date, prev_marriage_place,
                    prev_marriage_death_date, prev_marriage_death_place,
                    prev_marriage_court_name, prev_marriage_case_number,
                    prev_marriage_decree_final_date, prev_marriage_psa_annotation_date,
                    prev_marriage_divorce_country, prev_marriage_divorce_final_date,
                    prev_marriage_judicially_recognized, prev_marriage_ph_court_case_number
                ) VALUES (
                    %s, %s, %s, %s, %s, %s,
                    %s, %s, %s, %s, %s,
                    %s, %s, %s,
                    %s, %s, %s, %s,
                    %s, %s, %s, %s,
                    %s, %s, %s, %s,
                    %s, %s, %s, %s,
                    %s, %s, %s,
                    %s, %s,
                    %s, %s,
                    %s, %s,
                    %s, %s,
                    %s, %s
                )
            """, (
                application_id, role, sanitize(party.get('first_name')),
                sanitize(party.get('middle_name')), sanitize(party.get('last_name')),
                sanitize(party.get('suffix')),
                groom_dob if role == 'GROOM' else bride_dob, age,
                sanitize(party.get('birth_country')) or 'Philippines',
                sanitize(party.get('birth_region')), sanitize(party.get('birth_province')),
                sanitize(party.get('birth_city')), sanitize(party.get('birth_barangay')),
                sanitize(party.get('birth_foreign_city_state')),
                sanitize(party.get('citizenship')) or 'Filipino', sanitize(party.get('religion')),
                _parse_int(party.get('height_cm')), sanitize(party.get('distinguishing_marks')),
                sanitize(party.get('residence_region')), sanitize(party.get('residence_province')),
                sanitize(party.get('residence_city')), sanitize(party.get('residence_barangay')),
                sanitize(party.get('residence_street')), sanitize(party.get('residence_house_no')),
                sanitize(party.get('residence_zip')), sanitize(party.get('residence_foreign_address')),
                sanitize(party.get('mobile_number')), sanitize(party.get('email')),
                sanitize(party.get('alt_contact_person')), sanitize(party.get('alt_contact_number')),
                sanitize(pm.get('former_spouse')), _parse_date(pm.get('marriage_date')),
                sanitize(pm.get('marriage_place')),
                _parse_date(pm.get('death_date')), sanitize(pm.get('death_place')),
                sanitize(pm.get('court_name')), sanitize(pm.get('case_number')),
                _parse_date(pm.get('decree_final_date')), _parse_date(pm.get('psa_annotation_date')),
                sanitize(pm.get('divorce_country')), _parse_date(pm.get('divorce_final_date')),
                bool(pm.get('judicially_recognized')) if pm.get('judicially_recognized') is not None else None,
                sanitize(pm.get('ph_court_case_number')),
            ))

        for role, key in (
            ('GROOM_FATHER', 'groom_father'), ('GROOM_MOTHER', 'groom_mother'),
            ('BRIDE_FATHER', 'bride_father'), ('BRIDE_MOTHER', 'bride_mother'),
        ):
            p = parents.get(key) or {}
            cur.execute("""
                INSERT INTO app_marriage_license_parents (
                    application_id, role, first_name, middle_name, last_name, suffix,
                    citizenship, is_deceased,
                    residence_region, residence_province, residence_city, residence_barangay,
                    residence_street_house
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                application_id, role, sanitize(p.get('first_name')), sanitize(p.get('middle_name')),
                sanitize(p.get('last_name')), sanitize(p.get('suffix')),
                sanitize(p.get('citizenship')) or 'Filipino', bool(p.get('is_deceased')),
                sanitize(p.get('residence_region')), sanitize(p.get('residence_province')),
                sanitize(p.get('residence_city')), sanitize(p.get('residence_barangay')),
                sanitize(p.get('residence_street_house')),
            ))

        for role in ('groom', 'bride'):
            consent = consents.get(role)
            if not consent:
                continue
            cur.execute("""
                INSERT INTO app_marriage_license_consents (
                    application_id, role, type, first_name, middle_name, last_name,
                    relationship, citizenship,
                    residence_region, residence_province, residence_city, residence_barangay,
                    residence_street_house
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                application_id, role.upper(), sanitize(consent.get('type')),
                sanitize(consent.get('first_name')), sanitize(consent.get('middle_name')),
                sanitize(consent.get('last_name')), sanitize(consent.get('relationship')),
                sanitize(consent.get('citizenship')) or 'Filipino',
                sanitize(consent.get('residence_region')), sanitize(consent.get('residence_province')),
                sanitize(consent.get('residence_city')), sanitize(consent.get('residence_barangay')),
                sanitize(consent.get('residence_street_house')),
            ))

        new_doc_rows = _ml_upload_documents(files, user_id, app_number)
        existing = _parse_json_obj(data.get('existing_files'), [])
        existing_doc_rows = []
        if isinstance(existing, list):
            existing_doc_rows = [
                (e.get('document_type'), e.get('party_role', 'SHARED'), e.get('file_url'))
                for e in existing
                if isinstance(e, dict) and e.get('document_type') and e.get('file_url')
            ]
        # Dedup by (document_type, party_role): a freshly uploaded file replaces
        # any existing entry for the same slot carried over from the draft, so
        # insert existing rows first and let the new uploads overwrite them.
        doc_map = {}
        for doc_type, role, url in existing_doc_rows:
            doc_map[(doc_type, role)] = (doc_type, role, url)
        for doc_type, role, url in new_doc_rows:
            doc_map[(doc_type, role)] = (doc_type, role, url)
        doc_rows = list(doc_map.values())
        for doc_type, role, url in doc_rows:
            cur.execute("""
                INSERT INTO app_marriage_license_documents (
                    application_id, party_role, document_type, file_url, uploaded_at
                ) VALUES (%s, %s, %s, %s, %s)
            """, (application_id, role, doc_type, url, ts))

        groom_sig = next((u for t, r, u in doc_rows if t == 'groom_signature'), None)
        bride_sig = next((u for t, r, u in doc_rows if t == 'bride_signature'), None)
        if groom_sig or bride_sig:
            cur.execute("""
                UPDATE app_marriage_license_applications
                   SET groom_signature_url=COALESCE(%s, groom_signature_url),
                       bride_signature_url=COALESCE(%s, bride_signature_url)
                 WHERE id=%s
            """, (groom_sig, bride_sig, application_id))

        draft_id = (data.get('draft_id') or '').strip()
        if draft_id:
            cur.execute(
                "DELETE FROM app_marriage_license_drafts WHERE id=%s AND user_id=%s",
                (draft_id, user_id),
            )

        return ok({
            'status': True,
            'message': 'Marriage license application submitted',
            'application_number': app_number,
            'flagged_for_review': flagged,
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'submit_marriage_license_application error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def save_marriage_license_draft(cur, data, files, ts):
    try:
        require(data, 'user_profile_id')
        user_id = data['user_profile_id']
        draft_id = (data.get('draft_id') or '').strip()
        current_step = _parse_int(data.get('current_step')) or 0
        couple_names = sanitize(data.get('couple_names'))
        form_data = data.get('form_data') or '{}'

        kept = _parse_json_obj(data.get('kept_files'), [])
        if not isinstance(kept, list):
            kept = []
        new_rows = _ml_upload_documents(files, user_id, f'draft-{draft_id or "new"}')
        for doc_type, role, url in new_rows:
            kept.append({'document_type': doc_type, 'party_role': role, 'file_url': url})
        files_json = json.dumps(kept)

        if draft_id:
            cur.execute(
                "SELECT id FROM app_marriage_license_drafts WHERE id=%s AND user_id=%s LIMIT 1",
                (draft_id, user_id),
            )
            if not cur.fetchone():
                return fail('Draft not found', 404)
            cur.execute("""
                UPDATE app_marriage_license_drafts
                   SET couple_names=%s, current_step=%s, form_data=%s,
                       files=%s, updated_at=%s
                 WHERE id=%s AND user_id=%s
            """, (couple_names, current_step, form_data, files_json, ts,
                  draft_id, user_id))
        else:
            cur.execute("""
                INSERT INTO app_marriage_license_drafts (
                    user_id, couple_names, current_step, form_data, files,
                    status, created_at, updated_at
                ) VALUES (%s, %s, %s, %s, %s, 'draft', %s, %s)
            """, (user_id, couple_names, current_step, form_data, files_json, ts, ts))
            draft_id = cur.lastrowid

        return ok({
            'status': True,
            'message': 'Draft saved',
            'data': {'draft_id': str(draft_id), 'files': kept},
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'save_marriage_license_draft error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def list_marriage_license_drafts(cur, data, files, ts):
    try:
        require(data, 'user_profile_id')
        cur.execute("""
            SELECT id, couple_names, current_step, created_at, updated_at
            FROM app_marriage_license_drafts
            WHERE user_id=%s AND status='draft'
            ORDER BY updated_at DESC
        """, (data['user_profile_id'],))
        rows = cur.fetchall()
        return ok({
            'status': True,
            'data': {'items': [serialize_row(r) for r in rows], 'count': len(rows)},
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'list_marriage_license_drafts error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def get_marriage_license_draft(cur, data, files, ts):
    try:
        require(data, 'user_profile_id', 'draft_id')
        cur.execute("""
            SELECT id, couple_names, current_step, form_data, files, created_at, updated_at
            FROM app_marriage_license_drafts
            WHERE id=%s AND user_id=%s
            LIMIT 1
        """, (data['draft_id'], data['user_profile_id']))
        row = cur.fetchone()
        if not row:
            return fail('Draft not found', 404)
        return ok({
            'status': True,
            'data': {
                'id': str(row['id']),
                'couple_names': row.get('couple_names') or '',
                'current_step': row.get('current_step') or 0,
                'form_data': _parse_json_obj(row.get('form_data'), {}),
                'files': _parse_json_obj(row.get('files'), []),
            },
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'get_marriage_license_draft error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def delete_marriage_license_draft(cur, data, files, ts):
    try:
        require(data, 'user_profile_id', 'draft_id')
        cur.execute(
            "DELETE FROM app_marriage_license_drafts WHERE id=%s AND user_id=%s",
            (data['draft_id'], data['user_profile_id']),
        )
        return ok({'status': True, 'message': 'Draft deleted'})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'delete_marriage_license_draft error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def get_marriage_license_applications(cur, data, files, ts):
    try:
        require(data, 'user_profile_id')
        cur.execute("""
            SELECT a.id, a.application_number, a.status, a.wedding_date,
                   a.date_submitted, a.date_reviewed, a.date_approved,
                   MAX(CASE WHEN p.role='GROOM' THEN CONCAT(p.first_name, ' ', p.last_name) END) AS groom_name,
                   MAX(CASE WHEN p.role='BRIDE' THEN CONCAT(p.first_name, ' ', p.last_name) END) AS bride_name
            FROM app_marriage_license_applications a
            JOIN app_marriage_license_parties p ON p.application_id = a.id
            WHERE a.user_id=%s
            GROUP BY a.id
            ORDER BY a.date_submitted DESC
        """, (data['user_profile_id'],))
        rows = cur.fetchall()
        return ok({'status': True, 'applications': [serialize_row(r) for r in rows]})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'get_marriage_license_applications error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def get_marriage_license_application_detail(cur, data, files, ts):
    try:
        require(data, 'user_profile_id', 'application_number')
        cur.execute("""
            SELECT * FROM app_marriage_license_applications
            WHERE user_id=%s AND application_number=%s
            LIMIT 1
        """, (data['user_profile_id'], data['application_number']))
        app_row = cur.fetchone()
        if not app_row:
            return fail('Application not found', 404)
        application_id = app_row['id']

        cur.execute(
            "SELECT * FROM app_marriage_license_parties WHERE application_id=%s",
            (application_id,))
        parties = [serialize_row(r) for r in cur.fetchall()]

        cur.execute(
            "SELECT * FROM app_marriage_license_parents WHERE application_id=%s",
            (application_id,))
        parents = [serialize_row(r) for r in cur.fetchall()]

        cur.execute(
            "SELECT * FROM app_marriage_license_consents WHERE application_id=%s",
            (application_id,))
        consents = [serialize_row(r) for r in cur.fetchall()]

        cur.execute(
            "SELECT * FROM app_marriage_license_documents WHERE application_id=%s",
            (application_id,))
        documents = [serialize_row(r) for r in cur.fetchall()]

        return ok({
            'status': True,
            'data': {
                'application': serialize_row(app_row),
                'parties': parties,
                'parents': parents,
                'consents': consents,
                'documents': documents,
            },
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'get_marriage_license_application_detail error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)
