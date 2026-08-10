import random
import uuid
import logging
from datetime import datetime, timedelta
from helpers.auth import ok, fail, require
from helpers.db import sanitize, serialize_row
from helpers.forms import parse_int
from helpers.parse import parse_form_data
from helpers.audit import record_audit_log
from endpoints import tourism_pricing
# helpers.s3 (boto3) is imported lazily inside upload_tourism_images so this
# module stays importable in environments without boto3 (e.g. unit tests).

logger = logging.getLogger()

_IPASS_STATUSES = {'PENDING_PAYMENT', 'PAID', 'CANCELLED', 'EXPIRED'}
_DESTINATION_CATEGORIES = {'BEACHES', 'ISLANDS', 'RESORTS', 'CULTURE', 'OTHER'}


def _effective_ipass_status(row, ts, has_exp):
    """Derive the DISPLAY status for a lapsed-but-not-yet-swept pass, without
    writing to the DB. Admin read endpoints intentionally skip the lazy
    _expire_stale_ipass() UPDATE that citizen paths run, so a pass whose
    expiration_date has already passed would otherwise still show
    PENDING_PAYMENT here. This mirrors what that sweep would set, for display
    only."""
    if not has_exp or row.get('status') != 'PENDING_PAYMENT':
        return row.get('status')
    exp = row.get('expiration_date')
    if not exp:
        return row.get('status')
    exp_str = str(exp)
    if exp_str < ts:
        return 'EXPIRED'
    return row.get('status')


def _gen_reference(cur):
    """Unique TR-XXXXXXXXXX reference. Re-rolls until unused."""
    while True:
        num = ''.join(str(random.randint(0, 9)) for _ in range(10))
        ref = f'TR-{num}'
        cur.execute(
            "SELECT COUNT(*) AS c FROM app_tourism_ipass WHERE reference_no=%s",
            (ref,))
        if cur.fetchone()['c'] == 0:
            return ref


def _gen_qr_code(cur):
    """Unique QR-code token (32 hex chars) for an iPass record. Re-rolls until
    unused so the column's UNIQUE constraint never collides."""
    while True:
        token = uuid.uuid4().hex.upper()
        cur.execute(
            "SELECT COUNT(*) AS c FROM app_tourism_ipass WHERE qr_code=%s",
            (token,))
        if cur.fetchone()['c'] == 0:
            return token


# An iPass is valid for 30 days from creation.
_IPASS_VALID_DAYS = 30


def _expiration_from(ts):
    """Expiration timestamp = `ts` + 30 days, in the same string format. Returns
    None when `ts` can't be parsed (the column then stays NULL)."""
    try:
        return (datetime.strptime(ts, '%Y-%m-%d %H:%M:%S')
                + timedelta(days=_IPASS_VALID_DAYS)).strftime('%Y-%m-%d %H:%M:%S')
    except (ValueError, TypeError):
        return None


def _expire_stale_ipass(cur, ts):
    """Retire unpaid passes whose expiration has lapsed. No-op on tenants that
    haven't run migration 035 (the expiration_date column is absent)."""
    if not _has_columns(cur, 'app_tourism_ipass', 'expiration_date'):
        return
    cur.execute(
        "UPDATE app_tourism_ipass SET status='EXPIRED' "
        "WHERE status='PENDING_PAYMENT' AND expiration_date IS NOT NULL "
        "AND expiration_date < %s",
        (ts,))


def _has_active_ipass(cur, user_id):
    """True when the user's most recent pass is still active (i.e. not EXPIRED).
    A blank/None user id never counts as having one."""
    if not user_id:
        return False
    cur.execute(
        "SELECT status FROM app_tourism_ipass WHERE user_profile_id=%s "
        "ORDER BY created_at DESC LIMIT 1",
        (user_id,))
    row = cur.fetchone()
    return row is not None and str(row.get('status')) != 'EXPIRED'


def get_tourism_services(cur, data, files, ts):
    cur.execute(
        """SELECT id, code, name, description, provider, requirement,
                  price_local, price_foreign, pricing_unit, trip_scope,
                  has_variants, sort_order
           FROM app_tourism_services
           WHERE is_active = 1
           ORDER BY sort_order ASC, id ASC""")
    rows = [serialize_row(r) for r in cur.fetchall()]
    return ok({'status': True, 'services': rows})


def _has_columns(cur, table, *cols):
    """True only when every named column exists on `table` in the current DB.
    Lets the shared lambda keep serving tenants that haven't run the latest
    migration yet — newer columns are simply omitted from the SELECT."""
    cur.execute(
        "SELECT COLUMN_NAME FROM information_schema.COLUMNS "
        "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = %s",
        (table,))
    have = {r['COLUMN_NAME'] for r in cur.fetchall()}
    return all(c in have for c in cols)


