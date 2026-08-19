import logging
import uuid
from datetime import datetime, date

from pymysql.cursors import DictCursor

from helpers.auth import ok, fail, require
from helpers.audit import record_audit_log
from helpers.db import (
    sanitize, serialize_row, get_conn, ALLOWED_DBS, AUTH_DB,
)
from helpers.forms import parse_int
from helpers.s3 import upload_to_s3, generate_key
from endpoints import peso_application

logger = logging.getLogger()


# SELECT for a job posting joined to its company, used by the cross-tenant
# `list_jobs_universal` feed. Mirrors the projection in the single-tenant
# `list_job_postings`/`get_job_posting_detail` — keep them in sync if columns
# change.
_POSTING_SELECT = """
    SELECT p.id, p.title, p.description, p.department, p.location,
           p.employment_type, p.salary_min, p.salary_max, p.requirements,
           p.posted_at, p.closes_at, p.status,
           p.company_id,
           c.registered_company_name AS company_name,
           c.company_logo_url        AS company_logo_url,
           c.industry_sector         AS company_about,
           c.website                 AS company_website,
           TRIM(BOTH ', ' FROM CONCAT_WS(', ', c.address_street,
                c.barangay, c.city_municipality, c.province))
                                     AS company_address,
           c.official_email          AS company_contact_email,
           c.telephone_number        AS company_contact_phone,
           c.status                  AS company_status
    FROM app_job_postings p
    LEFT JOIN app_companies c ON c.id = p.company_id
"""

# Friendly LGU names for known tenant DBs; unknown DBs fall back to a
# title-cased version of the db_name (e.g. `tarlac_db` → `Tarlac`).
_LGU_LABELS = {
    'cebu_lgu_db': 'Cebu',
    'csjdm_lgu_db': 'CSJDM',
    'bataan_db': 'Bataan',
    'district_6_db': 'District 6',
    'universal_lgu_db': 'Universal',
}

_JOB_POSTING_STATUSES = {'PENDING', 'OPEN', 'CLOSED', 'FILLED', 'REJECTED'}
_JOB_POSTING_EMPLOYMENT_TYPES = {'FULL_TIME', 'PART_TIME', 'CONTRACT', 'INTERNSHIP'}


def _lgu_label(db_name):
    if db_name in _LGU_LABELS:
        return _LGU_LABELS[db_name]
    base = db_name.replace('_db', '').replace('_', ' ').strip()
    return base.title() or db_name


def _ref_number():
    return 'JA' + datetime.now().strftime('%Y%m%d') + uuid.uuid4().hex[:6].upper()


def _is_truthy(v):
    if v is None:
        return False
    return str(v).strip().lower() in ('1', 'true', 'yes', 'y', 't')


def _applicant_snapshot(cur, user_id):
    """Pull identity fields from app_users to snapshot onto the application."""
    try:
        cur.execute("""
            SELECT first_name, last_name, mobile_number, email_address
            FROM app_users WHERE id=%s LIMIT 1
        """, (user_id,))
    except Exception:
        cur.execute("SELECT * FROM app_users WHERE id=%s LIMIT 1", (user_id,))
    row = cur.fetchone() or {}
    fn = (row.get('first_name') or '').strip() if isinstance(row, dict) else ''
    ln = (row.get('last_name') or '').strip() if isinstance(row, dict) else ''
    name = (f'{fn} {ln}').strip() or 'Anonymous'
    mobile = (row.get('mobile_number') or '') if isinstance(row, dict) else ''
    email = (row.get('email_address') or '') if isinstance(row, dict) else ''
    return name, mobile, email


def _upload_resume(files, user_id, ref):
    """Pull the first file with field_name 'resume' from the multipart payload."""
    for f in files or []:
        field = (f.get('field_name') or '').strip()
        if field != 'resume':
            continue
        f['content'].seek(0)
        content = f['content'].read()
        filename = f.get('filename') or 'resume.pdf'
        key = generate_key(
            f'job_applications/{user_id}/{ref}', user_id, filename,
        )
        ctype = 'application/pdf' if filename.lower().endswith('.pdf') else 'image/jpeg'
        return upload_to_s3(content, key, content_type=ctype)
    return ''


