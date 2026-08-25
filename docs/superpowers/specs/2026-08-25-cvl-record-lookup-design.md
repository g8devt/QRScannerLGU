# CVL Record Lookup by QR — Design Spec

Date: 2026-08-25
Status: Approved

## Purpose

Add a third scan purpose to the existing scanner app: scan a QR code and
look up the matching `app_cvl_list` (voter/civil registry) record via
`app_qr_code`, showing the record's details, or a clear "no record found"
message when the code doesn't match anything. This is a separate data
domain from the existing `app_social_services` claim-verification flow —
no code or table overlap with it.

## Scope

- Four backend endpoints: `find_cvl_by_qr_bataan` (read-only lookup by
  scanned QR), `get_cvl_by_id_bataan` (read-only lookup by primary key,
  for the search flow), `search_cvl_by_name_bataan` (read-only search by
  name), and `update_cvl_photo_bataan` (the one write this feature
  performs).
- A second entry point besides scanning: search by name from the
  dashboard, landing on the same detail view.
- New Flutter feature module `cvl_lookup`, mirroring the existing
  `social_service_claim`'s `service_details_*` slice (fetch-by-QR →
  loading → details view / error view), not the claim-submission flow.
- Reuses the existing `qr_scanner` camera, `ScannerPage`, `ApiClient`, and
  staff login/token — no new auth mechanism.
- Android only (matches existing `qr_scanner` scope).
- Read-only except the record's photo: no QR assignment, and no editing
  of any other CVL field, from the app. (Originally scoped fully
  read-only; narrowed after the initial build shipped — see "Photo edit"
  below.)

## Backend

### New endpoint — `find_cvl_by_qr_bataan`

New module `backend/_external_lambdas/UniversalLGU-MainPost/endpoints/cvl_records_bataan.py`,
registered in `ROUTES` in `lambda_function.py`. Plain app-token auth via
the handler's existing `check_token()` path — same tier as
`get_service_details_bataan` / `verify_qr_bataan`, **not** added to
`ADMIN_SESSION_REQUIRED_ENDPOINTS` (that mechanism hardcodes rejection of
every tenant DB except `cebu_lgu_db`).