def get_tourism_destinations(cur, data, files, ts):
    """Discoverable destinations for the explore screen. Optional `category`
    filter (BEACHES/ISLANDS/RESORTS/CULTURE/OTHER); 'ALL' or empty returns all.
    Optional `search` does a case-insensitive match across name/location/blurb."""
    category = (data.get('category') or '').strip().upper()
    search = (data.get('search') or '').strip()
    # latitude/longitude land in migration 031 — only select them when present
    # so a tenant on an older schema still gets a working list (no map coords).
    coords = ', latitude, longitude' if _has_columns(
        cur, 'app_tourism_destinations', 'latitude', 'longitude') else ''
    # gallery_list_url lands in migration 033 — same guard so older tenants
    # keep working (no gallery list returned).
    gallery = ', gallery_list_url' if _has_columns(
        cur, 'app_tourism_destinations', 'gallery_list_url') else ''
    sql = (
        "SELECT id, code, name, category, location, blurb, overview, "
        f"amenities, address, image_url{gallery}, rating, "
        f"review_count, price, is_top_pick, is_trending, sort_order{coords} "
        "FROM app_tourism_destinations WHERE is_active = 1"
    )
    params = []
    if category and category != 'ALL':
        sql += " AND category = %s"
        params.append(category)
    if search:
        sql += " AND (name LIKE %s OR location LIKE %s OR blurb LIKE %s)"
        like = f"%{search}%"
        params += [like, like, like]
    sql += " ORDER BY sort_order ASC, id ASC"
    cur.execute(sql, params)
    rows = [serialize_row(r) for r in cur.fetchall()]
    return ok({'status': True, 'destinations': rows})


_IMAGE_CONTENT_TYPES = {
    'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
    'webp': 'image/webp', 'gif': 'image/gif',
}


def _image_ext_and_type(filename):
    ext = (filename.rsplit('.', 1)[-1] if '.' in filename else 'jpg').lower()
    if ext not in _IMAGE_CONTENT_TYPES:
        ext = 'jpg'
    return ext, _IMAGE_CONTENT_TYPES[ext]


def _extract_selfie(files):
    """Pull the multipart `selfie` file (if any) from the request. Returns
    (content_bytes, ext, content_type) or None when no usable selfie was sent."""
    for f in files or []:
        if (f.get('field_name') or '').strip() == 'selfie':
            f['content'].seek(0)
            content = f['content'].read()
            if not content:
                return None
            ext, ctype = _image_ext_and_type(f.get('filename') or '')
            return content, ext, ctype
    return None


def upload_tourism_images(cur, data, files, ts):
    """Admin: upload a destination's thumbnail / gallery images to S3 and update
    its catalog row. Send the destination `code` plus multipart files:
      - field `thumbnail`               → tourism/thumbnail/<code>.<ext>  (image_url)
      - field `gallery[]` or `gallery_N` → tourism/gallery/<code>_<n>.<ext> (gallery_list_url)
    Keys are deterministic (derived from the code) so re-uploads replace the
    existing image. Only the parts that were sent are touched. Returns the
    resulting public URLs."""
    from helpers.s3 import upload_to_s3
    require(data, 'code')
    code = data['code'].strip()
    if not code:
        return fail('Missing destination code')
    slug = code.lower()

    thumb_url = None
    gallery_urls = []
    gi = 0
    for f in files or []:
        field = (f.get('field_name') or '').strip()
        if not field:
            continue
        f['content'].seek(0)
        content = f['content'].read()
        ext, ctype = _image_ext_and_type(f.get('filename') or '')
        if field == 'thumbnail':
            thumb_url = upload_to_s3(
                content, f"tourism/thumbnail/{slug}.{ext}", content_type=ctype)
        elif field == 'gallery[]' or field.startswith('gallery'):
            gi += 1
            gallery_urls.append(upload_to_s3(
                content, f"tourism/gallery/{slug}_{gi}.{ext}", content_type=ctype))

    if not thumb_url and not gallery_urls:
        return fail('No images uploaded (send `thumbnail` and/or `gallery[]`)')

    # Persist only what was uploaded. gallery_list_url is guarded so this still
    # works on tenants that haven't run migration 033 yet.
    sets, params = [], []
    if thumb_url:
        sets.append('image_url = %s')
        params.append(thumb_url)
    if gallery_urls and _has_columns(
            cur, 'app_tourism_destinations', 'gallery_list_url'):
        sets.append('gallery_list_url = %s')
        params.append(','.join(gallery_urls))

    updated = False
    if sets:
        params.append(code)
        cur.execute(
            f"UPDATE app_tourism_destinations SET {', '.join(sets)} "
            "WHERE code = %s", params)
        updated = cur.rowcount > 0

    if updated:
        admin = data.get('_admin') or {}
        record_audit_log(cur, admin.get('id'), admin.get('role'), 'upload_tourism_images',
                          'destination', code, {'updated': updated}, ts)

    return ok({'status': True, 'code': code, 'updated': updated,
               'image_url': thumb_url, 'gallery_list_url': gallery_urls})


