import logging
import json
import uuid
from datetime import datetime

from helpers.auth import ok, fail, require
from helpers.db import sanitize, serialize_row
from helpers.s3 import upload_to_s3, generate_key
from helpers.audit import record_audit_log

logger = logging.getLogger()

# Files the Flutter app uploads as multipart parts, mapped to DB columns.
# Multiple files per key are stored as comma-separated S3 URLs.
_FILE_FIELDS = {
    'doc_dti_sec':     'dti_sec',
    'doc_barangay':    'barangay_clearance',
    'doc_lease':       'lease_contract',
    'doc_fire_permit': 'fire_permit',
    'doc_sanitary':    'sanitary_permit',
    'doc_other':       'other',
}

def _new_app_number():
    return 'BP' + datetime.now().strftime('%Y%m%d') + uuid.uuid4().hex[:6].upper()

def _merge_existing_files(file_urls, existing_raw):
    """
    Merge already-uploaded document URLs (from a resumed draft) into `file_urls`
    in place. `existing_raw` is a JSON string {multipart_category: [url, ...]}.
    Categories map to DB columns via _FILE_FIELDS; unknown categories are ignored.
    """
    if not existing_raw:
        return
    try:
        existing = json.loads(existing_raw) if isinstance(existing_raw, str) else existing_raw
    except Exception:
        return
    if not isinstance(existing, dict):
        return
    cat_to_col = {v: k for k, v in _FILE_FIELDS.items()}
    for cat, urls in existing.items():
        col = cat_to_col.get(cat)
        if not col or not isinstance(urls, list):
            continue
        keep = [u for u in urls if u]
        if not keep:
            continue
        current = file_urls.get(col) or ''
        merged = keep + ([current] if current else [])
        file_urls[col] = ','.join(merged)


def _upload_files(files, user_id, app_number):
    """
    Group uploaded multipart files by field name and upload each to S3.
    Returns a dict mapping DB column names to comma-separated URL strings.
    """
    urls = {col: '' for col in _FILE_FIELDS}
    by_field = {}
    for f in files:
        fn = f.get('field_name', '')
        by_field.setdefault(fn, []).append(f)

    for db_col, multipart_field in _FILE_FIELDS.items():
        uploaded = []
        for f in by_field.get(multipart_field, []):
            f['content'].seek(0)
            content = f['content'].read()
            key = generate_key(
                f'business_permits/{user_id}/{app_number}',
                user_id,
                f.get('filename') or multipart_field,
            )
            url = upload_to_s3(content, key)
            uploaded.append(url)
        urls[db_col] = ','.join(uploaded)
    return urls

