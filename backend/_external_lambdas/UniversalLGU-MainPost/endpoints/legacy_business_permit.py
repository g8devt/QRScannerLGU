"""Legacy `business`-schema business permit submit (marilao-fidelity).

Ports marilao's `insert_business_permit_data` into csjdm's backend so a NEW
application from the full 8-step wizard is written into the real
`business` / `business_capital` / `business_operation` / `business_approvals`
/ `business_history` / `business_inspections` / `business_images` tables
(all present in csjdm's DB), instead of the simplified `app_business_permits`
redesign.

Route: `insert_business_permit`
"""
import json
import logging
import re
import uuid
from datetime import datetime

from helpers.auth import ok, fail, require
from helpers.db import serialize_row
from helpers.s3 import upload_to_s3, generate_key

logger = logging.getLogger()

# Multipart field name (document category) -> S3 sub-folder. Mirrors marilao's
# FOLDER_MAP for the categories the citizen wizard uploads.
_FOLDER_MAP = {
    'clearance': 'clearance_pictures',
    'cedula': 'cedula_pictures',
    'valid_id': 'valid_id',
    'business_image': 'business_images',
    'dti_sec_cda': 'dti_sec_cda_pictures',
    'lease_contract': 'lease_pictures',
    'proof_of_ownership': 'proof_ownership_pictures',
    'tax_declaration': 'tax_declaration_pictures',
    'locational_clearance': 'conformance_pictures',
    'coop_cert': 'coop_cert_pictures',
    'hoa_cert': 'hoa_pictures',
    'spa': 'sworn_documents',
    # ── Renewal-only categories (marilao's renewal document set) ──
    'establishment_photo': 'establishment_pictures',
    'application_form': 'application_form_pictures',
    'mayors_permit': 'mayors_permit_pictures',
    'gross_declaration': 'gross_declaration_pictures',
    'secretary_cert': 'secretary_cert_pictures',
    'form_2303': 'form_2303_pictures',
    'gis': 'gis_pictures',
    # ── Closure-only categories (marilao's closure document set) ──
    # The other 6 closure slots (application_form, mayors_permit,
    # gross_declaration, tax_declaration, spa, secretary_cert) are already
    # mapped above — which is exactly why closure uploads with unique_keys=True.
    'letter_of_closure': 'letter_of_closure_pictures',
    'business_plate': 'business_plate_pictures',
    'barangay_closure_cert': 'barangay_closure_pictures',
    'sanitary_report': 'sanitary_report_pictures',
}


# Columns never copied into `business_old`. Retirement/closure state describes
# the live row's current standing, not the pre-renewal snapshot we're archiving.
# marilao's list is the first 12; 'id' is ours — a deliberate divergence:
#
#   `business`.`id` is that row's identity for its whole life — assigned once at
#   INSERT, never reassigned. `business_old`.`id` is a PRIMARY KEY. Copying the
#   former into the latter therefore writes the SAME key on every renewal of a
#   given business: the first archive succeeds, the second dies on
#   "1062 Duplicate entry for key 'PRIMARY'", rolls back, and 500s with the
#   citizen's documents already in S3. Since the id can't change, that business
#   is then unrenewable forever — and annual renewal is the whole feature.
#
#   The archive wants a NEW identity per snapshot, which is what excluding the
#   column and letting the column default supply one gets us. Migration 048 adds
#   the AUTO_INCREMENT that makes that default exist; without it, this exclusion
#   trades the duplicate-key error for "Field 'id' doesn't have a default value"
#   under STRICT_TRANS_TABLES. The two changes ship together.
#
# marilao never hit this because it isn't in its exclude list — see
# test_archive_over_real_schema_excludes_id, which pins this against the real
# dump rather than a synthetic column list.
_ARCHIVE_EXCLUDE = frozenset({
    'id',
    'business_closure_no',
    'bus_status_for_retirement',
    'last_bus_status_for_retirement',
    'last_bus_application_status_for_retirement',
    'last_renewed_for_year_for_retirement',
    'retirement_verification',
    'retirement_date_cancelled',
    'retirement_date_of_effectivity',
    'retirement_date_issued',
    'retirement_deny_reason',
    'retirement_denied_by',
    'retirement_denied_date',
})


# ── Renewal eligibility ──────────────────────────────────────────────────────
# These two sets are the server-side half of a gate that `isRenewable` in
# lib/features/business_permit/presentation/utils/renewal_utils.dart mirrors
# exactly. Change one, change both — see the comment there.
#
# bus_application_status: where the paperwork stands.
#   RELEASED     — last year's permit was issued and is done. The ordinary case.
#   FOR RENEWAL  — the LGU has already flagged the business as due for renewal.
#                  This is precisely the population the feature serves, so a
#                  RELEASED-only gate would reject the businesses most entitled
#                  to renew.
# Everything else stays out. The mid-application states (FOR CHECKING, FOR
# ASSESSMENT, FOR PAYMENT, ...) are what make this guard necessary at all: a
# double submit would otherwise archive an already-renewed row, so the snapshot
# meant to preserve the pre-renewal state would preserve the post-renewal one.
# FOR RENEWAL is not one of those — it's a resting state, not a half-finished
# application, so admitting it reintroduces nothing. DENIED stays out too: a
# denial is an admin's decision, not an error to route around.
_RENEWABLE_APP_STATUS = frozenset({'RELEASED', 'FOR RENEWAL'})

