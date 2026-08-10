import logging
import json
import uuid
import random

from helpers.auth import ok, fail, require
from helpers.db import sanitize, serialize_row, now_ph
from helpers.s3 import upload_to_s3, generate_key

logger = logging.getLogger()

_MAX_PHOTOS = 5

# Status transition machine (admin/web via respond_citizen_report).
# Terminal states (CLOSED, CANCELLED) have no outgoing transitions.
_TRANSITIONS = {
    'PENDING':     {'IN_PROGRESS', 'RESOLVED', 'CLOSED'},
    'IN_PROGRESS': {'RESOLVED', 'CLOSED'},
    'RESOLVED':    {'CLOSED'},
    'CLOSED':      set(),
    'CANCELLED':   set(),
}


def _ref_number(cur):
    """Generate a unique CR-YYYY-NNNNNN reference number.

    generate_number_id() in helpers.db is hardcoded to the `application_number`
    column, so we roll our own uniqueness loop against reference_number here.
    """
    year = now_ph().strftime('%Y')
    for _ in range(25):
        num = ''.join(str(random.randint(0, 9)) for _ in range(6))
        ref = f'CR-{year}-{num}'
        cur.execute(
            "SELECT COUNT(*) AS c FROM app_citizen_reports WHERE reference_number=%s",
            (ref,))
        if (cur.fetchone() or {}).get('c', 0) == 0:
            return ref
    # Extremely unlikely fallback — keep the CR-YYYY- prefix but widen entropy.
    return f'CR-{year}-{uuid.uuid4().hex[:6].upper()}'


def _upload_media(files, user_id, ref):
    """Upload photos (field_name starting 'photo', max 5) + optional single
    video (field_name == 'video') under citizen_reports/{user}/{Y}/{M}/{ref}.
    Returns a single combined list of S3 URLs (photos first, then video)."""
    urls = []
    now = now_ph()
    prefix = f'citizen_reports/{user_id}/{now:%Y}/{now:%m}/{ref}'

    photo_count = 0
    video_done = False
    for f in files or []:
        field = (f.get('field_name') or '').strip()
        if not field:
            continue

        if field.startswith('photo'):
            if photo_count >= _MAX_PHOTOS:
                continue
            f['content'].seek(0)
            content = f['content'].read()
            key = generate_key(prefix, user_id,
                               f.get('filename') or f'photo_{photo_count}.jpg')
            url = upload_to_s3(content, key)
            if url:
                urls.append(url)
                photo_count += 1

        elif field == 'video' and not video_done:
            f['content'].seek(0)
            content = f['content'].read()
            key = generate_key(prefix, user_id, f.get('filename') or 'video.mp4')
            url = upload_to_s3(content, key, content_type='video/mp4')
            if url:
                urls.append(url)
                video_done = True

    return urls


def _insert_message(cur, report_id, sender_type, sender_id, body, ts,
                    attachments=None):
    cur.execute("""
        INSERT INTO app_citizen_report_messages (
            report_id, sender_type, sender_id, body, attachments, datetime_created
        ) VALUES (%s, %s, %s, %s, %s, %s)
    """, (report_id, sender_type, sender_id, body,
          json.dumps(attachments) if attachments else None, ts))


def _decode_file_urls(row):
    row = dict(row) if not isinstance(row, dict) else row
    raw = row.get('file_urls')
    if isinstance(raw, str) and raw:
        try:
            row['file_urls'] = json.loads(raw)
        except Exception:
            row['file_urls'] = []
    elif raw is None:
        row['file_urls'] = []
    return row


