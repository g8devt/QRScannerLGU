# Social Service Claim Flow (Bataan) — Design Spec

Date: 2026-08-10
Status: Approved

## Purpose

Wire the existing QR scanner up to a real claim workflow for the Bataan
`app_social_services` process: scan QR → verify against the backend →
eligibility gate → claimant info → confirm identity → capture claimant ID
(front/back/signature/face photo) → preview → submit → confirm claim (record
marked `CLAIMED`). Replaces the current dead-end `ResultPage` stub.

## Scope

- Two new backend endpoints, both suffixed `_bataan`, dedicated to this flow
  only (not shared with other tenant DBs' social services table).
- New DB columns on `app_social_services` to capture claimant/claim details.
- New Flutter feature module for the post-scan workflow; `qr_scanner` stays
  scan-only.
- Android only (matches existing `qr_scanner` scope).

## Backend

### Schema change — `app_social_services`

```sql
ALTER TABLE app_social_services
  ADD COLUMN claim_method        VARCHAR(20)  NULL,  -- 'QR' | 'MANUAL'
  ADD COLUMN claimant_type       VARCHAR(20)  NULL,  -- 'SELF' | 'REPRESENTATIVE'
  ADD COLUMN claimant_name       VARCHAR(255) NULL,
  ADD COLUMN claimant_relation   VARCHAR(100) NULL,
  ADD COLUMN claimant_id_type    VARCHAR(50)  NULL,
  ADD COLUMN claimant_id_number  VARCHAR(100) NULL,
  ADD COLUMN claimant_id_front   VARCHAR(500) NULL,  -- S3 key/URL
  ADD COLUMN claimant_id_back    VARCHAR(500) NULL,
  ADD COLUMN claimant_signature  VARCHAR(500) NULL,
  ADD COLUMN claimant_face_photo VARCHAR(500) NULL;  -- live photo taken at claim time
```

`status`, `date_claimed`, and `claimed_amount` already exist on the table
(see `backend/database/bataan_db.sql` `app_social_services`, ~line 1997). No
in-repo migration files exist for this project — following the codebase's
existing convention, add a `_has_claim_columns(cur)` feature-detect helper
(mirrors `_has_appointment_columns` / `_has_qr_code_column`, both defined in
`social_services_bataan.py` itself, checking
`information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND
TABLE_NAME = 'app_social_services' AND COLUMN_NAME = '<col>'`), and update
the dumped schema `backend/database/bataan_db.sql` inline. The `ALTER
TABLE` above is the migration instruction to run manually against
`bataan_db`.

### Endpoint 1 — `verify_qr_bataan`

Registered in `ROUTES` in
`backend/_external_lambdas/UniversalLGU-MainPost/lambda_function.py`, lives
in `endpoints/social_services_bataan.py`. **Not** added to
`ADMIN_SESSION_REQUIRED_ENDPOINTS` — that mechanism's `_check_admin_session`
hardcodes `if tenant_db != 'cebu_lgu_db': return fail(...)`, so it would
reject every call against `bataan_db` outright. Instead this uses plain
app-token auth via the handler's existing `check_token()` path, the same
tier as `submit_social_service_bataan` / `get_social_services_bataan`
(neither of which is in `ADMIN_SESSION_REQUIRED_ENDPOINTS` either) — no
staff-permission distinction, matching how this backend already treats
every Bataan endpoint.

- **In:** `{endpoint: 'verify_qr_bataan', token, db_name, qr_code}`
- **Logic:** `SELECT * FROM app_social_services WHERE qr_code = %s`
  - No row → `fail('QR code not found')`
  - `status == 'CLAIMED'` → `fail('Already claimed on <date_claimed>')`
  - `status not in ('APPROVED', 'RELEASED')` →
    `fail('Not yet eligible — status is <status>')`
  - Else → `ok({data: {id, application_number, beneficiary_name, status,
    requested_for_fname, requested_for_mname, requested_for_lname,
    date_approved, date_released, ...}})`

  No stored photo column (`photo_2x2`, `image_verification`) is returned or
  used for identity confirmation — see `ConfirmIdentityPage` below, which is
  a photo-less manual judgement call.

These three failure branches are the diagram's "Eligibility gates → Stop,
show reason" step.

### Endpoint 2 — `submit_claim_bataan`

- **In (multipart):** `{endpoint: 'submit_claim_bataan', token, db_name, id,
  claim_method: 'QR', claimant_type, claimant_name?, claimant_relation?,
  claimant_id_type, claimant_id_number}` + files `claimant_id_front`,
  `claimant_id_back`, `claimant_signature`, `claimant_face_photo`
- **Logic:**
  1. `require(data, 'id', 'claimant_type', 'claimant_id_type',
     'claimant_id_number')`; if `claimant_type == 'REPRESENTATIVE'`, also
     require `claimant_name`, `claimant_relation`.
  2. Require all 4 files present (ID front, ID back, signature, live face
     photo).
  3. `upload_files_from_list(files, f'social_services/{id}/claim', ...)` to
     get stored S3 keys (mirrors `submit_kyc`'s use of `upload_files_from_list`
     in `endpoints/kyc.py`).
  4. `UPDATE app_social_services SET status='CLAIMED', date_claimed=NOW(),
     claim_method=%s, claimant_type=%s, claimant_name=%s,
     claimant_relation=%s, claimant_id_type=%s, claimant_id_number=%s,
     claimant_id_front=%s, claimant_id_back=%s, claimant_signature=%s,
     claimant_face_photo=%s WHERE id=%s AND status != 'CLAIMED'` — the
     `AND status != 'CLAIMED'` guard prevents a double-claim race between
     two staff devices.
  5. 0 rows affected → `fail('Already claimed by another session')`.
  6. `record_audit_log(...)`, then `ok({success: true})`.

Neither endpoint reuses code from `endpoints/social_services.py` — that file
belongs to a different (non-Bataan) tenant's social services table and has
no bearing on this feature. `social_services_bataan.py` currently has no
status-update function of its own (only `submit_social_service_bataan` /
`get_social_services_bataan`); the `UPDATE ... SET status=..., date_claimed=NOW()`
+ `record_audit_log(...)` shape above is written fresh in
`social_services_bataan.py`, following the general
`require()`/`ok()`/`fail()`/`record_audit_log()` conventions shared across
*all* endpoint files in this backend (not specific to any one tenant file).

## Flutter

### Feature boundary

`qr_scanner` (existing) stays scan-only: detect a code, hand off the raw
value. A new feature module owns everything after that:

```
lib/features/social_service_claim/
  domain/
    entities/claim_session.dart        // verified record + claimant info + photo paths
    repositories/claim_repository.dart // abstract: verifyQr(), submitClaim()
    usecases/verify_qr.dart, submit_claim.dart
  data/
    datasources/claim_remote_datasource.dart  // calls verify_qr_bataan / submit_claim_bataan
    repositories/claim_repository_impl.dart
  presentation/
    bloc/claim_bloc.dart   // holds session state across all steps
    pages/
      verify_page.dart
      stop_page.dart
      claimant_info_page.dart
      confirm_identity_page.dart
      capture_id_page.dart
      preview_page.dart
      confirm_claim_page.dart
```

Reuses `CameraRepository` / `CapturePhoto` usecase from `qr_scanner`'s
`domain` layer for the 4 captures (ID front, ID back, signature, live face
photo) — no duplication of camera-capture logic.

### Networking

New `lib/core/network/api_client.dart` (adds `http` package dependency,
currently absent from `pubspec.yaml`). Wraps the `{endpoint, token, db_name,
...}` JSON/multipart envelope convention used by the single Lambda backend
(`helpers/parse.py` `parse_event` / `parse_form_data`). Shared, not specific
to this feature, so future features can reuse it.

The app has no login/token-storage flow at all today. Since this is a
single-purpose LGU-staff scanner app (no multi-user login UI exists or is
in scope here), `lib/core/config/app_config.dart` holds a fixed staff
`token` and `dbName = 'bataan_db'` compiled into the app, read by
`ApiClient` for every request. This is a known, explicitly-flagged gap —
replacing it with real staff login/credential storage is future work, not
part of this pass.

### Flow

1. **ScannerPage** (existing, unchanged) — on detect, navigates to
   `VerifyPage(rawValue)` instead of the old `ResultPage`.
2. **VerifyPage** — calls `verify_qr_bataan` with the scanned value as
   `qr_code`. Loading spinner, then:
   - Failure → **StopPage**(reason) — banner with reason text + "Scan Again"
     button, returns to ScannerPage.
   - Success → applicant summary (name, status) → "Continue".
3. **ClaimantInfoPage** — radio `SELF` / `REPRESENTATIVE`; REPRESENTATIVE
   reveals name / relation / ID type / ID number fields. Stored into
   `ClaimBloc` session state.
4. **ConfirmIdentityPage** — no stored photo to show (no `photo_2x2` /
   `image_verification` reference exists). Displays the verified applicant's
   name/application details and a "Confirm this is the claimant" button —
   staff visually matches the physical person against the QR record's
   printed/on-screen details. Purely a manual gate.
5. **CaptureIdPage** — four sequential live captures (ID front, ID back,
   signature, claimant's face photo) via the reused `CapturePhoto` usecase.
   The face photo is evidentiary only (who physically claimed it), not
   compared against any stored reference.
6. **PreviewPage** — thumbnails of the 4 captures + claimant info summary;
   "Retake" (back to step 5) or "Submit".
7. Submit → `submit_claim_bataan` (multipart) → loading →
   - Success → **ConfirmClaimPage** ("Claim recorded", record now
     `CLAIMED`), "Scan Next" returns to ScannerPage.
   - Failure → snackbar on PreviewPage, stays put, retry without
     re-capturing photos.

### Error handling

Loading → error pattern matches the existing `CaptureBloc` convention
(inline error + retry, no crashes). No dedicated logging endpoint exists in
this codebase — the diagram's "log it" on Stop is satisfied by normal
request logging; verify failures never mutate server state.

## Out of scope (explicitly deferred)

- Automated tests (matches existing project convention unless requested
  separately).
- Offline queueing / retry-on-reconnect for `submit_claim_bataan`.
- iOS-specific config.
- Automated face-match identity check (deferred; manual staff confirmation
  chosen for this pass).
- Real staff login/credential storage (deferred; hardcoded `app_config.dart`
  token used instead, see Networking above).