# bus_status: whether the business itself is still alive. A CLOSED / FOR CLOSING
# business must not be renewable at ANY application status — without this check
# a direct API call resurrects a closed business (permit blanked, bus_status
# RENEW, FOR CHECKING) with no admin involved. The picker has always filtered on
# this; the endpoint is the trust boundary, and it wasn't checking.
_RENEWABLE_BUS_STATUS = frozenset({'NEW', 'RENEW'})

# Mirrors _grossPattern in renewal_utils.dart — re.ASCII is what makes that
# true: Python's \d is Unicode-aware (matches Arabic-indic '١٢٣', fullwidth
# '１２３', Devanagari '१२३', ...) where Dart's RegExp \d is ASCII-only, and
# float() accepts those Unicode digits too, so without re.ASCII this pattern
# would silently accept strings the client already rejects. Deliberately not
# float(): float() accepts '1e5', 'inf' and 'nan', none of which belong in a
# varchar(25) money column that admin tooling parses back out.
_GROSS_PATTERN = re.compile(r'^\d+(\.\d+)?$', re.ASCII)

# The column this is destined for — business.renew_business_gross — is
# varchar(25). Bound both sides against that (see validateGross in
# renewal_utils.dart for the client half) so an oversized value 400s here
# instead of hitting the UPDATE, where strict mode rolls the transaction back
# after S3 uploads already landed and non-strict mode silently truncates a
# money value.
_GROSS_MAX_LEN = 25

# ── Closure (retirement) ─────────────────────────────────────────────────────
# marilao's closure UX ported onto csjdm's `business` schema. Closure does NOT
# archive to business_old, unlike renewal: it destroys nothing — the pre-closure
# bus_status is preserved on the live row in last_bus_status_for_retirement —
# and business_old has no retirement_verification /
# retirement_date_of_effectivity columns at all (they're in _ARCHIVE_EXCLUDE
# precisely because they don't exist there). marilao doesn't archive on closure
# either. See docs/superpowers/specs/2026-07-17-business-permit-closure-design.md.

# The same two sets as renewal, for the same reasons — but the bus_status half
# does double duty here. Excluding FOR CLOSING / CLOSED is what stops a SECOND
# closure request from overwriting last_bus_status_for_retirement with
# 'FOR CLOSING', which would destroy the original status the closure needs in
# order to ever be cancelled. marilao gates this client-side only (it greys the
# button, closure_permit_view.dart:228) and its handler accepts the repeat
# happily. Mirrored by isClosable() in closure_utils.dart — change one, change
# both, in the same commit.
_CLOSABLE_APP_STATUS = frozenset({'RELEASED', 'FOR RENEWAL'})
_CLOSABLE_BUS_STATUS = frozenset({'NEW', 'RENEW'})

# marilao's verificationList (lib/utilities/global.dart:288-295), verbatim.
# retirement_verification is free `text` that an approver reads, so the values
# are pinned to this set server-side — the client is not the trust boundary.
# marilao stores a Dart List.toString() ("[Deceased Licensee]"), brackets and
# all; we store the values themselves. Mirrored by kRetirementVerificationOptions
# in closure_utils.dart. These are WIRE values, never translated.
_VERIFICATION_OPTIONS = (
    'Still Operating',
    'Change of Business Line',
    'Change of Business Name',
    'Placed under new management only',
    'Business transferred/sold to a new owner',
    'Deceased Licensee',
)

# retirement_date_of_effectivity is varchar(25), so nothing in the schema
# enforces a shape. YYYY-MM-DD matches ts ('%Y-%m-%d %H:%M:%S'), sorts
# lexicographically, and is what the old closure view already sent. re.ASCII for
# the same reason as _GROSS_PATTERN — see that comment.
_DATE_PATTERN = re.compile(r'^\d{4}-\d{2}-\d{2}$', re.ASCII)


def _clean_gross(raw):
    """Validate the one value the renewal collects. Returns the normalized
    string to store, or None when it isn't a positive number that fits the
    varchar(25) column it's stored in.

    Mirrors validateGross/normalizeGross in renewal_utils.dart. The client
    already normalizes and validates, but the client is not the trust boundary:
    before this, a direct call with '' or 'abc' persisted as-is and returned
    success: true — the same silent-data-loss shape 047 called out in marilao's
    handler and deliberately fixed, just moved from the schema to the wire.
    """
    v = (raw or '').replace(',', '').strip()
    if not v or len(v) > _GROSS_MAX_LEN or not _GROSS_PATTERN.match(v):
        return None
    return v if float(v) > 0 else None