def _ensure_favorites_table(cur):
    """Create the per-user favorites table on first use. Lets the shared lambda
    serve tenants that haven't run migration 032 yet — the table is created
    lazily and idempotently (CREATE TABLE IF NOT EXISTS is a no-op afterwards).
    Also back-fills the tourism_destinations_id column on deploys that created
    the table before it existed."""
    cur.execute(
        """CREATE TABLE IF NOT EXISTS `app_tourism_favorites` (
             `id` INT AUTO_INCREMENT PRIMARY KEY,
             `user_profile_id` VARCHAR(64) NOT NULL,
             `destination_code` VARCHAR(64) NOT NULL,
             `tourism_destinations_id` INT DEFAULT NULL,
             `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
             UNIQUE KEY `uniq_user_dest` (`user_profile_id`, `destination_code`),
             KEY `idx_user` (`user_profile_id`),
             KEY `idx_dest_id` (`tourism_destinations_id`)
           ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci""")
    if not _has_columns(cur, 'app_tourism_favorites', 'tourism_destinations_id'):
        cur.execute(
            "ALTER TABLE `app_tourism_favorites` "
            "ADD COLUMN `tourism_destinations_id` INT DEFAULT NULL, "
            "ADD KEY `idx_dest_id` (`tourism_destinations_id`)")


def get_tourism_favorites(cur, data, files, ts):
    """Destination codes the given user has hearted, newest first."""
    require(data, 'user_profile_id')
    _ensure_favorites_table(cur)
    cur.execute(
        "SELECT destination_code FROM app_tourism_favorites "
        "WHERE user_profile_id = %s ORDER BY id DESC",
        (data['user_profile_id'],))
    codes = [r['destination_code'] for r in cur.fetchall()]
    return ok({'status': True, 'favorites': codes})


def toggle_tourism_favorite(cur, data, files, ts):
    """Add or remove a destination from the user's favorites. `is_favorite`
    sets the desired state ('1' add / '0' remove); omit it to flip the current
    state. Returns the resulting state so the client can reconcile."""
    require(data, 'user_profile_id', 'destination_code')
    _ensure_favorites_table(cur)
    user_id = data['user_profile_id']
    code = data['destination_code']
    desired = data.get('is_favorite')
    if desired is None or str(desired).strip() == '':
        cur.execute(
            "SELECT id FROM app_tourism_favorites "
            "WHERE user_profile_id = %s AND destination_code = %s",
            (user_id, code))
        is_fav = cur.fetchone() is None  # not currently favorited → add it
    else:
        is_fav = str(desired).strip().lower() in ('1', 'true', 'yes')
    if is_fav:
        # Resolve the catalog row id from the code so the favorite carries a
        # stable FK-style reference alongside the human-readable code.
        cur.execute(
            "SELECT id FROM app_tourism_destinations WHERE code = %s", (code,))
        row = cur.fetchone()
        dest_id = row['id'] if row else None
        cur.execute(
            "INSERT INTO app_tourism_favorites "
            "(user_profile_id, destination_code, tourism_destinations_id, created_at) "
            "VALUES (%s, %s, %s, %s) "
            "ON DUPLICATE KEY UPDATE "
            "tourism_destinations_id = VALUES(tourism_destinations_id)",
            (user_id, code, dest_id, ts))
    else:
        cur.execute(
            "DELETE FROM app_tourism_favorites "
            "WHERE user_profile_id = %s AND destination_code = %s",
            (user_id, code))
    return ok({'status': True, 'destination_code': code, 'is_favorite': is_fav})