- **In:** `{endpoint: 'find_cvl_by_qr_bataan', token, db_name, qr_code}`
- **Logic** — mirrors `EMS/api/find_cvl_by_qr.php` (the existing PHP admin
  endpoint) in this repo (`bataan_lgu_admin`), which the mobile app cannot
  call directly (PHP-session cookie auth, not this Lambda's token scheme):
  ```sql
  SELECT c.id, c.cvl_id, c.cvl_fullname, c.cvl_fname, c.cvl_mname,
         c.cvl_lname, c.cvl_suffix, c.cvl_address, c.cvl_mun, c.cvl_brgy,
         c.cvl_precinct_no, c.cvl_birthdate, c.cvl_contact_no, c.cvl_email,
         c.cvl_gender, c.cvl_sector, c.cvl_img_path, c.cvl_qr,
         q.qr_code AS cvl_qr_code
  FROM app_cvl_list c
  INNER JOIN app_qr_code q ON q.id = c.cvl_qr
  WHERE q.qr_code = %s
     OR (%s != '' AND REPLACE(q.qr_code, 'QR-', '') = %s)
     OR (%s = 1 AND q.id = %s)
  ORDER BY
     CASE
        WHEN q.qr_code = %s THEN 1
        WHEN %s != '' AND REPLACE(q.qr_code, 'QR-', '') = %s THEN 2
        WHEN %s = 1 AND q.id = %s THEN 3
        ELSE 4
     END
  LIMIT 1
  ```
  Same three-way match as the PHP version: exact `qr_code` string, the
  `QR-` prefix stripped down to its numeric suffix, or (if the scanned
  value is purely numeric) a direct `app_qr_code.id` match. Python params
  computed the same way PHP does (`normalizeQrNumericValue` →
  `preg_replace('/\D+/', '', ...)`, `ctype_digit` check), and the same
  `ORDER BY CASE` ranking as the PHP version is required, not optional:
  an `OR`-only match with no ranking lets `LIMIT 1` return an arbitrary
  row when a scanned value ambiguously satisfies more than one branch
  (e.g. scanning `42` can match both `app_qr_code.id = 42` and a
  different row whose `qr_code` happens to be `QR-42`) — QR codes being
  unique per record does not prevent that cross-branch collision, so the
  ranking is what actually picks the correct row.
  - No row → `fail('No CVL record was found for this QR code.', 404)`
  - Row found → `ok({data: serialize_row(row)})`

  No separate "QR not yet assigned" case exists on this path — a staff
  member is scanning a physical/printed code, so it either resolves to a
  record via `app_qr_code` or it doesn't match anything at all. Both read
  as the same "no record found" outcome to the scanning staff member.

### New endpoint — `update_cvl_photo_bataan`

Same module, same auth tier as `find_cvl_by_qr_bataan`. The only write
this feature performs on `app_cvl_list`.

- **In (multipart):** `{endpoint: 'update_cvl_photo_bataan', token,
  db_name, id, updated_by?}` + file `cvl_photo`
- **Logic:**
  1. `require(data, 'id')`; require a `cvl_photo` file in the multipart
     payload.
  2. `SELECT id FROM app_cvl_list WHERE id=%s` → 404 `fail('CVL record
     not found', 404)` if missing.
  3. `upload_files_from_list(files, f'cvl/{id}', id)` (same S3 upload
     helper `social_services_bataan.submit_claim_bataan` already uses) →
     new `cvl_img_path` URL.
  4. `UPDATE app_cvl_list SET cvl_img_path=%s, cvl_updated_by=%s,
     cvl_last_date_updated=%s WHERE id=%s` — `updated_by` falls back to
     the literal string `'MOBILE_SCANNER'` if the caller omits it
     (`cvl_updated_by` is `NOT NULL`).
  5. `ok({data: {cvl_img_path: new_url}})`.

**Why photo storage is a real constraint, not a formality.**
`cvl_img_path` is populated by two different systems today: the PHP
admin (`bataan_lgu_admin`'s `EMS/index.php`) saves it as a *relative*
path like `storage/cvl/cvl_....jpg`, served only from inside that app's
login-gated PHP session — a `curl` to
`https://bataan.ems-web.com/EMS/storage/cvl/<file>` 302s to `login.php`
for an unauthenticated request. This Lambda-token-authenticated mobile
app has no way to load that. The existing KYC-connect flow
(`EMS/admin/api/cvl.php`), by contrast, already sets `cvl_img_path` to a
full S3 URL (copied from `app_kyc.face_picture`), which loads fine
anywhere. `update_cvl_photo_bataan` always writes a full S3 URL (via
`upload_files_from_list`, same as every other Lambda-driven photo
upload in this backend) — so a photo edited from this app is always
displayable afterward, but a record whose photo was last set by the PHP
admin will show a placeholder until someone edits it from here (or the
admin panel's photo is separately made public — out of scope).

### New endpoint — `get_cvl_by_id_bataan`

Same module, same auth tier. Read-only lookup by `app_cvl_list.id` — the
search flow's counterpart to `find_cvl_by_qr_bataan`. Same column list
(factored into a shared `_CVL_DETAIL_COLUMNS` constant so the two SELECTs
can't drift apart), but `LEFT JOIN`s `app_qr_code` instead of
`INNER JOIN`ing it — a record with `cvl_qr IS NULL` is a valid result
here (search intentionally surfaces those; a QR scan obviously can't
reach a record with no QR to scan).

- **In:** `{endpoint: 'get_cvl_by_id_bataan', token, db_name, id}`
- No row → `fail('CVL record not found', 404)`; row found →
  `ok({data: serialize_row(row)})`.

### New endpoint — `search_cvl_by_name_bataan`

Same module, same auth tier. Requires `name`, at least 2 characters after
trimming. Mirrors `bataan_lgu_admin`'s `EMS/index.php` search logic
against the same `ft_cvl_fullname` fulltext index: each whitespace-
separated keyword of 3+ alphanumeric characters becomes a `+word*`
fulltext boolean-mode term (prefix match); if any keyword is shorter than
that, the whole search falls back to `LIKE '%word%'` per keyword instead
(MySQL's fulltext minimum indexed word length would silently drop short
words otherwise). `LEFT JOIN`s `app_qr_code` (same reasoning as
`get_cvl_by_id_bataan`). Capped at 25 results, ordered by name.

- **In:** `{endpoint: 'search_cvl_by_name_bataan', token, db_name, name}`
- Returns lightweight rows, not the full record: `id, cvl_fullname,
  cvl_mun, cvl_brgy, cvl_qr_code` — enough to render a results list and
  know whether each match has a QR assigned, without the cost of the
  full column list for what might be dozens of rows.
- `ok({data: {results: [...], truncated: bool}})` — `truncated` is true
  when the 25-row cap was hit, so the UI can hint "refine your search".

## Flutter

### Feature boundary

```
lib/features/cvl_lookup/
  domain/
    entities/cvl_record.dart           // + imgPath, hasDisplayableImage, copyWith
    entities/cvl_search_result.dart    // lightweight: id, name, mun/brgy, qrCode
    repositories/cvl_repository.dart   // abstract: findByQr(), findById(), searchByName(), updatePhoto()
    usecases/find_cvl_by_qr.dart
    usecases/find_cvl_by_id.dart
    usecases/search_cvl_by_name.dart
    usecases/update_cvl_photo.dart
  data/
    datasources/cvl_remote_datasource.dart  // + get_cvl_by_id_bataan, search_cvl_by_name_bataan
    repositories/cvl_repository_impl.dart
  presentation/
    bloc/cvl_lookup_cubit.dart          // mirrors ServiceDetailsCubit; fetch() and fetchById()
    bloc/cvl_lookup_state.dart
    bloc/cvl_search_cubit.dart          // debounced-by-the-page search(name)
    bloc/cvl_search_state.dart
    pages/cvl_lookup_page.dart          // mirrors ServiceDetailsPage; two entry constructors
    pages/cvl_search_page.dart          // text field + results list
```

Mirrors `social_service_claim`'s `service_details_cubit.dart` /
`service_details_state.dart` / `service_details_page.dart` structure
exactly (fetch-on-init cubit, `initial`/`loading`/`failed`/`loaded`
states) — this is a single read-only fetch-and-display, not a multi-step
claim flow, so it does not touch `ClaimBloc` or its session-state
machinery.

### Networking

`CvlRemoteDatasource` calls `ApiClient.post('find_cvl_by_qr_bataan',
{'qr_code': qrCode})` — same envelope/client every other feature already
uses, no changes to `ApiClient` or `AppConfig`.

### Flow

1. **DashboardPage** — new third `Card`/`ListTile`: "Check CVL Record" /
   "Scan a QR to view voter record", pushes
   `ScannerPage(purpose: ScanPurpose.cvlLookup)`.
2. **ScannerPage** — `ScanPurpose` gets a third value `cvlLookup`. On
   detect, routes to `CvlLookupPage(rawValue: state.rawValue)` (same
   pattern as the existing `viewDetails` branch). Banner text: "Scan QR to
   View CVL Record" / "Align the QR within the frame to view the record."
3. **CvlLookupPage** — `initState` calls `CvlLookupCubit.fetch(rawValue)`.
   - `loading` → centered spinner.
   - `failed` → same `_ErrorView` shape as `ServiceDetailsPage`: error
     icon, the backend's message (**"No CVL record was found for this QR code."**
     on a 404, or a generic failure message on any other error), "Scan
     Again" button that pops back to `ScannerPage`.
   - `loaded` → a photo section, then sectioned `_SectionCard` list:
     - **Photo**: thumbnail (only when `hasDisplayableImage`; otherwise a
       placeholder person icon) + an "Edit Photo" button.
     - **Identity**: Full name, Gender, Birthdate
     - **Location**: Address, Barangay, Municipality, Precinct No.
     - **Contact**: Contact No., Email (each only if non-empty)
     - **Sector**: Sector (if non-empty)
     - **QR Code**: the resolved `cvl_qr_code` string
     followed by a "Scan Another" button, same as `ServiceDetailsPage`.
     The "QR Code" row shows "Not assigned" instead of a blank value
     when `qrCode` is empty — reachable now that search can surface
     no-QR records.

### Search flow

4. **DashboardPage** — a fourth tile: "Search CVL Record" / "Find a
   voter record by name", pushes `CvlSearchPage` directly (no camera
   involved — this entry point never touches `ScannerPage`).
5. **CvlSearchPage** — a `TextField` (400ms debounce, implemented as a
   `Timer` in the page itself, not the cubit — keeps `CvlSearchCubit`
   a plain "search now" cubit rather than owning timing logic) driving
   `CvlSearchCubit.search(name)`. Below it: `initial` → a hint icon +
   message; `loading` → spinner; `failed` → error icon + message;
   `loaded` with no results → "No matching records found."; `loaded`
   with results → a `ListView` of name + barangay/municipality rows,
   each with a QR/no-QR icon, plus a trailing hint row when `truncated`
   is true. Tapping a row pushes
   `CvlLookupPage.byId(recordId: result.id)`.
6. **CvlLookupPage** gains a second constructor, `.byId(recordId)`,
   alongside the existing `rawValue`-taking default constructor —
   `initState` calls `CvlLookupCubit.fetchById(recordId)` instead of
   `fetch(rawValue)`. Both land on the identical `_DetailsView`/photo/edit
   UI; the only difference is which backend endpoint resolved the record.

### Photo edit

"Edit Photo" reuses the existing `CapturePhoto` usecase (camera-only,
already used by the claim flow — no new gallery-picker surface) to get a
local file path, then `CvlLookupCubit.updatePhoto(path, updatedBy:
currentUsername)` uploads it via `update_cvl_photo_bataan` and — on
success — updates the displayed `CvlRecord` in place (`copyWith`, no
re-fetch needed). `updatedBy` comes from the already-logged-in
`AuthBloc`'s `ScannerUser.username`.

This is a separate, narrower piece of cubit state
(`isUpdatingPhoto`/`photoUpdateError` on `CvlLookupState`) from the
page's main `status` (`initial`/`loading`/`failed`/`loaded`) — an
in-flight photo edit shows a spinner on the Edit button and a snackbar
on failure, without blanking the already-loaded record behind a
full-page spinner the way re-running `fetch()` would.

### Error handling

Same loading/error/retry shape as `ServiceDetailsCubit` /
`ServiceDetailsPage` for the main fetch — inline error + retry, no
crashes, no new pattern introduced. Photo-edit failures surface as a
`SnackBar` (see above) rather than replacing the page.

## Out of scope (explicitly deferred)

- Automated tests for the Flutter side (matches existing project
  convention unless requested separately) — the backend endpoints do get
  `unittest`/`MagicMock` coverage, matching this repo's Python test
  convention.
- Editing, assigning, or removing a CVL record's QR code, or any field
  other than the photo, from the app.
- A gallery-picker option for the photo edit (camera-only, matching the
  claim flow's existing capture pattern).
- iOS-specific config.
- Any change to the PHP admin backend (`bataan_lgu_admin` /
  `EMS/api/find_cvl_by_qr.php`) — it is referenced here only as the
  existing lookup logic to mirror, not touched or called by the app.
- Making PHP-admin-uploaded photos (`storage/cvl/...` relative paths)
  loadable from this app — they stay behind a placeholder until
  re-uploaded from here.
