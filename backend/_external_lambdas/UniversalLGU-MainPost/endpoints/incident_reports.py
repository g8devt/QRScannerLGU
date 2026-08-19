import logging
import json
import uuid
from datetime import datetime, timedelta

from helpers.auth import ok, fail, require
from helpers.db import sanitize, serialize_row
from helpers.forms import parse_int
from helpers.s3 import upload_to_s3, generate_key
from helpers.audit import record_audit_log

logger = logging.getLogger()

_ALLOWED_TYPES = {
    'CALAMITY', 'FIRE', 'MEDICAL', 'CRIME', 'ACCIDENT', 'UTILITY', 'OTHER',
}

_MAX_PHOTOS = 5

_ALLOWED_STATUSES = {
    'PENDING', 'ACKNOWLEDGED', 'IN_PROGRESS', 'RESOLVED', 'CANCELLED',
}


def _ref_number():
    return 'IR' + datetime.now().strftime('%Y%m%d') + uuid.uuid4().hex[:6].upper()


def _reporter_name(cur, user_id):
    try:
        cur.execute("""
            SELECT fullname, full_name, first_name, last_name, username, email
            FROM app_users WHERE id=%s LIMIT 1
        """, (user_id,))
    except Exception:
        cur.execute("SELECT * FROM app_users WHERE id=%s LIMIT 1", (user_id,))
    row = cur.fetchone() or {}
    for key in ('fullname', 'full_name'):
        v = (row.get(key) or '').strip() if isinstance(row, dict) else ''
        if v:
            return v
    fn = (row.get('first_name') or '').strip() if isinstance(row, dict) else ''
    ln = (row.get('last_name') or '').strip() if isinstance(row, dict) else ''
    joined = (f'{fn} {ln}').strip()
    if joined:
        return joined
    for key in ('username', 'email'):
        v = (row.get(key) or '').strip() if isinstance(row, dict) else ''
        if v:
            return v
    return 'Anonymous'


def _upload_media(files, user_id, ref):
    photo_urls = []
    video_url = None
    now = datetime.now()
    prefix = f'incident_reports/{user_id}/{now:%Y}/{now:%m}/{ref}'

    photo_count = 0
    for f in files or []:
        field = (f.get('field_name') or '').strip()
        if not field:
            continue

        # photos[] or photo_0 / photo_1 / photo
        if field == 'photos[]' or field.startswith('photo'):
            if photo_count >= _MAX_PHOTOS:
                continue
            f['content'].seek(0)
            content = f['content'].read()
            key = generate_key(prefix, user_id, f.get('filename') or f'photo_{photo_count}.jpg')
            url = upload_to_s3(content, key)
            if url:
                photo_urls.append(url)
                photo_count += 1

        elif field == 'video' and video_url is None:
            f['content'].seek(0)
            content = f['content'].read()
            key = generate_key(prefix, user_id, f.get('filename') or 'video.mp4')
            url = upload_to_s3(content, key, content_type='video/mp4')
            if url:
                video_url = url

    return photo_urls, video_url


def submit_incident_report(cur, data, files, ts):
    try:
        require(data, 'user_profile_id', 'report_type', 'description',
                'latitude', 'longitude')
        user_id = data['user_profile_id']

        report_type = (data.get('report_type') or '').strip().upper()
        if report_type not in _ALLOWED_TYPES:
            return fail(f'Invalid report_type: {report_type}')

        try:
            lat = float(data['latitude'])
            lng = float(data['longitude'])
        except (TypeError, ValueError):
            return fail('latitude/longitude must be numbers')

        description = (data.get('description') or '').strip()
        if len(description) < 10:
            return fail('Description must be at least 10 characters')

        address_text = sanitize(data.get('address_text') or '')[:500]
        reporter = _reporter_name(cur, user_id)
        ref = _ref_number()
        photo_urls, video_url = _upload_media(files, user_id, ref)

        expires_at = datetime.now() + timedelta(days=7)

        cur.execute("""
            INSERT INTO app_incident_reports (
                user_id, reference_number, reporter_name, report_type,
                description, latitude, longitude, address_text,
                photo_urls, video_url, status,
                date_submitted, expires_at
            ) VALUES (
                %s, %s, %s, %s,
                %s, %s, %s, %s,
                %s, %s, 'PENDING',
                %s, %s
            )
        """, (
            user_id, ref, reporter, report_type,
            description, lat, lng, address_text or None,
            json.dumps(photo_urls) if photo_urls else None,
            video_url, ts, expires_at.strftime('%Y-%m-%d %H:%M:%S'),
        ))

        row_id = cur.lastrowid
        cur.connection.commit()

        return ok({
            'id': row_id,
            'reference_number': ref,
            'expires_at': expires_at.isoformat(),
            'photo_urls': photo_urls,
            'video_url': video_url,
        }, 201)

    except Exception as e:
        logger.exception('submit_incident_report failed')
        return fail(f'Submit failed: {e}', 500)


