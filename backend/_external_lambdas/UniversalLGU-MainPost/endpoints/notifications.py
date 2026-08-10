import json
import logging
from datetime import datetime

from helpers.auth import ok, fail, require
from helpers import fcm
from helpers.audit import record_audit_log
from helpers.forms import parse_int

logger = logging.getLogger()

# ─────────────────────────────────────────────────────────────────────────────
# Notifications API — universal / multi-tenant.
#
# Every handler receives `cur`, a cursor already bound to the tenant DB the
# request resolved to (cebu_lgu_db, bataan_db, district_6_db, …) — the routing
# happens once in lambda_handler via `db_name`. So nothing here is Cebu-specific:
# the same code stores/reads notifications in whichever tenant DB the caller
# targets.
#
# Table `app_notifications` (created by migration 002 in every tenant DB):
#   id INT PK
#   user_profile_id INT NULL   -- NULL = broadcast (visible to all users)
#   title VARCHAR(255)
#   message TEXT
#   type VARCHAR(50) DEFAULT 'GENERAL'
#   is_read TINYINT DEFAULT 0
#   data JSON NULL             -- arbitrary payload (e.g. {"route": "...", "extra": {...}})
#   date_created DATETIME
# ─────────────────────────────────────────────────────────────────────────────

# Hard cap on how many rows a single list call returns, mirroring the Flutter
# client's local cap (NotificationsService._maxStored).
_MAX_LIMIT = 100


def _coerce_int(val):
    """Best-effort int from a multipart string field; None when absent/blank."""
    if val is None:
        return None
    s = str(val).strip()
    if not s or s.lower() in ('null', 'none'):
        return None
    try:
        return int(s)
    except (TypeError, ValueError):
        return None


def _normalize_data_field(raw):
    """Validate/normalize the optional `data` JSON payload into a JSON string.

    Accepts a JSON string or a dict/list (when the caller sent JSON, not
    multipart). Returns a compact JSON string to store in the JSON column, or
    None when nothing usable was provided. Invalid JSON raises ValueError so
    the caller gets a clear 400 rather than a stored-garbage row.
    """
    if raw is None:
        return None
    if isinstance(raw, (dict, list)):
        return json.dumps(raw)
    s = str(raw).strip()
    if not s:
        return None
    try:
        parsed = json.loads(s)
    except (TypeError, ValueError):
        raise ValueError('Invalid data: must be valid JSON')
    return json.dumps(parsed)


def _decode_data_field(raw):
    """Turn a stored JSON column value back into a Python object for output."""
    if raw is None:
        return None
    if isinstance(raw, (dict, list)):
        return raw
    if isinstance(raw, (bytes, bytearray)):
        raw = raw.decode('utf-8')
    if isinstance(raw, str):
        try:
            return json.loads(raw)
        except (TypeError, ValueError):
            return None
    return None


def _row_to_json(row):
    """Shape a DB row into the client-facing notification object."""
    return {
        'id': str(row.get('id')),
        'user_profile_id': (
            str(row['user_profile_id'])
            if row.get('user_profile_id') is not None else None
        ),
        'title': row.get('title') or '',
        'message': row.get('message') or '',
        'type': row.get('type') or 'GENERAL',
        'is_read': bool(row.get('is_read')),
        'data': _decode_data_field(row.get('data')),
        'date_created': (
            row['date_created'].isoformat()
            if isinstance(row.get('date_created'), datetime)
            else (str(row['date_created']) if row.get('date_created') is not None else None)
        ),
    }