def _clean_verification(raw):
    """Normalize the retirement verification selection to a comma-joined string,
    or None when it's empty or holds anything outside _VERIFICATION_OPTIONS.

    Accepts a list (from form_data JSON) or a comma-joined string. Output is
    ordered by _VERIFICATION_OPTIONS, not by the order given, so the stored
    string is stable however the citizen tapped the checkboxes. Mirrors
    normalizeVerification in closure_utils.dart.
    """
    if isinstance(raw, str):
        items = [p.strip() for p in raw.split(',')]
    elif isinstance(raw, (list, tuple)):
        items = [str(p).strip() for p in raw]
    else:
        return None
    items = [p for p in items if p]
    if not items:
        return None
    if any(p not in _VERIFICATION_OPTIONS for p in items):
        return None
    chosen = set(items)
    return ', '.join(o for o in _VERIFICATION_OPTIONS if o in chosen)


def _clean_effectivity_date(raw):
    """Validate the retirement effectivity date. Returns the string to store, or
    None when it isn't a real YYYY-MM-DD date.

    strptime is what rejects 2026-02-31 — the pattern only checks the shape, and
    the column is varchar(25), so nothing downstream would catch it. Mirrors
    validateEffectivityDate in closure_utils.dart, which needs an explicit
    round-trip to match: Dart's DateTime.parse ROLLS 2026-02-31 over to
    2026-03-03 rather than rejecting it.
    """
    if not isinstance(raw, str):
        return None
    v = raw.strip()
    if not _DATE_PATTERN.match(v):
        return None
    try:
        datetime.strptime(v, '%Y-%m-%d')
    except ValueError:
        return None
    return v


def _archive_columns(row_keys, business_old_columns):
    """Columns to copy from a `business` row into `business_old`.

    marilao builds this list from the fetched row minus _ARCHIVE_EXCLUDE, which
    assumes the two tables match. csjdm's don't: `business_old` has 77 columns
    against `business`'s 94, and 7 unexcluded ones (business_owner_id,
    bus_pic_civil_status, bus_pic_place_of_birth, bus_pic_date_of_birth,
    bus_requirement_status, bus_application_for_compliance_document,
    business_sanitary_permit_control_no) have no home there — marilao's list
    would throw Unknown column in 'field list'.

    Intersecting against business_old's real columns fixes that and keeps fixing
    it: migration 046 added three columns to `business` and 047 adds another, so
    the drift is ongoing, not a one-off. Order follows business_old so the
    generated INSERT is stable.
    """
    keys = set(row_keys)
    return [c for c in business_old_columns
            if c in keys and c not in _ARCHIVE_EXCLUDE]


def _parse_form(data):
    """Return the merged form dict: form_data JSON overlaid with top-level data."""
    raw = data.get('form_data') or data.get('formData') or '{}'
    if isinstance(raw, (bytes, bytearray)):
        raw = raw.decode('utf-8', 'ignore')
    try:
        form = json.loads(raw) if isinstance(raw, str) else dict(raw or {})
    except Exception:
        form = {}
    if not isinstance(form, dict):
        form = {}
    # Merge top-level fields that aren't already in form_data.
    for k, v in data.items():
        form.setdefault(k, v)
    return form


def _enum(val, allowed, default=None):
    """Normalize to an allowed uppercase enum literal, else the default."""
    s = (val or '').strip().upper()
    return s if s in allowed else default


def _bool_enum(val):
    """Marilao stores yes/true → 'true', else 'false' (enum('true','false'))."""
    s = (val or '').strip().lower()
    return 'true' if s in ('true', 'yes', '1') else 'false'


def _content_type_for(filename):
    """Guess the S3 ContentType from the filename extension so stored PDFs
    aren't mislabeled as image/jpeg (the upload_to_s3 default)."""
    ext = filename.rsplit('.', 1)[-1].lower() if '.' in filename else ''
    return {
        'pdf': 'application/pdf',
        'png': 'image/png',
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
    }.get(ext, 'image/jpeg')


class _UploadFailed(Exception):
    """A document upload to S3 failed and the caller asked to be told.

    Only raised when _upload_docs(strict=True) — the renewal and closure
    paths. See the strict= note there for why insert_business_permit (the
    third caller) differs from those two.
    """