def submit_citizen_report(cur, data, files, ts):
    try:
        require(data, 'user_profile_id', 'category', 'subcategory', 'description')
        user_id = data['user_profile_id']

        category = (data.get('category') or '').strip()
        subcategory = (data.get('subcategory') or '').strip()
        description = (data.get('description') or '').strip()

        # Location (optional)
        lat = None
        lng = None
        if data.get('latitude') not in (None, ''):
            try:
                lat = float(data['latitude'])
            except (TypeError, ValueError):
                lat = None
        if data.get('longitude') not in (None, ''):
            try:
                lng = float(data['longitude'])
            except (TypeError, ValueError):
                lng = None

        address_text = sanitize(data.get('address_text') or '')
        if address_text:
            address_text = address_text[:255]

        department = sanitize(data.get('department') or '')
        ai_priority_reason = sanitize(data.get('ai_priority_reason') or '')
        if ai_priority_reason:
            ai_priority_reason = ai_priority_reason[:255]
        suggested_dept = sanitize(data.get('suggested_dept') or '')
        if suggested_dept:
            suggested_dept = suggested_dept[:80]

        priority = (data.get('priority') or 'MEDIUM').strip().upper() or 'MEDIUM'
        handle_mode = (data.get('handle_mode') or 'HUMAN').strip().upper() or 'HUMAN'

        try:
            spam_flag = int(data.get('spam_flag') or 0)
        except (TypeError, ValueError):
            spam_flag = 0
        try:
            quality_score = float(data.get('quality_score') or 0)
        except (TypeError, ValueError):
            quality_score = 0

        ref = _ref_number(cur)

        urls = _upload_media(files, user_id, ref)

        # `id` is a numeric BIGINT AUTO_INCREMENT — let the DB assign it and read
        # it back via lastrowid (no client-generated UUID).
        cur.execute("""
            INSERT INTO app_citizen_reports (
                reference_number, user_id, category, subcategory, description,
                latitude, longitude, address_text, file_urls,
                priority, ai_priority_reason, handle_mode, suggested_dept,
                spam_flag, quality_score, department, status,
                datetime_created, datetime_updated
            ) VALUES (
                %s, %s, %s, %s, %s,
                %s, %s, %s, %s,
                %s, %s, %s, %s,
                %s, %s, %s, 'PENDING',
                %s, %s
            )
        """, (
            ref, user_id, category, subcategory, description,
            lat, lng, address_text or None, json.dumps(urls),
            priority, ai_priority_reason or None, handle_mode, suggested_dept or None,
            spam_flag, quality_score, department or None,
            ts, ts,
        ))

        cur.connection.commit()
        report_id = cur.lastrowid  # numeric auto-increment id

        return ok({
            'id': report_id,
            'reference_number': ref,
            'status': 'PENDING',
        }, 201)

    except Exception as e:
        logger.exception('submit_citizen_report failed')
        return fail(f'Submit failed: {e}', 500)


def list_citizen_reports(cur, data, files, ts):
    try:
        require(data, 'user_profile_id')
        user_id = data['user_profile_id']

        status = (data.get('status') or '').strip().upper() or None
        try:
            limit = max(1, min(500, int(data.get('limit') or 100)))
        except (TypeError, ValueError):
            limit = 100

        if status:
            cur.execute("""
                SELECT * FROM app_citizen_reports
                WHERE user_id=%s AND status=%s
                ORDER BY datetime_created DESC
                LIMIT %s
            """, (user_id, status, limit))
        else:
            cur.execute("""
                SELECT * FROM app_citizen_reports
                WHERE user_id=%s
                ORDER BY datetime_created DESC
                LIMIT %s
            """, (user_id, limit))

        rows = cur.fetchall() or []
        out = [serialize_row(_decode_file_urls(r)) for r in rows]
        return ok({'items': out, 'count': len(out)})

    except Exception as e:
        logger.exception('list_citizen_reports failed')
        return fail(f'List failed: {e}', 500)


def get_citizen_report(cur, data, files, ts):
    try:
        require(data, 'user_profile_id', 'report_id')
        user_id = data['user_profile_id']
        report_id = data['report_id']

        cur.execute("""
            SELECT * FROM app_citizen_reports
            WHERE id=%s AND user_id=%s
            LIMIT 1
        """, (report_id, user_id))
        report = cur.fetchone()
        if not report:
            return fail('Report not found', 404)

        cur.execute("""
            SELECT * FROM app_citizen_report_messages
            WHERE report_id=%s
            ORDER BY datetime_created ASC
        """, (report_id,))
        messages = cur.fetchall() or []

        return ok({
            'report': serialize_row(_decode_file_urls(report)),
            'messages': [serialize_row(m) for m in messages],
        })

    except Exception as e:
        logger.exception('get_citizen_report failed')
        return fail(f'Get failed: {e}', 500)


