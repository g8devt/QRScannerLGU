# Social Service Claim Flow (Bataan) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the QR scanner up to a real Bataan social-service claim workflow: scan → verify → eligibility gate → claimant info → confirm identity → capture ID (front/back/signature/face) → preview → submit → confirm claim (`status=CLAIMED`).

**Architecture:** Two new backend endpoints (`verify_qr_bataan`, `submit_claim_bataan`) in the existing single-Lambda dispatch pattern; a new Flutter feature module `social_service_claim` (domain/data/presentation) that owns everything after a QR is detected, reusing `qr_scanner`'s `CapturePhoto` usecase for the 4 photo captures.

**Tech Stack:** Python 3 / pymysql (backend Lambda, unchanged), Flutter 3.10 / flutter_bloc / equatable, new `http` package for the Flutter→Lambda HTTP client.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-08-10-social-service-claim-flow-design.md`.
- Endpoint names end in `_bataan`, registered in `ROUTES` in `lambda_function.py`.
- Both new endpoints use **plain app-token auth** (the handler's default `check_token()` path) — **not** `ADMIN_SESSION_REQUIRED_ENDPOINTS`, which hardcodes `tenant_db != 'cebu_lgu_db'` → reject.
- Eligibility gate: `status` must be `APPROVED` or `RELEASED`; `CLAIMED` and any other status are rejected with a reason.
- New DB columns are nullable, guarded by a `_has_claim_columns(cur)` feature-detect helper (mirrors `_has_appointment_columns`/`_has_qr_code_column` in `social_services_bataan.py`).
- Flutter SDK constraint: `^3.10.7` (`pubspec.yaml`). Android `minSdk 24` / `compileSdk 36` / `targetSdk 36`. `CAMERA` permission already present in `AndroidManifest.xml` — no manifest change needed.
- `qr_scanner` stays scan-only; the new `social_service_claim` feature owns verify→submit. `qr_scanner`'s `CameraRepository`/`CapturePhoto` usecase is reused, not duplicated.
- No login UI in scope — `lib/core/config/app_config.dart` holds a hardcoded staff `token` + `dbName='bataan_db'`, explicitly flagged as a known gap.
- No new Flutter test dependencies (no `bloc_test`/`mocktail` — not present in `pubspec.yaml`); verify Dart changes with `flutter analyze`. Backend gets lightweight `unittest`/`unittest.mock` tests (stdlib only, no new pip dependency, backend currently has zero test harness) alongside `python -m py_compile` syntax checks.

---

## File Structure

**Backend** (`backend/_external_lambdas/UniversalLGU-MainPost/`):
- Create: `backend/database/migrations/031_bataan_claim_columns.sql` — the `ALTER TABLE` to run manually.
- Modify: `backend/database/bataan_db.sql` — append new columns to the dumped `CREATE TABLE app_social_services`.
- Modify: `endpoints/social_services_bataan.py` — add `_has_claim_columns`, `verify_qr_bataan`, `submit_claim_bataan`, `_CLAIM_FILE_FIELDS`, import `record_audit_log`.
- Modify: `lambda_function.py` — register both new endpoints in `ROUTES`.
- Create: `endpoints/../tests/test_social_services_bataan_claim.py` — actually placed at `backend/_external_lambdas/UniversalLGU-MainPost/tests/test_social_services_bataan_claim.py` (new `tests/` package).

**Flutter** (`lib/`):
- Modify: `pubspec.yaml` — add `http` dependency.
- Create: `lib/core/config/app_config.dart` — hardcoded backend config.
- Create: `lib/core/network/api_client.dart` — JSON/multipart envelope client.
- Create: `lib/features/social_service_claim/domain/entities/verified_application.dart`
- Create: `lib/features/social_service_claim/domain/entities/claimant_info.dart`
- Create: `lib/features/social_service_claim/domain/entities/claim_captures.dart`
- Create: `lib/features/social_service_claim/domain/repositories/claim_repository.dart`
- Create: `lib/features/social_service_claim/domain/usecases/verify_qr.dart`
- Create: `lib/features/social_service_claim/domain/usecases/submit_claim.dart`
- Create: `lib/features/social_service_claim/data/datasources/claim_remote_datasource.dart`
- Create: `lib/features/social_service_claim/data/repositories/claim_repository_impl.dart`
- Create: `lib/features/social_service_claim/presentation/bloc/claim_event.dart`
- Create: `lib/features/social_service_claim/presentation/bloc/claim_state.dart`
- Create: `lib/features/social_service_claim/presentation/bloc/claim_bloc.dart`
- Create: `lib/features/social_service_claim/presentation/pages/verify_page.dart`
- Create: `lib/features/social_service_claim/presentation/pages/stop_page.dart`
- Create: `lib/features/social_service_claim/presentation/pages/claimant_info_page.dart`
- Create: `lib/features/social_service_claim/presentation/pages/confirm_identity_page.dart`
- Create: `lib/features/social_service_claim/presentation/pages/capture_id_page.dart`
- Create: `lib/features/social_service_claim/presentation/pages/preview_page.dart`
- Create: `lib/features/social_service_claim/presentation/pages/confirm_claim_page.dart`
- Modify: `lib/features/qr_scanner/presentation/pages/scanner_page.dart` — navigate to `VerifyPage` instead of `ResultPage`.
- Modify: `lib/main.dart` — wire `ApiClient`/`ClaimRepository`/`ClaimBloc`.
- Delete: `lib/features/qr_scanner/presentation/pages/result_page.dart`, `lib/features/qr_scanner/presentation/bloc/capture_bloc.dart`, `capture_event.dart`, `capture_state.dart` (dead code once `ResultPage` is replaced).

---

### Task 1: DB migration + `_has_claim_columns` helper

**Files:**
- Create: `backend/database/migrations/031_bataan_claim_columns.sql`
- Modify: `backend/database/bataan_db.sql` (append columns to `app_social_services`)
- Modify: `backend/_external_lambdas/UniversalLGU-MainPost/endpoints/social_services_bataan.py`

**Interfaces:**
- Produces: `_has_claim_columns(cur) -> bool`, used by Task 3.

- [ ] **Step 1: Create the migration SQL file**

```sql
-- Migration 031: Bataan social-service claim-capture columns.
-- Adds claimant/claim-method tracking to app_social_services for the
-- verify_qr_bataan / submit_claim_bataan endpoints. Run manually against
-- bataan_db (no migration-runner exists in this repo yet).

ALTER TABLE app_social_services
  ADD COLUMN claim_method        VARCHAR(20)  NULL,  -- 'QR' | 'MANUAL'
  ADD COLUMN claimant_type       VARCHAR(20)  NULL,  -- 'SELF' | 'REPRESENTATIVE'
  ADD COLUMN claimant_name       VARCHAR(255) NULL,
  ADD COLUMN claimant_relation   VARCHAR(100) NULL,
  ADD COLUMN claimant_id_type    VARCHAR(50)  NULL,
  ADD COLUMN claimant_id_number  VARCHAR(100) NULL,
  ADD COLUMN claimant_id_front   VARCHAR(500) NULL,
  ADD COLUMN claimant_id_back    VARCHAR(500) NULL,
  ADD COLUMN claimant_signature  VARCHAR(500) NULL,
  ADD COLUMN claimant_face_photo VARCHAR(500) NULL;
```

Save this to `backend/database/migrations/031_bataan_claim_columns.sql`.

- [ ] **Step 2: Append the same columns to the dumped schema**

Open `backend/database/bataan_db.sql`, find `CREATE TABLE app_social_services`
(around line 1997), locate the `document_sent_type varchar(20)` column
(the last column before the table's closing `)` / keys section — search
for `document_sent_type` to find it), and add these lines directly after
it, before the closing of the column list:

```sql
  `claim_method` varchar(20) DEFAULT NULL,
  `claimant_type` varchar(20) DEFAULT NULL,
  `claimant_name` varchar(255) DEFAULT NULL,
  `claimant_relation` varchar(100) DEFAULT NULL,
  `claimant_id_type` varchar(50) DEFAULT NULL,
  `claimant_id_number` varchar(100) DEFAULT NULL,
  `claimant_id_front` varchar(500) DEFAULT NULL,
  `claimant_id_back` varchar(500) DEFAULT NULL,
  `claimant_signature` varchar(500) DEFAULT NULL,
  `claimant_face_photo` varchar(500) DEFAULT NULL,
