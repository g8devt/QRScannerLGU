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

- One new backend endpoint (`find_cvl_by_qr_bataan`), read-only.
- New Flutter feature module `cvl_lookup`, mirroring the existing
  `social_service_claim`'s `service_details_*` slice (fetch-by-QR →
  loading → details view / error view), not the claim-submission flow.
- Reuses the existing `qr_scanner` camera, `ScannerPage`, `ApiClient`, and
  staff login/token — no new auth mechanism.
- Android only (matches existing `qr_scanner` scope).
- Read-only: no QR assignment, editing, or CVL record mutation from the
  app.

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

## Flutter

### Feature boundary

```
lib/features/cvl_lookup/
  domain/
    entities/cvl_record.dart
    repositories/cvl_repository.dart   // abstract: findByQr()
    usecases/find_cvl_by_qr.dart
  data/
    datasources/cvl_remote_datasource.dart  // calls find_cvl_by_qr_bataan
    repositories/cvl_repository_impl.dart
  presentation/
    bloc/cvl_lookup_cubit.dart          // mirrors ServiceDetailsCubit
    bloc/cvl_lookup_state.dart
    pages/cvl_lookup_page.dart          // mirrors ServiceDetailsPage
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
   - `loaded` → sectioned `_SectionCard` list:
     - **Identity**: Full name, Gender, Birthdate
     - **Location**: Address, Barangay, Municipality, Precinct No.
     - **Contact**: Contact No., Email (each only if non-empty)
     - **Sector**: Sector (if non-empty)
     - **QR Code**: the resolved `cvl_qr_code` string
     followed by a "Scan Another" button, same as `ServiceDetailsPage`.

### Error handling

Same loading/error/retry shape as `ServiceDetailsCubit` /
`ServiceDetailsPage` — inline error + retry, no crashes, no new pattern
introduced.

## Out of scope (explicitly deferred)

- Automated tests (matches existing project convention unless requested
  separately).
- Editing, assigning, or removing a CVL record's QR code from the app —
  read-only lookup only.
- iOS-specific config.
- Any change to the PHP admin backend (`bataan_lgu_admin` /
  `EMS/api/find_cvl_by_qr.php`) — it is referenced here only as the
  existing lookup logic to mirror, not touched or called by the app.
