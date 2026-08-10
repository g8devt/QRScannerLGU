# Scanner-Staff Login Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add username/password login for scanner-staff, backed by a new `app_users_scanner` table and a `login_scanner_bataan` endpoint, gating the existing `ScannerPage`.

**Architecture:** Backend: one new table + one new endpoint file + one new hashing helper, wired into the existing `UniversalLGU-MainPost` Lambda's `ROUTES` dict. Frontend: a new `lib/features/auth/` slice (clean architecture + bloc, mirroring `social_service_claim`), with a session cached in `shared_preferences` so staff stay logged in across launches, gating `main.dart`'s `home`.

**Tech Stack:** Python 3 / pymysql (Lambda), unittest + MagicMock (backend tests), Flutter / flutter_bloc / equatable (app), flutter_test (frontend tests, no mocking package — hand-written fakes via subclassing).

## Global Constraints

- New endpoint name: `login_scanner_bataan` (per spec — suffix `_bataan`, distinct from `login`/`login_scanner`).
- New backend files use the `_bataan` suffix: `endpoints/scanner_auth_bataan.py`, `helpers/scanner_auth_bataan.py`.
- Password hashing: SHA-256 with a **static salt distinct from** `helpers/pin.py`'s `_PIN_SALT` (separate credential domain — citizen PIN vs. scanner-staff password).
- `password` must never appear in any endpoint response.
- Username lookups are case-insensitive (`LOWER(username)=LOWER(%s)`).
- Table lives in `bataan_db` (this app's only tenant DB — see `AppConfig.dbName`).
- Backend endpoint signature: `(cur, data, files, ts)`, registered in `UniversalLGU-MainPost/lambda_function.py`'s `ROUTES` — no `NO_TOKEN_ENDPOINTS` bypass (the app already sends the app-level `staffToken` on every call).
- Frontend: no new test-mocking dependency — fakes are hand-written subclasses (matches this repo, which has zero mocking-library usage today).

---

## File Structure

```
backend/database/migrations/032_app_users_scanner.sql           [new]
backend/_external_lambdas/UniversalLGU-MainPost/
  helpers/scanner_auth_bataan.py                                [new] hash_scanner_password()
  endpoints/scanner_auth_bataan.py                               [new] login_scanner_bataan()
  lambda_function.py                                             [modify] import + ROUTES entry
  tests/test_scanner_auth_bataan.py                              [new]

lib/features/auth/
  domain/entities/scanner_user.dart                              [new]
  domain/repositories/auth_repository.dart                       [new]
  domain/usecases/login_usecase.dart                             [new]
  domain/usecases/logout_usecase.dart                            [new]
  domain/usecases/restore_session_usecase.dart                   [new]
  data/datasources/auth_remote_datasource.dart                   [new]
  data/datasources/auth_local_datasource.dart                    [new]
  data/repositories/auth_repository_impl.dart                    [new]
  presentation/bloc/auth_event.dart                               [new]
  presentation/bloc/auth_state.dart                               [new]
  presentation/bloc/auth_bloc.dart                                [new]
  presentation/pages/login_page.dart                              [new]
  presentation/pages/auth_gate.dart                                [new]
lib/main.dart                                                     [modify] wire AuthBloc, home -> AuthGate
lib/features/qr_scanner/presentation/pages/scanner_page.dart      [modify] add logout button
pubspec.yaml                                                      [modify] add shared_preferences

test/features/auth/domain/entities/scanner_user_test.dart         [new]
test/features/auth/data/repositories/auth_repository_impl_test.dart [new]
test/features/auth/presentation/bloc/auth_bloc_test.dart          [new]
```

---

### Task 1: Password hashing helper

**Files:**
- Create: `backend/_external_lambdas/UniversalLGU-MainPost/helpers/scanner_auth_bataan.py`
- Test: `backend/_external_lambdas/UniversalLGU-MainPost/tests/test_scanner_auth_bataan.py`

**Interfaces:**
- Produces: `hash_scanner_password(password) -> str` (64-char lowercase hex SHA-256 digest), imported by Task 3.

- [ ] **Step 1: Write the failing test**

Create `backend/_external_lambdas/UniversalLGU-MainPost/tests/test_scanner_auth_bataan.py`:

```python
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from helpers.scanner_auth_bataan import hash_scanner_password


class HashScannerPasswordTest(unittest.TestCase):
    def test_same_password_hashes_the_same(self):
        self.assertEqual(hash_scanner_password('Secret123'), hash_scanner_password('Secret123'))

    def test_different_passwords_hash_differently(self):
        self.assertNotEqual(hash_scanner_password('Secret123'), hash_scanner_password('Other456'))

    def test_returns_hex_sha256_digest(self):
        result = hash_scanner_password('Secret123')
        self.assertEqual(len(result), 64)
        int(result, 16)  # raises ValueError if not valid hex
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `backend/_external_lambdas/UniversalLGU-MainPost/`):
`python -m pytest tests/test_scanner_auth_bataan.py -v`
Expected: FAIL / ERROR — `ModuleNotFoundError: No module named 'helpers.scanner_auth_bataan'`

- [ ] **Step 3: Write minimal implementation**

Create `backend/_external_lambdas/UniversalLGU-MainPost/helpers/scanner_auth_bataan.py`:

```python
import hashlib

# Static-salt SHA-256 hash for app_users_scanner.password. Mirrors
# helpers/pin.py's hash_pin, but uses its own salt constant since this is a
# distinct credential domain (scanner-staff username/password, not the
# citizen app's mobile+PIN).
_SCANNER_PASSWORD_SALT = "LGU_SCANNER_BATAAN_SALT_2026"


def hash_scanner_password(password):
    return hashlib.sha256((str(password) + _SCANNER_PASSWORD_SALT).encode('utf-8')).hexdigest()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest tests/test_scanner_auth_bataan.py -v`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add backend/_external_lambdas/UniversalLGU-MainPost/helpers/scanner_auth_bataan.py backend/_external_lambdas/UniversalLGU-MainPost/tests/test_scanner_auth_bataan.py
git commit -m "feat(backend): add scanner-staff password hashing helper"
```

---

### Task 2: `app_users_scanner` migration

**Files:**
- Create: `backend/database/migrations/032_app_users_scanner.sql`

**Interfaces:**
- Produces: table `app_users_scanner` with columns `id, user_status, username, password, firstname, middlename, lastname, suffix, gender, birth_date, mobile_number, email_address, is_active, date_created, date_modified`, consumed by Task 3's `SELECT`.

No automated migration runner exists in this repo (see migration 031's header) — this task is file-only, applied manually against `bataan_db`.

- [ ] **Step 1: Write the migration file**

Create `backend/database/migrations/032_app_users_scanner.sql`:

```sql
-- Migration 032: Scanner-staff accounts for the bataan_lgu_scanner app's
-- login_scanner_bataan endpoint. Separate from app_users (citizen accounts) --
-- staff log in with username/password, not mobile+PIN. Run manually against
-- bataan_db (no migration-runner exists in this repo yet).

CREATE TABLE app_users_scanner (
  id            BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_status   ENUM('VERIFIED','PENDING','NOT_VERIFIED','DEACTIVATED')
                  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
                  NOT NULL DEFAULT 'PENDING',
  username      VARCHAR(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  password      VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  firstname     VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  middlename    VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  lastname      VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  suffix        VARCHAR(20)  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  gender        VARCHAR(20)  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  birth_date    DATE         DEFAULT NULL,
  mobile_number VARCHAR(11)  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  email_address VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  is_active     TINYINT(1)   NOT NULL DEFAULT 1,
  date_created  DATETIME(6)  DEFAULT NULL,
  date_modified DATETIME(6)  DEFAULT NULL,
  UNIQUE KEY uq_app_users_scanner_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

- [ ] **Step 2: Sanity-check the SQL**

No DB/runner available in this repo to apply it automatically. Read the file back and confirm: every column from the spec is present (`id, user_status, username, password, firstname, middlename, lastname, suffix, gender, birth_date, mobile_number, email_address, is_active`), plus `date_created`/`date_modified`, and the statement is a single well-formed `CREATE TABLE` ending in `;`.

- [ ] **Step 3: Commit**

```bash
git add backend/database/migrations/032_app_users_scanner.sql
git commit -m "feat(backend): add app_users_scanner migration"
```

---

### Task 3: `login_scanner_bataan` endpoint

**Files:**
- Create: `backend/_external_lambdas/UniversalLGU-MainPost/endpoints/scanner_auth_bataan.py`
- Modify (test): `backend/_external_lambdas/UniversalLGU-MainPost/tests/test_scanner_auth_bataan.py`

**Interfaces:**
- Consumes: `hash_scanner_password(password)` from Task 1; `ok/fail/require` from `helpers.auth`; `sanitize/serialize_row` from `helpers.db` (existing).
- Produces: `login_scanner_bataan(cur, data, files, ts) -> dict` (Lambda response shape), imported by Task 4.

- [ ] **Step 1: Write the failing tests**

Append to `backend/_external_lambdas/UniversalLGU-MainPost/tests/test_scanner_auth_bataan.py` (below the existing `HashScannerPasswordTest`, keep the existing imports and add these two):

```python
import json
from unittest.mock import MagicMock

from endpoints.scanner_auth_bataan import login_scanner_bataan


class LoginScannerBataanTest(unittest.TestCase):
    def _cur(self, fetchone_return):
        cur = MagicMock()
        cur.fetchone.return_value = fetchone_return
        return cur

    def test_missing_fields_returns_400(self):
        cur = self._cur(None)
        result = login_scanner_bataan(cur, {'username': 'staff1'}, [], '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 400)

    def test_no_matching_user_returns_400_invalid_credential(self):
        cur = self._cur(None)
        result = login_scanner_bataan(
            cur, {'username': 'staff1', 'password': 'wrongpass'}, [], '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 400)
        body = json.loads(result['body'])
        self.assertEqual(body['message'], 'Invalid Credential')

    def test_password_is_hashed_before_query(self):
        cur = self._cur(None)
        login_scanner_bataan(cur, {'username': 'staff1', 'password': 'Secret123'}, [], '2026-08-10 00:00:00')
        args, _ = cur.execute.call_args
        params = args[1]
        self.assertIn(hash_scanner_password('Secret123'), params)

    def test_valid_credentials_returns_200_with_user_data(self):
        cur = self._cur({
            'id': 7, 'username': 'staff1', 'password': hash_scanner_password('Secret123'),
            'user_status': 'VERIFIED', 'firstname': 'Juan', 'middlename': '',
            'lastname': 'Dela Cruz', 'suffix': '', 'gender': 'MALE',
            'birth_date': '1990-01-01', 'mobile_number': '09171234567',
            'email_address': 'staff1@example.com', 'is_active': 1,
        })
        result = login_scanner_bataan(
            cur, {'username': 'staff1', 'password': 'Secret123'}, [], '2026-08-10 00:00:00')
        self.assertEqual(result['statusCode'], 200)
        body = json.loads(result['body'])
        self.assertTrue(body['status'])
        self.assertEqual(body['user_profile_id'], '7')
        self.assertNotIn('password', body['data'])
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python -m pytest tests/test_scanner_auth_bataan.py -v`
Expected: FAIL / ERROR — `ModuleNotFoundError: No module named 'endpoints.scanner_auth_bataan'`

- [ ] **Step 3: Write minimal implementation**

Create `backend/_external_lambdas/UniversalLGU-MainPost/endpoints/scanner_auth_bataan.py`:

```python
import logging
from helpers.auth import ok, fail, require
from helpers.db import sanitize, serialize_row
from helpers.scanner_auth_bataan import hash_scanner_password

logger = logging.getLogger()


def login_scanner_bataan(cur, data, files, ts):
    """Authenticate scanner-app staff against app_users_scanner by
    username/password (distinct from the citizen app_users mobile+PIN
    login)."""
    try:
        require(data, 'username', 'password')
        username = sanitize(data['username'])
        if not username:
            return fail('Invalid Credential')
        hashed = hash_scanner_password(data['password'])

        cur.execute(
            "SELECT * FROM app_users_scanner WHERE LOWER(username)=LOWER(%s) "
            "AND password=%s AND is_active=1 AND user_status != 'DEACTIVATED'",
            (username, hashed),
        )
        user = cur.fetchone()
        if not user:
            return fail('Invalid Credential')

        row = serialize_row(user)
        row.pop('password', None)
        return ok({
            'status': True,
            'message': 'Login Successfully',
            'user_profile_id': str(user['id']),
            'username': user['username'],
            'user_status': user.get('user_status', ''),
            'data': row,
        })
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"login_scanner_bataan error: {e}", exc_info=True)
        return fail(f'Server error: {e}', 500)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python -m pytest tests/test_scanner_auth_bataan.py -v`
Expected: PASS (7 tests total: 3 from Task 1 + 4 new)

- [ ] **Step 5: Commit**

```bash
git add backend/_external_lambdas/UniversalLGU-MainPost/endpoints/scanner_auth_bataan.py backend/_external_lambdas/UniversalLGU-MainPost/tests/test_scanner_auth_bataan.py
git commit -m "feat(backend): add login_scanner_bataan endpoint"
```

---

### Task 4: Wire `login_scanner_bataan` into the router

**Files:**
- Modify: `backend/_external_lambdas/UniversalLGU-MainPost/lambda_function.py`

**Interfaces:**
- Consumes: `scanner_auth_bataan.login_scanner_bataan` from Task 3.

- [ ] **Step 1: Add the import**

In `lambda_function.py`, alongside the other `from endpoints import ...` lines (near line 27, after `from endpoints import analytics`), add:

```python
from endpoints import scanner_auth_bataan
```

- [ ] **Step 2: Register the route**

In the `ROUTES` dict, add a new entry (e.g. right after the `'confirm_tourism_booking_payment': tourism.confirm_tourism_booking_payment,` line at the end):

```python
    'login_scanner_bataan': scanner_auth_bataan.login_scanner_bataan,
```

- [ ] **Step 3: Run the full backend test suite to confirm nothing broke**

Run (from `backend/_external_lambdas/UniversalLGU-MainPost/`): `python -m pytest tests/ -v`
Expected: all tests PASS, including the 7 from Task 1/3.

- [ ] **Step 4: Commit**

```bash
git add backend/_external_lambdas/UniversalLGU-MainPost/lambda_function.py
git commit -m "feat(backend): register login_scanner_bataan in MainPost router"
```

---

### Task 5: Auth domain layer (Flutter)

**Files:**
- Create: `lib/features/auth/domain/entities/scanner_user.dart`
- Create: `lib/features/auth/domain/repositories/auth_repository.dart`
- Create: `lib/features/auth/domain/usecases/login_usecase.dart`
- Create: `lib/features/auth/domain/usecases/logout_usecase.dart`
- Create: `lib/features/auth/domain/usecases/restore_session_usecase.dart`
- Test: `test/features/auth/domain/entities/scanner_user_test.dart`

**Interfaces:**
- Produces: `ScannerUser` (entity, with `.fromJson`/`.toJson`), `AuthRepository` (abstract: `login`, `restoreSession`, `logout`), `AuthException`, `LoginUsecase`, `LogoutUsecase`, `RestoreSessionUsecase` — all consumed by Tasks 6 and 8.

- [ ] **Step 1: Write the failing test**

Create `test/features/auth/domain/entities/scanner_user_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bataan_lgu_scanner/features/auth/domain/entities/scanner_user.dart';

void main() {
  test('fromJson parses all fields and toJson round-trips them', () {
    final json = {
      'id': 7,
      'username': 'staff1',
      'user_status': 'VERIFIED',
      'firstname': 'Juan',
      'middlename': '',
      'lastname': 'Dela Cruz',
      'suffix': '',
    };

    final user = ScannerUser.fromJson(json);

    expect(user.id, 7);
    expect(user.username, 'staff1');
    expect(user.userStatus, 'VERIFIED');
    expect(user.fullName, 'Juan Dela Cruz');
    expect(user.toJson(), json);
  });

  test('fromJson defaults missing string fields to empty string', () {
    final user = ScannerUser.fromJson({'id': 1});

    expect(user.username, '');
    expect(user.userStatus, '');
    expect(user.fullName, '');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/domain/entities/scanner_user_test.dart`
Expected: FAIL — `Error: Error when reading 'lib/features/auth/domain/entities/scanner_user.dart'`

- [ ] **Step 3: Write minimal implementation**

Create `lib/features/auth/domain/entities/scanner_user.dart`:

```dart
import 'package:equatable/equatable.dart';

/// A logged-in scanner-staff account, as returned by the
/// `login_scanner_bataan` endpoint's `data` object.
class ScannerUser extends Equatable {
  const ScannerUser({
    required this.id,
    required this.username,
    required this.userStatus,
    required this.firstname,
    required this.middlename,
    required this.lastname,
    required this.suffix,
  });

  final int id;
  final String username;
  final String userStatus;
  final String firstname;
  final String middlename;
  final String lastname;
  final String suffix;

  String get fullName =>
      [firstname, middlename, lastname, suffix].where((s) => s.isNotEmpty).join(' ');

  factory ScannerUser.fromJson(Map<String, dynamic> json) {
    return ScannerUser(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      username: (json['username'] ?? '').toString(),
      userStatus: (json['user_status'] ?? '').toString(),
      firstname: (json['firstname'] ?? '').toString(),
      middlename: (json['middlename'] ?? '').toString(),
      lastname: (json['lastname'] ?? '').toString(),
      suffix: (json['suffix'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'user_status': userStatus,
        'firstname': firstname,
        'middlename': middlename,
        'lastname': lastname,
        'suffix': suffix,
      };

  @override
  List<Object?> get props => [id, username, userStatus, firstname, middlename, lastname, suffix];
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/auth/domain/entities/scanner_user_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Add the repository contract and usecases (no separate test — thin pass-throughs, same convention as `VerifyQr`/`SubmitClaim`)**

Create `lib/features/auth/domain/repositories/auth_repository.dart`:

```dart
import '../entities/scanner_user.dart';

abstract class AuthRepository {
  /// Authenticates against `login_scanner_bataan`. Throws
  /// [AuthException] with a human-readable reason on invalid credentials,
  /// a deactivated account, or a network failure.
  Future<ScannerUser> login({required String username, required String password});

  /// Returns the locally cached session, or null if none is stored.
  Future<ScannerUser?> restoreSession();

  /// Clears the locally cached session.
  Future<void> logout();
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}
```

Create `lib/features/auth/domain/usecases/login_usecase.dart`:

```dart
import '../entities/scanner_user.dart';
import '../repositories/auth_repository.dart';

class LoginUsecase {
  LoginUsecase(this._repository);

  final AuthRepository _repository;

  Future<ScannerUser> call({required String username, required String password}) =>
      _repository.login(username: username, password: password);
}
```

Create `lib/features/auth/domain/usecases/logout_usecase.dart`:

```dart
import '../repositories/auth_repository.dart';

class LogoutUsecase {
  LogoutUsecase(this._repository);

  final AuthRepository _repository;

  Future<void> call() => _repository.logout();
}
```

Create `lib/features/auth/domain/usecases/restore_session_usecase.dart`:

```dart
import '../entities/scanner_user.dart';
import '../repositories/auth_repository.dart';

class RestoreSessionUsecase {
  RestoreSessionUsecase(this._repository);

  final AuthRepository _repository;

  Future<ScannerUser?> call() => _repository.restoreSession();
}
```

- [ ] **Step 6: Run `flutter analyze` to confirm the new files compile cleanly**

Run: `flutter analyze lib/features/auth`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/features/auth/domain test/features/auth/domain/entities/scanner_user_test.dart
git commit -m "feat(auth): add auth domain layer (entity, repository contract, usecases)"
```

---

### Task 6: Auth data layer (Flutter)

**Files:**
- Create: `lib/features/auth/data/datasources/auth_remote_datasource.dart`
- Create: `lib/features/auth/data/datasources/auth_local_datasource.dart`
- Create: `lib/features/auth/data/repositories/auth_repository_impl.dart`
- Test: `test/features/auth/data/repositories/auth_repository_impl_test.dart`

**Interfaces:**
- Consumes: `ApiClient` (`lib/core/network/api_client.dart`, existing), `ScannerUser`/`AuthRepository`/`AuthException` from Task 5.
- Produces: `AuthRemoteDatasource` (`Future<Map<String, dynamic>> login({username, password})`), `AuthLocalDatasource` (`saveSession`/`getSession`/`clearSession`), `AuthRepositoryImpl implements AuthRepository` — consumed by Task 8.

- [ ] **Step 1: Write the failing test**

Create `test/features/auth/data/repositories/auth_repository_impl_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bataan_lgu_scanner/core/network/api_client.dart';
import 'package:bataan_lgu_scanner/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:bataan_lgu_scanner/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:bataan_lgu_scanner/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:bataan_lgu_scanner/features/auth/domain/repositories/auth_repository.dart';

class _FakeAuthRemoteDatasource extends AuthRemoteDatasource {
  _FakeAuthRemoteDatasource({this.response, this.error}) : super(ApiClient());
  final Map<String, dynamic>? response;
  final Object? error;

  @override
  Future<Map<String, dynamic>> login({required String username, required String password}) async {
    if (error != null) throw error!;
    return response!;
  }
}

class _FakeAuthLocalDatasource extends AuthLocalDatasource {
  Map<String, dynamic>? stored;

  @override
  Future<void> saveSession(Map<String, dynamic> json) async => stored = json;

  @override
  Future<Map<String, dynamic>?> getSession() async => stored;

  @override
  Future<void> clearSession() async => stored = null;
}

void main() {
  group('AuthRepositoryImpl.login', () {
    test('maps a successful response to a ScannerUser and caches it locally', () async {
      final local = _FakeAuthLocalDatasource();
      final repo = AuthRepositoryImpl(
        _FakeAuthRemoteDatasource(response: {
          'status': true,
          'data': {
            'id': 7, 'username': 'staff1', 'user_status': 'VERIFIED', 'firstname': 'Juan',
            'middlename': '', 'lastname': 'Dela Cruz', 'suffix': '',
          },
        }),
        local,
      );

      final user = await repo.login(username: 'staff1', password: 'Secret123');

      expect(user.id, 7);
      expect(user.username, 'staff1');
      expect(local.stored, isNotNull);
      expect(local.stored!['username'], 'staff1');
    });

    test('wraps an ApiException as an AuthException', () async {
      final repo = AuthRepositoryImpl(
        _FakeAuthRemoteDatasource(error: ApiException('Invalid Credential')),
        _FakeAuthLocalDatasource(),
      );

      expect(
        () => repo.login(username: 'staff1', password: 'wrong'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', 'Invalid Credential')),
      );
    });
  });

  group('AuthRepositoryImpl.restoreSession', () {
    test('returns null when nothing is cached', () async {
      final repo = AuthRepositoryImpl(
        _FakeAuthRemoteDatasource(response: const {}),
        _FakeAuthLocalDatasource(),
      );

      expect(await repo.restoreSession(), isNull);
    });

    test('returns the cached ScannerUser when present', () async {
      final local = _FakeAuthLocalDatasource();
      local.stored = {
        'id': 7, 'username': 'staff1', 'user_status': 'VERIFIED',
        'firstname': 'Juan', 'middlename': '', 'lastname': 'Dela Cruz', 'suffix': '',
      };
      final repo = AuthRepositoryImpl(_FakeAuthRemoteDatasource(response: const {}), local);

      final user = await repo.restoreSession();

      expect(user, isNotNull);
      expect(user!.username, 'staff1');
    });
  });

  group('AuthRepositoryImpl.logout', () {
    test('clears the local session', () async {
      final local = _FakeAuthLocalDatasource()..stored = {'id': 1};
      final repo = AuthRepositoryImpl(_FakeAuthRemoteDatasource(response: const {}), local);

      await repo.logout();

      expect(local.stored, isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/data/repositories/auth_repository_impl_test.dart`
Expected: FAIL — missing source files (`auth_remote_datasource.dart`, `auth_local_datasource.dart`, `auth_repository_impl.dart`)

- [ ] **Step 3: Write minimal implementation**

Create `lib/features/auth/data/datasources/auth_remote_datasource.dart`:

```dart
import '../../../../core/network/api_client.dart';

/// Talks to the scanner-staff login endpoint. Returns raw decoded JSON —
/// mapping to [ScannerUser] happens in AuthRepositoryImpl.
class AuthRemoteDatasource {
  AuthRemoteDatasource(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> login({required String username, required String password}) {
    return _apiClient.post('login_scanner_bataan', {'username': username, 'password': password});
  }
}
```

Create `lib/features/auth/data/datasources/auth_local_datasource.dart`:

```dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the logged-in scanner user's raw JSON locally so the app can
/// skip the login page on subsequent launches.
class AuthLocalDatasource {
  static const _sessionKey = 'scanner_auth_session';

  Future<void> saveSession(Map<String, dynamic> json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(json));
  }

  Future<Map<String, dynamic>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }
}
```

Create `lib/features/auth/data/repositories/auth_repository_impl.dart`:

```dart
import '../../../../core/network/api_client.dart';
import '../../domain/entities/scanner_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote, this._local);

  final AuthRemoteDatasource _remote;
  final AuthLocalDatasource _local;

  @override
  Future<ScannerUser> login({required String username, required String password}) async {
    try {
      final json = await _remote.login(username: username, password: password);
      final data = json['data'] as Map<String, dynamic>? ?? {};
      final user = ScannerUser.fromJson(data);
      await _local.saveSession(data);
      return user;
    } on ApiException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw AuthException('Network error — could not reach the server: $e');
    }
  }

  @override
  Future<ScannerUser?> restoreSession() async {
    final json = await _local.getSession();
    if (json == null) return null;
    return ScannerUser.fromJson(json);
  }

  @override
  Future<void> logout() => _local.clearSession();
}
```

NOTE: this step requires the `shared_preferences` package, added in Task 7. If running this task's tests before Task 7, first add the dependency (see Task 7, Step 1) — the fakes in the test never touch `SharedPreferences` directly, but `auth_local_datasource.dart` must still compile.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/auth/data/repositories/auth_repository_impl_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/data test/features/auth/data/repositories/auth_repository_impl_test.dart
git commit -m "feat(auth): add auth data layer (datasources, repository impl)"
```

---

### Task 7: Add `shared_preferences` dependency

**Files:**
- Modify: `pubspec.yaml`

**Interfaces:**
- Produces: the `shared_preferences` package, consumed by Task 6's `AuthLocalDatasource`.

(This task must run before or alongside Task 6's Step 3-4, since `auth_local_datasource.dart` won't compile without it — if executing tasks strictly in order, do this task first.)

- [ ] **Step 1: Add the dependency**

In `pubspec.yaml`, under `dependencies:` (after the existing `signature: ^6.3.0` line), add:

```yaml
  shared_preferences: ^2.3.2
```

- [ ] **Step 2: Fetch it**

Run: `flutter pub get`
Expected: resolves successfully. If `^2.3.2` doesn't resolve against this project's Flutter/Dart SDK, bump to whatever `flutter pub add shared_preferences` picks.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add shared_preferences dependency"
```

---

### Task 8: Auth bloc (Flutter)

**Files:**
- Create: `lib/features/auth/presentation/bloc/auth_event.dart`
- Create: `lib/features/auth/presentation/bloc/auth_state.dart`
- Create: `lib/features/auth/presentation/bloc/auth_bloc.dart`
- Test: `test/features/auth/presentation/bloc/auth_bloc_test.dart`

**Interfaces:**
- Consumes: `LoginUsecase`, `LogoutUsecase`, `RestoreSessionUsecase`, `AuthRepository`, `AuthException`, `ScannerUser` from Tasks 5/6.
- Produces: `AuthEvent` (`AppStarted`, `LoginRequested(username, password)`, `LogoutRequested`), `AuthStatus` enum (`unknown, loading, authenticated, unauthenticated, error`), `AuthState` (`status, user, errorMessage`), `AuthBloc` — consumed by Tasks 9/10.

- [ ] **Step 1: Write the failing test**

Create `test/features/auth/presentation/bloc/auth_bloc_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bataan_lgu_scanner/features/auth/domain/entities/scanner_user.dart';
import 'package:bataan_lgu_scanner/features/auth/domain/repositories/auth_repository.dart';
import 'package:bataan_lgu_scanner/features/auth/domain/usecases/login_usecase.dart';
import 'package:bataan_lgu_scanner/features/auth/domain/usecases/logout_usecase.dart';
import 'package:bataan_lgu_scanner/features/auth/domain/usecases/restore_session_usecase.dart';
import 'package:bataan_lgu_scanner/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:bataan_lgu_scanner/features/auth/presentation/bloc/auth_event.dart';
import 'package:bataan_lgu_scanner/features/auth/presentation/bloc/auth_state.dart';

class _FakeAuthRepository implements AuthRepository {
  ScannerUser? loginResult;
  Object? loginError;
  ScannerUser? restoredSession;
  bool loggedOut = false;

  @override
  Future<ScannerUser> login({required String username, required String password}) async {
    if (loginError != null) throw loginError!;
    return loginResult!;
  }

  @override
  Future<ScannerUser?> restoreSession() async => restoredSession;

  @override
  Future<void> logout() async => loggedOut = true;
}

const _user = ScannerUser(
  id: 7, username: 'staff1', userStatus: 'VERIFIED',
  firstname: 'Juan', middlename: '', lastname: 'Dela Cruz', suffix: '',
);

void main() {
  late _FakeAuthRepository repository;
  late AuthBloc bloc;

  setUp(() {
    repository = _FakeAuthRepository();
    bloc = AuthBloc(
      LoginUsecase(repository),
      LogoutUsecase(repository),
      RestoreSessionUsecase(repository),
    );
  });

  tearDown(() => bloc.close());

  test('AppStarted emits authenticated when a session is cached', () async {
    repository.restoredSession = _user;
    final states = <AuthState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const AppStarted());
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(states, [const AuthState(status: AuthStatus.authenticated, user: _user)]);
  });

  test('AppStarted emits unauthenticated when no session is cached', () async {
    final states = <AuthState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const AppStarted());
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(states, [const AuthState(status: AuthStatus.unauthenticated)]);
  });

  test('LoginRequested emits loading then authenticated on success', () async {
    repository.loginResult = _user;
    final states = <AuthState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const LoginRequested(username: 'staff1', password: 'Secret123'));
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(states, [
      const AuthState(status: AuthStatus.loading),
      const AuthState(status: AuthStatus.authenticated, user: _user),
    ]);
  });

  test('LoginRequested emits loading then error on invalid credentials', () async {
    repository.loginError = AuthException('Invalid Credential');
    final states = <AuthState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const LoginRequested(username: 'staff1', password: 'wrong'));
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(states, [
      const AuthState(status: AuthStatus.loading),
      const AuthState(status: AuthStatus.error, errorMessage: 'Invalid Credential'),
    ]);
  });

  test('LogoutRequested clears the session and emits unauthenticated', () async {
    final states = <AuthState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const LogoutRequested());
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(repository.loggedOut, isTrue);
    expect(states, [const AuthState(status: AuthStatus.unauthenticated)]);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/presentation/bloc/auth_bloc_test.dart`
Expected: FAIL — missing source files (`auth_event.dart`, `auth_state.dart`, `auth_bloc.dart`)

- [ ] **Step 3: Write minimal implementation**

Create `lib/features/auth/presentation/bloc/auth_event.dart`:

```dart
import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Checked once on app start — restores a cached session if one exists.
class AppStarted extends AuthEvent {
  const AppStarted();
}

/// Submits the login form.
class LoginRequested extends AuthEvent {
  const LoginRequested({required this.username, required this.password});

  final String username;
  final String password;

  @override
  List<Object?> get props => [username, password];
}

/// Staff tapped the logout control.
class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}
```

Create `lib/features/auth/presentation/bloc/auth_state.dart`:

```dart
import 'package:equatable/equatable.dart';

import '../../domain/entities/scanner_user.dart';

enum AuthStatus { unknown, loading, authenticated, unauthenticated, error }

class AuthState extends Equatable {
  const AuthState({this.status = AuthStatus.unknown, this.user, this.errorMessage});

  final AuthStatus status;
  final ScannerUser? user;
  final String? errorMessage;

  AuthState copyWith({AuthStatus? status, ScannerUser? user, String? errorMessage}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, user, errorMessage];
}
```

Create `lib/features/auth/presentation/bloc/auth_bloc.dart`:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/restore_session_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._login, this._logout, this._restoreSession) : super(const AuthState()) {
    on<AppStarted>(_onAppStarted);
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }

  final LoginUsecase _login;
  final LogoutUsecase _logout;
  final RestoreSessionUsecase _restoreSession;

  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    final user = await _restoreSession();
    if (user != null) {
      emit(state.copyWith(status: AuthStatus.authenticated, user: user));
    } else {
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    }
  }

  Future<void> _onLoginRequested(LoginRequested event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final user = await _login(username: event.username, password: event.password);
      emit(state.copyWith(status: AuthStatus.authenticated, user: user));
    } catch (e) {
      emit(state.copyWith(status: AuthStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onLogoutRequested(LogoutRequested event, Emitter<AuthState> emit) async {
    await _logout();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/auth/presentation/bloc/auth_bloc_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/presentation/bloc test/features/auth/presentation/bloc/auth_bloc_test.dart
git commit -m "feat(auth): add AuthBloc"
```

---

### Task 9: Login page UI

**Files:**
- Create: `lib/features/auth/presentation/pages/login_page.dart`

**Interfaces:**
- Consumes: `AuthBloc`, `AuthEvent.LoginRequested`, `AuthState`, `AuthStatus` from Task 8 (via `context.read<AuthBloc>()` / `BlocBuilder`).
- Produces: `LoginPage` widget, consumed by Task 10's `AuthGate`.

No dedicated widget test — this repo has no widget tests for any existing page (`claimant_info_page.dart`, `scanner_page.dart`, etc.); behavior is covered by Task 8's bloc tests. Verify manually via `flutter analyze` and, if a device/emulator is available, `flutter run`.

- [ ] **Step 1: Write the page**

Create `lib/features/auth/presentation/pages/login_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(LoginRequested(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            final loading = state.status == AuthStatus.loading;
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Bataan LGU Scanner',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text('Sign in with your scanner-staff account.'),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(labelText: 'Username'),
                        textInputAction: TextInputAction.next,
                        enabled: !loading,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        enabled: !loading,
                        onFieldSubmitted: (_) => _submit(),
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      if (state.status == AuthStatus.error) ...[
                        const SizedBox(height: 16),
                        Text(state.errorMessage ?? 'Login failed', style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: loading ? null : _submit,
                        child: loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Log In'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/features/auth/presentation/pages/login_page.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/auth/presentation/pages/login_page.dart
git commit -m "feat(auth): add login page UI"
```

---

### Task 10: Auth gate + wire into `main.dart`

**Files:**
- Create: `lib/features/auth/presentation/pages/auth_gate.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `LoginPage` (Task 9), `ScannerPage` (existing), `AuthBloc`/`AuthState`/`AuthStatus`/`AppStarted` (Task 8).
- Produces: `AuthGate` widget, set as `main.dart`'s `home`.

No dedicated widget test (same rationale as Task 9). Verify via `flutter analyze` and `flutter run` (manual smoke test): app opens to `LoginPage`, logging in with a seeded `app_users_scanner` row navigates to `ScannerPage`, relaunching the app skips straight to `ScannerPage`.

- [ ] **Step 1: Write the gate widget**

Create `lib/features/auth/presentation/pages/auth_gate.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../qr_scanner/presentation/pages/scanner_page.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'login_page.dart';

/// Shown as the app's `home`. Dispatches [AppStarted] once, then swaps
/// between [LoginPage] and [ScannerPage] based on auth status.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>().add(const AppStarted());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        switch (state.status) {
          case AuthStatus.authenticated:
            return const ScannerPage();
          case AuthStatus.unknown:
          case AuthStatus.loading:
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          case AuthStatus.unauthenticated:
          case AuthStatus.error:
            return const LoginPage();
        }
      },
    );
  }
}
```

- [ ] **Step 2: Wire it into `main.dart`**

Modify `lib/main.dart`. Add these imports (alongside the existing ones):

```dart
import 'features/auth/data/datasources/auth_local_datasource.dart';
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/usecases/login_usecase.dart';
import 'features/auth/domain/usecases/logout_usecase.dart';
import 'features/auth/domain/usecases/restore_session_usecase.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/pages/auth_gate.dart';
```

In the `builder` callback (inside `Builder(builder: (context) { ... })`), after the existing `final submitClaim = SubmitClaim(claimRepository);` line, add:

```dart
          final authRemoteDatasource = AuthRemoteDatasource(apiClient);
          final authLocalDatasource = AuthLocalDatasource();
          final authRepository = AuthRepositoryImpl(authRemoteDatasource, authLocalDatasource);
          final loginUsecase = LoginUsecase(authRepository);
          final logoutUsecase = LogoutUsecase(authRepository);
          final restoreSessionUsecase = RestoreSessionUsecase(authRepository);
```

Add `AuthBloc` to the `MultiBlocProvider`'s `providers` list (alongside `ScannerBloc` and `ClaimBloc`):

```dart
                BlocProvider(create: (_) => AuthBloc(loginUsecase, logoutUsecase, restoreSessionUsecase)),
```

Replace `home: const ScannerPage(),` with:

```dart
                home: const AuthGate(),
```

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/auth/presentation/pages/auth_gate.dart lib/main.dart
git commit -m "feat(auth): add AuthGate and wire login into app startup"
```

---

### Task 11: Logout button on `ScannerPage`

**Files:**
- Modify: `lib/features/qr_scanner/presentation/pages/scanner_page.dart`

**Interfaces:**
- Consumes: `AuthBloc`, `LogoutRequested` from Task 8.

- [ ] **Step 1: Add the imports**

In `scanner_page.dart`, add alongside the existing imports:

```dart
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
```

- [ ] **Step 2: Add the logout icon to the top banner**

In the `build` method, find the top `InfoBanner` (the one with `icon: Icons.qr_code_scanner`) and give it a `trailing`:

```dart
                    child: InfoBanner(
                      icon: Icons.qr_code_scanner,
                      trailing: IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white),
                        tooltip: 'Log out',
                        onPressed: () => context.read<AuthBloc>().add(const LogoutRequested()),
                      ),
                      child: const Text('Scan QR to Fetch ID', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
```

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze lib/features/qr_scanner/presentation/pages/scanner_page.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/qr_scanner/presentation/pages/scanner_page.dart
git commit -m "feat(auth): add logout button to scanner page"
```

---

### Task 12: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full Flutter test suite**

Run: `flutter test`
Expected: all tests PASS (existing `widget_test.dart` plus all new tests from Tasks 5/6/8).

- [ ] **Step 2: Run `flutter analyze` on the whole project**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Run the full backend test suite**

Run (from `backend/_external_lambdas/UniversalLGU-MainPost/`): `python -m pytest tests/ -v`
Expected: all tests PASS.

- [ ] **Step 4: Manual smoke test (requires a seeded `app_users_scanner` row and a deployed backend — skip if unavailable, note as a follow-up)**

Insert a test row (password hash from `hash_scanner_password('Secret123')` computed via `python -c "from helpers.scanner_auth_bataan import hash_scanner_password; print(hash_scanner_password('Secret123'))"`), then `flutter run`: confirm the app opens to the login page, wrong credentials show an inline error, correct credentials navigate to the scanner, the logout button returns to the login page, and relaunching after a successful login skips straight to the scanner.