```

Match the exact backtick/comma style already used by the surrounding
column definitions in that file.

- [ ] **Step 3: Add the `_has_claim_columns` helper**

In `backend/_external_lambdas/UniversalLGU-MainPost/endpoints/social_services_bataan.py`,
add this function immediately after `_has_qr_code_column` (after line 254 in
the current file):

```python
def _has_claim_columns(cur):
    """True when migration 031 (claimant_* claim-capture columns) is
    applied on this tenant."""
    cur.execute(
        """
        SELECT COUNT(*) AS c
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'app_social_services'
          AND COLUMN_NAME = 'claimant_face_photo'
        """
    )
    row = cur.fetchone()
    return bool(row and row.get('c'))
```

- [ ] **Step 4: Verify the file still parses**

Run: `python -m py_compile backend/_external_lambdas/UniversalLGU-MainPost/endpoints/social_services_bataan.py`
Expected: no output, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add backend/database/migrations/031_bataan_claim_columns.sql backend/database/bataan_db.sql backend/_external_lambdas/UniversalLGU-MainPost/endpoints/social_services_bataan.py
git commit -m "feat(backend): add claim-capture columns and _has_claim_columns helper"
```

---

### Task 2: `verify_qr_bataan` endpoint

**Files:**
- Modify: `backend/_external_lambdas/UniversalLGU-MainPost/endpoints/social_services_bataan.py`
- Create: `backend/_external_lambdas/UniversalLGU-MainPost/tests/__init__.py` (empty, makes it a package)
- Create: `backend/_external_lambdas/UniversalLGU-MainPost/tests/test_social_services_bataan_claim.py`

**Interfaces:**
- Consumes: `ok`, `fail`, `require` from `helpers.auth` (already imported in this file); `serialize_row` from `helpers.db` (already imported).
- Produces: `verify_qr_bataan(cur, data, files, ts) -> dict` (Lambda response shape `{statusCode, body, headers}`), used by Task 3's route registration.

- [ ] **Step 1: Write the failing tests**

Create `backend/_external_lambdas/UniversalLGU-MainPost/tests/__init__.py` (empty file).

Create `backend/_external_lambdas/UniversalLGU-MainPost/tests/test_social_services_bataan_claim.py`:

```python
import json
import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from endpoints.social_services_bataan import verify_qr_bataan


class VerifyQrBataanTest(unittest.TestCase):
    def _cur(self, fetchone_return):
        cur = MagicMock()
        cur.fetchone.return_value = fetchone_return
        return cur

    def test_qr_not_found_returns_404(self):
        cur = self._cur(None)
        result = verify_qr_bataan(cur, {'qr_code': 'SS-000001-ABC'}, [], '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 404)

    def test_already_claimed_returns_409(self):
        cur = self._cur({'id': 1, 'status': 'CLAIMED', 'date_claimed': '2026-08-01'})
        result = verify_qr_bataan(cur, {'qr_code': 'SS-000001-ABC'}, [], '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 409)

    def test_not_yet_eligible_status_returns_409(self):
        cur = self._cur({'id': 1, 'status': 'PENDING', 'date_claimed': None})
        result = verify_qr_bataan(cur, {'qr_code': 'SS-000001-ABC'}, [], '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 409)

    def test_approved_status_returns_200_with_data(self):
        cur = self._cur({
            'id': 1, 'application_number': 'SS-000001', 'beneficiary_name': 'Juan',
            'status': 'APPROVED', 'requested_for_fname': 'Juan', 'requested_for_mname': '',
            'requested_for_lname': 'Dela Cruz', 'date_approved': '2026-08-05',
            'date_released': None, 'date_claimed': None,
        })
        result = verify_qr_bataan(cur, {'qr_code': 'SS-000001-ABC'}, [], '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 200)
        body = json.loads(result['body'])
        self.assertEqual(body['data']['application_number'], 'SS-000001')

    def test_missing_qr_code_returns_400(self):
        cur = self._cur(None)
        result = verify_qr_bataan(cur, {}, [], '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 400)


if __name__ == '__main__':
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd backend/_external_lambdas/UniversalLGU-MainPost && python -m unittest tests.test_social_services_bataan_claim -v`
Expected: `ImportError: cannot import name 'verify_qr_bataan'`.

- [ ] **Step 3: Implement `verify_qr_bataan`**

Add this function to `endpoints/social_services_bataan.py`, right after
`get_social_services_bataan` (end of file):

```python
def verify_qr_bataan(cur, data, files, ts):
    try:
        require(data, 'qr_code')
        qr_code = data['qr_code']

        cur.execute(
            """
            SELECT id, application_number, beneficiary_name, status,
                   requested_for_fname, requested_for_mname, requested_for_lname,
                   date_approved, date_released, date_claimed
            FROM app_social_services WHERE qr_code=%s
            """,
            (qr_code,),
        )
        row = cur.fetchone()
        if not row:
            return fail('QR code not found', 404)

        status = row['status']
        if status == 'CLAIMED':
            claimed_on = row.get('date_claimed')
            message = f'Already claimed on {claimed_on}' if claimed_on else 'Already claimed'
            return fail(message, 409)
        if status not in ('APPROVED', 'RELEASED'):
            return fail(f'Not yet eligible for claim — status is {status}', 409)

        return ok({'status': True, 'data': serialize_row(row)})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"verify_qr_bataan error: {e}", exc_info=True)
        return fail(f'Server error: {str(e)}', 500)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd backend/_external_lambdas/UniversalLGU-MainPost && python -m unittest tests.test_social_services_bataan_claim -v`
Expected: all 5 tests PASS.

- [ ] **Step 5: Verify syntax**

Run: `python -m py_compile backend/_external_lambdas/UniversalLGU-MainPost/endpoints/social_services_bataan.py`
Expected: no output, exit code 0.

- [ ] **Step 6: Commit**

```bash
git add backend/_external_lambdas/UniversalLGU-MainPost/endpoints/social_services_bataan.py backend/_external_lambdas/UniversalLGU-MainPost/tests/
git commit -m "feat(backend): add verify_qr_bataan endpoint"
```

---

### Task 3: `submit_claim_bataan` endpoint + route registration

**Files:**
- Modify: `backend/_external_lambdas/UniversalLGU-MainPost/endpoints/social_services_bataan.py`
- Modify: `backend/_external_lambdas/UniversalLGU-MainPost/lambda_function.py`
- Modify: `backend/_external_lambdas/UniversalLGU-MainPost/tests/test_social_services_bataan_claim.py`

**Interfaces:**
- Consumes: `upload_files_from_list(files, prefix, user_id) -> dict[field_name, url]` from `helpers.s3` (already imported); `sanitize` from `helpers.db` (already imported); `record_audit_log(cur, admin_id, admin_role, action, target_type, target_id, details, ts)` from `helpers.audit` (new import).
- Produces: `submit_claim_bataan(cur, data, files, ts) -> dict`, registered in `ROUTES['submit_claim_bataan']`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_social_services_bataan_claim.py`:

```python
from io import BytesIO
from unittest.mock import patch

from endpoints.social_services_bataan import submit_claim_bataan


def _claim_files():
    return [
        {'filename': 'front.jpg', 'content': BytesIO(b'a'), 'field_name': 'claimant_id_front'},
        {'filename': 'back.jpg', 'content': BytesIO(b'b'), 'field_name': 'claimant_id_back'},
        {'filename': 'sig.jpg', 'content': BytesIO(b'c'), 'field_name': 'claimant_signature'},
        {'filename': 'face.jpg', 'content': BytesIO(b'd'), 'field_name': 'claimant_face_photo'},
    ]


