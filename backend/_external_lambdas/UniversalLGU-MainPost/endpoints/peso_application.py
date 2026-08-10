"""PESO job-application persistence.

The Flutter job-application form is a full PESO (NSRP-style) registration
form. It already collects personal info, job preferences, languages,
education, trainings, work experience, skills and eligibility — but the
old `submit_job_application` only ever wrote a single summary row into
`app_job_applications` (everything else was buried in a JSON blob inside
the cover_letter column).

This module unpacks that payload and writes it into the structured
`app_peso_applications*` tables so every field is queryable.

Target DB: whatever the request's `db_name` resolves to (generic_360_db).
"""

import json
import logging
import uuid
from datetime import datetime

logger = logging.getLogger()

# Marker the Flutter form embeds in the cover_letter string.
_PESO_MARKER = '__peso_extra__:'


# ─── parsing helpers ──────────────────────────────────────────────────────

def extract_peso_payload(cover_letter):
    """Pull the embedded `__peso_extra__:{...}` JSON out of a cover letter.

    Returns a dict (possibly empty) — never raises.
    """
    if not cover_letter:
        return {}
    text = str(cover_letter)
    idx = text.find(_PESO_MARKER)
    if idx == -1:
        return {}
    raw = text[idx + len(_PESO_MARKER):].strip()
    try:
        decoded = json.loads(raw)
        if isinstance(decoded, dict):
            logger.info(
                f'extract_peso_payload: parsed PESO blob, sections={sorted(decoded.keys())}'
            )
            return decoded
        return {}
    except Exception:
        logger.warning('extract_peso_payload: cover_letter blob was not valid JSON')
        return {}


def _s(val):
    """Trim a value to a non-empty string, else None."""
    if val is None:
        return None
    s = str(val).strip()
    return s or None


def _clip(val, length):
    s = _s(val)
    return s[:length] if s else None


def _to_date(val):
    """Best-effort parse to 'YYYY-MM-DD'. Returns None when it can't."""
    s = _s(val)
    if not s:
        return None
    s = s.replace('/', '-')
    fmts = ('%Y-%m-%d', '%Y-%m-%dT%H:%M:%S', '%m-%d-%Y', '%d-%m-%Y', '%Y')
    for fmt in fmts:
        try:
            d = datetime.strptime(s[:len(fmt) + 4] if fmt == '%Y' else s[:19], fmt)
            return d.strftime('%Y-%m-%d')
        except Exception:
            continue
    # bare 4-digit year
    digits = ''.join(c for c in s if c.isdigit())
    if len(digits) == 4:
        return f'{digits}-01-01'
    return None


def _yn(val):
    """Coerce a bool / 'yes' / 'true' / 1 to the 'Yes'/'No' enum strings."""
    if val is None:
        return 'No'
    if isinstance(val, bool):
        return 'Yes' if val else 'No'
    return 'Yes' if str(val).strip().lower() in ('1', 'true', 'yes', 'y', 't') else 'No'


def _sex(gender):
    g = (_s(gender) or '').lower()
    if g in ('male', 'm'):
        return 'Male'
    if g in ('female', 'f'):
        return 'Female'
    return None


def _ref_number():
    return 'PA' + datetime.now().strftime('%Y%m%d') + uuid.uuid4().hex[:6].upper()


# ─── main entry point ─────────────────────────────────────────────────────