def cancel_citizen_report(cur, data, files, ts):
    try:
        require(data, 'user_profile_id', 'report_id')
        user_id = data['user_profile_id']
        report_id = data['report_id']

        cur.execute("""
            SELECT status FROM app_citizen_reports
            WHERE id=%s AND user_id=%s
            LIMIT 1
        """, (report_id, user_id))
        row = cur.fetchone()
        if not row:
            return fail('Report not found', 404)

        current = (row.get('status') or '').upper()
        if current not in ('PENDING', 'IN_PROGRESS'):
            return fail(f'Report cannot be cancelled from status {current}')

        remarks = sanitize(data.get('cancellation_remarks') or '')

        cur.execute("""
            UPDATE app_citizen_reports
            SET status='CANCELLED', datetime_updated=%s
            WHERE id=%s AND user_id=%s
        """, (ts, report_id, user_id))

        # The schema has no dedicated remarks column, so the citizen's
        # cancellation remarks live in the SYSTEM message body.
        note = 'Report cancelled by citizen.'
        if remarks:
            note += f' Remarks: {remarks}'
        _insert_message(cur, report_id, 'SYSTEM', user_id, note, ts)

        cur.connection.commit()

        return ok({'id': report_id, 'status': 'CANCELLED'})

    except Exception as e:
        logger.exception('cancel_citizen_report failed')
        return fail(f'Cancel failed: {e}', 500)


def post_citizen_message(cur, data, files, ts):
    try:
        require(data, 'user_profile_id', 'report_id', 'body')
        user_id = data['user_profile_id']
        report_id = data['report_id']
        body = (data.get('body') or '').strip()

        cur.execute("""
            SELECT id FROM app_citizen_reports
            WHERE id=%s AND user_id=%s
            LIMIT 1
        """, (report_id, user_id))
        if not cur.fetchone():
            return fail('Report not found', 404)

        _insert_message(cur, report_id, 'CITIZEN', user_id, body, ts)
        cur.connection.commit()

        return ok({'report_id': report_id, 'sender_type': 'CITIZEN'})

    except Exception as e:
        logger.exception('post_citizen_message failed')
        return fail(f'Post message failed: {e}', 500)


def respond_citizen_report(cur, data, files, ts):
    """Admin/web: change status, record responder, append staff/system messages."""
    try:
        require(data, 'report_id', 'admin_id', 'status')
        report_id = data['report_id']
        admin_id = data['admin_id']
        new_status = (data.get('status') or '').strip().upper()

        cur.execute("""
            SELECT status FROM app_citizen_reports WHERE id=%s LIMIT 1
        """, (report_id,))
        row = cur.fetchone()
        if not row:
            return fail('Report not found', 404)

        current = (row.get('status') or '').upper()
        if current not in _TRANSITIONS:
            return fail(f'Unknown current status {current}')
        allowed = _TRANSITIONS.get(current, set())
        if new_status not in allowed:
            return fail(
                f'Invalid transition {current} -> {new_status}')

        admin_response = sanitize(data.get('admin_response') or '')
        department = sanitize(data.get('department') or '')
        priority = (data.get('priority') or '').strip().upper() or None

        fields = ['status=%s', 'responded_by=%s', 'responded_at=%s',
                  'datetime_updated=%s']
        params = [new_status, admin_id, ts, ts]
        if admin_response:
            fields.append('admin_response=%s')
            params.append(admin_response)
        if department:
            fields.append('department=%s')
            params.append(department)
        if priority:
            fields.append('priority=%s')
            params.append(priority)
        params.append(report_id)

        cur.execute(
            f"UPDATE app_citizen_reports SET {', '.join(fields)} WHERE id=%s",
            params)

        # SYSTEM status-change note + optional STAFF reply.
        _insert_message(cur, report_id, 'SYSTEM', admin_id,
                        f'Status changed: {current} -> {new_status}', ts)
        if admin_response:
            _insert_message(cur, report_id, 'STAFF', admin_id, admin_response, ts)

        cur.connection.commit()

        return ok({'id': report_id, 'status': new_status})

    except Exception as e:
        logger.exception('respond_citizen_report failed')
        return fail(f'Respond failed: {e}', 500)