class SubmitClaimBataanTest(unittest.TestCase):
    def _base_data(self, claimant_type='SELF'):
        return {
            'id': '1', 'claimant_type': claimant_type,
            'claimant_id_type': "Driver's License", 'claimant_id_number': '123',
        }

    def test_missing_files_returns_400(self):
        cur = MagicMock()
        result = submit_claim_bataan(cur, self._base_data(), [], '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 400)

    def test_representative_without_name_returns_400(self):
        cur = MagicMock()
        result = submit_claim_bataan(
            cur, self._base_data(claimant_type='REPRESENTATIVE'), _claim_files(), '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 400)

    def test_application_not_found_returns_404(self):
        cur = MagicMock()
        cur.fetchone.return_value = None
        result = submit_claim_bataan(cur, self._base_data(), _claim_files(), '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 404)

    @patch('endpoints.social_services_bataan.upload_files_from_list')
    def test_already_claimed_race_returns_409(self, mock_upload):
        mock_upload.return_value = {
            'claimant_id_front': 'url1', 'claimant_id_back': 'url2',
            'claimant_signature': 'url3', 'claimant_face_photo': 'url4',
        }
        cur = MagicMock()
        cur.fetchone.side_effect = [{'status': 'APPROVED'}, {'c': 1}]
        cur.rowcount = 0
        result = submit_claim_bataan(cur, self._base_data(), _claim_files(), '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 409)

    @patch('endpoints.social_services_bataan.upload_files_from_list')
    def test_success_returns_200(self, mock_upload):
        mock_upload.return_value = {
            'claimant_id_front': 'url1', 'claimant_id_back': 'url2',
            'claimant_signature': 'url3', 'claimant_face_photo': 'url4',
        }
        cur = MagicMock()
        cur.fetchone.side_effect = [{'status': 'APPROVED'}, {'c': 1}]
        cur.rowcount = 1
        result = submit_claim_bataan(cur, self._base_data(), _claim_files(), '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 200)
```

(Keep the existing `VerifyQrBataanTest` class above this in the same file;
this adds a second `SubmitClaimBataanTest` class and the extra imports at
the top — `from io import BytesIO`, `from unittest.mock import patch`, and
`from endpoints.social_services_bataan import submit_claim_bataan` added to
the existing import block.)

- [ ] **Step 2: Run the tests to verify the new ones fail**

Run: `cd backend/_external_lambdas/UniversalLGU-MainPost && python -m unittest tests.test_social_services_bataan_claim -v`
Expected: `ImportError: cannot import name 'submit_claim_bataan'`.

- [ ] **Step 3: Add the `record_audit_log` import**

In `endpoints/social_services_bataan.py`, change the import block at the
top from:

```python
from helpers.auth import ok, fail, require
from helpers.db import sanitize, serialize_row, generate_number_id, now_ph
from helpers.parse import parse_form_data
from helpers.s3 import upload_files_from_list
```

to:

```python
from helpers.auth import ok, fail, require
from helpers.audit import record_audit_log
from helpers.db import sanitize, serialize_row, generate_number_id, now_ph
from helpers.parse import parse_form_data
from helpers.s3 import upload_files_from_list
```

- [ ] **Step 4: Implement `submit_claim_bataan`**

Add this near the top of the file, after the `ONLINE_APPOINTMENT_LOCATION`
constant:

```python
_CLAIM_FILE_FIELDS = ('claimant_id_front', 'claimant_id_back', 'claimant_signature', 'claimant_face_photo')
```

Add this function at the end of the file, after `verify_qr_bataan`:

```python
def submit_claim_bataan(cur, data, files, ts):
    try:
        require(data, 'id', 'claimant_type', 'claimant_id_type', 'claimant_id_number')
        app_id = data['id']
        claimant_type = (data['claimant_type'] or '').strip().upper()
        if claimant_type not in ('SELF', 'REPRESENTATIVE'):
            return fail(f'Invalid claimant_type: {claimant_type}')

        if claimant_type == 'REPRESENTATIVE':
            require(data, 'claimant_name', 'claimant_relation')

        provided_fields = {f['field_name'] for f in files}
        missing_files = [f for f in _CLAIM_FILE_FIELDS if f not in provided_fields]
        if missing_files:
            return fail(f"Missing: {', '.join(missing_files)}")

        cur.execute("SELECT status FROM app_social_services WHERE id=%s", (app_id,))
        existing = cur.fetchone()
        if not existing:
            return fail('Application not found', 404)

        if not _has_claim_columns(cur):
            return fail('Claim capture is not configured for this LGU', 500)

        file_urls = upload_files_from_list(files, f'social_services/{app_id}/claim', app_id)

        cur.execute(
            """
            UPDATE app_social_services
            SET status='CLAIMED', date_claimed=%s,
                claim_method=%s, claimant_type=%s, claimant_name=%s,
                claimant_relation=%s, claimant_id_type=%s, claimant_id_number=%s,
                claimant_id_front=%s, claimant_id_back=%s, claimant_signature=%s,
                claimant_face_photo=%s
            WHERE id=%s AND status != 'CLAIMED'
            """,
            (
                ts,
                'QR', claimant_type,
                sanitize(data.get('claimant_name')),
                sanitize(data.get('claimant_relation')),
                sanitize(data['claimant_id_type']),
                sanitize(data['claimant_id_number']),
                file_urls.get('claimant_id_front'),
                file_urls.get('claimant_id_back'),
                file_urls.get('claimant_signature'),
                file_urls.get('claimant_face_photo'),
                app_id,
            ),
        )
        if cur.rowcount == 0:
            return fail('Already claimed by another session', 409)

        record_audit_log(cur, None, None, 'submit_claim_bataan', 'social_service', app_id,
                          {'claimant_type': claimant_type}, ts)

        return ok({'status': True, 'id': str(app_id)})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"submit_claim_bataan error: {e}", exc_info=True)
        return fail(f'Server error: {str(e)}', 500)
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd backend/_external_lambdas/UniversalLGU-MainPost && python -m unittest tests.test_social_services_bataan_claim -v`
Expected: all 10 tests PASS (5 from Task 2 + 5 new).

- [ ] **Step 6: Register both endpoints in `ROUTES`**

In `lambda_function.py`, find:

```python
    'submit_social_service_bataan': social_services_bataan.submit_social_service_bataan,
    'get_social_services_bataan': social_services_bataan.get_social_services_bataan,
```

and change to:

```python
    'submit_social_service_bataan': social_services_bataan.submit_social_service_bataan,
    'get_social_services_bataan': social_services_bataan.get_social_services_bataan,
    'verify_qr_bataan': social_services_bataan.verify_qr_bataan,
    'submit_claim_bataan': social_services_bataan.submit_claim_bataan,
```

Do **not** add either name to `ADMIN_SESSION_REQUIRED_ENDPOINTS` or
`NO_TOKEN_ENDPOINTS` — both use the default app-token-only auth path.

- [ ] **Step 7: Verify syntax**

Run:
```bash
python -m py_compile backend/_external_lambdas/UniversalLGU-MainPost/endpoints/social_services_bataan.py
python -m py_compile backend/_external_lambdas/UniversalLGU-MainPost/lambda_function.py
```
Expected: no output, exit code 0 for both.

- [ ] **Step 8: Commit**

```bash
git add backend/_external_lambdas/UniversalLGU-MainPost/endpoints/social_services_bataan.py backend/_external_lambdas/UniversalLGU-MainPost/lambda_function.py backend/_external_lambdas/UniversalLGU-MainPost/tests/test_social_services_bataan_claim.py
git commit -m "feat(backend): add submit_claim_bataan endpoint, register both bataan claim routes"
```

---

### Task 4: Flutter core layer — `AppConfig` + `ApiClient`

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/core/config/app_config.dart`
- Create: `lib/core/network/api_client.dart`

**Interfaces:**
- Produces: `AppConfig.apiBaseUrl`, `AppConfig.dbName`, `AppConfig.staffToken` (all `static const String`); `ApiClient.post(String endpoint, Map<String, dynamic> fields) -> Future<Map<String, dynamic>>`; `ApiClient.postMultipart(String endpoint, Map<String, String> fields, Map<String, String> files) -> Future<Map<String, dynamic>>`; `ApiException(String message)`.

- [ ] **Step 1: Add the `http` dependency**

In `pubspec.yaml`, under `dependencies:`, add after `image_picker: ^1.2.3`:

```yaml
  http: ^1.2.2
```

Run: `flutter pub get`
Expected: resolves without errors.

- [ ] **Step 2: Create `AppConfig`**

```dart
/// Hardcoded backend config for this single-purpose LGU-staff scanner app.
/// There is no login flow yet — replacing this with real staff
/// authentication is tracked as future work, not part of this feature.
class AppConfig {
  const AppConfig._();

  /// Base URL of the single-Lambda backend (API Gateway endpoint).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://REPLACE_WITH_API_GATEWAY_URL',
  );

  /// Tenant database name, sent as `db_name` in every request envelope.
  static const String dbName = 'bataan_db';

  /// Staff session token, sent as `token` in every request envelope.
  static const String staffToken = String.fromEnvironment(
    'STAFF_TOKEN',
    defaultValue: 'REPLACE_WITH_STAFF_TOKEN',
  );
}
```

Save to `lib/core/config/app_config.dart`.

- [ ] **Step 3: Create `ApiClient`**

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Thin wrapper around the single-Lambda backend's `{endpoint, token,
/// db_name, ...}` envelope convention. The only place in the app that
/// talks HTTP directly.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Calls [endpoint] with a JSON body. [fields] are merged into the
  /// envelope alongside `endpoint`/`token`/`db_name`.
  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> fields) async {
    final body = {
      'endpoint': endpoint,
      'token': AppConfig.staffToken,
      'db_name': AppConfig.dbName,
      ...fields,
    };
    final response = await _client.post(
      Uri.parse(AppConfig.apiBaseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  /// Calls [endpoint] as multipart/form-data. [fields] become form fields;
  /// [files] map a field name to a local file path.
  Future<Map<String, dynamic>> postMultipart(
    String endpoint,
    Map<String, String> fields,
    Map<String, String> files,
  ) async {
    final request = http.MultipartRequest('POST', Uri.parse(AppConfig.apiBaseUrl))
      ..fields['endpoint'] = endpoint
      ..fields['token'] = AppConfig.staffToken
      ..fields['db_name'] = AppConfig.dbName
      ..fields.addAll(fields);

    for (final entry in files.entries) {
      request.files.add(await http.MultipartFile.fromPath(entry.key, entry.value));
    }

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    late final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw ApiException('Unexpected server response (${response.statusCode})');
    }
    if (response.statusCode >= 200 && response.statusCode < 300 && decoded['status'] != false) {
      return decoded;
    }
    final message = decoded['message']?.toString() ?? 'Request failed (${response.statusCode})';
    throw ApiException(message);
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
```

Save to `lib/core/network/api_client.dart`.

- [ ] **Step 4: Verify**

Run: `flutter analyze lib/core`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/config/app_config.dart lib/core/network/api_client.dart
git commit -m "feat(flutter): add ApiClient and hardcoded AppConfig for backend calls"
```

---

### Task 5: Domain layer — entities, repository interface, usecases

**Files:**
- Create: `lib/features/social_service_claim/domain/entities/verified_application.dart`
- Create: `lib/features/social_service_claim/domain/entities/claimant_info.dart`
- Create: `lib/features/social_service_claim/domain/entities/claim_captures.dart`
- Create: `lib/features/social_service_claim/domain/repositories/claim_repository.dart`
- Create: `lib/features/social_service_claim/domain/usecases/verify_qr.dart`
- Create: `lib/features/social_service_claim/domain/usecases/submit_claim.dart`

**Interfaces:**
- Produces: `VerifiedApplication` (fields: `id int`, `applicationNumber String`, `beneficiaryName String`, `status String`, `requestedForFname/Mname/Lname String`, getter `applicantFullName`), `ClaimantType` enum (`self`, `representative`), `ClaimantInfo` (fields: `type`, `name`, `relation`, `idType`, `idNumber`, `copyWith`), `ClaimCaptures` (fields: `idFrontPath`, `idBackPath`, `signaturePath`, `facePhotoPath`, getter `isComplete`, `copyWith`), `ClaimRepository` (abstract: `verifyQr`, `submitClaim`), `ClaimVerifyException`, `ClaimSubmitException`, `VerifyQr`, `SubmitClaim` usecases. Consumed by Tasks 6 and 7.

- [ ] **Step 1: Create `VerifiedApplication`**

```dart
import 'package:equatable/equatable.dart';

/// The application record returned by `verify_qr_bataan` once eligibility
/// gates (status, not already claimed) have passed server-side.
class VerifiedApplication extends Equatable {
  const VerifiedApplication({
    required this.id,
    required this.applicationNumber,
    required this.beneficiaryName,
    required this.status,
    required this.requestedForFname,
    required this.requestedForMname,
    required this.requestedForLname,
  });

  final int id;
  final String applicationNumber;
  final String beneficiaryName;
  final String status;
  final String requestedForFname;
  final String requestedForMname;
  final String requestedForLname;

  String get applicantFullName => [requestedForFname, requestedForMname, requestedForLname]
      .where((s) => s.isNotEmpty)
      .join(' ');

  factory VerifiedApplication.fromJson(Map<String, dynamic> json) {
    return VerifiedApplication(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      applicationNumber: (json['application_number'] ?? '').toString(),
      beneficiaryName: (json['beneficiary_name'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      requestedForFname: (json['requested_for_fname'] ?? '').toString(),
      requestedForMname: (json['requested_for_mname'] ?? '').toString(),
      requestedForLname: (json['requested_for_lname'] ?? '').toString(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        applicationNumber,
        beneficiaryName,
        status,
        requestedForFname,
        requestedForMname,
        requestedForLname,
      ];
}
```

- [ ] **Step 2: Create `ClaimantInfo`**

```dart
import 'package:equatable/equatable.dart';

enum ClaimantType { self, representative }

class ClaimantInfo extends Equatable {
  const ClaimantInfo({
    required this.type,
    this.name = '',
    this.relation = '',
    required this.idType,
    required this.idNumber,
  });

  final ClaimantType type;
  final String name;
  final String relation;
  final String idType;
  final String idNumber;

  ClaimantInfo copyWith({
    ClaimantType? type,
    String? name,
    String? relation,
    String? idType,
    String? idNumber,
  }) {
    return ClaimantInfo(
      type: type ?? this.type,
      name: name ?? this.name,
      relation: relation ?? this.relation,
      idType: idType ?? this.idType,
      idNumber: idNumber ?? this.idNumber,
    );
  }

  @override
  List<Object?> get props => [type, name, relation, idType, idNumber];
}
```

- [ ] **Step 3: Create `ClaimCaptures`**

```dart
import 'package:equatable/equatable.dart';

/// The 4 live captures taken during the claim flow (ID front, ID back,
/// signature, claimant's face photo) — local file paths only until
/// submitted.
class ClaimCaptures extends Equatable {
  const ClaimCaptures({
    this.idFrontPath,
    this.idBackPath,
    this.signaturePath,
    this.facePhotoPath,
  });

  final String? idFrontPath;
  final String? idBackPath;
  final String? signaturePath;
  final String? facePhotoPath;

  bool get isComplete =>
      idFrontPath != null && idBackPath != null && signaturePath != null && facePhotoPath != null;

  ClaimCaptures copyWith({
    String? idFrontPath,
    String? idBackPath,
    String? signaturePath,
    String? facePhotoPath,
  }) {
    return ClaimCaptures(
      idFrontPath: idFrontPath ?? this.idFrontPath,
      idBackPath: idBackPath ?? this.idBackPath,
      signaturePath: signaturePath ?? this.signaturePath,
      facePhotoPath: facePhotoPath ?? this.facePhotoPath,
    );
  }

  @override
  List<Object?> get props => [idFrontPath, idBackPath, signaturePath, facePhotoPath];
}
```

- [ ] **Step 4: Create `ClaimRepository`**

```dart
import 'entities/claim_captures.dart';
import 'entities/claimant_info.dart';
import 'entities/verified_application.dart';

abstract class ClaimRepository {
  /// Looks up [qrCode] against the backend. Returns the verified
  /// application when eligible for claim. Throws [ClaimVerifyException]
  /// with a human-readable reason on any rejection (not found, already
  /// claimed, not yet eligible) or network failure.
  Future<VerifiedApplication> verifyQr(String qrCode);

  /// Submits the claim: claimant info + 4 capture file paths. Throws
  /// [ClaimSubmitException] with a human-readable reason on failure.
  Future<void> submitClaim({
    required int applicationId,
    required ClaimantInfo claimant,
    required ClaimCaptures captures,
  });
}

class ClaimVerifyException implements Exception {
  ClaimVerifyException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ClaimSubmitException implements Exception {
  ClaimSubmitException(this.message);
  final String message;
  @override
  String toString() => message;
}
```

Note: this file must live at `lib/features/social_service_claim/domain/repositories/claim_repository.dart`, so its relative imports are `entities/claim_captures.dart` etc. (siblings under `domain/`, one level up then into `entities/`) — i.e. `import '../entities/claim_captures.dart';` and `import '../entities/claimant_info.dart';` and `import '../entities/verified_application.dart';`. Use those relative paths (correct the `entities/...` shown above to `../entities/...`).

- [ ] **Step 5: Create `VerifyQr` usecase**

```dart
import '../entities/verified_application.dart';
import '../repositories/claim_repository.dart';

class VerifyQr {
  VerifyQr(this._repository);

  final ClaimRepository _repository;

  Future<VerifiedApplication> call(String qrCode) => _repository.verifyQr(qrCode);
}
```

Save to `lib/features/social_service_claim/domain/usecases/verify_qr.dart`.

- [ ] **Step 6: Create `SubmitClaim` usecase**

```dart
import '../entities/claim_captures.dart';
import '../entities/claimant_info.dart';
import '../repositories/claim_repository.dart';

class SubmitClaim {
  SubmitClaim(this._repository);

  final ClaimRepository _repository;

  Future<void> call({
    required int applicationId,
    required ClaimantInfo claimant,
    required ClaimCaptures captures,
  }) {
    return _repository.submitClaim(applicationId: applicationId, claimant: claimant, captures: captures);
  }
}
```

Save to `lib/features/social_service_claim/domain/usecases/submit_claim.dart`.

- [ ] **Step 7: Verify**

Run: `flutter analyze lib/features/social_service_claim/domain`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/features/social_service_claim/domain
git commit -m "feat(flutter): add social_service_claim domain layer"
```

---

### Task 6: Data layer — remote datasource + repository impl

**Files:**
- Create: `lib/features/social_service_claim/data/datasources/claim_remote_datasource.dart`
- Create: `lib/features/social_service_claim/data/repositories/claim_repository_impl.dart`

**Interfaces:**
- Consumes: `ApiClient` (Task 4), `ApiException` (Task 4), `VerifiedApplication`, `ClaimantInfo`, `ClaimCaptures`, `ClaimRepository`, `ClaimVerifyException`, `ClaimSubmitException` (Task 5).
- Produces: `ClaimRemoteDatasource`, `ClaimRepositoryImpl implements ClaimRepository`, used by Task 13's wiring.

- [ ] **Step 1: Create `ClaimRemoteDatasource`**

```dart
import '../../../../core/network/api_client.dart';

/// Talks to the two Bataan-specific claim endpoints. Returns raw decoded
/// JSON — mapping to domain entities happens in [ClaimRepositoryImpl].
class ClaimRemoteDatasource {
  ClaimRemoteDatasource(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> verifyQr(String qrCode) {
    return _apiClient.post('verify_qr_bataan', {'qr_code': qrCode});
  }

  Future<void> submitClaim({
    required int applicationId,
    required String claimantType,
    required String claimantName,
    required String claimantRelation,
    required String claimantIdType,
    required String claimantIdNumber,
    required String idFrontPath,
    required String idBackPath,
    required String signaturePath,
    required String facePhotoPath,
  }) {
    return _apiClient.postMultipart(
      'submit_claim_bataan',
      {
        'id': applicationId.toString(),
        'claim_method': 'QR',
        'claimant_type': claimantType,
        'claimant_name': claimantName,
        'claimant_relation': claimantRelation,
        'claimant_id_type': claimantIdType,
        'claimant_id_number': claimantIdNumber,
      },
      {
        'claimant_id_front': idFrontPath,
        'claimant_id_back': idBackPath,
        'claimant_signature': signaturePath,
        'claimant_face_photo': facePhotoPath,
      },
    );
  }
}
```

Save to `lib/features/social_service_claim/data/datasources/claim_remote_datasource.dart`.

- [ ] **Step 2: Create `ClaimRepositoryImpl`**

```dart
import '../../../../core/network/api_client.dart';
import '../../domain/entities/claim_captures.dart';
import '../../domain/entities/claimant_info.dart';
import '../../domain/entities/verified_application.dart';
import '../../domain/repositories/claim_repository.dart';
import '../datasources/claim_remote_datasource.dart';

class ClaimRepositoryImpl implements ClaimRepository {
  ClaimRepositoryImpl(this._datasource);

  final ClaimRemoteDatasource _datasource;

  @override
  Future<VerifiedApplication> verifyQr(String qrCode) async {
    try {
      final json = await _datasource.verifyQr(qrCode);
      final data = json['data'] as Map<String, dynamic>? ?? {};
      return VerifiedApplication.fromJson(data);
    } on ApiException catch (e) {
      throw ClaimVerifyException(e.message);
    } catch (e) {
      throw ClaimVerifyException('Could not verify QR code: $e');
    }
  }

  @override
  Future<void> submitClaim({
    required int applicationId,
    required ClaimantInfo claimant,
    required ClaimCaptures captures,
  }) async {
    if (!captures.isComplete) {
      throw ClaimSubmitException('All 4 captures are required before submitting.');
    }
    try {
      await _datasource.submitClaim(
        applicationId: applicationId,
        claimantType: claimant.type == ClaimantType.self ? 'SELF' : 'REPRESENTATIVE',
        claimantName: claimant.name,
        claimantRelation: claimant.relation,
        claimantIdType: claimant.idType,
        claimantIdNumber: claimant.idNumber,
        idFrontPath: captures.idFrontPath!,
        idBackPath: captures.idBackPath!,
        signaturePath: captures.signaturePath!,
        facePhotoPath: captures.facePhotoPath!,
      );
    } on ApiException catch (e) {
      throw ClaimSubmitException(e.message);
    } catch (e) {
      throw ClaimSubmitException('Could not submit claim: $e');
    }
  }
}
```

Save to `lib/features/social_service_claim/data/repositories/claim_repository_impl.dart`.

- [ ] **Step 3: Verify**

Run: `flutter analyze lib/features/social_service_claim/data`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/social_service_claim/data
git commit -m "feat(flutter): add social_service_claim data layer"
```

---

### Task 7: `ClaimBloc` — events, state, bloc

**Files:**
- Create: `lib/features/social_service_claim/presentation/bloc/claim_event.dart`
- Create: `lib/features/social_service_claim/presentation/bloc/claim_state.dart`
- Create: `lib/features/social_service_claim/presentation/bloc/claim_bloc.dart`

**Interfaces:**
- Consumes: `VerifyQr`, `SubmitClaim` (Task 5); `ClaimantInfo`, `ClaimCaptures`, `VerifiedApplication` (Task 5).
- Produces: `ClaimEvent` subtypes (`VerifyQrRequested`, `ClaimantInfoSaved`, `IdentityConfirmed`, `CapturesUpdated`, `ClaimSubmitRequested`, `ClaimSessionReset`), `ClaimStatus` enum, `ClaimState` (fields: `status`, `application`, `claimant`, `identityConfirmed`, `captures`, `errorMessage`), `ClaimBloc`. Consumed by all pages in Tasks 8–12 and the wiring in Task 13.

- [ ] **Step 1: Create `claim_event.dart`**

```dart
import 'package:equatable/equatable.dart';

import '../../domain/entities/claim_captures.dart';
import '../../domain/entities/claimant_info.dart';

abstract class ClaimEvent extends Equatable {
  const ClaimEvent();

  @override
  List<Object?> get props => [];
}

/// Kicks off `verify_qr_bataan` for the just-scanned code.
class VerifyQrRequested extends ClaimEvent {
  const VerifyQrRequested(this.qrCode);

  final String qrCode;

  @override
  List<Object?> get props => [qrCode];
}

/// Stores the claimant-type form (self/representative + ID details).
class ClaimantInfoSaved extends ClaimEvent {
  const ClaimantInfoSaved(this.info);

  final ClaimantInfo info;

  @override
  List<Object?> get props => [info];
}

/// Staff manually confirmed the physical person matches the record.
class IdentityConfirmed extends ClaimEvent {
  const IdentityConfirmed();
}

/// A capture step completed (or was retaken); replaces the whole
/// [ClaimCaptures] snapshot.
class CapturesUpdated extends ClaimEvent {
  const CapturesUpdated(this.captures);

  final ClaimCaptures captures;

  @override
  List<Object?> get props => [captures];
}

/// Submits the claim (calls `submit_claim_bataan`).
class ClaimSubmitRequested extends ClaimEvent {
  const ClaimSubmitRequested();
}

/// Resets the whole session — used after Stop or after a successful claim,
/// before returning to the scanner.
class ClaimSessionReset extends ClaimEvent {
  const ClaimSessionReset();
}
```

- [ ] **Step 2: Create `claim_state.dart`**

```dart
import 'package:equatable/equatable.dart';

import '../../domain/entities/claim_captures.dart';
import '../../domain/entities/claimant_info.dart';
import '../../domain/entities/verified_application.dart';

enum ClaimStatus {
  initial,
  verifying,
  verifyFailed,
  verified,
  submitting,
  submitFailed,
  submitted,
}

class ClaimState extends Equatable {
  const ClaimState({
    this.status = ClaimStatus.initial,
    this.application,
    this.claimant = const ClaimantInfo(type: ClaimantType.self, idType: '', idNumber: ''),
    this.identityConfirmed = false,
    this.captures = const ClaimCaptures(),
    this.errorMessage,
  });

  final ClaimStatus status;
  final VerifiedApplication? application;
  final ClaimantInfo claimant;
  final bool identityConfirmed;
  final ClaimCaptures captures;
  final String? errorMessage;

  ClaimState copyWith({
    ClaimStatus? status,
    VerifiedApplication? application,
    ClaimantInfo? claimant,
    bool? identityConfirmed,
    ClaimCaptures? captures,
    String? errorMessage,
  }) {
    return ClaimState(
      status: status ?? this.status,
      application: application ?? this.application,
      claimant: claimant ?? this.claimant,
      identityConfirmed: identityConfirmed ?? this.identityConfirmed,
      captures: captures ?? this.captures,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [status, application, claimant, identityConfirmed, captures, errorMessage];
}
```

- [ ] **Step 3: Create `claim_bloc.dart`**

```dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/submit_claim.dart';
import '../../domain/usecases/verify_qr.dart';
import 'claim_event.dart';
import 'claim_state.dart';

class ClaimBloc extends Bloc<ClaimEvent, ClaimState> {
  ClaimBloc(this._verifyQr, this._submitClaim) : super(const ClaimState()) {
    on<VerifyQrRequested>(_onVerifyQrRequested);
    on<ClaimantInfoSaved>(_onClaimantInfoSaved);
    on<IdentityConfirmed>(_onIdentityConfirmed);
    on<CapturesUpdated>(_onCapturesUpdated);
    on<ClaimSubmitRequested>(_onClaimSubmitRequested);
    on<ClaimSessionReset>(_onClaimSessionReset);
  }

  final VerifyQr _verifyQr;
  final SubmitClaim _submitClaim;

  Future<void> _onVerifyQrRequested(VerifyQrRequested event, Emitter<ClaimState> emit) async {
    emit(state.copyWith(status: ClaimStatus.verifying));
    try {
      final application = await _verifyQr(event.qrCode);
      emit(state.copyWith(status: ClaimStatus.verified, application: application));
    } catch (e) {
      emit(state.copyWith(status: ClaimStatus.verifyFailed, errorMessage: e.toString()));
    }
  }

  void _onClaimantInfoSaved(ClaimantInfoSaved event, Emitter<ClaimState> emit) {
    emit(state.copyWith(claimant: event.info));
  }

  void _onIdentityConfirmed(IdentityConfirmed event, Emitter<ClaimState> emit) {
    emit(state.copyWith(identityConfirmed: true));
  }

  void _onCapturesUpdated(CapturesUpdated event, Emitter<ClaimState> emit) {
    emit(state.copyWith(captures: event.captures));
  }

  Future<void> _onClaimSubmitRequested(ClaimSubmitRequested event, Emitter<ClaimState> emit) async {
    final application = state.application;
    if (application == null) {
      emit(state.copyWith(
        status: ClaimStatus.submitFailed,
        errorMessage: 'No verified application in session.',
      ));
      return;
    }
    emit(state.copyWith(status: ClaimStatus.submitting));
    try {
      await _submitClaim(
        applicationId: application.id,
        claimant: state.claimant,
        captures: state.captures,
      );
      emit(state.copyWith(status: ClaimStatus.submitted));
    } catch (e) {
      emit(state.copyWith(status: ClaimStatus.submitFailed, errorMessage: e.toString()));
    }
  }

  void _onClaimSessionReset(ClaimSessionReset event, Emitter<ClaimState> emit) {
    emit(const ClaimState());
  }
}
```

- [ ] **Step 4: Verify**

Run: `flutter analyze lib/features/social_service_claim/presentation/bloc`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/social_service_claim/presentation/bloc
git commit -m "feat(flutter): add ClaimBloc"
```

---

### Task 8: `VerifyPage` + `StopPage`

**Files:**
- Create: `lib/features/social_service_claim/presentation/pages/verify_page.dart`
- Create: `lib/features/social_service_claim/presentation/pages/stop_page.dart`

**Interfaces:**
- Consumes: `ClaimBloc`, `VerifyQrRequested`, `ClaimStatus`, `ClaimState`, `ClaimSessionReset` (Task 7). Forward-references `ClaimantInfoPage` (Task 9, created in this same task's Step 1 file but not yet implemented — see note below).

- [ ] **Step 1: Create `VerifyPage`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/claim_bloc.dart';
import '../bloc/claim_event.dart';
import '../bloc/claim_state.dart';
import 'claimant_info_page.dart';
import 'stop_page.dart';

/// First screen after a QR detection: calls verify_qr_bataan and routes to
/// [ClaimantInfoPage] on success or [StopPage] on any rejection.
class VerifyPage extends StatefulWidget {
  const VerifyPage({super.key, required this.rawValue});

  final String rawValue;

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  @override
  void initState() {
    super.initState();
    context.read<ClaimBloc>().add(VerifyQrRequested(widget.rawValue));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verifying')),
      body: BlocConsumer<ClaimBloc, ClaimState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          if (state.status == ClaimStatus.verifyFailed) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => StopPage(reason: state.errorMessage ?? 'Verification failed.'),
              ),
            );
          } else if (state.status == ClaimStatus.verified) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const ClaimantInfoPage()),
            );
          }
        },
        builder: (context, state) {
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
```

Save to `lib/features/social_service_claim/presentation/pages/verify_page.dart`.
This file references `claimant_info_page.dart` (Task 9) — the project
won't fully compile until Task 9 exists; that's expected mid-plan and is
resolved by the end of Task 9.

- [ ] **Step 2: Create `StopPage`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/claim_bloc.dart';
import '../bloc/claim_event.dart';

/// Terminal screen for any rejection from verify_qr_bataan (not found,
/// already claimed, not yet eligible).
class StopPage extends StatelessWidget {
  const StopPage({super.key, required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block, color: Colors.red.shade700, size: 64),
                const SizedBox(height: 16),
                Text(
                  reason,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    context.read<ClaimBloc>().add(const ClaimSessionReset());
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

Save to `lib/features/social_service_claim/presentation/pages/stop_page.dart`.

- [ ] **Step 3: Commit (analysis deferred to Task 9 since this task is not yet self-contained)**

```bash
git add lib/features/social_service_claim/presentation/pages/verify_page.dart lib/features/social_service_claim/presentation/pages/stop_page.dart
git commit -m "feat(flutter): add VerifyPage and StopPage"
```

---

### Task 9: `ClaimantInfoPage`

**Files:**
- Create: `lib/features/social_service_claim/presentation/pages/claimant_info_page.dart`

**Interfaces:**
- Consumes: `ClaimBloc`, `ClaimantInfoSaved`, `ClaimantInfo`, `ClaimantType` (Tasks 5, 7). Forward-references `ConfirmIdentityPage` (Task 10).

- [ ] **Step 1: Create `ClaimantInfoPage`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/claimant_info.dart';
import '../bloc/claim_bloc.dart';
import '../bloc/claim_event.dart';
import 'confirm_identity_page.dart';

class ClaimantInfoPage extends StatefulWidget {
  const ClaimantInfoPage({super.key});

  @override
  State<ClaimantInfoPage> createState() => _ClaimantInfoPageState();
}

class _ClaimantInfoPageState extends State<ClaimantInfoPage> {
  ClaimantType _type = ClaimantType.self;
  final _nameController = TextEditingController();
  final _relationController = TextEditingController();
  final _idTypeController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _relationController.dispose();
    _idTypeController.dispose();
    _idNumberController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    final info = ClaimantInfo(
      type: _type,
      name: _type == ClaimantType.representative ? _nameController.text.trim() : '',
      relation: _type == ClaimantType.representative ? _relationController.text.trim() : '',
      idType: _idTypeController.text.trim(),
      idNumber: _idNumberController.text.trim(),
    );
    context.read<ClaimBloc>().add(ClaimantInfoSaved(info));
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConfirmIdentityPage()));
  }

  @override
  Widget build(BuildContext context) {
    final application = context.select((ClaimBloc bloc) => bloc.state.application);
    return Scaffold(
      appBar: AppBar(title: const Text('Claimant Information')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (application != null)
                Text('Applicant: ${application.applicantFullName}', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              const Text('Who is claiming?', style: TextStyle(fontWeight: FontWeight.bold)),
              RadioListTile<ClaimantType>(
                title: const Text('Self'),
                value: ClaimantType.self,
                groupValue: _type,
                onChanged: (v) => setState(() => _type = v!),
              ),
              RadioListTile<ClaimantType>(
                title: const Text('Representative'),
                value: ClaimantType.representative,
                groupValue: _type,
                onChanged: (v) => setState(() => _type = v!),
              ),
              if (_type == ClaimantType.representative) ...[
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Representative name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: _relationController,
                  decoration: const InputDecoration(labelText: 'Relation to applicant'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ],
              TextFormField(
                controller: _idTypeController,
                decoration: const InputDecoration(labelText: "ID type (e.g. Driver's License)"),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _idNumberController,
                decoration: const InputDecoration(labelText: 'ID number'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _continue, child: const Text('Continue')),
            ],
          ),
        ),
      ),
    );
  }
}
```

Save to `lib/features/social_service_claim/presentation/pages/claimant_info_page.dart`.
This still references `confirm_identity_page.dart` (Task 10) — full
compile resolves after Task 10.

- [ ] **Step 2: Commit**

```bash
git add lib/features/social_service_claim/presentation/pages/claimant_info_page.dart
git commit -m "feat(flutter): add ClaimantInfoPage"
```

---

### Task 10: `ConfirmIdentityPage`

**Files:**
- Create: `lib/features/social_service_claim/presentation/pages/confirm_identity_page.dart`

**Interfaces:**
- Consumes: `ClaimBloc`, `IdentityConfirmed` (Task 7). Forward-references `CaptureIdPage` (Task 11).

- [ ] **Step 1: Create `ConfirmIdentityPage`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/claim_bloc.dart';
import '../bloc/claim_event.dart';
import 'capture_id_page.dart';

/// Photo-less manual gate: staff visually matches the physical claimant
/// against the verified application's name/details. No stored reference
/// photo exists to show (neither `photo_2x2` nor `image_verification` is
/// used for this step — see the design spec).
class ConfirmIdentityPage extends StatelessWidget {
  const ConfirmIdentityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final application = context.select((ClaimBloc bloc) => bloc.state.application);
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Identity')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Application #${application?.applicationNumber ?? ''}'),
                      const SizedBox(height: 8),
                      Text(
                        application?.applicantFullName ?? '',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text('Beneficiary: ${application?.beneficiaryName ?? ''}'),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              const Text(
                'Confirm that the person physically present matches this record before proceeding.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  context.read<ClaimBloc>().add(const IdentityConfirmed());
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CaptureIdPage()));
                },
                child: const Text('Confirm this is the claimant'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Save to `lib/features/social_service_claim/presentation/pages/confirm_identity_page.dart`.

- [ ] **Step 2: Commit**

```bash
git add lib/features/social_service_claim/presentation/pages/confirm_identity_page.dart
git commit -m "feat(flutter): add ConfirmIdentityPage"
```

---

### Task 11: `CaptureIdPage`

**Files:**
- Create: `lib/features/social_service_claim/presentation/pages/capture_id_page.dart`

**Interfaces:**
- Consumes: `CapturePhoto` (from `qr_scanner`'s domain layer, already provided globally — see Task 13), `ClaimBloc`, `CapturesUpdated`, `ClaimCaptures` (Tasks 5, 7). Forward-references `PreviewPage` (Task 12).

- [ ] **Step 1: Create `CaptureIdPage`**

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../qr_scanner/domain/usecases/capture_photo.dart';
import '../../domain/entities/claim_captures.dart';
import '../bloc/claim_bloc.dart';
import '../bloc/claim_event.dart';
import 'preview_page.dart';

class _CaptureStep {
  const _CaptureStep(this.label, this.getPath, this.withPath);

  final String label;
  final String? Function(ClaimCaptures) getPath;
  final ClaimCaptures Function(ClaimCaptures, String) withPath;
}

final List<_CaptureStep> _steps = [
  _CaptureStep('ID Front', (c) => c.idFrontPath, (c, p) => c.copyWith(idFrontPath: p)),
  _CaptureStep('ID Back', (c) => c.idBackPath, (c, p) => c.copyWith(idBackPath: p)),
  _CaptureStep('Signature', (c) => c.signaturePath, (c, p) => c.copyWith(signaturePath: p)),
  _CaptureStep("Claimant's Face Photo", (c) => c.facePhotoPath, (c, p) => c.copyWith(facePhotoPath: p)),
];

/// Four sequential live captures (ID front, ID back, signature, claimant's
/// face photo). Reuses [CapturePhoto] from the qr_scanner feature's domain
/// layer — no duplicated camera-capture logic.
class CaptureIdPage extends StatefulWidget {
  const CaptureIdPage({super.key});

  @override
  State<CaptureIdPage> createState() => _CaptureIdPageState();
}

class _CaptureIdPageState extends State<CaptureIdPage> {
  int _stepIndex = 0;
  bool _capturing = false;

  Future<void> _capture() async {
    setState(() => _capturing = true);
    try {
      final capturePhoto = context.read<CapturePhoto>();
      final path = await capturePhoto();
      if (!mounted) return;
      if (path == null) return; // cancelled — stay on this step
      final bloc = context.read<ClaimBloc>();
      final updated = _steps[_stepIndex].withPath(bloc.state.captures, path);
      bloc.add(CapturesUpdated(updated));
      if (_stepIndex < _steps.length - 1) {
        setState(() => _stepIndex++);
      } else {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PreviewPage()));
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_stepIndex];
    final captures = context.select((ClaimBloc bloc) => bloc.state.captures);
    final path = step.getPath(captures);

    return Scaffold(
      appBar: AppBar(title: Text('Capture: ${step.label}')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text('Step ${_stepIndex + 1} of ${_steps.length}'),
              const SizedBox(height: 16),
              if (path != null)
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(path), fit: BoxFit.contain),
                  ),
                )
              else
                const Expanded(child: Center(child: Icon(Icons.camera_alt, size: 96))),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _capturing ? null : _capture,
                icon: _capturing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.camera_alt),
                label: Text(path == null ? 'Capture ${step.label}' : 'Retake'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Save to `lib/features/social_service_claim/presentation/pages/capture_id_page.dart`.

- [ ] **Step 2: Commit**

```bash
git add lib/features/social_service_claim/presentation/pages/capture_id_page.dart
git commit -m "feat(flutter): add CaptureIdPage"
```

---

### Task 12: `PreviewPage` + `ConfirmClaimPage`

**Files:**
- Create: `lib/features/social_service_claim/presentation/pages/preview_page.dart`
- Create: `lib/features/social_service_claim/presentation/pages/confirm_claim_page.dart`

**Interfaces:**
- Consumes: `ClaimBloc`, `ClaimSubmitRequested`, `ClaimStatus`, `ClaimState`, `ClaimantType`, `ClaimSessionReset` (Tasks 5, 7). Consumes `CaptureIdPage` (Task 11).

- [ ] **Step 1: Create `PreviewPage`**

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/claimant_info.dart';
import '../bloc/claim_bloc.dart';
import '../bloc/claim_event.dart';
import '../bloc/claim_state.dart';
import 'capture_id_page.dart';
import 'confirm_claim_page.dart';

class PreviewPage extends StatelessWidget {
  const PreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: SafeArea(
        child: BlocConsumer<ClaimBloc, ClaimState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            if (state.status == ClaimStatus.submitted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const ConfirmClaimPage()),
              );
            } else if (state.status == ClaimStatus.submitFailed) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(state.errorMessage ?? 'Submit failed.')));
            }
          },
          builder: (context, state) {
            final captures = state.captures;
            final claimant = state.claimant;
            final thumbnails = [
              ('ID Front', captures.idFrontPath),
              ('ID Back', captures.idBackPath),
              ('Signature', captures.signaturePath),
              ('Face Photo', captures.facePhotoPath),
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('Claimant: ${claimant.type == ClaimantType.self ? 'Self' : claimant.name}'),
                      Text('ID: ${claimant.idType} ${claimant.idNumber}'),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        children: [
                          for (final (label, path) in thumbnails)
                            Column(
                              children: [
                                Expanded(
                                  child: path != null
                                      ? Image.file(File(path), fit: BoxFit.cover)
                                      : const ColoredBox(color: Colors.black12),
                                ),
                                Text(label),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const CaptureIdPage()),
                          ),
                          child: const Text('Retake'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: state.status == ClaimStatus.submitting
                              ? null
                              : () => context.read<ClaimBloc>().add(const ClaimSubmitRequested()),
                          child: state.status == ClaimStatus.submitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Submit'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
```

Save to `lib/features/social_service_claim/presentation/pages/preview_page.dart`.

- [ ] **Step 2: Create `ConfirmClaimPage`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/claim_bloc.dart';
import '../bloc/claim_event.dart';

class ConfirmClaimPage extends StatelessWidget {
  const ConfirmClaimPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700, size: 72),
                const SizedBox(height: 16),
                const Text('Claim recorded', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    context.read<ClaimBloc>().add(const ClaimSessionReset());
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan Next'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

Save to `lib/features/social_service_claim/presentation/pages/confirm_claim_page.dart`.

- [ ] **Step 3: Verify the full `social_service_claim` feature analyzes clean**

Run: `flutter analyze lib/features/social_service_claim`
Expected: `No issues found!` (this is the first point in the plan where
every file in the feature — Tasks 5–12 — exists, so all forward-references
resolve).

- [ ] **Step 4: Commit**

```bash
git add lib/features/social_service_claim/presentation/pages/preview_page.dart lib/features/social_service_claim/presentation/pages/confirm_claim_page.dart
git commit -m "feat(flutter): add PreviewPage and ConfirmClaimPage"
```

---

### Task 13: Wire `main.dart`, rewire `ScannerPage`, remove dead `ResultPage`/`CaptureBloc`

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/features/qr_scanner/presentation/pages/scanner_page.dart`
- Delete: `lib/features/qr_scanner/presentation/pages/result_page.dart`
- Delete: `lib/features/qr_scanner/presentation/bloc/capture_bloc.dart`
- Delete: `lib/features/qr_scanner/presentation/bloc/capture_event.dart`
- Delete: `lib/features/qr_scanner/presentation/bloc/capture_state.dart`

**Interfaces:**
- Consumes: everything from Tasks 4–12 (`ApiClient`, `ClaimRemoteDatasource`, `ClaimRepositoryImpl`, `VerifyQr`, `SubmitClaim`, `ClaimBloc`, `VerifyPage`).

- [ ] **Step 1: Rewrite `lib/main.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/network/api_client.dart';
import 'features/qr_scanner/data/datasources/image_picker_datasource.dart';
import 'features/qr_scanner/data/datasources/mobile_scanner_datasource.dart';
import 'features/qr_scanner/data/repositories/camera_repository_impl.dart';
import 'features/qr_scanner/data/repositories/scanner_repository_impl.dart';
import 'features/qr_scanner/domain/usecases/capture_photo.dart';
import 'features/qr_scanner/presentation/bloc/scanner_bloc.dart';
import 'features/qr_scanner/presentation/pages/scanner_page.dart';
import 'features/social_service_claim/data/datasources/claim_remote_datasource.dart';
import 'features/social_service_claim/data/repositories/claim_repository_impl.dart';
import 'features/social_service_claim/domain/usecases/submit_claim.dart';
import 'features/social_service_claim/domain/usecases/verify_qr.dart';
import 'features/social_service_claim/presentation/bloc/claim_bloc.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (_) => MobileScannerDatasource(),
      dispose: (datasource) => datasource.dispose(),
      child: Builder(
        builder: (context) {
          final scannerDatasource = context.read<MobileScannerDatasource>();
          final imagePickerDatasource = ImagePickerDatasource();
          final scannerRepository = ScannerRepositoryImpl(scannerDatasource);
          final cameraRepository = CameraRepositoryImpl(imagePickerDatasource);
          final capturePhoto = CapturePhoto(cameraRepository);

          final apiClient = ApiClient();
          final claimRemoteDatasource = ClaimRemoteDatasource(apiClient);
          final claimRepository = ClaimRepositoryImpl(claimRemoteDatasource);
          final verifyQr = VerifyQr(claimRepository);
          final submitClaim = SubmitClaim(claimRepository);

          return RepositoryProvider<CapturePhoto>(
            create: (_) => capturePhoto,
            child: MultiBlocProvider(
              providers: [
                BlocProvider(create: (_) => ScannerBloc(scannerRepository)),
                BlocProvider(create: (_) => ClaimBloc(verifyQr, submitClaim)),
              ],
              child: MaterialApp(
                title: 'Bataan LGU Scanner',
                theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
                home: const ScannerPage(),
              ),
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Rewire `ScannerPage`'s navigation**

In `lib/features/qr_scanner/presentation/pages/scanner_page.dart`, change
the import block from:

```dart
import '../../data/datasources/mobile_scanner_datasource.dart';
import '../../domain/usecases/capture_photo.dart';
import '../bloc/capture_bloc.dart';
import '../bloc/scanner_bloc.dart';
import '../bloc/scanner_event.dart';
import '../bloc/scanner_state.dart';
import '../widgets/info_banner.dart';
import '../widgets/scanner_overlay.dart';
import 'result_page.dart';
```

to:

```dart
import '../../../social_service_claim/presentation/pages/verify_page.dart';
import '../../data/datasources/mobile_scanner_datasource.dart';
import '../bloc/scanner_bloc.dart';
import '../bloc/scanner_event.dart';
import '../bloc/scanner_state.dart';
import '../widgets/info_banner.dart';
import '../widgets/scanner_overlay.dart';
```

Then change the listener block from:

```dart
        listener: (context, state) {
          if (state is ScannerDetected) {
            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (_) => BlocProvider(
                      create: (_) => CaptureBloc(context.read<CapturePhoto>()),
                      child: ResultPage(rawValue: state.rawValue),
                    ),
                  ),
                )
                .then((_) {
                  if (context.mounted) context.read<ScannerBloc>().add(const StartScan());
                });
          }
        },
```

to:

```dart
        listener: (context, state) {
          if (state is ScannerDetected) {
            Navigator.of(context)
                .push(
                  MaterialPageRoute(builder: (_) => VerifyPage(rawValue: state.rawValue)),
                )
                .then((_) {
                  if (context.mounted) context.read<ScannerBloc>().add(const StartScan());
                });
          }
        },
```

- [ ] **Step 3: Delete dead files**

```bash
git rm lib/features/qr_scanner/presentation/pages/result_page.dart
git rm lib/features/qr_scanner/presentation/bloc/capture_bloc.dart
git rm lib/features/qr_scanner/presentation/bloc/capture_event.dart
git rm lib/features/qr_scanner/presentation/bloc/capture_state.dart
```

- [ ] **Step 4: Verify the whole app analyzes clean**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Verify the existing smoke test still passes**

Run: `flutter test`
Expected: `test/widget_test.dart`'s `MyApp builds without throwing` PASSES
(confirms `MyApp` still constructs its whole provider tree without
throwing, now including the new `ClaimBloc` wiring).

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart lib/features/qr_scanner/presentation/pages/scanner_page.dart
git commit -m "feat(flutter): wire ClaimBloc into app, route scans to VerifyPage, remove dead ResultPage/CaptureBloc"
```

---

## Self-Review Notes

**Spec coverage:** Purpose/flow (Task 8–12 pages match the 7-step flow),
schema change (Task 1), both endpoints (Tasks 2–3), auth correction (Tasks
2–3 use plain token, not the cebu-only admin-session gate), networking +
hardcoded config (Task 4), domain/data/presentation split (Tasks 5–7),
`qr_scanner` reuse (`CapturePhoto` consumed directly in Task 11, not
`CaptureBloc`), `ResultPage` retirement (Task 13) — all covered.

**Type consistency check performed:** `ClaimantInfo(type: ..., idType:
..., idNumber: ...)` constructor signature (Task 5) matches every call
site (`ClaimantInfoPage` Task 9, `ClaimState`'s default Task 7,
`PreviewPage` Task 12). `ClaimCaptures.copyWith` field names (`idFrontPath`,
`idBackPath`, `signaturePath`, `facePhotoPath`) match `_CaptureStep`'s
lambdas in Task 11 and `PreviewPage`'s `thumbnails` list in Task 12.
`VerifiedApplication.applicantFullName` getter (Task 5) is the one used in
`ClaimantInfoPage` and `ConfirmIdentityPage`. `ClaimBloc(VerifyQr,
SubmitClaim)` constructor (Task 7) matches its instantiation in `main.dart`
(Task 13). `ClaimRepositoryImpl(ClaimRemoteDatasource)` (Task 6) matches
its instantiation in `main.dart` (Task 13).