def insert_peso_application(cur, user_id, peso, resume_url, ts):
    """Insert a full PESO application (header + child rows).

    `peso` is the dict produced by extract_peso_payload(). `cur` is a
    DictCursor already bound to the tenant DB. Returns the new
    app_peso_applications.id and reference_no as a tuple.

    Each child-table group is wrapped independently so one malformed
    section never loses the rest of the application.
    """
    logger.info(
        f'insert_peso_application: user={user_id} '
        f'sections_present={[k for k in ("personal", "preferences", "education", "experience") if peso.get(k)]} '
        f'has_resume={bool(resume_url)}'
    )

    reference_no = _ref_number()

    # ---- header ----
    # Build the header as ordered (column, value) pairs, then drop any column
    # that doesn't exist in THIS tenant's table. The PESO tables were created
    # with `CREATE TABLE IF NOT EXISTS`, so columns added to the migration
    # later (e.g. `zip_code`) never reached LGU DBs whose table already
    # existed — the schemas have drifted. Saving the application without a
    # missing field beats failing the whole submission.
    header = [('reference_no', reference_no)]
    header += _demographic_pairs(peso)
    header += [
        ('consent_agreed', 'Yes'),
        ('requested_from', 'MOBILE'),
        ('status', 'PENDING'),
        ('created_at', ts),
        ('user_id', user_id),
    ]

    cur.execute("SHOW COLUMNS FROM app_peso_applications")
    existing = {
        (r['Field'] if isinstance(r, dict) else r[0])
        for r in (cur.fetchall() or [])
    }
    cols = [c for c, _ in header if c in existing]
    vals = [v for c, v in header if c in existing]
    dropped = [c for c, _ in header if c not in existing]
    if dropped:
        logger.warning(
            f'insert_peso_application: skipping columns absent from this DB: {dropped}'
        )

    col_sql = ', '.join(f'`{c}`' for c in cols)
    placeholders = ', '.join(['%s'] * len(cols))
    cur.execute(
        f"INSERT INTO app_peso_applications ({col_sql}) VALUES ({placeholders})",
        tuple(vals),
    )
    application_id = cur.lastrowid
    logger.info(
        f'insert_peso_application: header saved id={application_id} '
        f'ref={reference_no} ({len(cols)} columns)'
    )

    _insert_peso_children(cur, application_id, peso, resume_url, ts)
    logger.info(
        f'insert_peso_application: completed id={application_id} ref={reference_no}'
    )
    return application_id, reference_no


def _demographic_pairs(peso):
    """Ordered (column, value) pairs for the mutable demographic / disability /
    employment columns of the PESO header. Shared by insert and update so the
    column mapping lives in exactly one place."""
    personal = peso.get('personal') or {}
    prefs = peso.get('preferences') or {}

    disabilities = [str(d).strip().lower() for d in (personal.get('disabilities') or [])]
    dis_other_text = _clip(personal.get('disability_other'), 120)
    dis_visual = 1 if any('visual' in d for d in disabilities) else 0
    dis_hearing = 1 if any('hearing' in d for d in disabilities) else 0
    dis_speech = 1 if any('speech' in d for d in disabilities) else 0
    dis_physical = 1 if any('physical' in d or 'orthopedic' in d for d in disabilities) else 0
    dis_mental = 1 if any(k in d for d in disabilities for k in ('intellectual', 'psychosocial', 'mental')) else 0
    dis_other = 1 if dis_other_text else 0

    birth_date = _to_date(personal.get('date_of_birth')) or '1900-01-01'
    try:
        age = int(str(personal.get('age')).strip())
        if age < 0 or age > 120:
            age = None
    except Exception:
        age = None

    job_pref_list = [j for j in (prefs.get('preferred_jobs') or []) if _s(j)]
    job_preferences = _clip(json.dumps(job_pref_list, ensure_ascii=False), 120) if job_pref_list else None

    return [
        ('surname', _clip(personal.get('last_name'), 80) or 'N/A'),
        ('firstname', _clip(personal.get('first_name'), 80) or 'N/A'),
        ('middlename', _clip(personal.get('middle_name'), 80)),
        ('suffix', _clip(personal.get('suffix'), 20)),
        ('birth_date', birth_date),
        ('age', age),
        ('place_of_birth', _clip(personal.get('place_of_birth'), 120)),
        ('sex', _sex(personal.get('gender'))),
        ('present_house_street', _clip(personal.get('residence'), 160)),
        ('present_barangay', _clip(personal.get('barangay'), 120)),
        ('present_municipality', _clip(personal.get('city_municipality'), 120)),
        ('present_province', _clip(personal.get('province'), 120)),
        ('present_region', _clip(personal.get('region'), 120)),
        ('zip_code', _clip(personal.get('zip_code'), 10)),
        ('email', _clip(personal.get('email'), 120)),
        ('cellphone_no', _clip(personal.get('contact_number'), 20)),
        ('disability_visual', dis_visual),
        ('disability_hearing', dis_hearing),
        ('disability_speech', dis_speech),
        ('disability_physical', dis_physical),
        ('disability_mental', dis_mental),
        ('disability_other', dis_other),
        ('disability_other_specify', dis_other_text),
        ('emp_status', _clip(prefs.get('employment_type'), 20)),
        ('emp_type', _clip(prefs.get('employment_type'), 30)),
        ('ofw', _yn(prefs.get('is_ofw'))),
        ('former_ofw', _yn(prefs.get('is_former_ofw'))),
        ('four_ps_beneficiary', _yn(prefs.get('is_4ps'))),
        ('job_preferences', job_preferences),
    ]