def _upload_docs(files, business_id, unique_keys=False, strict=False):
    """Upload each multipart file to S3 under app/uploads/<id>/<folder>/<name>.
    Returns a list of {url, folder, filename, size}.

    unique_keys — append a random suffix to every object key (via
    helpers.s3.generate_key). Off by default; renewal and closure both turn
    it ON.

        The default key is fully deterministic: the app names its parts
        `<category>_<n>.<ext>` (business_permit_remote_datasource.dart), so the
        key is a pure function of (business_id, category, index). That's
        harmless for a NEW permit, which mints a fresh TEMP_<uuid> business_id
        per submit and so can never collide with anything. Renewal reuses the
        EXISTING business_id, and 7 of its 14 categories (business_image,
        valid_id, cedula, clearance, locational_clearance, coop_cert, spa) are
        also new-permit categories — so a renewal's
        app/uploads/B1/valid_id/valid_id_1.jpg is byte-for-byte the key the
        original application already wrote, and put_object silently overwrites
        it. The original's business_images row still points there, now serving
        the renewal's file; next year's renewal then clobbers this year's.
        Uniqueness per upload is the only thing that makes an archive an
        archive. (The endpoint renewal replaced used generate_key and did not
        have this bug.)

    strict — raise _UploadFailed instead of skipping a file that fails to
    upload. Off by default; renewal and closure both turn it ON.

        Swallowing per-file failures is right for insert_business_permit: it
        has no eligibility lock, so a citizen whose document didn't land can
        just submit again. Renewal and closure are the opposite. A silently-
        dropped required document still returns status: True and still moves
        the business to FOR CHECKING (renewal) or FOR CLOSING (closure) — at
        which point the eligibility guard rejects every retry and only an
        admin can unstick it. Both callers' uploads run before the
        transaction opens, so raising here strands nothing: the business row
        is untouched and the citizen simply retries.
    """
    out = []
    for f in files or []:
        filename = None
        try:
            field = (f.get('field_name') or 'business_image').strip()
            folder = _FOLDER_MAP.get(field, 'business_images')
            content = f['content']
            content.seek(0)
            body = content.read()
            filename = f.get('filename') or f'{field}.jpg'
            if unique_keys:
                # generate_key(prefix, user_id, filename) ->
                # "<prefix>/<user_id>/<name>_<uuid8>.<ext>", which lands on the
                # same app/uploads/<id>/<folder>/ layout as the default key,
                # just with a collision-proof leaf.
                key = generate_key(f'app/uploads/{business_id}', folder, filename)
            else:
                key = f'app/uploads/{business_id}/{folder}/{filename}'
            url = upload_to_s3(body, key, content_type=_content_type_for(filename))
            out.append({'url': url, 'folder': folder,
                        'filename': filename, 'size': len(body)})
        except Exception as e:
            logger.error(f'business doc upload failed: {e}', exc_info=True)
            if strict:
                raise _UploadFailed(filename or f.get('field_name') or '?') from e
            # else: isolate per-file failures, don't abort submit
    return out