def save_notification(cur, data, files, ts):
    """Persist one received notification into `app_notifications`.

    Required: title, message.
    Optional: user_profile_id (omit / blank → broadcast), type, data (JSON).
    Returns the stored row (including its new id) so the client can render it
    immediately without a follow-up list call.
    """
    try:
        require(data, 'title', 'message')
        title = str(data['title']).strip()
        message = str(data['message']).strip()
        if not title or not message:
            return fail('title and message cannot be empty')

        user_profile_id = _coerce_int(data.get('user_profile_id'))
        ntype = (str(data.get('type')).strip() if data.get('type') else '') or 'GENERAL'
        data_json = _normalize_data_field(data.get('data'))

        cur.execute(
            """
            INSERT INTO app_notifications
                (user_profile_id, title, message, type, is_read, data, date_created)
            VALUES (%s, %s, %s, %s, 0, %s, %s)
            """,
            (user_profile_id, title[:255], message, ntype[:50], data_json, ts),
        )
        new_id = cur.lastrowid
        cur.connection.commit()

        cur.execute(
            """
            SELECT id, user_profile_id, title, message, type, is_read, data, date_created
            FROM app_notifications WHERE id=%s
            """,
            (new_id,),
        )
        row = cur.fetchone()
        return ok({
            'status': 'success',
            'message': 'Notification saved',
            'data': _row_to_json(row) if row else {'id': str(new_id)},
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"save_notification error: {e}", exc_info=True)
        return fail(f'Server error: {e}', 500)


def send_notification(cur, data, files, ts):
    """Persist a notification AND push it to the target device via FCM.

    This is the authoritative path for server-originated notifications: the row
    is always written to `app_notifications` (so it shows in-app regardless of
    app state), then a best-effort FCM HTTP v1 push is delivered.

    Required: title, message.
    Target (one of): `fcm_token` (explicit device token, handy for testing) or
        `user_profile_id` (the row's owner; their app_users.registration_id is
        used as the push target). When neither resolves to a token, the row is
        still saved and `push` reports why it was skipped.
    Optional: type, data (JSON: {"route": "...", "extra": {...}}).
    """
    try:
        require(data, 'title', 'message')
        title = str(data['title']).strip()
        message = str(data['message']).strip()
        if not title or not message:
            return fail('title and message cannot be empty')

        user_profile_id = _coerce_int(data.get('user_profile_id'))
        ntype = (str(data.get('type')).strip() if data.get('type') else '') or 'GENERAL'
        data_json = _normalize_data_field(data.get('data'))

        # 1) Persist — authoritative, always happens.
        cur.execute(
            """
            INSERT INTO app_notifications
                (user_profile_id, title, message, type, is_read, data, date_created)
            VALUES (%s, %s, %s, %s, 0, %s, %s)
            """,
            (user_profile_id, title[:255], message, ntype[:50], data_json, ts),
        )
        new_id = cur.lastrowid
        cur.connection.commit()

        # 2) Resolve the push target: explicit token wins, else the user's
        #    stored registration_id.
        target_token = (data.get('fcm_token') or '').strip() or None
        if not target_token and user_profile_id is not None:
            cur.execute(
                "SELECT registration_id FROM app_users WHERE id=%s",
                (user_profile_id,),
            )
            row = cur.fetchone()
            if row:
                target_token = (
                    row.get('registration_id') if isinstance(row, dict) else row[0]
                ) or None

        # 3) Build the FCM data payload so the app can categorize/route on tap.
        #    FCM requires all data values to be strings; `extra` is JSON-encoded.
        push_data = {'type': ntype, 'notif_id': str(new_id)}
        if data_json:
            try:
                parsed = json.loads(data_json)
            except (TypeError, ValueError):
                parsed = None
            if isinstance(parsed, dict):
                if parsed.get('route'):
                    push_data['route'] = str(parsed['route'])
                if parsed.get('extra') is not None:
                    push_data['extra'] = json.dumps(parsed['extra'])

        # 4) Best-effort send.
        if not target_token:
            push_status = 'skipped_no_token'
        elif not fcm.is_configured():
            push_status = 'skipped_not_configured'
        else:
            sent, info = fcm.send_to_token(target_token, title, message, push_data)
            push_status = 'sent' if sent else f'failed:{info}'

        cur.execute(
            """
            SELECT id, user_profile_id, title, message, type, is_read, data, date_created
            FROM app_notifications WHERE id=%s
            """,
            (new_id,),
        )
        saved = cur.fetchone()
        return ok({
            'status': 'success',
            'message': 'Notification saved',
            'push': push_status,
            'data': _row_to_json(saved) if saved else {'id': str(new_id)},
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"send_notification error: {e}", exc_info=True)
        return fail(f'Server error: {e}', 500)


_NOTIFICATION_TYPES = {'GENERAL', 'ALERT', 'UPDATE', 'PROMO'}


def admin_send_notification(cur, data, files, ts):
    """Admin-composed notification — same persist+push behavior as
    `send_notification`, plus an audit-log entry. See that function's
    docstring for the full field semantics; this wrapper exists purely to
    add the admin session's audit trail without touching the citizen-facing
    endpoint."""
    try:
        require(data, 'title', 'message')
        title = str(data['title']).strip()
        message = str(data['message']).strip()
        if not title or not message:
            return fail('title and message cannot be empty')

        user_profile_id = _coerce_int(data.get('user_profile_id'))
        ntype = (str(data.get('type')).strip().upper() if data.get('type') else '') or 'GENERAL'
        if ntype not in _NOTIFICATION_TYPES:
            return fail(f'Invalid type: {ntype}')
        data_json = _normalize_data_field(data.get('data'))

        cur.execute(
            """
            INSERT INTO app_notifications
                (user_profile_id, title, message, type, is_read, data, date_created)
            VALUES (%s, %s, %s, %s, 0, %s, %s)
            """,
            (user_profile_id, title[:255], message, ntype[:50], data_json, ts),
        )
        new_id = cur.lastrowid
        cur.connection.commit()

        target_token = (data.get('fcm_token') or '').strip() or None
        if not target_token and user_profile_id is not None:
            cur.execute(
                "SELECT registration_id FROM app_users WHERE id=%s",
                (user_profile_id,),
            )
            row = cur.fetchone()
            if row:
                target_token = (
                    row.get('registration_id') if isinstance(row, dict) else row[0]
                ) or None

        push_data = {'type': ntype, 'notif_id': str(new_id)}
        if data_json:
            try:
                parsed = json.loads(data_json)
            except (TypeError, ValueError):
                parsed = None
            if isinstance(parsed, dict):
                if parsed.get('route'):
                    push_data['route'] = str(parsed['route'])
                if parsed.get('extra') is not None:
                    push_data['extra'] = json.dumps(parsed['extra'])

        if not target_token:
            push_status = 'skipped_no_token'
        elif not fcm.is_configured():
            push_status = 'skipped_not_configured'
        else:
            sent, info = fcm.send_to_token(target_token, title, message, push_data)
            push_status = 'sent' if sent else f'failed:{info}'

        cur.execute(
            """
            SELECT id, user_profile_id, title, message, type, is_read, data, date_created
            FROM app_notifications WHERE id=%s
            """,
            (new_id,),
        )
        saved = cur.fetchone()

        admin = data.get('_admin') or {}
        record_audit_log(cur, admin.get('id'), admin.get('role'),
                          'admin_send_notification', 'notification',
                          new_id, {'title': title, 'user_profile_id': user_profile_id,
                                   'type': ntype, 'push': push_status}, ts)

        return ok({
            'status': 'success',
            'message': 'Notification saved',
            'push': push_status,
            'data': _row_to_json(saved) if saved else {'id': str(new_id)},
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"admin_send_notification error: {e}", exc_info=True)
        return fail(f'Server error: {e}', 500)


def admin_list_notifications(cur, data, files, ts):
    try:
        page = max(parse_int(data.get('page')) or 1, 1)
        limit = min(max(parse_int(data.get('limit')) or 20, 1), 100)
        offset = (page - 1) * limit
        ntype = (data.get('type') or '').strip().upper()
        scope = (data.get('scope') or '').strip().upper()

        where = []
        params = []
        if ntype and ntype != 'ALL':
            if ntype not in _NOTIFICATION_TYPES:
                return fail(f'Invalid type: {ntype}')
            where.append('type=%s')
            params.append(ntype)
        if scope == 'BROADCAST':
            where.append('user_profile_id IS NULL')
        elif scope == 'TARGETED':
            where.append('user_profile_id IS NOT NULL')
        elif scope and scope != 'ALL':
            return fail(f'Invalid scope: {scope}')
        clause = ('WHERE ' + ' AND '.join(where)) if where else ''

        cur.execute(f"""
            SELECT id, user_profile_id, title, message, type, is_read, data, date_created
            FROM app_notifications
            {clause}
            ORDER BY date_created DESC, id DESC
            LIMIT %s OFFSET %s
        """, tuple(params + [limit + 1, offset]))
        rows = cur.fetchall() or []
        has_more = len(rows) > limit
        rows = rows[:limit]
        return ok({'status': True,
                   'data': {'items': [_row_to_json(r) for r in rows],
                            'page': page, 'has_more': has_more}})
    except Exception as e:
        logger.error(f'admin_list_notifications error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def admin_delete_notification(cur, data, files, ts):
    try:
        require(data, 'id')
        nid = _coerce_int(data.get('id'))
        if nid is None:
            return fail('Invalid id')

        cur.execute("DELETE FROM app_notifications WHERE id=%s", (nid,))
        if cur.rowcount == 0:
            return fail('Notification not found', 404)
        cur.connection.commit()

        admin = data.get('_admin') or {}
        record_audit_log(cur, admin.get('id'), admin.get('role'),
                          'admin_delete_notification', 'notification',
                          nid, {}, ts)

        return ok({'status': True, 'message': 'Notification deleted'})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'admin_delete_notification error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def list_notifications(cur, data, files, ts):
    """Return a user's notifications: their own rows plus broadcasts.

    Required: user_profile_id.
    Optional: limit (default/cap 100), unread_only ('1'/'true' to filter).
    """
    try:
        require(data, 'user_profile_id')
        user_profile_id = _coerce_int(data.get('user_profile_id'))
        if user_profile_id is None:
            return fail('Invalid user_profile_id')

        limit = _coerce_int(data.get('limit')) or _MAX_LIMIT
        limit = max(1, min(limit, _MAX_LIMIT))

        unread_only = str(data.get('unread_only') or '').strip().lower() in ('1', 'true', 'yes')

        sql = """
            SELECT id, user_profile_id, title, message, type, is_read, data, date_created
            FROM app_notifications
            WHERE (user_profile_id=%s OR user_profile_id IS NULL)
        """
        params = [user_profile_id]
        if unread_only:
            sql += " AND is_read=0"
        sql += " ORDER BY date_created DESC, id DESC LIMIT %s"
        params.append(limit)

        cur.execute(sql, tuple(params))
        rows = cur.fetchall() or []
        items = [_row_to_json(r) for r in rows]
        unread = sum(1 for r in rows if not r.get('is_read'))
        return ok({
            'status': 'success',
            'data': items,
            'unread_count': unread,
            'count': len(items),
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"list_notifications error: {e}", exc_info=True)
        return fail(f'Server error: {e}', 500)


def mark_notification_read(cur, data, files, ts):
    """Mark a single notification row as read by id."""
    try:
        require(data, 'id')
        nid = _coerce_int(data.get('id'))
        if nid is None:
            return fail('Invalid id')
        cur.execute("UPDATE app_notifications SET is_read=1 WHERE id=%s", (nid,))
        cur.connection.commit()
        return ok({'status': 'success', 'message': 'Marked as read', 'updated': cur.rowcount})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"mark_notification_read error: {e}", exc_info=True)
        return fail(f'Server error: {e}', 500)


def mark_all_notifications_read(cur, data, files, ts):
    """Mark all of a user's notifications (own + broadcasts) as read."""
    try:
        require(data, 'user_profile_id')
        user_profile_id = _coerce_int(data.get('user_profile_id'))
        if user_profile_id is None:
            return fail('Invalid user_profile_id')
        cur.execute(
            """
            UPDATE app_notifications SET is_read=1
            WHERE is_read=0 AND (user_profile_id=%s OR user_profile_id IS NULL)
            """,
            (user_profile_id,),
        )
        cur.connection.commit()
        return ok({'status': 'success', 'message': 'All marked as read', 'updated': cur.rowcount})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"mark_all_notifications_read error: {e}", exc_info=True)
        return fail(f'Server error: {e}', 500)


def delete_notification(cur, data, files, ts):
    """Delete a single notification row by id."""
    try:
        require(data, 'id')
        nid = _coerce_int(data.get('id'))
        if nid is None:
            return fail('Invalid id')
        cur.execute("DELETE FROM app_notifications WHERE id=%s", (nid,))
        cur.connection.commit()
        return ok({'status': 'success', 'message': 'Deleted', 'deleted': cur.rowcount})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"delete_notification error: {e}", exc_info=True)
        return fail(f'Server error: {e}', 500)