def find_latest_peso_application(cur, user_id):
    """Return (id, reference_no) of the user's most recent PESO application,
    or (None, None) if they have none. Never raises."""
    try:
        cur.execute(
            "SELECT id, reference_no FROM app_peso_applications "
            "WHERE user_id=%s ORDER BY id DESC LIMIT 1",
            (user_id,),
        )
        row = cur.fetchone()
        if not row:
            return None, None
        if isinstance(row, dict):
            return row.get('id'), row.get('reference_no')
        return row[0], row[1]
    except Exception as e:
        logger.warning(f'find_latest_peso_application failed: {e}')
        return None, None


def update_peso_application(cur, user_id, peso, resume_url, ts):
    """Update the user's EXISTING PESO application in place — no new row.

    Updates the header demographic columns and fully replaces the child
    rows (preferred jobs/locations, languages, education, trainings, work,
    skills, eligibility) from the new payload. The resume attachment is only
    touched when a new `resume_url` is supplied, so editing the profile
    without re-uploading keeps the old resume.

    Falls back to a fresh insert when the user has no PESO record yet.
    Returns (application_id, reference_no).
    """
    application_id, reference_no = find_latest_peso_application(cur, user_id)
    if not application_id:
        logger.info(f'update_peso_application: no record for user={user_id} -> insert')
        return insert_peso_application(cur, user_id, peso, resume_url, ts)

    pairs = list(_demographic_pairs(peso))
    pairs.append(('date_updated', ts))
    pairs.append(('updated_at', ts))

    cur.execute("SHOW COLUMNS FROM app_peso_applications")
    existing = {
        (r['Field'] if isinstance(r, dict) else r[0])
        for r in (cur.fetchall() or [])
    }
    upd = [(c, v) for c, v in pairs if c in existing]
    if upd:
        set_sql = ', '.join(f'`{c}`=%s' for c, _ in upd)
        params = [v for _, v in upd] + [application_id]
        cur.execute(
            f"UPDATE app_peso_applications SET {set_sql} WHERE id=%s",
            tuple(params),
        )
    logger.info(
        f'update_peso_application: header updated id={application_id} '
        f'ref={reference_no} ({len(upd)} columns)'
    )

    replace_resume = bool(resume_url)
    _delete_peso_children(cur, application_id, replace_resume=replace_resume)
    _insert_peso_children(
        cur, application_id, peso, resume_url, ts, include_resume=replace_resume,
    )
    logger.info(
        f'update_peso_application: completed id={application_id} ref={reference_no}'
    )
    return application_id, reference_no


def _delete_peso_children(cur, application_id, replace_resume=True):
    """Clear the child rows for a PESO application so they can be re-inserted
    from a fresh payload. Each table is wrapped independently. Resume
    attachments are only removed when a replacement is being uploaded."""
    tables = [
        'app_peso_applications_preferred_occupations',
        'app_peso_applications_preferred_locations',
        'app_peso_applications_language_proficiency',
        'app_peso_applications_education',
        'app_peso_applications_training',
        'app_peso_applications_work_experience',
        'app_peso_applications_skills',
        'app_peso_applications_eligibility',
        'app_peso_applications_prc_license',
    ]
    for t in tables:
        try:
            cur.execute(f"DELETE FROM {t} WHERE application_id=%s", (application_id,))
        except Exception as e:
            logger.error(f'update peso: delete {t} failed: {e}')
    if replace_resume:
        try:
            cur.execute(
                "DELETE FROM app_peso_applications_attachments "
                "WHERE application_id=%s AND attachment_type='resume'",
                (application_id,),
            )
        except Exception as e:
            logger.error(f'update peso: delete attachments failed: {e}')