def list_incident_reports(cur, data, files, ts):
    try:
        require(data, 'user_profile_id')
        user_id = data['user_profile_id']

        status = (data.get('status') or '').strip().upper() or None
        try:
            limit = max(1, min(200, int(data.get('limit') or 50)))
            offset = max(0, int(data.get('offset') or 0))
        except (TypeError, ValueError):
            limit, offset = 50, 0

        if status:
            cur.execute("""
                SELECT id, reference_number, report_type, status, description,
                       latitude, longitude, address_text, photo_urls, video_url,
                       date_submitted, expires_at
                FROM app_incident_reports
                WHERE user_id=%s AND status=%s
                ORDER BY date_submitted DESC
                LIMIT %s OFFSET %s
            """, (user_id, status, limit, offset))
        else:
            cur.execute("""
                SELECT id, reference_number, report_type, status, description,
                       latitude, longitude, address_text, photo_urls, video_url,
                       date_submitted, expires_at
                FROM app_incident_reports
                WHERE user_id=%s
                ORDER BY date_submitted DESC
                LIMIT %s OFFSET %s
            """, (user_id, limit, offset))

        rows = cur.fetchall() or []
        out = []
        for r in rows:
            r = dict(r) if not isinstance(r, dict) else r
            raw = r.get('photo_urls')
            if isinstance(raw, str) and raw:
                try:
                    r['photo_urls'] = json.loads(raw)
                except Exception:
                    r['photo_urls'] = []
            elif raw is None:
                r['photo_urls'] = []
            out.append(serialize_row(r))
        return ok({'reports': out, 'count': len(out)})

    except Exception as e:
        logger.exception('list_incident_reports failed')
        return fail(f'List failed: {e}', 500)


def _parse_photo_urls(row):
    row = dict(row) if not isinstance(row, dict) else row
    raw = row.get('photo_urls')
    if isinstance(raw, str) and raw:
        try:
            row['photo_urls'] = json.loads(raw)
        except Exception:
            row['photo_urls'] = []
    elif raw is None:
        row['photo_urls'] = []
    return row


def admin_get_incident_report_detail(cur, data, files, ts):
    try:
        require(data, 'id')
        report_id = data['id']

        cur.execute("""
            SELECT id, user_id, reference_number, reporter_name, report_type,
                   description, latitude, longitude, address_text, photo_urls,
                   video_url, status, remarks, date_submitted, expires_at,
                   date_modified
            FROM app_incident_reports
            WHERE id=%s
            LIMIT 1
        """, (report_id,))
        row = cur.fetchone()
        if not row:
            return fail('Incident report not found', 404)

        return ok({'status': True, 'data': serialize_row(_parse_photo_urls(row))})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.exception('admin_get_incident_report_detail failed')
        return fail(f'Server error: {e}', 500)