def submit_business_permit(cur, data, files, ts):
    try:
        require(data, 'user_profile_id')
        user_id = data['user_profile_id']

        # form_data carries the structured JSON payload
        raw = data.get('form_data') or '{}'
        try:
            form = json.loads(raw) if isinstance(raw, str) else dict(raw)
        except Exception:
            return fail('Invalid form_data JSON')

        # Validate required fields
        for field in ('business_name', 'owner_fname', 'owner_lname',
                      'owner_mobile', 'address_line', 'barangay',
                      'municipality', 'province'):
            if not (form.get(field) or '').strip():
                return fail(f'Missing required field: {field}')

        app_number = _new_app_number()
        file_urls = _upload_files(files, user_id, app_number)
        # Merge documents that were already uploaded while the application was a
        # draft (existing_files: {category:[url,...]}). Keeps them on the final
        # permit instead of silently dropping them on submit.
        _merge_existing_files(file_urls, data.get('existing_files'))

        cur.execute("""
            INSERT INTO app_business_permits (
                user_id, application_number, application_type,
                business_name, trade_name, business_type, tin_number,
                registration_number, capitalization,
                owner_fname, owner_mname, owner_lname, owner_suffix,
                owner_mobile, owner_email,
                address_line, barangay, municipality, province, zip_code,
                line_of_business, num_employees, operating_hours,
                has_signage, has_parking,
                doc_dti_sec, doc_barangay, doc_lease, doc_fire_permit,
                doc_sanitary, doc_other,
                status, date_submitted
            ) VALUES (
                %s, %s, %s,
                %s, %s, %s, %s,
                %s, %s,
                %s, %s, %s, %s,
                %s, %s,
                %s, %s, %s, %s, %s,
                %s, %s, %s,
                %s, %s,
                %s, %s, %s, %s,
                %s, %s,
                'PENDING', %s
            )
        """, (
            user_id, app_number,
            sanitize(form.get('application_type') or 'NEW'),
            sanitize(form.get('business_name')),
            sanitize(form.get('trade_name')),
            sanitize(form.get('business_type')),
            sanitize(form.get('tin_number')),
            sanitize(form.get('registration_number')),
            _parse_decimal(form.get('capitalization')),
            sanitize(form.get('owner_fname')),
            sanitize(form.get('owner_mname')),
            sanitize(form.get('owner_lname')),
            sanitize(form.get('owner_suffix')),
            sanitize(form.get('owner_mobile')),
            sanitize(form.get('owner_email')),
            sanitize(form.get('address_line')),
            sanitize(form.get('barangay')),
            sanitize(form.get('municipality')),
            sanitize(form.get('province')),
            sanitize(form.get('zip_code')),
            sanitize(form.get('line_of_business')),
            _parse_int(form.get('num_employees')),
            sanitize(form.get('operating_hours')),
            1 if form.get('has_signage') else 0,
            1 if form.get('has_parking') else 0,
            file_urls['doc_dti_sec'],
            file_urls['doc_barangay'],
            file_urls['doc_lease'],
            file_urls['doc_fire_permit'],
            file_urls['doc_sanitary'],
            file_urls['doc_other'],
            ts,
        ))

        return ok({
            'status': True,
            'message': 'Business permit application submitted',
            'application_number': app_number,
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'submit_business_permit error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)

def get_business_permits(cur, data, files, ts):
    try:
        require(data, 'user_profile_id')
        cur.execute("""
            SELECT id, application_number, application_type, business_name,
                   trade_name, business_type, owner_fname, owner_lname,
                   address_line, barangay, municipality, province,
                   status, permit_number, remarks, date_submitted,
                   date_reviewed, date_approved
            FROM app_business_permits
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
        logger.error(f'get_business_permits error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)

def get_business_permit_detail(cur, data, files, ts):
    try:
        require(data, 'user_profile_id', 'application_number')
        cur.execute("""
            SELECT * FROM app_business_permits
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
        logger.error(f'get_business_permit_detail error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)

def _parse_int(v):
    if v in (None, ''): return None
    try: return int(v)
    except Exception: return None

def _parse_decimal(v):
    if v in (None, ''): return None
    try: return float(v)
    except Exception: return None


def _insert_permit_row(cur, user_id, app_number, application_type, form, file_urls, ts):
    """
    Shared INSERT used by all three submit variants. Variant-specific columns
    (previous_permit_number, renewal_reason, closure_date, closure_reason,
    final_remarks) come from `form` — the caller is responsible for setting
    / leaving them blank as appropriate.
    """
    cur.execute("""
        INSERT INTO app_business_permits (
            user_id, application_number, application_type,
            previous_permit_number, renewal_reason,
            closure_date, closure_reason, final_remarks,
            business_name, trade_name, business_type, tin_number,
            registration_number, capitalization,
            owner_fname, owner_mname, owner_lname, owner_suffix,
            owner_mobile, owner_email,
            address_line, barangay, municipality, province, zip_code,
            line_of_business, num_employees, operating_hours,
            has_signage, has_parking,
            doc_dti_sec, doc_barangay, doc_lease, doc_fire_permit,
            doc_sanitary, doc_other,
            status, date_submitted
        ) VALUES (
            %s, %s, %s,
            %s, %s,
            %s, %s, %s,
            %s, %s, %s, %s,
            %s, %s,
            %s, %s, %s, %s,
            %s, %s,
            %s, %s, %s, %s, %s,
            %s, %s, %s,
            %s, %s,
            %s, %s, %s, %s,
            %s, %s,
            'PENDING', %s
        )
    """, (
        user_id, app_number, application_type,
        sanitize(form.get('previous_permit_number')),
        sanitize(form.get('renewal_reason')),
        form.get('closure_date') or None,
        sanitize(form.get('closure_reason')),
        sanitize(form.get('final_remarks')),
        sanitize(form.get('business_name')),
        sanitize(form.get('trade_name')),
        sanitize(form.get('business_type')),
        sanitize(form.get('tin_number')),
        sanitize(form.get('registration_number')),
        _parse_decimal(form.get('capitalization')),
        sanitize(form.get('owner_fname')),
        sanitize(form.get('owner_mname')),
        sanitize(form.get('owner_lname')),
        sanitize(form.get('owner_suffix')),
        sanitize(form.get('owner_mobile')),
        sanitize(form.get('owner_email')),
        sanitize(form.get('address_line')),
        sanitize(form.get('barangay')),
        sanitize(form.get('municipality')),
        sanitize(form.get('province')),
        sanitize(form.get('zip_code')),
        sanitize(form.get('line_of_business')),
        _parse_int(form.get('num_employees')),
        sanitize(form.get('operating_hours')),
        1 if form.get('has_signage') else 0,
        1 if form.get('has_parking') else 0,
        file_urls['doc_dti_sec'],
        file_urls['doc_barangay'],
        file_urls['doc_lease'],
        file_urls['doc_fire_permit'],
        file_urls['doc_sanitary'],
        file_urls['doc_other'],
        ts,
    ))


def submit_business_permit_renewal(cur, data, files, ts):
    """
    Renewal application. Requires the previous permit number plus a
    renewal reason, then the standard business-info payload so the LGU
    reviewer sees what (if anything) has changed since the last permit.
    """
    try:
        require(data, 'user_profile_id')
        user_id = data['user_profile_id']

        raw = data.get('form_data') or '{}'
        try:
            form = json.loads(raw) if isinstance(raw, str) else dict(raw)
        except Exception:
            return fail('Invalid form_data JSON')

        # Renewal-specific requirements
        for field in ('previous_permit_number', 'renewal_reason'):
            if not (form.get(field) or '').strip():
                return fail(f'Missing required field: {field}')
        # Plus the usual business-info minimums
        for field in ('business_name', 'owner_fname', 'owner_lname',
                      'owner_mobile', 'address_line', 'barangay',
                      'municipality', 'province'):
            if not (form.get(field) or '').strip():
                return fail(f'Missing required field: {field}')

        app_number = _new_app_number()
        file_urls = _upload_files(files, user_id, app_number)
        _insert_permit_row(cur, user_id, app_number, 'RENEWAL', form, file_urls, ts)

        return ok({
            'status': True,
            'message': 'Business permit renewal submitted',
            'application_number': app_number,
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'submit_business_permit_renewal error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def submit_business_permit_closure(cur, data, files, ts):
    """
    Business closure / retirement. Minimal payload: the permit being closed,
    closure date, reason, and optional final remarks. We still route through
    the shared insert for consistency.
    """
    try:
        require(data, 'user_profile_id')
        user_id = data['user_profile_id']

        raw = data.get('form_data') or '{}'
        try:
            form = json.loads(raw) if isinstance(raw, str) else dict(raw)
        except Exception:
            return fail('Invalid form_data JSON')

        for field in ('previous_permit_number', 'closure_date',
                      'closure_reason'):
            if not (form.get(field) or '').strip():
                return fail(f'Missing required field: {field}')

        app_number = _new_app_number()
        file_urls = _upload_files(files, user_id, app_number)
        _insert_permit_row(cur, user_id, app_number, 'CLOSURE', form, file_urls, ts)

        return ok({
            'status': True,
            'message': 'Business closure request submitted',
            'application_number': app_number,
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'submit_business_permit_closure error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


# ─── ez_permit Phase 1: drafts & Link Business ────────────────────────────────

def _parse_json_obj(raw, default):
    """Best-effort JSON decode; returns `default` on empty/garbage."""
    if not raw:
        return default
    if not isinstance(raw, str):
        return raw
    try:
        return json.loads(raw)
    except Exception:
        return default


def _upload_named_files(files, prefix, user_id):
    """
    Upload each multipart file part, grouped by its `field_name` (document
    category). Returns {category: [s3_url, ...]}. Empty when no files.
    """
    grouped = {}
    for f in files or []:
        cat = f.get('field_name') or 'other'
        f['content'].seek(0)
        content = f['content'].read()
        key = generate_key(prefix, user_id, f.get('filename') or cat)
        url = upload_to_s3(content, key)
        grouped.setdefault(cat, []).append(url)
    return grouped


def save_business_permit_draft(cur, data, files, ts):
    """
    Upsert an in-progress NEW application. INSERT when no draft_id, else UPDATE
    the caller's own row. Newly attached documents are uploaded to S3 and merged
    into the `kept_files` the client sends back, so a resume restores everything.
    """
    try:
        require(data, 'user_profile_id')
        user_id = data['user_profile_id']
        draft_id = (data.get('draft_id') or '').strip()
        current_step = _parse_int(data.get('current_step')) or 0
        business_name = sanitize(data.get('business_name'))
        form_data = data.get('form_data') or '{}'
        # Merge already-uploaded doc URLs (kept_files) with any new uploads.
        kept = _parse_json_obj(data.get('kept_files'), {})
        if not isinstance(kept, dict):
            kept = {}
        new_urls = _upload_named_files(files, f'business_permit_drafts/{user_id}', user_id)
        for cat, urls in new_urls.items():
            kept.setdefault(cat, []).extend(urls)
        files_json = json.dumps(kept)

        if draft_id:
            cur.execute(
                "SELECT id FROM app_business_permit_drafts WHERE id=%s AND user_id=%s LIMIT 1",
                (draft_id, user_id),
            )
            if not cur.fetchone():
                return fail('Draft not found', 404)
            cur.execute("""
                UPDATE app_business_permit_drafts
                   SET business_name=%s, current_step=%s, form_data=%s,
                       files=%s, updated_at=%s
                 WHERE id=%s AND user_id=%s
            """, (business_name, current_step, form_data, files_json, ts,
                  draft_id, user_id))
        else:
            cur.execute("""
                INSERT INTO app_business_permit_drafts (
                    user_id, business_name, current_step, form_data, files,
                    status, created_at, updated_at
                ) VALUES (%s, %s, %s, %s, %s, 'draft', %s, %s)
            """, (user_id, business_name, current_step, form_data, files_json,
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
        logger.error(f'save_business_permit_draft error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def list_business_permit_drafts(cur, data, files, ts):
    try:
        require(data, 'user_profile_id')
        cur.execute("""
            SELECT id, business_name, current_step, created_at, updated_at
            FROM app_business_permit_drafts
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
        logger.error(f'list_business_permit_drafts error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def get_business_permit_draft(cur, data, files, ts):
    try:
        require(data, 'user_profile_id', 'draft_id')
        cur.execute("""
            SELECT id, business_name, current_step, form_data, files,
                   created_at, updated_at
            FROM app_business_permit_drafts
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
                'business_name': row.get('business_name') or '',
                'current_step': row.get('current_step') or 0,
                'form_data': _parse_json_obj(row.get('form_data'), {}),
                'files': _parse_json_obj(row.get('files'), {}),
            },
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'get_business_permit_draft error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def delete_business_permit_draft(cur, data, files, ts):
    try:
        require(data, 'user_profile_id', 'draft_id')
        cur.execute(
            "DELETE FROM app_business_permit_drafts WHERE id=%s AND user_id=%s",
            (data['draft_id'], data['user_profile_id']),
        )
        return ok({'status': True, 'message': 'Draft deleted'})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'delete_business_permit_draft error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def admin_assess_permit(cur, data, files, ts):
    """Admin sets a payable fee on a permit and moves it to FOR_PAYMENT."""
    try:
        require(data, 'application_number', 'amount')
        amount = _parse_decimal(data.get('amount'))
        if amount is None or round(amount * 100) < 2000:
            return fail('Amount must be at least PHP 20')
        cur.execute("""
            UPDATE app_business_permits
               SET status='FOR_PAYMENT', assessed_amount=%s, date_reviewed=%s
             WHERE application_number=%s
        """, (amount, ts, data['application_number']))

        admin = data.get('_admin') or {}
        record_audit_log(cur, admin.get('id'), admin.get('role'), 'admin_assess_permit',
                          'permit', data['application_number'], {'amount': str(amount)}, ts)

        return ok({'status': True, 'message': 'Permit assessed for payment'})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'admin_assess_permit error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def confirm_business_permit_payment(cur, data, files, ts):
    """
    Reconcile a citizen's PayMongo payment against a FOR_PAYMENT permit and
    advance it to FOR_RELEASING. Server-authoritative: trusts the paid
    app_paymongo_sessions row keyed by reference_number (= application_number),
    not the client.
    """
    try:
        require(data, 'user_profile_id', 'application_number')
        user_id = data['user_profile_id']
        app_number = data['application_number']

        cur.execute("""
            SELECT assessed_amount, status FROM app_business_permits
             WHERE user_id=%s AND application_number=%s LIMIT 1
        """, (user_id, app_number))
        permit = cur.fetchone()
        if not permit:
            return fail('Permit not found', 404)
        if (permit.get('status') or '').upper() != 'FOR_PAYMENT':
            return fail('Permit is not awaiting payment')
        expected_centavos = int(round(float(permit.get('assessed_amount') or 0) * 100))

        cur.execute("""
            SELECT amount_centavos FROM app_paymongo_sessions
             WHERE reference_number=%s AND status='paid'
             ORDER BY updated_at DESC LIMIT 1
        """, (app_number,))
        sess = cur.fetchone()
        if not sess:
            return fail('No completed payment found for this permit')
        paid_centavos = int(sess.get('amount_centavos') or 0)
        if paid_centavos < expected_centavos:
            return fail('Payment amount is insufficient')

        cur.execute("""
            UPDATE app_business_permits
               SET payment_status='PAID', date_paid=%s, status='FOR_RELEASING'
             WHERE application_number=%s
        """, (ts, app_number))
        return ok({'status': True, 'message': 'Payment confirmed'})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'confirm_business_permit_payment error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def submit_business_link(cur, data, files, ts):
    """
    Record a citizen's request to claim an existing business by permit number,
    with a live photo of the permit. Stored PENDING; admin approval is a later
    phase.
    """
    try:
        require(data, 'user_profile_id', 'business_permit_no')
        user_id = data['user_profile_id']
        permit_no = (data['business_permit_no'] or '').strip()
        if not permit_no:
            return fail('Missing required field: business_permit_no')

        photo_url = None
        uploaded = _upload_named_files(files, f'business_links/{user_id}', user_id)
        for urls in uploaded.values():
            if urls:
                photo_url = urls[0]
                break

        cur.execute("""
            INSERT INTO app_business_link_requests (
                user_id, business_permit_no, photo_url, status,
                datetime_created
            ) VALUES (%s, %s, %s, 'PENDING', %s)
        """, (user_id, permit_no, photo_url, ts))

        return ok({
            'status': True,
            'message': 'Business link request submitted',
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'submit_business_link error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)