def admin_list_destinations(cur, data, files, ts):
    try:
        page = max(parse_int(data.get('page')) or 1, 1)
        limit = min(max(parse_int(data.get('limit')) or 20, 1), 100)
        offset = (page - 1) * limit
        category = (data.get('category') or '').strip().upper()

        where = []
        params = []
        if category and category != 'ALL':
            if category not in _DESTINATION_CATEGORIES:
                return fail(f'Invalid category: {category}')
            where.append('category=%s')
            params.append(category)
        clause = ('WHERE ' + ' AND '.join(where)) if where else ''

        coords = ', latitude, longitude' if _has_columns(
            cur, 'app_tourism_destinations', 'latitude', 'longitude') else ''
        gallery = ', gallery_list_url' if _has_columns(
            cur, 'app_tourism_destinations', 'gallery_list_url') else ''

        cur.execute(f"""
            SELECT id, code, name, category, location, blurb, overview,
                   amenities, address, image_url{gallery}, rating,
                   review_count, price, is_top_pick, is_trending, is_active,
                   sort_order{coords}
            FROM app_tourism_destinations
            {clause}
            ORDER BY sort_order ASC, id ASC
            LIMIT %s OFFSET %s
        """, tuple(params + [limit + 1, offset]))
        rows = cur.fetchall() or []
        has_more = len(rows) > limit
        rows = rows[:limit]
        return ok({'status': True,
                   'data': {'items': [serialize_row(r) for r in rows],
                            'page': page, 'has_more': has_more}})
    except Exception as e:
        logger.error(f'admin_list_destinations error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def admin_update_destination(cur, data, files, ts):
    try:
        require(data, 'code')
        code = data['code'].strip()

        cur.execute("SELECT id FROM app_tourism_destinations WHERE code=%s", (code,))
        if not cur.fetchone():
            return fail('Destination not found', 404)

        if 'category' in data:
            category = (data['category'] or '').strip().upper()
            if category not in _DESTINATION_CATEGORIES:
                return fail(f'Invalid category: {category}')

        sets = []
        params = []
        for field in ('name', 'location', 'blurb', 'overview', 'amenities', 'address'):
            if field in data:
                sets.append(f'{field}=%s')
                params.append(sanitize(data[field]))
        if 'category' in data:
            sets.append('category=%s')
            params.append((data['category'] or '').strip().upper())
        for field in ('latitude', 'longitude'):
            if field in data and _has_columns(cur, 'app_tourism_destinations', field):
                sets.append(f'{field}=%s')
                params.append(data[field])
        if 'price' in data:
            sets.append('price=%s')
            params.append(data['price'])
        for field in ('is_top_pick', 'is_trending', 'is_active'):
            if field in data:
                sets.append(f'{field}=%s')
                params.append(1 if str(data[field]).strip().lower() in ('1', 'true', 'yes') else 0)
        if 'sort_order' in data:
            sets.append('sort_order=%s')
            params.append(data['sort_order'])

        if not sets:
            return fail('No fields to update')

        params.append(code)
        cur.execute(
            f"UPDATE app_tourism_destinations SET {', '.join(sets)} WHERE code=%s",
            tuple(params))

        admin = data.get('_admin') or {}
        record_audit_log(cur, admin.get('id'), admin.get('role'), 'admin_update_destination',
                          'destination', code, {'updated_fields': [s.split('=')[0] for s in sets]}, ts)

        return ok({'status': True, 'code': code,
                   'updated_fields': [s.split('=')[0] for s in sets]})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'admin_update_destination error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def _load_catalog(cur):
    cur.execute(
        """SELECT id, code, name, price_local, price_foreign
           FROM app_tourism_services WHERE is_active = 1""")
    by_id = {}
    convenience = None
    for r in cur.fetchall():
        r['price_local'] = None if r['price_local'] is None else float(r['price_local'])
        r['price_foreign'] = None if r['price_foreign'] is None else float(r['price_foreign'])
        by_id[int(r['id'])] = r
        if r['code'] == 'CONVENIENCE_FEE':
            convenience = r
    return by_id, convenience


def submit_tourism_ipass(cur, data, files, ts):
    require(data, 'user_profile_id')
    user_id = data['user_profile_id']
    # Enforce one active pass per user (server-side mirror of the client
    # "Get iPass" gate). Retire lapsed passes first, then block if one is live.
    _expire_stale_ipass(cur, ts)
    if _has_active_ipass(cur, user_id):
        return fail('You already have an active iPass. You can register for a '
                    'new one once it has expired.')
    form = parse_form_data(data)
    require(form, 'email')

    guests = form.get('guests') or []
    catalog_by_id, convenience = _load_catalog(cur)
    lines, subtotal = tourism_pricing.compute_ipass_lines(
        catalog_by_id, form.get('services') or [], convenience)
    discount = max(0.0, float(form.get('discount') or 0))
    grand_total = tourism_pricing.compute_totals(subtotal, discount)

    reference_no = _gen_reference(cur)
    # qr_code lands in migration 034 — only generate/insert it when the column
    # exists so tenants on an older schema still submit successfully.
    has_qr = _has_columns(cur, 'app_tourism_ipass', 'qr_code')
    qr_code = _gen_qr_code(cur) if has_qr else None
    # expiration_date lands in migration 035 — same guard.
    has_exp = _has_columns(cur, 'app_tourism_ipass', 'expiration_date')
    expiration_date = _expiration_from(ts) if has_exp else None

    # selfie_url lands in migration 036 — only upload/insert when the column
    # exists, and only when a selfie file was actually sent (client enforces
    # that it is). Guarded so older tenants keep submitting successfully.
    has_selfie = _has_columns(cur, 'app_tourism_ipass', 'selfie_url')
    selfie_url = None
    selfie = _extract_selfie(files)
    if has_selfie and selfie is not None:
        from helpers.s3 import upload_to_s3
        content, ext, ctype = selfie
        selfie_url = upload_to_s3(
            content, f"tourism/ipass/selfie/{reference_no}.{ext}",
            content_type=ctype)

    cols = ['reference_no', 'user_profile_id', 'email', 'trip_type',
            'arrival_date', 'departure_date', 'hotel_accommodation',
            'rooms_count', 'purpose_of_travel', 'mode_of_travel', 'arrival_time',
            'guest_count', 'subtotal', 'discount', 'grand_total', 'status',
            'created_at']
    vals = [reference_no, user_id, form.get('email'),
            (form.get('trip_type') or 'ONE_WAY'),
            form.get('arrival_date') or None, form.get('departure_date') or None,
            form.get('hotel_accommodation'), int(form.get('rooms_count') or 1),
            form.get('purpose_of_travel'), form.get('mode_of_travel'),
            form.get('arrival_time') or None,
            int(form.get('guest_count') or len(guests) or 1),
            subtotal, discount, grand_total, 'PENDING_PAYMENT', ts]
    if has_qr:
        cols.insert(1, 'qr_code')
        vals.insert(1, qr_code)
    if has_exp:
        cols.append('expiration_date')
        vals.append(expiration_date)
    if has_selfie:
        cols.append('selfie_url')
        vals.append(selfie_url)
    placeholders = ','.join(['%s'] * len(cols))
    cur.execute(
        f"INSERT INTO app_tourism_ipass ({','.join(cols)}) "
        f"VALUES ({placeholders})",
        vals)
    ipass_id = cur.lastrowid

    for g in guests:
        cur.execute(
            """INSERT INTO app_tourism_ipass_guests
               (ipass_id, is_main_guest, first_name, middle_name, last_name,
                suffix, age, gender, guest_type, contact_type, contact_value, address)
               VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)""",
            (ipass_id, 1 if g.get('is_main_guest') else 0,
             g.get('first_name'), g.get('middle_name'), g.get('last_name'),
             g.get('suffix'), g.get('age') or None, g.get('gender'),
             (g.get('guest_type') or 'LOCAL'), g.get('contact_type'),
             g.get('contact_value'), g.get('address')))

    for ln in lines:
        cur.execute(
            """INSERT INTO app_tourism_ipass_services
               (ipass_id, service_id, service_code, service_name, unit_price,
                quantity, line_total, variant_label)
               VALUES (%s,%s,%s,%s,%s,%s,%s,%s)""",
            (ipass_id, ln['service_id'], ln['service_code'], ln['service_name'],
             ln['unit_price'], ln['quantity'], ln['line_total'], ln['variant_label']))

    return ok({'status': True, 'ipass_id': ipass_id,
               'reference_no': reference_no, 'qr_code': qr_code,
               'expiration_date': expiration_date,
               'subtotal': subtotal, 'discount': discount,
               'grand_total': grand_total,
               'payment_status': 'PENDING_PAYMENT',
               'selfie_url': selfie_url})


def get_tourism_ipass(cur, data, files, ts):
    require(data, 'user_profile_id')
    # Retire any lapsed unpaid passes so the list reflects EXPIRED status.
    _expire_stale_ipass(cur, ts)
    # qr_code / expiration_date land in migrations 034 / 035 — only select them
    # when present so older tenants keep returning a working list.
    qr = ', qr_code' if _has_columns(
        cur, 'app_tourism_ipass', 'qr_code') else ''
    exp = ', expiration_date' if _has_columns(
        cur, 'app_tourism_ipass', 'expiration_date') else ''
    cur.execute(
        f"""SELECT id, reference_no{qr}, email, trip_type, arrival_date,
                   grand_total, status{exp}, created_at
            FROM app_tourism_ipass
            WHERE user_profile_id = %s
            ORDER BY created_at DESC""",
        (data['user_profile_id'],))
    rows = [serialize_row(r) for r in cur.fetchall()]
    return ok({'status': True, 'ipass': rows})


def check_tourism_ipass(cur, data, files, ts):
    """Gate the 'Get iPass' button: a user may start a new booking only when
    they have no prior pass, or their most recent pass has EXPIRED. An active
    pass (PENDING_PAYMENT / PAID / CANCELLED, i.e. not expired) blocks a new one.

    Returns `can_create` plus the blocking record (when any) so the client can
    explain why the button is gated."""
    require(data, 'user_profile_id')
    # Flip lapsed unpaid passes to EXPIRED first so the check is accurate.
    _expire_stale_ipass(cur, ts)
    exp = ', expiration_date' if _has_columns(
        cur, 'app_tourism_ipass', 'expiration_date') else ''
    cur.execute(
        f"""SELECT id, reference_no, status{exp}, grand_total, created_at
            FROM app_tourism_ipass
            WHERE user_profile_id = %s
            ORDER BY created_at DESC
            LIMIT 1""",
        (data['user_profile_id'],))
    row = cur.fetchone()
    has_data = row is not None
    # No prior pass, or the latest one has expired → allow a new booking.
    can_create = (not has_data) or (str(row.get('status')) == 'EXPIRED')
    return ok({'status': True,
               'has_data': has_data,
               'can_create': can_create,
               'active': None if can_create else serialize_row(row)})


def admin_list_ipass(cur, data, files, ts):
    try:
        page = max(parse_int(data.get('page')) or 1, 1)
        limit = min(max(parse_int(data.get('limit')) or 20, 1), 100)
        offset = (page - 1) * limit
        status = (data.get('status') or '').strip().upper()

        where = []
        params = []
        if status and status != 'ALL':
            if status not in _IPASS_STATUSES:
                return fail(f'Invalid status: {status}')
            where.append('status=%s')
            params.append(status)
        clause = ('WHERE ' + ' AND '.join(where)) if where else ''

        qr = ', qr_code' if _has_columns(cur, 'app_tourism_ipass', 'qr_code') else ''
        exp = ', expiration_date' if _has_columns(cur, 'app_tourism_ipass', 'expiration_date') else ''

        cur.execute(f"""
            SELECT id, reference_no{qr}, user_profile_id, email, trip_type,
                   arrival_date, departure_date, guest_count, grand_total,
                   status{exp}, created_at
            FROM app_tourism_ipass
            {clause}
            ORDER BY created_at DESC
            LIMIT %s OFFSET %s
        """, tuple(params + [limit + 1, offset]))
        rows = cur.fetchall() or []
        has_more = len(rows) > limit
        rows = rows[:limit]
        for r in rows:
            r['status'] = _effective_ipass_status(r, ts, bool(exp))
        return ok({'status': True,
                   'data': {'items': [serialize_row(r) for r in rows],
                            'page': page, 'has_more': has_more}})
    except Exception as e:
        logger.error(f'admin_list_ipass error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def verify_ipass_qr(cur, data, files, ts):
    try:
        require(data, 'code')
        code = (data['code'] or '').strip()
        has_qr = _has_columns(cur, 'app_tourism_ipass', 'qr_code')
        exp = ', expiration_date' if _has_columns(cur, 'app_tourism_ipass', 'expiration_date') else ''

        if has_qr:
            cur.execute(f"""
                SELECT id, reference_no, qr_code, user_profile_id, email, trip_type,
                       arrival_date, departure_date, guest_count, grand_total,
                       status{exp}, created_at
                FROM app_tourism_ipass
                WHERE reference_no=%s OR qr_code=%s
                LIMIT 1
            """, (code, code))
        else:
            cur.execute(f"""
                SELECT id, reference_no, user_profile_id, email, trip_type,
                       arrival_date, departure_date, guest_count, grand_total,
                       status{exp}, created_at
                FROM app_tourism_ipass
                WHERE reference_no=%s
                LIMIT 1
            """, (code,))
        row = cur.fetchone()
        if not row:
            return ok({'status': True, 'data': {'found': False}})
        row['status'] = _effective_ipass_status(row, ts, bool(exp))

        ipass_id = row['id']
        cur.execute("""
            SELECT is_main_guest, first_name, middle_name, last_name, suffix,
                   age, gender, guest_type, contact_type, contact_value, address
            FROM app_tourism_ipass_guests WHERE ipass_id=%s
            ORDER BY is_main_guest DESC, id
        """, (ipass_id,))
        guests = [serialize_row(g) for g in cur.fetchall()]

        cur.execute("""
            SELECT service_code, service_name, unit_price, quantity, line_total,
                   variant_label
            FROM app_tourism_ipass_services WHERE ipass_id=%s
        """, (ipass_id,))
        services = [serialize_row(s) for s in cur.fetchall()]

        data_out = serialize_row(row)
        data_out['guests'] = guests
        data_out['services'] = services
        return ok({'status': True, 'data': {'found': True, 'data': data_out}})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'verify_ipass_qr error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


# ── Destination booking ──────────────────────────────────────────────────────
def _gen_booking_reference(cur):
    """Unique BK-XXXXXXXX reference. Re-rolls until unused."""
    while True:
        num = ''.join(str(random.randint(0, 9)) for _ in range(8))
        ref = f'BK-{num}'
        cur.execute(
            "SELECT COUNT(*) AS c FROM app_tourism_bookings WHERE reference_no=%s",
            (ref,))
        if cur.fetchone()['c'] == 0:
            return ref


def _gen_booking_qr(cur):
    """Unique 32-hex QR token for a booking. Re-rolls until unused."""
    while True:
        token = uuid.uuid4().hex.upper()
        cur.execute(
            "SELECT COUNT(*) AS c FROM app_tourism_bookings WHERE qr_code=%s",
            (token,))
        if cur.fetchone()['c'] == 0:
            return token


def _nights_between(check_in, check_out):
    """Whole nights between two YYYY-MM-DD strings; floored at 1."""
    try:
        ci = datetime.strptime(check_in, '%Y-%m-%d')
        co = datetime.strptime(check_out, '%Y-%m-%d')
        return max(1, (co - ci).days)
    except (ValueError, TypeError):
        return 1


def _table_exists(cur, table):
    cur.execute(
        "SELECT COUNT(*) AS c FROM information_schema.TABLES "
        "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = %s", (table,))
    return cur.fetchone()['c'] > 0


def _booking_quote_from_form(cur, form):
    """Resolve the room and compute the price breakdown for a booking form.
    Returns ((room_row, breakdown), None) or (None, fail_response)."""
    require(form, 'room_id')
    cur.execute(
        "SELECT id, destination_id, destination_code, name, price_per_night "
        "FROM app_tourism_rooms WHERE id=%s", (int(form['room_id']),))
    room = cur.fetchone()
    if room is None:
        return None, fail('Room not found')
    nights = _nights_between(form.get('check_in_date'), form.get('check_out_date'))
    breakdown = tourism_pricing.compute_booking_total(
        room['price_per_night'], nights, form.get('promo_code'))
    return (room, breakdown), None


def get_tourism_rooms(cur, data, files, ts):
    """Active room types for a destination (by code), ordered for display.
    Returns an empty list on tenants that haven't run migration 037."""
    require(data, 'destination_code')
    if not _table_exists(cur, 'app_tourism_rooms'):
        return ok({'status': True, 'rooms': []})
    cur.execute(
        """SELECT id, destination_code, code, name, bed_type, view_type,
                  inclusions, price_per_night, image_url, sort_order
           FROM app_tourism_rooms
           WHERE destination_code=%s AND is_active=1
           ORDER BY sort_order ASC, id ASC""",
        (data['destination_code'],))
    rows = [serialize_row(r) for r in cur.fetchall()]
    return ok({'status': True, 'rooms': rows})


def quote_tourism_booking(cur, data, files, ts):
    """Compute the price breakdown for display on the Order Summary. No persist."""
    form = parse_form_data(data)
    res, err = _booking_quote_from_form(cur, form)
    if err:
        return err
    _room, breakdown = res
    return ok({'status': True, **breakdown})


def create_tourism_booking(cur, data, files, ts):
    """Persist a confirmed booking. Recomputes the breakdown server-side, snapshots
    the destination + room, and returns the reference, QR, and breakdown."""
    require(data, 'user_profile_id')
    form = parse_form_data(data)
    res, err = _booking_quote_from_form(cur, form)
    if err:
        return err
    room, breakdown = res
    cur.execute(
        "SELECT id, code, name, image_url, location "
        "FROM app_tourism_destinations WHERE id=%s", (room['destination_id'],))
    dest = cur.fetchone() or {}
    reference_no = _gen_booking_reference(cur)
    qr_code = _gen_booking_qr(cur)
    cols = ['reference_no', 'qr_code', 'user_profile_id', 'destination_id',
            'destination_code', 'destination_name', 'room_id', 'room_name',
            'nightly_rate', 'check_in_date', 'check_out_date', 'nights', 'adults',
            'children', 'guest_first_name', 'guest_middle_name', 'guest_last_name',
            'guest_suffix', 'guest_age', 'guest_gender', 'guest_type',
            'contact_email', 'contact_number', 'special_requests', 'room_subtotal',
            'room_upgrade_discount', 'promo_code', 'promo_discount', 'tourism_tax',
            'vat', 'total', 'status', 'created_at']
    vals = [reference_no, qr_code, data['user_profile_id'], room['destination_id'],
            room['destination_code'], dest.get('name'), room['id'], room['name'],
            breakdown['nightly_rate'], form.get('check_in_date') or None,
            form.get('check_out_date') or None, breakdown['nights'],
            int(form.get('adults') or 1), int(form.get('children') or 0),
            form.get('guest_first_name'), form.get('guest_middle_name'),
            form.get('guest_last_name'), form.get('guest_suffix'),
            form.get('guest_age') or None, form.get('guest_gender'),
            (form.get('guest_type') or 'LOCAL'), form.get('contact_email'),
            form.get('contact_number'), form.get('special_requests'),
            breakdown['room_subtotal'], breakdown['room_upgrade_discount'],
            breakdown['promo_code'], breakdown['promo_discount'],
            breakdown['tourism_tax'], breakdown['vat'], breakdown['total'],
            'PENDING_PAYMENT', ts]
    # destination_image_url/location land in migration 039 — only insert when the
    # columns exist so a tenant mid-migration still books successfully.
    if _has_columns(cur, 'app_tourism_bookings', 'destination_image_url'):
        cols += ['destination_image_url', 'destination_location']
        vals += [dest.get('image_url'), dest.get('location')]
    placeholders = ','.join(['%s'] * len(cols))
    cur.execute(
        f"INSERT INTO app_tourism_bookings ({','.join(cols)}) "
        f"VALUES ({placeholders})", vals)
    booking_id = cur.lastrowid
    return ok({'status': True, 'booking_id': booking_id,
               'reference_no': reference_no, 'qr_code': qr_code,
               'booking_status': 'PENDING_PAYMENT', **breakdown})


def get_tourism_bookings(cur, data, files, ts):
    """A user's bookings, newest first. Empty on tenants without migration 038."""
    require(data, 'user_profile_id')
    if not _table_exists(cur, 'app_tourism_bookings'):
        return ok({'status': True, 'bookings': []})
    cur.execute(
        """SELECT id, reference_no, qr_code, destination_name, room_name,
                  check_in_date, check_out_date, nights, adults, children,
                  total, status, created_at
           FROM app_tourism_bookings WHERE user_profile_id=%s
           ORDER BY created_at DESC""",
        (data['user_profile_id'],))
    rows = [serialize_row(r) for r in cur.fetchall()]
    return ok({'status': True, 'bookings': rows})


def check_tourism_booking(cur, data, files, ts):
    """Gate the destination 'Book Now' button: a user may start a new booking for a
    given destination only when they have no active (non-CANCELLED) booking for THAT
    destination — booking other destinations stays allowed. Pass `destination_code`
    to scope the check; omit it for a global check. Returns can_create plus the
    blocking active booking row (when any). Mirrors check_tourism_ipass."""
    require(data, 'user_profile_id')
    if not _table_exists(cur, 'app_tourism_bookings'):
        return ok({'status': True, 'has_data': False,
                   'can_create': True, 'active': None})
    params = [data['user_profile_id']]
    dest_filter = ''
    destination_code = (data.get('destination_code') or '').strip()
    if destination_code:
        dest_filter = ' AND destination_code=%s'
        params.append(destination_code)
    cur.execute(
        f"""SELECT * FROM app_tourism_bookings
            WHERE user_profile_id=%s{dest_filter} AND status != 'CANCELLED'
            ORDER BY created_at DESC
            LIMIT 1""",
        tuple(params))
    row = cur.fetchone()
    has_data = row is not None
    can_create = not has_data
    return ok({'status': True, 'has_data': has_data, 'can_create': can_create,
               'active': None if can_create else serialize_row(row)})


def cancel_tourism_booking(cur, data, files, ts):
    """Cancel a user's booking (status=CANCELLED), freeing the booking gate.
    Scoped by user_profile_id so one user cannot cancel another's booking."""
    require(data, 'user_profile_id', 'booking_id')
    booking_id = int(data['booking_id'])
    cur.execute(
        "UPDATE app_tourism_bookings SET status='CANCELLED' "
        "WHERE id=%s AND user_profile_id=%s",
        (booking_id, data['user_profile_id']))
    return ok({'status': True, 'booking_id': booking_id,
               'booking_status': 'CANCELLED'})


def confirm_tourism_booking_payment(cur, data, files, ts):
    """Flip a PENDING_PAYMENT booking to CONFIRMED once its PayMongo checkout
    has settled. The booking's own `reference_no` was passed as the checkout's
    `reference_number`, so we look up the paid session by that rather than
    trusting the client's success/cancel signal — `app_paymongo_sessions` is
    kept in sync by check_paymongo_status, which the client always calls right
    after the checkout WebView closes, before this action ever runs."""
    require(data, 'user_profile_id', 'booking_id')
    booking_id = int(data['booking_id'])
    cur.execute(
        "SELECT id, reference_no, total, status FROM app_tourism_bookings "
        "WHERE id=%s AND user_profile_id=%s",
        (booking_id, data['user_profile_id']))
    booking = cur.fetchone()
    if booking is None:
        return fail('Booking not found')
    if booking['status'] == 'CONFIRMED':
        return ok({'status': True, 'booking_id': booking_id,
                   'booking_status': 'CONFIRMED'})
    if booking['status'] != 'PENDING_PAYMENT':
        return fail(f"Booking is {booking['status']}, cannot confirm payment")

    cur.execute(
        "SELECT amount_centavos FROM app_paymongo_sessions "
        "WHERE reference_number=%s AND status='paid' "
        "ORDER BY updated_at DESC LIMIT 1",
        (booking['reference_no'],))
    session = cur.fetchone()
    if session is None:
        return fail('Payment not confirmed for this booking')
    expected_centavos = int(round(float(booking['total']) * 100))
    if int(session['amount_centavos']) < expected_centavos:
        return fail('Paid amount does not match booking total')

    cur.execute(
        "UPDATE app_tourism_bookings SET status='CONFIRMED' "
        "WHERE id=%s AND user_profile_id=%s AND status='PENDING_PAYMENT'",
        (booking_id, data['user_profile_id']))
    return ok({'status': True, 'booking_id': booking_id,
               'booking_status': 'CONFIRMED'})