def admin_list_incident_reports(cur, data, files, ts):
    try:
        page = max(parse_int(data.get('page')) or 1, 1)
        limit = min(max(parse_int(data.get('limit')) or 20, 1), 100)
        offset = (page - 1) * limit
        status = (data.get('status') or '').strip().upper()
        report_type = (data.get('report_type') or '').strip().upper()
        search = sanitize(data.get('search'))
        date_from = sanitize(data.get('date_from'))
        date_to = sanitize(data.get('date_to'))

        where = []
        params = []
        if status and status != 'ALL':
            if status not in _ALLOWED_STATUSES:
                return fail(f'Invalid status: {status}')
            where.append('status=%s')
            params.append(status)
        if report_type and report_type != 'ALL':
            if report_type not in _ALLOWED_TYPES:
                return fail(f'Invalid report_type: {report_type}')
            where.append('report_type=%s')
            params.append(report_type)
        if search:
            like = f'%{search}%'
            where.append('(reference_number LIKE %s OR reporter_name LIKE %s)')
            params += [like, like]
        if date_from:
            where.append('date_submitted >= %s')
            params.append(date_from)
        if date_to:
            where.append('date_submitted <= %s')
            params.append(f'{date_to} 23:59:59')
        clause = ('WHERE ' + ' AND '.join(where)) if where else ''

        cur.execute(f"""
            SELECT id, user_id, reference_number, reporter_name, report_type,
                   description, latitude, longitude, address_text, photo_urls,
                   video_url, status, remarks, date_submitted, expires_at,
                   date_modified
            FROM app_incident_reports
            {clause}
            ORDER BY date_submitted DESC
            LIMIT %s OFFSET %s
        """, tuple(params + [limit + 1, offset]))
        rows = cur.fetchall() or []
        has_more = len(rows) > limit
        rows = rows[:limit]
        out = [serialize_row(_parse_photo_urls(r)) for r in rows]

        cur.execute("SELECT status, COUNT(*) AS c FROM app_incident_reports GROUP BY status")
        raw_counts = {row['status']: row['c'] for row in cur.fetchall()}
        stat_counts = {s: raw_counts.get(s, 0) for s in _ALLOWED_STATUSES}
        stat_counts['ALL'] = sum(stat_counts.values())

        return ok({'status': True,
                   'data': {'items': out, 'page': page, 'has_more': has_more,
                             'counts': stat_counts}})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.exception('admin_list_incident_reports failed')
        return fail(f'List failed: {e}', 500)


def admin_delete_incident_report(cur, data, files, ts):
    try:
        require(data, 'id')
        report_id = data['id']

        cur.execute("SELECT reference_number FROM app_incident_reports WHERE id=%s", (report_id,))
        row = cur.fetchone()
        if not row:
            return fail('Incident report not found', 404)

        cur.execute("DELETE FROM app_incident_reports WHERE id=%s", (report_id,))

        admin = data.get('_admin') or {}
        record_audit_log(cur, admin.get('id'), admin.get('role'),
                          'admin_delete_incident_report', 'incident_report',
                          report_id, {'reference_number': row['reference_number']}, ts)

        return ok({'status': True, 'id': str(report_id)})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.exception('admin_delete_incident_report failed')
        return fail(f'Server error: {e}', 500)


def admin_update_incident_status(cur, data, files, ts):
    try:
        require(data, 'report_id', 'status')
        report_id = data['report_id']
        status = (data['status'] or '').strip().upper()
        if status not in _ALLOWED_STATUSES:
            return fail(f'Invalid status: {status}')

        cur.execute(
            "SELECT id FROM app_incident_reports WHERE id=%s LIMIT 1", (report_id,))
        row = cur.fetchone()
        if not row:
            return fail('Incident report not found', 404)

        if 'remarks' in data:
            remarks = sanitize(data.get('remarks'))
            cur.execute("""
                UPDATE app_incident_reports
                   SET status=%s, remarks=%s, date_modified=%s
                 WHERE id=%s
            """, (status, remarks, ts, report_id))
        else:
            cur.execute("""
                UPDATE app_incident_reports
                   SET status=%s, date_modified=%s
                 WHERE id=%s
            """, (status, ts, report_id))

        admin = data.get('_admin') or {}
        record_audit_log(cur, admin.get('id'), admin.get('role'), 'admin_update_incident_status',
                          'incident_report', report_id, {'status': status}, ts)

        return ok({'status': True, 'message': f'Status updated to {status}',
                   'data': {'id': str(report_id), 'status': status}})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.exception('admin_update_incident_status failed')
        return fail(f'Update failed: {e}', 500)