def insert_business_permit(cur, data, files, ts):
    try:
        require(data, 'user_profile_id')
        form = _parse_form(data)
        added_by = (data.get('user_profile_id') or '').strip()
        business_id = (data.get('business_id') or '').strip() \
            or f'TEMP_{uuid.uuid4().hex[:12]}'
        is_renew = (data.get('is_renew') or '').strip().upper()
        bus_status = 'RENEW' if is_renew == 'RENEW' else 'NEW'
        year = datetime.strptime(ts, '%Y-%m-%d %H:%M:%S').year \
            if isinstance(ts, str) else datetime.now().year

        def g(k):
            v = form.get(k)
            return v.strip() if isinstance(v, str) else v

        # ── business ──
        cur.execute("""
            INSERT INTO business (
                business_id, bus_status, bus_application_type, bus_name,
                bus_trade, bus_franchise, bus_type_of_registration,
                bus_registration_no, bus_registration_date,
                bus_registration_date_exp, bus_type, bus_ctc, bus_tin,
                bus_ad_region, bus_ad_prov, bus_ad_city_mun, bus_ad_brgy,
                bus_ad_zip, bus_ad_bldg_name, bus_ad_bldg_no, bus_ad_lot_no,
                bus_ad_block_no, bus_ad_street, bus_ad_subdivision,
                bus_telephone, bus_mobile, bus_email, bus_pic_first_name,
                bus_pic_middle_name, bus_pic_last_name, bus_pic_suffix,
                bus_pic_civil_status, bus_pic_place_of_birth,
                bus_pic_date_of_birth,
                bus_kind, renewed_for_year, bus_for_delivery,
                bus_application_status, bus_application_for_compliance_document,
                added_by, bus_geo_tagging, date_added, bus_capital,
                business_owner_id
            ) VALUES (%s,%s,'MOBILE',%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,
                      %s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,
                      %s,'false',
                      'FOR CHECKING','',%s,%s,%s,%s,%s)
        """, (
            business_id, bus_status, g('businessName'), g('tradeName'),
            g('franchiseName'), g('registrationType'), g('regNo'),
            g('dateReg'), g('dateExp'),
            _enum(g('businessType'),
                  {'CORPORATION', 'PARTNERSHIP', 'SOLE PROPRIETORSHIP',
                   'COOPERATIVE', 'ASSOCIATION'}),
            g('ctc'), g('tin'), g('mainOfficeSelectedRegion'),
            g('mainOfficeSelectedProvince'), g('mainOfficeSelectedCity'),
            g('mainOfficeSelectedBarangay'), g('zipCodeController'),
            g('bldgNameController'), g('houseNoController'), g('lotNoController'),
            g('blockNoController'), g('streetController'),
            g('subdivisionController'), g('telephoneController'),
            g('mobile_number'), g('emailController'), g('firstNameController'),
            g('middleNameController'), g('lastNameController'),
            g('suffixController'),
            # Optional owner fields. Civil status is normalized against the
            # allowed set (None when blank/unrecognized); DOB stays the app's
            # MM/dd/yyyy string — bus_pic_date_of_birth is varchar, like the
            # sibling bus_registration_date columns.
            _enum(g('ownerCivilStatus'),
                  {'SINGLE', 'MARRIED', 'WIDOWED', 'SEPARATED'}),
            g('ownerPlaceOfBirth'), g('ownerDateOfBirth'),
            _enum(g('kindOfBusiness'), {'FILIPINO', 'FOREIGN'}, 'FILIPINO'),
            year, added_by, g('busGeoTagging'), ts,
            g('businessCapitalController'), added_by,
        ))

        # ── business_capital ──
        cur.execute("""
            INSERT INTO business_capital
                (business_id, bus_capital, added_by, date_added)
            VALUES (%s,%s,%s,%s)
        """, (business_id, g('businessCapitalController'), added_by, ts))

        # ── business_operation ──
        cur.execute("""
            INSERT INTO business_operation (
                business_op_id, business_op_activity, bus_op_ad_region,
                bus_op_ad_prov, bus_op_ad_city_mun, bus_op_ad_brgy,
                bus_op_ad_zip, bus_op_ad_bldg_name, bus_op_ad_bldg_no,
                bus_op_ad_lot_no, bus_op_ad_block_no, bus_op_ad_street,
                bus_op_ad_subdivision, business_op_if_subd, bus_op_area,
                bus_op_floor_area, bus_op_internet_provider, bus_op_est_male,
                bus_op_est_female, bus_op_res_male, bus_op_res_female,
                bus_op_sputum, bus_op_no_of_truck_van, bus_op_no_of_motorcycles,
                bus_op_is_owned, bus_op_tdn, bus_op_pin, bus_op_has_incentives,
                bus_op_is_rented, bus_op_is_rented_hm, bus_op_thru_representative,
                bus_op_lessor_name, bus_op_lessor_address, bus_op_lessor_contact,
                bus_op_lessor_email, bus_op_emergency_fullname,
                bus_op_emergency_contact, bus_op_line_of_business, added_by,
                date_added
            ) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,
                      %s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,
                      %s,%s)
        """, (
            business_id, g('businessActivity'),
            g('businessOperationSelectedRegion'),
            g('businessOperationSelectedProvince'),
            g('businessOperationSelectedCity'),
            g('businessOperationSelectedBarangay'),
            g('businessOPZipCodeController'), g('businessOPBldgNameController'),
            g('businessOPHouseNoController'), g('businessOPLotNoController'),
            g('businessOPBlockNoController'), g('businessOPStreetController'),
            g('businessOPSubdivisionController'),
            _enum(g('isSubdivision'), {'YES', 'NO'}, 'NO'),
            g('businessAreaController'), g('totalFloorAreaController'),
            g('internetProviderController'), g('noMaleEstablishmentController'),
            g('noFemaleEstablishmentController'), g('noMaleLGUController'),
            g('noFemaleLGUController'), g('noSputumTestController'),
            g('noDeliveryVehiclesTruckController'),
            g('noDeliveryVehiclesMotorcycleController'),
            _bool_enum(g('owned')), g('taxDeclarationController'),
            g('propertyIndexController'), _bool_enum(g('taxIncentives')),
            _bool_enum(g('rentedBusinessPlace')),
            (g('monthlyRent') or '0'),
            _enum(g('representative'), {'YES', 'NO'}, 'NO'),
            g('lessorNameController'), g('lessorAddressController'),
            g('lessorContactController'), g('lessorEmailController'),
            g('emergencyContactPersonController'),
            g('emergencyContactNumberController'), g('lineOfBusiness'),
            added_by, ts,
        ))

        # ── business_approvals / history / inspections ──
        cur.execute("""
            INSERT INTO business_approvals
                (business_id, approval_year, added_by, date_added)
            VALUES (%s,%s,%s,%s)
        """, (business_id, year, added_by, ts))
        cur.execute("""
            INSERT INTO business_history (business_id, added_by, date_added)
            VALUES (%s,%s,%s)
        """, (business_id, added_by, ts))
        cur.execute("""
            INSERT INTO business_inspections
                (business_id, inspection_year, added_by, date_added)
            VALUES (%s,%s,%s,%s)
        """, (business_id, year, added_by, ts))

        # ── business_images (one row per uploaded document) ──
        for item in _upload_docs(files, business_id):
            cur.execute("""
                INSERT INTO business_images (
                    business_id, image_path, image_dep, file_folder_name,
                    file_name, file_size, date_added, added_by, date_updated,
                    updated_by, is_sync
                ) VALUES (%s,%s,'SKETCH | PICTURE',%s,%s,%s,%s,%s,%s,%s,'0')
            """, (
                business_id, item['url'], item['folder'],
                item['url'].split('/')[-1], str(item['size']),
                ts, added_by, ts, added_by,
            ))

        return ok({
            'status': True,
            'message': 'Business permit application submitted',
            'business_id': business_id,
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'insert_business_permit error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def get_my_businesses(cur, data, files, ts):
    """List the signed-in user's business-schema permits (newest first)."""
    try:
        require(data, 'user_profile_id')
        uid = data['user_profile_id']
        # retirement_date_applied feeds the closure picker's "Requested on
        # <date>" line for a business already FOR CLOSING
        # (business_permit_closure_view.dart). Do NOT prune it as unused —
        # serialize_row() turns the NULL default into '' for businesses that
        # have never had a closure filed, which the picker's .isNotEmpty
        # check already handles.
        cur.execute("""
            SELECT business_id, bus_name, bus_trade, bus_type, bus_status,
                   bus_application_type, bus_application_status,
                   business_permit_no, bus_pic_first_name, bus_pic_middle_name,
                   bus_pic_last_name, bus_pic_suffix, bus_ad_brgy,
                   bus_ad_city_mun, bus_ad_prov, date_added,
                   retirement_date_applied
            FROM business
            WHERE deleted='false' AND (added_by=%s OR business_owner_id=%s)
            ORDER BY date_added DESC
        """, (uid, uid))
        rows = cur.fetchall()
        return ok({
            'status': True,
            'data': {'items': [serialize_row(r) for r in rows]},
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'get_my_businesses error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def get_business_detail(cur, data, files, ts):
    """Full detail of one business-schema permit: business row + operation +
    document image URLs."""
    try:
        require(data, 'user_profile_id', 'business_id')
        uid = data['user_profile_id']
        bid = data['business_id']
        cur.execute("""
            SELECT * FROM business
            WHERE business_id=%s AND (added_by=%s OR business_owner_id=%s)
            LIMIT 1
        """, (bid, uid, uid))
        biz = cur.fetchone()
        if not biz:
            return fail('Business not found', 404)
        cur.execute(
            "SELECT * FROM business_operation WHERE business_op_id=%s LIMIT 1",
            (bid,))
        op = cur.fetchone()
        cur.execute(
            "SELECT image_path FROM business_images WHERE business_id=%s", (bid,))
        images = [r['image_path'] for r in cur.fetchall() if r.get('image_path')]
        return ok({
            'status': True,
            'data': {
                'business': serialize_row(biz),
                'operation': serialize_row(op) if op else {},
                'images': images,
            },
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'get_business_detail error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)


def renew_business_application(cur, data, files, ts):
    """Renew an existing business permit — marilao's renew_business_application,
    ported onto csjdm's `business` schema.

    Unlike insert_business_permit this is an UPDATE IN PLACE of the existing
    `business` row (after snapshotting it into `business_old`), not an INSERT.
    The citizen supplies exactly one value — last year's gross — and every other
    field carries forward from the row being renewed.

    Route: `renew_business_application`
    """
    try:
        require(data, 'user_profile_id')
        form = _parse_form(data)
        added_by = (data.get('user_profile_id') or '').strip()
        business_id = (form.get('business_id') or '').strip()
        if not business_id:
            return fail('business_id is required', 400)
        gross = _clean_gross(form.get('renew_business_gross'))
        if gross is None:
            return fail('Gross sales must be a number greater than zero', 400)

        # 1. Renewal year. LGU config (migration 047 seeds it); renewal cannot
        #    be stamped without it.
        cur.execute("SELECT year FROM default_renewal_year LIMIT 1")
        year_row = cur.fetchone()
        if not year_row:
            return fail('No renewal year set', 400)
        year = year_row['year']

        # 2. Fetch, scoped to the caller. marilao looks the business up by
        #    business_id alone, so any authenticated user can renew anyone's
        #    business by guessing an id. get_business_detail already scopes this
        #    way; renewal matches it.
        #    NOTE: raw row — do NOT serialize_row() here. serialize_row turns
        #    None into '' and ints into str, which the archive must not do.
        cur.execute("""
            SELECT * FROM business
            WHERE business_id=%s AND deleted='false'
              AND (added_by=%s OR business_owner_id=%s)
        """, (business_id, added_by, added_by))
        business = cur.fetchone()
        if not business:
            return fail('Business not found', 404)

        # 3. Eligibility. Both halves are required and both are enforced here,
        #    not just in the picker: the paperwork must be at rest
        #    (_RENEWABLE_APP_STATUS) AND the business must still be alive
        #    (_RENEWABLE_BUS_STATUS). See those constants for the reasoning, and
        #    keep them in step with isRenewable() in renewal_utils.dart.
        app_status = (business.get('bus_application_status') or '').strip().upper()
        bus_status = (business.get('bus_status') or '').strip().upper()
        if (app_status not in _RENEWABLE_APP_STATUS
                or bus_status not in _RENEWABLE_BUS_STATUS):
            return fail('This business is not eligible for renewal', 400)

        # 4-6 mutate `business_old`, `business`, `business_history`, and
        # `business_images` across four statements. Every other handler in this
        # module relies on autocommit — but here a partial failure between the
        # UPDATE (step 5, sets bus_application_status='FOR CHECKING') and the
        # trailing INSERTs would strand the row: the RELEASED guard above (step
        # 3) would then reject every retry, since the row is no longer RELEASED,
        # and only an admin could unstick it. This handler is the deliberate
        # first exception to the no-transaction convention — the read-side
        # guards above (all early-return fail()s) run before the transaction
        # opens, so we never open one we'd immediately abandon.
        #
        # Upload documents to S3 *before* opening that transaction, not inside
        # it. _upload_docs does synchronous network I/O (upload_to_s3 per
        # file, up to 9MB each); the UPDATE below takes an exclusive lock on
        # this business_id row, and holding that lock across the upload loop
        # would block any concurrent write to the same row for the whole
        # upload window, risking innodb_lock_wait_timeout. Pre-fetching here
        # keeps the transaction to four fast DB statements only. Do NOT move
        # this back inside the transaction.
        #
        # unique_keys/strict both diverge from insert_business_permit's defaults
        # and both depend on running here, ahead of any write — see _upload_docs.
        # Bailing out at this point leaves nothing stranded: the business row is
        # still RELEASED/FOR RENEWAL, so the citizen can just retry. Bailing out
        # after the UPDATE would leave it at FOR CHECKING, which the guard in
        # step 3 rejects — locking the citizen out of the very retry that would
        # fix it.
        try:
            docs = _upload_docs(files, business_id, unique_keys=True, strict=True)
        except _UploadFailed as e:
            logger.error(f'renewal aborted before any write, upload failed: {e}')
            return fail('A document failed to upload. Please try again.', 500)

        cur.connection.begin()
        try:
            # 4. Snapshot the pre-renewal row.
            cur.execute("SHOW COLUMNS FROM business_old")
            old_cols = [r['Field'] for r in cur.fetchall()]
            cols = _archive_columns(business.keys(), old_cols)
            if cols:
                col_list = ','.join(f'`{c}`' for c in cols)
                placeholders = ','.join(['%s'] * len(cols))
                cur.execute(
                    f"INSERT INTO business_old ({col_list}) VALUES ({placeholders})",
                    tuple(business[c] for c in cols))

            # 5. Update in place. marilao additionally re-writes ~30 bus_*
            #    columns to their own existing values — a no-op self-copy;
            #    omitted.
            cur.execute("""
                UPDATE business SET
                    bus_status='RENEW',
                    business_permit_no='',
                    bus_application_type='MOBILE',
                    bus_application_status='FOR CHECKING',
                    date_of_renewal=%s,
                    renewed_for_year=%s,
                    renew_business_gross=%s,
                    added_by=%s
                WHERE business_id=%s
            """, (ts, year, gross, added_by, business_id))

            cur.execute("""
                INSERT INTO business_history (business_id, added_by, date_added)
                VALUES (%s,%s,%s)
            """, (business_id, added_by, ts))

            # 6. Documents. image_dep is NOT NULL with no default, so it must
            #    be set explicitly — same value insert_business_permit uses.
            #    docs were already uploaded to S3 above, outside the lock
            #    window; this just inserts the pre-fetched results.
            for item in docs:
                cur.execute("""
                    INSERT INTO business_images (
                        business_id, image_path, image_dep, file_folder_name,
                        file_name, file_size, date_added, added_by, date_updated,
                        updated_by, is_sync
                    ) VALUES (%s,%s,'SKETCH | PICTURE',%s,%s,%s,%s,%s,%s,%s,'0')
                """, (
                    business_id, item['url'], item['folder'],
                    item['url'].split('/')[-1], str(item['size']),
                    ts, added_by, ts, added_by,
                ))
            cur.connection.commit()
        except Exception:
            cur.connection.rollback()
            raise

        return ok({'status': True, 'business_id': business_id,
                   'renewed_for_year': year})
    except ValueError:
        raise  # lambda_handler maps this to a 400
    except Exception as e:
        logger.error(f'renew_business_application failed: {e}', exc_info=True)
        return fail('Failed to submit renewal', 500)


def retire_business_application(cur, data, files, ts):
    """Request closure (retirement) of a business permit — marilao's
    retire_business_application, ported onto csjdm's `business` schema.

    An UPDATE IN PLACE of the `business` row: bus_status becomes FOR CLOSING and
    the pre-closure status is preserved in last_bus_status_for_retirement.
    Deliberately NO business_old archive — see the _CLOSABLE_* block above.

    marilao's version cannot be reached from its own app (its required-docs list
    holds scholarship document names, so validation never passes) and, if it
    could, would discard three of the four values the citizen enters. This one
    persists all of them and guards the row. See
    docs/superpowers/specs/2026-07-17-business-permit-closure-design.md.

    Route: `retire_business_application`
    """
    try:
        require(data, 'user_profile_id')
        form = _parse_form(data)
        # user_profile_id is arbitrary user input (via require parsing). A
        # non-string value like 123 would raise AttributeError on .strip(),
        # which the generic except below turns into an opaque 500. Since
        # user_profile_id is required, a non-string value must 400 same as a
        # missing one (same bug class _clean_effectivity_date and business_id
        # guard against).
        raw_user_id = data.get('user_profile_id')
        added_by = raw_user_id.strip() \
            if isinstance(raw_user_id, str) else ''
        if not added_by:
            return fail('user_profile_id is required', 400)

        # form_data is arbitrary JSON (_parse_form), so business_id can arrive
        # as a non-string (e.g. {"business_id": 123}). (raw or '').strip()
        # raises AttributeError on that, which the generic except below turns
        # into an opaque 500 — same bug class _clean_effectivity_date guards
        # against with its isinstance check. business_id is required, so a
        # non-string value 400s same as a missing one.
        raw_business_id = form.get('business_id')
        business_id = raw_business_id.strip() \
            if isinstance(raw_business_id, str) else ''
        if not business_id:
            return fail('business_id is required', 400)

        verification = _clean_verification(form.get('retirement_verification'))
        if verification is None:
            return fail('Select at least one valid retirement verification', 400)
        effectivity = _clean_effectivity_date(
            form.get('retirement_date_of_effectivity'))
        if effectivity is None:
            return fail('Effectivity date must be a valid date (YYYY-MM-DD)', 400)
        # Optional — the verification list already carries the categorical
        # reason. marilao collects this and never reads it. Same non-string
        # guard as business_id above, but reason is optional so a non-string
        # value coerces to '' instead of 400ing.
        raw_reason = form.get('retirement_reason')
        reason = raw_reason.strip() if isinstance(raw_reason, str) else ''

        # 1. Fetch, scoped to the caller. marilao looks the business up by
        #    business_id alone behind a shared static app token, so any token
        #    holder can close anyone's business. Matches renewal /
        #    get_business_detail.
        #    NOTE: raw row — do NOT serialize_row() here (None -> '', int -> str).
        cur.execute("""
            SELECT * FROM business
            WHERE business_id=%s AND deleted='false'
              AND (added_by=%s OR business_owner_id=%s)
        """, (business_id, added_by, added_by))
        business = cur.fetchone()
        if not business:
            return fail('Business not found', 404)

        # 2. Eligibility. Both halves, server-side — the picker is a courtesy,
        #    this is the trust boundary. See _CLOSABLE_APP_STATUS /
        #    _CLOSABLE_BUS_STATUS, and keep them in step with isClosable() in
        #    closure_utils.dart.
        app_status = (business.get('bus_application_status') or '').strip().upper()
        bus_status = (business.get('bus_status') or '').strip().upper()
        if (app_status not in _CLOSABLE_APP_STATUS
                or bus_status not in _CLOSABLE_BUS_STATUS):
            return fail('This business is not eligible for closure', 400)

        # 3. Upload to S3 *before* opening the transaction — same two reasons as
        #    renewal: the UPDATE takes an exclusive lock on this business_id row
        #    and holding it across the upload loop (up to 9MB/file) risks
        #    innodb_lock_wait_timeout; and strict=True must be able to bail
        #    without stranding anything. Bailing here leaves the row untouched,
        #    so the citizen retries. Bailing after the UPDATE would leave it
        #    FOR CLOSING, which step 2 then rejects on every retry — locking the
        #    citizen out of the fix. Do NOT move this inside the transaction.
        #
        #    unique_keys=True because closure reuses an EXISTING business_id and
        #    6 of its 10 categories (application_form, mayors_permit,
        #    gross_declaration, tax_declaration, spa, secretary_cert) are also
        #    new-permit/renewal categories — a deterministic key is byte-for-byte
        #    the one the original application wrote, and put_object silently
        #    overwrites it.
        try:
            docs = _upload_docs(files, business_id, unique_keys=True, strict=True)
        except _UploadFailed as e:
            logger.error(f'closure aborted before any write, upload failed: {e}')
            return fail('A document failed to upload. Please try again.', 500)

        cur.connection.begin()
        try:
            # 4. Update in place. bus_application_status is deliberately NOT
            #    touched: closure is orthogonal to where the paperwork stands,
            #    and marilao leaves it alone too. last_bus_status_for_retirement
            #    captures the status the row had on the way IN — it is the only
            #    record of it, and the thing a cancellation would restore.
            cur.execute("""
                UPDATE business SET
                    last_bus_status_for_retirement=%s,
                    bus_status='FOR CLOSING',
                    retirement_status='pending',
                    retirement_verification=%s,
                    retirement_reason=%s,
                    retirement_date_applied=%s,
                    retirement_date_of_effectivity=%s,
                    date_updated=%s,
                    updated_by=%s
                WHERE business_id=%s
            """, (bus_status, verification, reason, ts, effectivity, ts,
                  added_by, business_id))

            cur.execute("""
                INSERT INTO business_history (business_id, added_by, date_added)
                VALUES (%s,%s,%s)
            """, (business_id, added_by, ts))

            # 5. Documents. image_dep is NOT NULL with no default, so it must be
            #    set explicitly — same value insert_business_permit uses. docs
            #    were uploaded above, outside the lock window; this only inserts
            #    the pre-fetched results.
            for item in docs:
                cur.execute("""
                    INSERT INTO business_images (
                        business_id, image_path, image_dep, file_folder_name,
                        file_name, file_size, date_added, added_by, date_updated,
                        updated_by, is_sync
                    ) VALUES (%s,%s,'SKETCH | PICTURE',%s,%s,%s,%s,%s,%s,%s,'0')
                """, (
                    business_id, item['url'], item['folder'],
                    item['url'].split('/')[-1], str(item['size']),
                    ts, added_by, ts, added_by,
                ))
            cur.connection.commit()
        except Exception:
            cur.connection.rollback()
            raise

        return ok({'status': True, 'business_id': business_id})
    except ValueError:
        raise  # lambda_handler maps this to a 400
    except Exception as e:
        logger.error(f'retire_business_application failed: {e}', exc_info=True)
        return fail('Failed to submit closure request', 500)