def list_job_postings(cur, data, files, ts):
    """Return active (status='OPEN') job postings, newest first."""
    try:
        try:
            limit = int(data.get('limit') or 50)
        except (TypeError, ValueError):
            limit = 50
        try:
            offset = int(data.get('offset') or 0)
        except (TypeError, ValueError):
            offset = 0
        limit = max(1, min(limit, 200))
        offset = max(0, offset)
        logger.info(f'list_job_postings: limit={limit} offset={offset}')

        cur.execute("""
            SELECT p.id, p.title, p.description, p.department, p.location,
                   p.employment_type, p.salary_min, p.salary_max, p.requirements,
                   p.posted_at, p.closes_at, p.status,
                   p.company_id,
                   c.registered_company_name AS company_name,
                   c.company_logo_url        AS company_logo_url,
                   c.industry_sector         AS company_about,
                   c.website                 AS company_website,
                   TRIM(BOTH ', ' FROM CONCAT_WS(', ', c.address_street,
                        c.barangay, c.city_municipality, c.province))
                                             AS company_address,
                   c.official_email          AS company_contact_email,
                   c.telephone_number        AS company_contact_phone,
                   c.status                  AS company_status
            FROM app_job_postings p
            LEFT JOIN app_companies c ON c.id = p.company_id
            WHERE p.status='OPEN'
            ORDER BY p.posted_at DESC, p.id DESC
            LIMIT %s OFFSET %s
        """, (limit, offset))
        rows = cur.fetchall()
        logger.info(f'list_job_postings: returning {len(rows)} posting(s)')
        return ok({
            'status': True,
            'postings': [serialize_row(r) for r in rows],
            'limit': limit,
            'offset': offset,
        })
    except Exception as e:
        logger.error(f'list_job_postings error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def admin_list_job_postings(cur, data, files, ts):
    try:
        page = max(parse_int(data.get('page')) or 1, 1)
        limit = min(max(parse_int(data.get('limit')) or 20, 1), 100)
        offset = (page - 1) * limit
        status = (data.get('status') or '').strip().upper()
        employment_type = (data.get('employment_type') or '').strip().upper()
        search = sanitize(data.get('search'))
        date_from = sanitize(data.get('date_from'))
        date_to = sanitize(data.get('date_to'))

        where = []
        params = []
        if status and status != 'ALL':
            if status not in _JOB_POSTING_STATUSES:
                return fail(f'Invalid status: {status}')
            where.append('status=%s')
            params.append(status)
        if employment_type and employment_type != 'ALL':
            if employment_type not in _JOB_POSTING_EMPLOYMENT_TYPES:
                return fail(f'Invalid employment_type: {employment_type}')
            where.append('employment_type=%s')
            params.append(employment_type)
        if search:
            like = f'%{search}%'
            where.append('(title LIKE %s OR department LIKE %s)')
            params += [like, like]
        if date_from:
            where.append('posted_at >= %s')
            params.append(date_from)
        if date_to:
            where.append('posted_at <= %s')
            params.append(f'{date_to} 23:59:59')
        clause = ('WHERE ' + ' AND '.join(where)) if where else ''

        cur.execute(f"""
            SELECT id, title, department, location, employment_type,
                   salary_min, salary_max, posted_at, closes_at, status,
                   company_id, reviewed_by, reviewed_at, review_remarks
            FROM app_job_postings
            {clause}
            ORDER BY posted_at DESC, id DESC
            LIMIT %s OFFSET %s
        """, tuple(params + [limit + 1, offset]))
        rows = cur.fetchall() or []
        has_more = len(rows) > limit
        rows = rows[:limit]

        cur.execute("SELECT status, COUNT(*) AS c FROM app_job_postings GROUP BY status")
        raw_counts = {row['status']: row['c'] for row in cur.fetchall()}
        stat_counts = {s: raw_counts.get(s, 0) for s in _JOB_POSTING_STATUSES}
        stat_counts['ALL'] = sum(stat_counts.values())

        return ok({'status': True,
                   'data': {'items': [serialize_row(r) for r in rows],
                            'page': page, 'has_more': has_more,
                            'counts': stat_counts}})
    except Exception as e:
        logger.error(f'admin_list_job_postings error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def admin_get_job_posting_detail(cur, data, files, ts):
    try:
        require(data, 'id')
        posting_id = data['id']

        cur.execute(_POSTING_SELECT + " WHERE p.id=%s LIMIT 1", (posting_id,))
        row = cur.fetchone()
        if not row:
            return fail('Job posting not found', 404)

        cur.execute("""
            SELECT reviewed_by, reviewed_at, review_remarks
            FROM app_job_postings WHERE id=%s
        """, (posting_id,))
        review = cur.fetchone() or {}

        detail = serialize_row(row)
        detail.update(serialize_row(review))
        return ok({'status': True, 'data': detail})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'admin_get_job_posting_detail error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def admin_review_job_posting(cur, data, files, ts):
    try:
        require(data, 'id', 'decision')
        posting_id = data['id']
        decision = (data['decision'] or '').strip().upper()
        if decision not in _JOB_POSTING_STATUSES:
            return fail('Invalid decision')
        remarks = sanitize(data.get('remarks'))
        if decision == 'REJECTED' and not remarks:
            return fail('remarks is required when rejecting')

        cur.execute("SELECT id FROM app_job_postings WHERE id=%s", (posting_id,))
        if not cur.fetchone():
            return fail('Job posting not found', 404)

        admin = data.get('_admin') or {}
        cur.execute("""
            UPDATE app_job_postings
               SET status=%s, reviewed_by=%s, reviewed_at=%s, review_remarks=%s
             WHERE id=%s
        """, (decision, admin.get('id'), ts, remarks, posting_id))

        record_audit_log(cur, admin.get('id'), admin.get('role'),
                          'admin_review_job_posting', 'job_posting',
                          posting_id, {'decision': decision}, ts)

        return ok({'status': True, 'message': f'Job posting {decision.lower()}'})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'admin_review_job_posting error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


_JOB_POSTING_EDITABLE_FIELDS = (
    'title', 'department', 'location', 'employment_type',
    'salary_min', 'salary_max', 'description', 'requirements', 'closes_at',
)


def admin_update_job_posting(cur, data, files, ts):
    """Edit a job posting's own fields (title/department/salary/etc). Status
    changes go through `admin_review_job_posting` instead, since those carry
    reviewer/remarks bookkeeping."""
    try:
        require(data, 'id')
        posting_id = data['id']

        cur.execute("SELECT id FROM app_job_postings WHERE id=%s", (posting_id,))
        if not cur.fetchone():
            return fail('Job posting not found', 404)

        employment_type = data.get('employment_type')
        if employment_type is not None:
            employment_type = (employment_type or '').strip().upper()
            if employment_type and employment_type not in _JOB_POSTING_EMPLOYMENT_TYPES:
                return fail(f'Invalid employment_type: {employment_type}')

        sets = []
        params = []
        for field in _JOB_POSTING_EDITABLE_FIELDS:
            if field not in data:
                continue
            val = data.get(field)
            if field in ('salary_min', 'salary_max'):
                val = parse_int(val) if val not in (None, '') else None
            elif field == 'employment_type':
                val = employment_type or None
            elif isinstance(val, str):
                val = sanitize(val.strip()) or None
            sets.append(f'{field}=%s')
            params.append(val)

        if not sets:
            return fail('No editable fields provided')

        params.append(posting_id)
        cur.execute(f"""
            UPDATE app_job_postings SET {', '.join(sets)} WHERE id=%s
        """, tuple(params))

        admin = data.get('_admin') or {}
        record_audit_log(cur, admin.get('id'), admin.get('role'),
                          'admin_update_job_posting', 'job_posting',
                          posting_id, {'fields': [f for f in _JOB_POSTING_EDITABLE_FIELDS if f in data]}, ts)

        return ok({'status': True, 'message': 'Job posting updated'})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'admin_update_job_posting error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def admin_delete_job_posting(cur, data, files, ts):
    try:
        require(data, 'id')
        posting_id = data['id']

        cur.execute("SELECT title FROM app_job_postings WHERE id=%s", (posting_id,))
        row = cur.fetchone()
        if not row:
            return fail('Job posting not found', 404)

        cur.execute("DELETE FROM app_job_postings WHERE id=%s", (posting_id,))

        admin = data.get('_admin') or {}
        record_audit_log(cur, admin.get('id'), admin.get('role'),
                          'admin_delete_job_posting', 'job_posting',
                          posting_id, {'title': row['title']}, ts)

        return ok({'status': True, 'id': str(posting_id)})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'admin_delete_job_posting error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def list_jobs_universal(cur, data, files, ts):
    """Aggregate OPEN job postings across EVERY LGU tenant database.

    Unlike `list_job_postings` (scoped to the single tenant DB named in the
    request's `db_name`), this endpoint fans out across all allowlisted tenant
    DBs, reads each one's `app_job_postings`/`app_companies`, and merges the
    rows into a single feed sorted newest-first — every posting tagged with its
    source LGU (`source_db` + `lgu`).

    It is driven entirely by `ALLOWED_DBS`, so onboarding a new LGU is just an
    env change (no code edit). DBs missing the jobs tables are skipped rather
    than failing the whole request. The shared identity DB (`AUTH_DB`) is
    excluded since it holds no postings.

    Optional fields:
      - `limit`  (default 50, max 200) — page size of the merged result.
      - `offset` (default 0)           — page offset into the merged result.
    """
    try:
        try:
            limit = int(data.get('limit') or 50)
        except (TypeError, ValueError):
            limit = 50
        try:
            offset = int(data.get('offset') or 0)
        except (TypeError, ValueError):
            offset = 0
        limit = max(1, min(limit, 200))
        offset = max(0, offset)

        target_dbs = sorted(d for d in ALLOWED_DBS if d != AUTH_DB)
        logger.info(
            f'list_jobs_universal: limit={limit} offset={offset} '
            f'scanning {len(target_dbs)} DB(s): {target_dbs}'
        )

        sql = _POSTING_SELECT + """
            WHERE p.status='OPEN'
            ORDER BY p.posted_at DESC, p.id DESC
            LIMIT %s
        """
        # Pull enough from each DB to satisfy the global page once merged.
        per_db_cap = offset + limit

        merged = []   # (posted_at, id, serialized_row)
        sources = []  # diagnostics: which DBs answered and with how many rows

        for db in target_dbs:
            try:
                conn = get_conn(db)
                c = conn.cursor(DictCursor)
                c.execute(sql, (per_db_cap,))
                rows = c.fetchall() or []
            except Exception as e:
                logger.warning(f'list_jobs_universal: skipping {db}: {e}')
                continue

            logger.info(f'list_jobs_universal: {db} -> {len(rows)} posting(s)')
            label = _lgu_label(db)
            for r in rows:
                posted = r.get('posted_at')
                # Normalize to datetime so the cross-DB sort never compares
                # date vs datetime (a TypeError in Python 3).
                if isinstance(posted, date) and not isinstance(posted, datetime):
                    posted = datetime(posted.year, posted.month, posted.day)
                if not isinstance(posted, datetime):
                    posted = datetime.min
                try:
                    rid = int(r.get('id') or 0)
                except (TypeError, ValueError):
                    rid = 0
                row = serialize_row(r)
                row['source_db'] = db
                row['lgu'] = label
                merged.append((posted, rid, row))
            sources.append({'db_name': db, 'lgu': label, 'count': len(rows)})

        merged.sort(key=lambda t: (t[0], t[1]), reverse=True)
        page = [row for _, _, row in merged[offset:offset + limit]]
        logger.info(
            f'list_jobs_universal: merged {len(merged)} total, '
            f'returning {len(page)}; sources={sources}'
        )

        return ok({
            'status': True,
            'postings': page,
            'count': len(page),
            'total': len(merged),
            'sources': sources,
            'limit': limit,
            'offset': offset,
        })
    except Exception as e:
        logger.error(f'list_jobs_universal error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def get_job_posting_detail(cur, data, files, ts):
    try:
        require(data, 'job_posting_id')
        try:
            posting_id = int(data['job_posting_id'])
        except (TypeError, ValueError):
            return fail('Invalid job_posting_id')
        logger.info(f'get_job_posting_detail: job_posting_id={posting_id}')

        cur.execute("""
            SELECT p.id, p.title, p.description, p.department, p.location,
                   p.employment_type, p.salary_min, p.salary_max, p.requirements,
                   p.posted_at, p.closes_at, p.status,
                   p.company_id,
                   c.registered_company_name AS company_name,
                   c.company_logo_url        AS company_logo_url,
                   c.industry_sector         AS company_about,
                   c.website                 AS company_website,
                   TRIM(BOTH ', ' FROM CONCAT_WS(', ', c.address_street,
                        c.barangay, c.city_municipality, c.province))
                                             AS company_address,
                   c.official_email          AS company_contact_email,
                   c.telephone_number        AS company_contact_phone,
                   c.status                  AS company_status
            FROM app_job_postings p
            LEFT JOIN app_companies c ON c.id = p.company_id
            WHERE p.id=%s LIMIT 1
        """, (posting_id,))
        row = cur.fetchone()
        if not row:
            logger.info(f'get_job_posting_detail: posting {posting_id} not found')
            return fail('Job posting not found', 404)
        logger.info(f'get_job_posting_detail: found posting {posting_id}')
        return ok({'status': True, 'data': serialize_row(row)})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'get_job_posting_detail error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def _ensure_job_favorites_table(cur):
    """Create the per-user job favorites table on first use. Lets the shared
    lambda serve tenants that haven't run migration 041 yet — the table is
    created lazily and idempotently (CREATE TABLE IF NOT EXISTS is a no-op
    afterwards). Mirrors tourism.py's `_ensure_favorites_table`."""
    cur.execute(
        """CREATE TABLE IF NOT EXISTS `app_job_favorites` (
             `id` INT AUTO_INCREMENT PRIMARY KEY,
             `user_profile_id` VARCHAR(64) NOT NULL,
             `job_posting_id` BIGINT UNSIGNED NOT NULL,
             `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
             UNIQUE KEY `uniq_user_job` (`user_profile_id`, `job_posting_id`),
             KEY `idx_user` (`user_profile_id`)
           ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci""")


def get_job_favorites(cur, data, files, ts):
    """Job posting ids the given user has bookmarked, newest first."""
    try:
        require(data, 'user_profile_id')
        _ensure_job_favorites_table(cur)
        cur.execute(
            "SELECT job_posting_id FROM app_job_favorites "
            "WHERE user_profile_id = %s ORDER BY id DESC",
            (data['user_profile_id'],))
        ids = [r['job_posting_id'] for r in cur.fetchall()]
        return ok({'status': True, 'favorites': ids})
    except Exception as e:
        logger.error(f'get_job_favorites error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def toggle_job_favorite(cur, data, files, ts):
    """Add or remove a job posting from the user's favorites. `is_favorite`
    sets the desired state ('1' add / '0' remove); omit it to flip the
    current state. Returns the resulting state so the client can reconcile."""
    try:
        require(data, 'user_profile_id', 'job_posting_id')
        try:
            posting_id = int(data['job_posting_id'])
        except (TypeError, ValueError):
            return fail('Invalid job_posting_id')
        _ensure_job_favorites_table(cur)
        user_id = data['user_profile_id']
        desired = data.get('is_favorite')
        if desired is None or str(desired).strip() == '':
            cur.execute(
                "SELECT id FROM app_job_favorites "
                "WHERE user_profile_id = %s AND job_posting_id = %s",
                (user_id, posting_id))
            is_fav = cur.fetchone() is None  # not currently favorited → add it
        else:
            is_fav = str(desired).strip().lower() in ('1', 'true', 'yes')
        if is_fav:
            cur.execute(
                "INSERT INTO app_job_favorites "
                "(user_profile_id, job_posting_id, created_at) "
                "VALUES (%s, %s, %s) "
                "ON DUPLICATE KEY UPDATE job_posting_id = VALUES(job_posting_id)",
                (user_id, posting_id, ts))
        else:
            cur.execute(
                "DELETE FROM app_job_favorites "
                "WHERE user_profile_id = %s AND job_posting_id = %s",
                (user_id, posting_id))
        return ok({'status': True, 'job_posting_id': posting_id, 'is_favorite': is_fav})
    except Exception as e:
        logger.error(f'toggle_job_favorite error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def submit_job_application(cur, data, files, ts):
    try:
        require(data, 'user_profile_id', 'job_posting_id', 'cover_letter')
        user_id = data['user_profile_id']

        try:
            posting_id = int(data['job_posting_id'])
        except (TypeError, ValueError):
            return fail('Invalid job_posting_id')
        logger.info(
            f'submit_job_application: user={user_id} posting={posting_id} '
            f'is_draft={_is_truthy(data.get("is_draft"))} files={len(files or [])}'
        )

        cover_letter = (data.get('cover_letter') or '').strip()
        if len(cover_letter) < 10:
            return fail('Cover letter must be at least 10 characters')

        # Verify the posting exists and is OPEN
        cur.execute("""
            SELECT id, status FROM app_job_postings WHERE id=%s LIMIT 1
        """, (posting_id,))
        posting = cur.fetchone()
        if not posting:
            return fail('Job posting not found', 404)
        if (posting.get('status') if isinstance(posting, dict) else None) != 'OPEN':
            return fail('This job is no longer accepting applications')

        name, mobile, email = _applicant_snapshot(cur, user_id)
        ref = _ref_number()
        resume_url = _upload_resume(files, user_id, ref)

        is_draft = _is_truthy(data.get('is_draft'))

        # Block duplicate real submissions: one (non-DRAFT) application per
        # user per posting. Drafts are exempt so users can keep editing.
        if not is_draft:
            cur.execute("""
                SELECT reference_number FROM app_job_applications
                WHERE user_id=%s AND job_posting_id=%s AND status<>'DRAFT'
                ORDER BY id DESC LIMIT 1
            """, (user_id, posting_id))
            dup = cur.fetchone()
            if dup:
                dup_ref = dup.get('reference_number') if isinstance(dup, dict) else None
                logger.info(
                    f'submit_job_application: duplicate blocked user={user_id} '
                    f'posting={posting_id} existing_ref={dup_ref}'
                )
                return ok({
                    'status': False,
                    'already_applied': True,
                    'message': 'You have already applied to this job.',
                    'reference_number': dup_ref,
                }, 409)

        status_val = 'DRAFT' if is_draft else 'PENDING'
        date_submitted_val = None if is_draft else ts

        cur.execute("""
            INSERT INTO app_job_applications (
                user_id, job_posting_id, reference_number,
                applicant_name_snapshot, mobile, email,
                cover_letter, resume_url,
                status, date_submitted
            ) VALUES (
                %s, %s, %s,
                %s, %s, %s,
                %s, %s,
                %s, %s
            )
        """, (
            user_id, posting_id, ref,
            sanitize(name), sanitize(mobile), sanitize(email),
            sanitize(cover_letter), resume_url or None,
            status_val, date_submitted_val,
        ))

        new_id = cur.lastrowid

        # On a real submission (not a draft), unpack the full PESO form the
        # Flutter app embeds in the cover letter and write it into the
        # structured app_peso_applications* tables, then link the applicant
        # to this job posting via app_job_vacancies_applicant so admins can
        # see every applicant per vacancy.
        peso_id = None
        peso_ref = None
        if not is_draft:
            peso = peso_application.extract_peso_payload(cover_letter)
            peso_id, peso_ref = peso_application.insert_peso_application(
                cur, user_id, peso, resume_url, ts,
            )
            # `ref` (JA-prefixed) is this job application's own number —
            # distinct from `peso_ref` (PA-prefixed), which identifies the
            # reusable PESO profile, not this specific vacancy application.
            peso_application.insert_job_vacancy_link(
                cur, posting_id, user_id, peso_id, ref, ts,
            )

        try:
            cur.connection.commit()
        except Exception:
            pass

        logger.info(
            f'submit_job_application: saved id={new_id} ref={ref} '
            f'status={status_val} peso_id={peso_id} peso_ref={peso_ref}'
        )
        return ok({
            'status': True,
            'message': 'Job application saved' if is_draft else 'Job application submitted',
            'id': new_id,
            'reference_number': ref,
            'application_number': ref,
            'peso_application_id': peso_id,
            'peso_reference_no': peso_ref,
        }, 201)
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'submit_job_application error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def check_job_application_status(cur, data, files, ts):
    """Pre-apply check for the new-jobs flow.

    Given a user and a job posting, tells the app, in one round-trip:
      - `already_applied`  — an ACTIVE link row for THIS posting exists in
        app_job_vacancies_applicant, so the app shows the "Already Applied"
        dialog instead of the form.
      - `has_profile`      — the user already has a saved PESO application,
        so the app can offer to edit it before applying.
      - `profile`          — the saved PESO profile blob (reassembled from
        app_peso_applications + children) for prefilling the edit form
        (null when none).

    The profile lookup is defensive: a missing/drifted table for a tenant
    never fails the whole check.
    """
    try:
        require(data, 'user_profile_id', 'job_posting_id')
        user_id = data['user_profile_id']
        try:
            posting_id = int(data['job_posting_id'])
        except (TypeError, ValueError):
            return fail('Invalid job_posting_id')
        logger.info(
            f'check_job_application_status: user={user_id} posting={posting_id}'
        )

        # 1) Already applied to THIS posting? Source of truth is
        # app_job_vacancies_applicant (one ACTIVE link row per user+posting).
        already_applied = False
        application_reference = None
        application_status = None
        cur.execute("""
            SELECT application_number, status FROM app_job_vacancies_applicant
            WHERE user_id=%s AND job_posting_id=%s AND is_active='ACTIVE'
            ORDER BY id DESC LIMIT 1
        """, (user_id, posting_id))
        applied = cur.fetchone()
        if applied:
            already_applied = True
            application_reference = (
                applied.get('application_number') if isinstance(applied, dict) else None
            )
            application_status = (
                applied.get('status') if isinstance(applied, dict) else None
            )

        # 2) Existing structured PESO application (the sole profile source)?
        peso_id, peso_ref = peso_application.find_latest_peso_application(cur, user_id)
        profile = None
        if peso_id:
            try:
                profile = peso_application.load_peso_profile(cur, user_id)
            except Exception as e:
                logger.warning(f'check_job_application_status: profile load failed: {e}')

        has_profile = bool(peso_id)
        logger.info(
            f'check_job_application_status: user={user_id} posting={posting_id} '
            f'already_applied={already_applied} has_profile={has_profile} '
            f'peso_id={peso_id}'
        )
        return ok({
            'status': True,
            'already_applied': already_applied,
            'application_reference': application_reference,
            'application_status': application_status,
            'has_profile': has_profile,
            'profile': profile,
            'peso_application_id': peso_id,
            'peso_reference_no': peso_ref,
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'check_job_application_status error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def apply_to_job(cur, data, files, ts):
    """Lightweight "quick apply": link the user's EXISTING PESO profile to a
    job posting without touching the profile data at all. Used when
    `check_job_application_status` already reported `has_profile=True` and
    the user chose "Apply Now" (not "Edit") on the prompt.

    Fails if the user has no PESO profile yet — the app should only call
    this endpoint once a profile is confirmed to exist.
    """
    try:
        require(data, 'user_profile_id', 'job_posting_id')
        user_id = data['user_profile_id']
        try:
            posting_id = int(data['job_posting_id'])
        except (TypeError, ValueError):
            return fail('Invalid job_posting_id')
        logger.info(f'apply_to_job: user={user_id} posting={posting_id}')

        cur.execute("""
            SELECT id, status FROM app_job_postings WHERE id=%s LIMIT 1
        """, (posting_id,))
        posting = cur.fetchone()
        if not posting:
            return fail('Job posting not found', 404)
        if (posting.get('status') if isinstance(posting, dict) else None) != 'OPEN':
            return fail('This job is no longer accepting applications')

        cur.execute("""
            SELECT id FROM app_job_vacancies_applicant
            WHERE user_id=%s AND job_posting_id=%s AND is_active='ACTIVE'
            LIMIT 1
        """, (user_id, posting_id))
        if cur.fetchone():
            return ok({
                'status': False,
                'already_applied': True,
                'message': 'You have already applied to this job.',
            }, 409)

        peso_id, _peso_ref = peso_application.find_latest_peso_application(cur, user_id)
        if not peso_id:
            return fail('No saved job profile found. Please fill out your profile first.', 409)

        application_number = _ref_number()
        peso_application.insert_job_vacancy_link(
            cur, posting_id, user_id, peso_id, application_number, ts,
        )

        try:
            cur.connection.commit()
        except Exception:
            pass

        logger.info(
            f'apply_to_job: applied user={user_id} posting={posting_id} '
            f'application_number={application_number} peso_id={peso_id}'
        )
        return ok({
            'status': True,
            'message': 'Application submitted',
            'application_number': application_number,
            'peso_application_id': peso_id,
        }, 201)
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'apply_to_job error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def update_job_profile(cur, data, files, ts):
    """Edit the user's job profile IN PLACE — never inserts a new application.

    Updates the user's EXISTING PESO application (app_peso_applications +
    child rows). When the user has no PESO record yet, one is created so the
    profile is persisted; otherwise the existing record is updated, not
    duplicated. This is the sole storage for the job profile — this project
    does not use app_applicant_profiles.

    `profile_data` must be a JSON-encoded `{personal, preferences, education,
    experience}` object — the same shape the apply form already produces. An
    optional `resume` multipart file replaces the stored resume.

    An optional `job_posting_id` links the (now saved) profile to that job
    via `app_job_vacancies_applicant` in the same call — this is how the
    apply form's single "Save Profile" / "Apply Now" button works: it always
    saves the profile, and additionally applies when opened with a job in
    context. No-op (not an error) if the user already applied to that job.
    """
    try:
        require(data, 'user_profile_id', 'profile_data')
        user_id = data['user_profile_id']
        raw = (data.get('profile_data') or '').strip()
        if not raw:
            return fail('profile_data is required')
        try:
            decoded = _json.loads(raw)
        except Exception:
            return fail('profile_data must be valid JSON')
        if not isinstance(decoded, dict):
            return fail('profile_data must be a JSON object')

        logger.info(
            f'update_job_profile: user={user_id} '
            f'sections={sorted(decoded.keys())} files={len(files or [])}'
        )

        # Update the structured PESO record in place (no new row).
        resume_url = _upload_resume(files, user_id, f'profile_{user_id}')
        peso_id, peso_ref = peso_application.update_peso_application(
            cur, user_id, decoded, resume_url or None, ts,
        )

        # Optional: apply to a specific job in the same call.
        application_number = None
        already_applied = False
        posting_id = None
        if data.get('job_posting_id') not in (None, ''):
            try:
                posting_id = int(data['job_posting_id'])
            except (TypeError, ValueError):
                posting_id = None
        if posting_id is not None:
            cur.execute("""
                SELECT application_number FROM app_job_vacancies_applicant
                WHERE user_id=%s AND job_posting_id=%s AND is_active='ACTIVE'
                LIMIT 1
            """, (user_id, posting_id))
            existing = cur.fetchone()
            if existing:
                already_applied = True
                application_number = (
                    existing.get('application_number')
                    if isinstance(existing, dict) else None
                )
            else:
                application_number = _ref_number()
                peso_application.insert_job_vacancy_link(
                    cur, posting_id, user_id, peso_id, application_number, ts,
                )

        try:
            cur.connection.commit()
        except Exception:
            pass

        logger.info(
            f'update_job_profile: user={user_id} peso_id={peso_id} '
            f'peso_ref={peso_ref} posting={posting_id} '
            f'application_number={application_number}'
        )
        return ok({
            'status': True,
            'ok': True,
            'peso_application_id': peso_id,
            'peso_reference_no': peso_ref,
            'applied': posting_id is not None,
            'already_applied': already_applied,
            'application_number': application_number,
            'updated_at': ts,
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'update_job_profile error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def list_my_job_applications(cur, data, files, ts):
    """Returns the user's job applications from app_job_vacancies_applicant
    (the source of truth for "did I apply"), joined to app_job_postings for
    display fields. Response field names are kept aligned with the old
    app_job_applications-based shape (application_number, status, job_title,
    date_submitted, job_posting_id) so the Flutter "My Applications" list
    needs no changes."""
    try:
        require(data, 'user_profile_id')
        user_id = data['user_profile_id']
        status = (data.get('status') or '').strip().upper()
        logger.info(
            f'list_my_job_applications: user={user_id} status={status or "ALL"}'
        )

        sql = """
            SELECT a.id, a.application_number, a.job_posting_id,
                   a.status, a.date_created AS date_submitted,
                   a.date_updated AS date_modified,
                   p.title AS job_title, p.department AS job_department,
                   p.location AS job_location, p.employment_type
            FROM app_job_vacancies_applicant a
            LEFT JOIN app_job_postings p ON p.id = a.job_posting_id
            WHERE a.user_id=%s AND a.is_active='ACTIVE'
        """
        params = [user_id]
        if status:
            sql += ' AND a.status=%s'
            params.append(status)
        sql += ' ORDER BY a.id DESC'

        cur.execute(sql, tuple(params))
        rows = cur.fetchall()
        logger.info(
            f'list_my_job_applications: user={user_id} -> {len(rows)} application(s)'
        )
        return ok({
            'status': True,
            'applications': [serialize_row(r) for r in rows],
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'list_my_job_applications error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def update_job_application(cur, data, files, ts):
    """Edit a DRAFT application; optionally promote it to PENDING.

    Only the owning user can edit, and only while status='DRAFT'.
    """
    try:
        require(data, 'user_profile_id', 'application_number')
        user_id = data['user_profile_id']
        ref = (data.get('application_number') or '').strip()
        if not ref:
            return fail('Invalid application_number')
        logger.info(
            f'update_job_application: user={user_id} ref={ref}'
        )

        cur.execute("""
            SELECT id, status, job_posting_id FROM app_job_applications
            WHERE reference_number=%s AND user_id=%s LIMIT 1
        """, (ref, user_id))
        row = cur.fetchone()
        if not row:
            return fail('Application not found', 404)

        current_status = row.get('status') if isinstance(row, dict) else None
        posting_id = row.get('job_posting_id') if isinstance(row, dict) else None
        if current_status != 'DRAFT':
            return fail('Application already submitted; no edits allowed', 409)

        # Build dynamic SET clause from optional editable fields
        editable = ['applicant_name_snapshot', 'mobile', 'email', 'cover_letter', 'resume_url']
        sets = []
        params = []
        for field in editable:
            if field in data and data.get(field) is not None:
                val = data.get(field)
                if isinstance(val, str):
                    val = sanitize(val.strip())
                sets.append(f'{field}=%s')
                params.append(val)

        # is_draft: truthy = stay DRAFT; falsy (when explicitly provided) = promote to PENDING
        promote = False
        if 'is_draft' in data and data.get('is_draft') is not None:
            promote = not _is_truthy(data.get('is_draft'))

        new_status = 'DRAFT'
        if promote:
            new_status = 'PENDING'
            sets.append('status=%s')
            params.append('PENDING')
            sets.append('date_submitted=%s')
            params.append(ts)

        sets.append('date_modified=%s')
        params.append(ts)

        params.extend([ref, user_id])
        sql = f"""
            UPDATE app_job_applications SET {', '.join(sets)}
            WHERE reference_number=%s AND user_id=%s
        """
        cur.execute(sql, tuple(params))

        # Promoting a draft to PENDING is a real submission — write the full
        # PESO record and link it to the job posting for admin visibility.
        peso_id = None
        peso_ref = None
        if promote:
            cur.execute("""
                SELECT cover_letter, resume_url FROM app_job_applications
                WHERE reference_number=%s AND user_id=%s LIMIT 1
            """, (ref, user_id))
            final = cur.fetchone() or {}
            cover_letter = final.get('cover_letter') if isinstance(final, dict) else None
            resume_url = final.get('resume_url') if isinstance(final, dict) else None
            peso = peso_application.extract_peso_payload(cover_letter)
            peso_id, peso_ref = peso_application.insert_peso_application(
                cur, user_id, peso, resume_url, ts,
            )
            if posting_id is not None:
                peso_application.insert_job_vacancy_link(
                    cur, posting_id, user_id, peso_id, peso_ref, ts,
                )

        try:
            cur.connection.commit()
        except Exception:
            pass

        logger.info(
            f'update_job_application: ref={ref} new_status={new_status} '
            f'promote={promote} peso_id={peso_id} peso_ref={peso_ref}'
        )
        return ok({
            'status': True,
            'application_number': ref,
            'application_status': new_status,
            'peso_application_id': peso_id,
            'peso_reference_no': peso_ref,
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'update_job_application error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def get_job_application(cur, data, files, ts):
    """Return a single application (with posting summary) owned by the user."""
    try:
        require(data, 'user_profile_id', 'application_number')
        user_id = data['user_profile_id']
        ref = (data.get('application_number') or '').strip()
        if not ref:
            return fail('Invalid application_number')
        logger.info(f'get_job_application: user={user_id} ref={ref}')

        cur.execute("""
            SELECT a.*,
                   p.title AS posting_title,
                   p.department AS posting_department,
                   p.location AS posting_location
            FROM app_job_applications a
            LEFT JOIN app_job_postings p ON p.id = a.job_posting_id
            WHERE a.reference_number=%s AND a.user_id=%s
            LIMIT 1
        """, (ref, user_id))
        row = cur.fetchone()
        if not row:
            logger.info(f'get_job_application: ref={ref} not found for user={user_id}')
            return fail('Application not found', 404)

        full = serialize_row(row) if isinstance(row, dict) else {}
        posting = {
            'title': full.pop('posting_title', None),
            'department': full.pop('posting_department', None),
            'location': full.pop('posting_location', None),
        }
        return ok({
            'status': True,
            'application': full,
            'posting': posting,
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'get_job_application error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


# ─── Applicant Profile (CV) ────────────────────────────────────────────
#
# Persistent CV-style data shared across every job application by a user.
# Shape of profile_data matches the legacy `__peso_extra__` blob written
# into app_job_applications.cover_letter, so the Flutter side reuses one
# model (lib/features/job_application/domain/applicant_profile.dart).
# See: docs/superpowers/specs/2026-04-27-applicant-profile-design.md.

import json as _json


def get_applicant_profile(cur, data, files, ts):
    """Returns the signed-in user's saved job profile, or null if they
    haven't saved one yet. Response: { profile, updated_at }.

    Sourced from the structured PESO tables (app_peso_applications +
    children) — NOT app_applicant_profiles, which this project doesn't use.
    """
    try:
        require(data, 'user_profile_id')
        user_id = data['user_profile_id']
        logger.info(f'get_applicant_profile: user={user_id}')

        profile = peso_application.load_peso_profile(cur, user_id)
        if not profile:
            logger.info(f'get_applicant_profile: no PESO profile for user={user_id}')
            return ok({'status': True, 'profile': None, 'updated_at': None})

        logger.info(f'get_applicant_profile: user={user_id} loaded PESO profile')
        return ok({
            'status': True,
            'profile': profile,
            'updated_at': ts,
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'get_applicant_profile error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def save_applicant_profile(cur, data, files, ts):
    """Upserts the applicant profile for the signed-in user. The
    `profile_data` field must be a JSON-encoded string with the
    {personal, preferences, education, experience} shape."""
    try:
        require(data, 'user_profile_id', 'profile_data')
        user_id = data['user_profile_id']
        raw = (data.get('profile_data') or '').strip()
        if not raw:
            return fail('profile_data is required')

        # Validate JSON shape early so we never write a malformed blob to
        # the column.
        try:
            decoded = _json.loads(raw)
        except Exception:
            return fail('profile_data must be valid JSON')
        if not isinstance(decoded, dict):
            return fail('profile_data must be a JSON object')

        # Normalize back to a canonical compact JSON string.
        canonical = _json.dumps(decoded, ensure_ascii=False)
        logger.info(
            f'save_applicant_profile: user={user_id} '
            f'sections={sorted(decoded.keys())} bytes={len(canonical)}'
        )

        cur.execute("""
            INSERT INTO app_applicant_profiles
                (user_id, profile_data, date_created, date_modified)
            VALUES (%s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE
                profile_data = VALUES(profile_data),
                date_modified = VALUES(date_modified)
        """, (user_id, canonical, ts, ts))

        logger.info(f'save_applicant_profile: upserted profile for user={user_id}')
        return ok({'status': True, 'ok': True, 'updated_at': ts})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'save_applicant_profile error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)