def _insert_peso_children(cur, application_id, peso, resume_url, ts,
                          include_resume=True):
    """Insert every child-table group for a PESO application. Extracted from
    insert_peso_application so the update path can reuse it. Each group is
    wrapped independently so one malformed section never loses the rest."""
    personal = peso.get('personal') or {}
    prefs = peso.get('preferences') or {}
    edu = peso.get('education') or {}
    exp = peso.get('experience') or {}
    job_pref_list = [j for j in (prefs.get('preferred_jobs') or []) if _s(j)]

    # ---- preferred occupations ----
    try:
        n = 0
        for rank, occ in enumerate(job_pref_list, start=1):
            cur.execute("""
                INSERT INTO app_peso_applications_preferred_occupations
                    (application_id, rank_no, occupation)
                VALUES (%s, %s, %s)
            """, (application_id, rank, _clip(occ, 160)))
            n += 1
        if n:
            logger.info(f'peso[{application_id}]: inserted {n} preferred occupation(s)')
    except Exception as e:
        logger.error(f'peso preferred_occupations failed: {e}', exc_info=True)

    # ---- preferred locations ----
    try:
        locs = [l for l in (prefs.get('preferred_locations') or []) if _s(l)]
        for rank, loc in enumerate(locs, start=1):
            cur.execute("""
                INSERT INTO app_peso_applications_preferred_locations
                    (application_id, location_type, rank_no, location_value)
                VALUES (%s, %s, %s, %s)
            """, (application_id, 'Local', rank, _clip(loc, 160)))
        if locs:
            logger.info(f'peso[{application_id}]: inserted {len(locs)} preferred location(s)')
    except Exception as e:
        logger.error(f'peso preferred_locations failed: {e}', exc_info=True)

    # ---- language proficiency ----
    try:
        lang_count = 0
        languages = prefs.get('languages') or {}
        for name, skills in languages.items():
            if not isinstance(skills, dict):
                continue
            can_read = 1 if skills.get('read') else 0
            can_write = 1 if skills.get('write') else 0
            can_speak = 1 if skills.get('speak') else 0
            if not (can_read or can_write or can_speak):
                continue
            known = (_s(name) or '').lower() in ('filipino', 'english', 'mandarin')
            lang_name = _clip(name, 40) if known else 'Other'
            other_specify = None if known else _clip(name, 60)
            cur.execute("""
                INSERT INTO app_peso_applications_language_proficiency (
                    application_id, language_name, other_language_specify,
                    can_read, can_write, can_speak, can_understand
                ) VALUES (%s, %s, %s, %s, %s, %s, %s)
            """, (application_id, lang_name, other_specify,
                  can_read, can_write, can_speak, can_speak))
            lang_count += 1
        if lang_count:
            logger.info(f'peso[{application_id}]: inserted {lang_count} language proficiency row(s)')
    except Exception as e:
        logger.error(f'peso language_proficiency failed: {e}', exc_info=True)

    # ---- education ----
    try:
        has_edu = any(_s(edu.get(k)) for k in
                      ('school', 'course', 'year_graduated', 'year_last_attended',
                       'attainment', 'awards'))
        if has_edu or edu.get('currently_in_school'):
            cur.execute("""
                INSERT INTO app_peso_applications_education (
                    application_id, currently_in_school, level, school, course,
                    year_graduated, if_undergraduate_what_level,
                    year_last_attended, awards_received
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                application_id,
                _yn(edu.get('currently_in_school')),
                # `level` is NOT NULL with no default; '' (not a sentinel
                # like 'N/A') satisfies that without colliding with any real
                # dropdown option on read-back — see load_peso_profile.
                _clip(edu.get('attainment'), 40) or '',
                _clip(edu.get('school'), 160),
                _clip(edu.get('course'), 160),
                _clip(edu.get('year_graduated'), 20),
                None,
                _clip(edu.get('year_last_attended'), 20),
                _clip(edu.get('awards'), 160),
            ))
            logger.info(f'peso[{application_id}]: inserted education row')
    except Exception as e:
        logger.error(f'peso education failed: {e}', exc_info=True)

    # ---- trainings ----
    try:
        train_count = 0
        for row_no, t in enumerate(edu.get('trainings') or [], start=1):
            if not isinstance(t, dict):
                continue
            course = _clip(t.get('title'), 160)
            institution = _clip(t.get('by'), 160)
            hours = _s(t.get('hours'))
            if not (course or institution or hours):
                continue
            cur.execute("""
                INSERT INTO app_peso_applications_training (
                    application_id, row_no, course, duration_from, duration_to,
                    training_institution, certificates_received
                ) VALUES (%s, %s, %s, %s, %s, %s, %s)
            """, (
                application_id, row_no, course,
                _to_date(t.get('year')), None,
                institution,
                _clip(f'{hours} hrs' if hours else None, 160),
            ))
            train_count += 1
        if train_count:
            logger.info(f'peso[{application_id}]: inserted {train_count} training(s)')
    except Exception as e:
        logger.error(f'peso training failed: {e}', exc_info=True)

    # ---- work experience ----
    try:
        work_count = 0
        for row_no, w in enumerate(exp.get('previous_jobs') or [], start=1):
            if not isinstance(w, dict):
                continue
            company = _clip(w.get('company'), 160)
            position = _clip(w.get('position'), 120)
            if not (company or position):
                continue
            cur.execute("""
                INSERT INTO app_peso_applications_work_experience (
                    application_id, row_no, company_name,
                    company_address_city_municipality, position,
                    inclusive_from, inclusive_to, status, status_other
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                application_id, row_no, company, None, position,
                _to_date(w.get('from')), _to_date(w.get('to')), None, None,
            ))
            work_count += 1
        if work_count:
            logger.info(f'peso[{application_id}]: inserted {work_count} work experience row(s)')
    except Exception as e:
        logger.error(f'peso work_experience failed: {e}', exc_info=True)

    # ---- skills (lookup against skill catalog, unknowns -> "Others") ----
    try:
        _insert_skills(cur, application_id, exp.get('skills'))
    except Exception as e:
        logger.error(f'peso skills failed: {e}', exc_info=True)

    # ---- eligibility (free-text from the form) ----
    try:
        eligibility = _s(exp.get('eligibility'))
        if eligibility:
            cur.execute("""
                INSERT INTO app_peso_applications_eligibility
                    (application_id, row_no, eligibility_name, rating, exam_date)
                VALUES (%s, %s, %s, %s, %s)
            """, (application_id, 1, _clip(eligibility, 120), None, None))
            logger.info(f'peso[{application_id}]: inserted eligibility row')
    except Exception as e:
        logger.error(f'peso eligibility failed: {e}', exc_info=True)

    # ---- PRC licenses (applicant self-reported) ----
    try:
        lic_count = 0
        for row_no, lic in enumerate(exp.get('licenses') or [], start=1):
            if not isinstance(lic, dict):
                continue
            name = _clip(lic.get('name'), 120)
            valid_until = _to_date(lic.get('valid_until'))
            if not (name or valid_until):
                continue
            cur.execute("""
                INSERT INTO app_peso_applications_prc_license
                    (application_id, row_no, license_name, valid_until)
                VALUES (%s, %s, %s, %s)
            """, (application_id, row_no, name, valid_until))
            lic_count += 1
        if lic_count:
            logger.info(f'peso[{application_id}]: inserted {lic_count} PRC license(s)')
    except Exception as e:
        logger.error(f'peso prc_license failed: {e}', exc_info=True)

    # ---- resume attachment ----
    try:
        if include_resume and resume_url:
            resume_name = _clip(exp.get('resume_filename'), 255) or 'resume'
            cur.execute("""
                INSERT INTO app_peso_applications_attachments (
                    application_id, attachment_type, file_name, file_url,
                    bucket_name, object_key, date_created, date_updated, is_active
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                application_id, 'resume', resume_name, _clip(resume_url, 1000),
                None, None, ts, ts, 'Yes',
            ))
            logger.info(f'peso[{application_id}]: attached resume')
    except Exception as e:
        logger.error(f'peso attachment failed: {e}', exc_info=True)

    logger.info(f'_insert_peso_children: done for application_id={application_id}')


_DISABILITY_LABELS = {
    'disability_visual': 'Visual Impairment',
    'disability_hearing': 'Hearing Impairment',
    'disability_speech': 'Speech Impairment',
    'disability_physical': 'Physical Disability',
    'disability_mental': 'Psychosocial Disability',
}


def load_peso_profile(cur, user_id):
    """Reassemble the user's latest PESO application (header + every child
    table) back into the `{personal, preferences, education, experience}`
    blob shape the Flutter form reads/writes — the reverse of
    insert_peso_application/_insert_peso_children. Returns None if the user
    has no PESO application yet. Never raises; a failed child-table read
    just leaves that section empty rather than losing the whole profile."""
    application_id, _ref = find_latest_peso_application(cur, user_id)
    if not application_id:
        return None

    cur.execute(
        "SELECT * FROM app_peso_applications WHERE id=%s LIMIT 1",
        (application_id,),
    )
    header = cur.fetchone() or {}

    def g(key):
        return header.get(key) if isinstance(header, dict) else None

    disabilities = [
        label for col, label in _DISABILITY_LABELS.items() if g(col)
    ]
    if g('disability_other'):
        disabilities.append('Others')
    if not disabilities:
        disabilities = ['None']

    gender = _s(g('sex'))
    personal = {
        'first_name': _s(g('firstname')) or '',
        'middle_name': _s(g('middlename')) or '',
        'last_name': _s(g('surname')) or '',
        'suffix': _s(g('suffix')) or '',
        'date_of_birth': _s(g('birth_date')) or '',
        'age': _s(g('age')) or '',
        'place_of_birth': _s(g('place_of_birth')) or '',
        'gender': gender.upper() if gender else None,
        'religion': _s(g('religion')) or '',
        'civil_status': (_s(g('civil_status')) or '').upper() or None,
        'region': _s(g('present_region')) or '',
        'province': _s(g('present_province')) or '',
        'city_municipality': _s(g('present_municipality')) or '',
        'barangay': _s(g('present_barangay')) or '',
        'residence': _s(g('present_house_street')) or '',
        'zip_code': _s(g('zip_code')) or '',
        'height': _s(g('height_cm')) or '',
        'tin': _s(g('tin_no')) or '',
        'email': _s(g('email')) or '',
        'contact_number': _s(g('cellphone_no')) or '',
        'disabilities': disabilities,
        'disability_other': _s(g('disability_other_specify')) or '',
    }

    try:
        cur.execute(
            "SELECT occupation FROM app_peso_applications_preferred_occupations "
            "WHERE application_id=%s ORDER BY rank_no", (application_id,))
        preferred_jobs = [r['occupation'] for r in (cur.fetchall() or [])]
    except Exception as e:
        logger.warning(f'load_peso_profile: preferred_occupations failed: {e}')
        preferred_jobs = []

    try:
        cur.execute(
            "SELECT location_value FROM app_peso_applications_preferred_locations "
            "WHERE application_id=%s ORDER BY rank_no", (application_id,))
        preferred_locations = [r['location_value'] for r in (cur.fetchall() or [])]
    except Exception as e:
        logger.warning(f'load_peso_profile: preferred_locations failed: {e}')
        preferred_locations = []

    languages = {}
    try:
        cur.execute(
            "SELECT language_name, other_language_specify, can_read, "
            "can_write, can_speak FROM app_peso_applications_language_proficiency "
            "WHERE application_id=%s", (application_id,))
        for r in cur.fetchall() or []:
            name = r.get('language_name')
            if name == 'Other':
                name = r.get('other_language_specify') or 'Other'
            languages[name] = {
                'read': bool(r.get('can_read')),
                'write': bool(r.get('can_write')),
                'speak': bool(r.get('can_speak')),
            }
    except Exception as e:
        logger.warning(f'load_peso_profile: language_proficiency failed: {e}')

    preferences = {
        'preferred_jobs': preferred_jobs,
        'preferred_locations': preferred_locations,
        'employment_type': _s(g('emp_type')),
        'is_ofw': (_s(g('ofw')) or '').lower() == 'yes',
        'is_former_ofw': (_s(g('former_ofw')) or '').lower() == 'yes',
        'is_4ps': (_s(g('four_ps_beneficiary')) or '').lower() == 'yes',
        'languages': languages,
    }

    education = {
        'school': '', 'course': '', 'year_graduated': '',
        'year_last_attended': '', 'currently_in_school': False,
        'attainment': None, 'awards': '',
    }
    try:
        cur.execute(
            "SELECT * FROM app_peso_applications_education "
            "WHERE application_id=%s LIMIT 1", (application_id,))
        edu = cur.fetchone()
        if edu:
            education = {
                'school': _s(edu.get('school')) or '',
                'course': _s(edu.get('course')) or '',
                'year_graduated': _s(edu.get('year_graduated')) or '',
                'year_last_attended': _s(edu.get('year_last_attended')) or '',
                'currently_in_school':
                    (_s(edu.get('currently_in_school')) or '').lower() == 'yes',
                'attainment': _s(edu.get('level')),
                'awards': _s(edu.get('awards_received')) or '',
            }
    except Exception as e:
        logger.warning(f'load_peso_profile: education failed: {e}')

    trainings = []
    try:
        cur.execute(
            "SELECT * FROM app_peso_applications_training "
            "WHERE application_id=%s ORDER BY row_no", (application_id,))
        for r in cur.fetchall() or []:
            cert = _s(r.get('certificates_received')) or ''
            hours = cert[:-4].strip() if cert.endswith(' hrs') else ''
            year = ''
            dfrom = r.get('duration_from')
            if dfrom:
                year = str(dfrom)[:4]
            trainings.append({
                'title': _s(r.get('course')) or '',
                'by': _s(r.get('training_institution')) or '',
                'hours': hours,
                'year': year,
            })
    except Exception as e:
        logger.warning(f'load_peso_profile: training failed: {e}')

    previous_jobs = []
    try:
        cur.execute(
            "SELECT * FROM app_peso_applications_work_experience "
            "WHERE application_id=%s ORDER BY row_no", (application_id,))
        for r in cur.fetchall() or []:
            previous_jobs.append({
                'position': _s(r.get('position')) or '',
                'company': _s(r.get('company_name')) or '',
                'from': _s(r.get('inclusive_from')) or '',
                'to': _s(r.get('inclusive_to')) or '',
            })
    except Exception as e:
        logger.warning(f'load_peso_profile: work_experience failed: {e}')

    licenses = []
    try:
        cur.execute(
            "SELECT * FROM app_peso_applications_prc_license "
            "WHERE application_id=%s ORDER BY row_no", (application_id,))
        for r in cur.fetchall() or []:
            licenses.append({
                'name': _s(r.get('license_name')) or '',
                'valid_until': _s(r.get('valid_until')) or '',
            })
    except Exception as e:
        logger.warning(f'load_peso_profile: prc_license failed: {e}')

    skills = ''
    try:
        cur.execute("""
            SELECT s.other_specify, c.skill_name
            FROM app_peso_applications_skills s
            LEFT JOIN app_peso_applications_skill_catalog c ON c.id = s.skill_id
            WHERE s.application_id=%s
        """, (application_id,))
        parts = []
        for r in cur.fetchall() or []:
            name = r.get('skill_name')
            if name == 'Others' and r.get('other_specify'):
                parts.append(r.get('other_specify'))
            elif name:
                parts.append(name)
        skills = ', '.join(parts)
    except Exception as e:
        logger.warning(f'load_peso_profile: skills failed: {e}')

    eligibility = ''
    try:
        cur.execute(
            "SELECT eligibility_name FROM app_peso_applications_eligibility "
            "WHERE application_id=%s ORDER BY row_no LIMIT 1", (application_id,))
        row = cur.fetchone()
        if row:
            eligibility = _s(row.get('eligibility_name')) or ''
    except Exception as e:
        logger.warning(f'load_peso_profile: eligibility failed: {e}')

    resume_filename = None
    try:
        cur.execute(
            "SELECT file_name FROM app_peso_applications_attachments "
            "WHERE application_id=%s AND attachment_type='resume' "
            "ORDER BY id DESC LIMIT 1", (application_id,))
        row = cur.fetchone()
        if row:
            resume_filename = row.get('file_name')
    except Exception as e:
        logger.warning(f'load_peso_profile: attachments failed: {e}')

    experience = {
        'previous_jobs': previous_jobs,
        'skills': skills,
        'eligibility': eligibility,
        'resume_filename': resume_filename,
        'licenses': licenses,
    }

    return {
        'personal': personal,
        'preferences': preferences,
        'education': education,
        'experience': experience,
    }


def insert_job_vacancy_link(cur, job_posting_id, user_id, applicant_id,
                            application_number, ts):
    """Link a PESO applicant row to the specific job posting they applied
    to (app_job_vacancies_applicant), so an admin can list every applicant
    per vacancy. Returns the new link-row id."""
    date_only = str(ts)[:10]
    cur.execute("""
        INSERT INTO app_job_vacancies_applicant (
            application_number, status, date_created, date_updated,
            is_active, job_posting_id, user_id, applicant_id
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
    """, (
        application_number, 'PENDING', date_only, date_only,
        'ACTIVE', job_posting_id, user_id, applicant_id,
    ))
    link_id = cur.lastrowid
    logger.info(
        f'insert_job_vacancy_link: linked applicant={applicant_id} '
        f'posting={job_posting_id} user={user_id} link_id={link_id}'
    )
    return link_id


def _insert_skills(cur, application_id, skills_raw):
    """Resolve free-text skills against app_peso_applications_skill_catalog.

    Matched skills get a real skill_id; everything unmatched is rolled up
    into a single "Others" row with the raw text in other_specify.
    """
    text = _s(skills_raw)
    if not text:
        return
    logger.info(f'peso[{application_id}]: resolving skills against catalog')

    # Build a name->id catalog map once.
    cur.execute("SELECT id, skill_name FROM app_peso_applications_skill_catalog")
    catalog = {}
    others_id = None
    for row in cur.fetchall() or []:
        name = (row.get('skill_name') if isinstance(row, dict) else row[1]) or ''
        sid = row.get('id') if isinstance(row, dict) else row[0]
        catalog[name.strip().lower()] = sid
        if name.strip().lower() == 'others':
            others_id = sid

    parts = [p.strip() for p in text.replace(';', ',').split(',') if p.strip()]
    unmatched = []
    matched = 0
    for part in parts:
        sid = catalog.get(part.lower())
        if sid and part.lower() != 'others':
            cur.execute("""
                INSERT INTO app_peso_applications_skills
                    (application_id, skill_id, other_specify)
                VALUES (%s, %s, %s)
            """, (application_id, sid, None))
            matched += 1
        else:
            unmatched.append(part)

    if unmatched and others_id:
        cur.execute("""
            INSERT INTO app_peso_applications_skills
                (application_id, skill_id, other_specify)
            VALUES (%s, %s, %s)
        """, (application_id, others_id, _clip(', '.join(unmatched), 120)))

    logger.info(
        f'peso[{application_id}]: skills matched={matched} '
        f'unmatched={len(unmatched)}'
    )