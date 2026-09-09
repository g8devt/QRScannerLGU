# Scanner Auto-Login Status Revalidation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Scanner app's auto-login (Remember Me / `restoreSession()`) enforce the same `is_active = 1 AND user_status != 'DEACTIVATED'` rule as fresh manual login, by revalidating the cached session against the backend on every app start instead of trusting the locally cached JSON.

**Architecture:** Add a new backend endpoint `check_scanner_status_bataan` (same module as `login_scanner_bataan`) that looks up the current `is_active`/`user_status` for a given `user_profile_id` and always responds 200 with `{status: true, is_valid: bool}` — never using the `fail()`/non-200 path for a legitimate "inactive" result, so the Flutter `ApiClient` only throws for genuine network/server failures. `AuthRepositoryImpl.restoreSession()` calls this endpoint using the cached user's `id` before trusting the cached session; on `is_valid: false` it clears the cache and throws a new `AccountInactiveException`, on a network/server failure it throws the existing `AuthException` without touching the cache (fail closed, retryable). `AuthBloc._onAppStarted` catches the two cases differently: `AccountInactiveException` → clear + emit a new `AuthStatus.accountInactive` (carries a user-safe message); `AuthException` (network/server) → emit `unauthenticated` without clearing; anything else (corrupted local JSON) → clear + emit `unauthenticated`, same as today. `AuthGate` shows the existing `showMessageDialog` once when it observes `accountInactive`, then falls through to `LoginPage` like every other non-authenticated status.

**Tech Stack:** Flutter/Dart (flutter_bloc, http), Python 3.12 Lambda (pymysql), pytest, flutter_test.

**Spec:** This plan implements the "Scanner app authentication fix" spec given directly in the task request (no separate spec file) — see the Global Constraints below for its exact requirements.

## Global Constraints

- The only condition allowing access, for BOTH fresh login and auto-login: `is_active = 1 AND user_status != 'DEACTIVATED'`.
- Never trust the cached user's old `is_active`/`user_status` — the backend is the source of truth on every app start.
- Manual login's existing SQL-level check in `login_scanner_bataan` must not change.
- Reuse the existing auth architecture (repository/datasource/usecase/bloc layering, the shared `ApiClient` envelope, the existing `showMessageDialog` widget) — no parallel auth system.
- Account-rejection (`is_valid: false`) must be visually and behaviorally distinct from a network/server failure: only a confirmed rejection clears the cached session and shows "Account Inactive"; a network/server failure fails closed (does not authenticate) but does not show that dialog and does not clear the cache.
- Dialog copy exactly: title `Account Inactive`, message `Your account is no longer active. Please contact your administrator for assistance.`, button `OK`. No technical/DB details exposed.
- Do not modify unrelated Scanner features (QR, CVL, permissions, etc.).

---

## File Structure

- Modify `backend/_external_lambdas/UniversalLGU-MainPost/endpoints/scanner_auth_bataan.py` — add `check_scanner_status_bataan`.
- Modify `backend/_external_lambdas/UniversalLGU-MainPost/lambda_function.py` — route the new action.
- Modify `backend/_external_lambdas/UniversalLGU-MainPost/tests/test_scanner_auth_bataan.py` — unit tests for the new endpoint covering all 4 status combinations.
- Modify `lib/features/auth/domain/repositories/auth_repository.dart` — add `AccountInactiveException`, update `restoreSession()` doc.
- Modify `lib/features/auth/data/datasources/auth_remote_datasource.dart` — add `checkStatus`.
- Modify `lib/features/auth/data/repositories/auth_repository_impl.dart` — revalidate in `restoreSession()`.
- Modify `lib/features/auth/presentation/bloc/auth_state.dart` — add `AuthStatus.accountInactive`.
- Modify `lib/features/auth/presentation/bloc/auth_bloc.dart` — distinguish exception types in `_onAppStarted`.
- Modify `lib/features/auth/presentation/pages/auth_gate.dart` — show the dialog on `accountInactive`, route it to `LoginPage`.
- Modify `test/features/auth/data/repositories/auth_repository_impl_test.dart` — update/add `restoreSession` tests.
- Modify `test/features/auth/presentation/bloc/auth_bloc_test.dart` — add `AppStarted` tests for the new states.

---

### Task 1: Backend — `check_scanner_status_bataan` endpoint + routing

**Files:**
- Modify: `backend/_external_lambdas/UniversalLGU-MainPost/endpoints/scanner_auth_bataan.py`
- Modify: `backend/_external_lambdas/UniversalLGU-MainPost/lambda_function.py:360` (right after the existing `check_app_version_scanner_bataan` ROUTES line)
- Test: `backend/_external_lambdas/UniversalLGU-MainPost/tests/test_scanner_auth_bataan.py`

**Interfaces:**
- Produces: action name `check_scanner_status_bataan`, request field `user_profile_id` (string/int, the `ScannerUser.id` the app already has from login), response `{'status': True, 'is_valid': bool}` on any resolvable outcome (including "user not found" and "inactive/deactivated" — those are `is_valid: false`, NOT an HTTP/`fail()` error). Only `require()`'s `ValueError` (missing `user_profile_id`) or an unexpected exception use `fail()`.

- [ ] **Step 1: Write the failing tests**

Append to `backend/_external_lambdas/UniversalLGU-MainPost/tests/test_scanner_auth_bataan.py`:

```python
from endpoints.scanner_auth_bataan import check_scanner_status_bataan


class CheckScannerStatusBataanTest(unittest.TestCase):
    def _cur(self, fetchone_return):
        cur = MagicMock()
        cur.fetchone.return_value = fetchone_return
        return cur

    def test_missing_user_profile_id_returns_400(self):
        cur = self._cur(None)
        result = check_scanner_status_bataan(cur, {}, [], '2026-09-09 00:00:00')
        self.assertEqual(result['statusCode'], 400)

    def test_active_and_not_deactivated_is_valid(self):
        cur = self._cur({'is_active': 1, 'user_status': 'VERIFIED'})
        result = check_scanner_status_bataan(
            cur, {'user_profile_id': '7'}, [], '2026-09-09 00:00:00')
        self.assertEqual(result['statusCode'], 200)
        body = json.loads(result['body'])
        self.assertTrue(body['status'])
        self.assertTrue(body['is_valid'])

    def test_inactive_and_not_deactivated_is_invalid(self):
        cur = self._cur({'is_active': 0, 'user_status': 'VERIFIED'})
        result = check_scanner_status_bataan(
            cur, {'user_profile_id': '7'}, [], '2026-09-09 00:00:00')
        self.assertEqual(result['statusCode'], 200)
        body = json.loads(result['body'])
        self.assertTrue(body['status'])
        self.assertFalse(body['is_valid'])

    def test_active_and_deactivated_is_invalid(self):
        cur = self._cur({'is_active': 1, 'user_status': 'DEACTIVATED'})
        result = check_scanner_status_bataan(
            cur, {'user_profile_id': '7'}, [], '2026-09-09 00:00:00')
        body = json.loads(result['body'])
        self.assertTrue(body['status'])
        self.assertFalse(body['is_valid'])

    def test_inactive_and_deactivated_is_invalid(self):
        cur = self._cur({'is_active': 0, 'user_status': 'DEACTIVATED'})
        result = check_scanner_status_bataan(
            cur, {'user_profile_id': '7'}, [], '2026-09-09 00:00:00')
        body = json.loads(result['body'])
        self.assertTrue(body['status'])
        self.assertFalse(body['is_valid'])

    def test_user_not_found_is_invalid_not_an_error(self):
        cur = self._cur(None)
        result = check_scanner_status_bataan(
            cur, {'user_profile_id': '999'}, [], '2026-09-09 00:00:00')
        self.assertEqual(result['statusCode'], 200)
        body = json.loads(result['body'])
        self.assertTrue(body['status'])
        self.assertFalse(body['is_valid'])

    def test_queries_by_the_given_user_profile_id(self):
        cur = self._cur({'is_active': 1, 'user_status': 'VERIFIED'})
        check_scanner_status_bataan(
            cur, {'user_profile_id': '7'}, [], '2026-09-09 00:00:00')
        args, _ = cur.execute.call_args
        params = args[1]
        self.assertIn('7', params)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend/_external_lambdas/UniversalLGU-MainPost && python -m pytest tests/test_scanner_auth_bataan.py -v`
Expected: the 7 new tests FAIL with `ImportError`/`AttributeError` (`check_scanner_status_bataan` does not exist yet); the existing `LoginScannerBataanTest`/`HashScannerPasswordTest` tests still pass.

- [ ] **Step 3: Implement `check_scanner_status_bataan`**

Add to `backend/_external_lambdas/UniversalLGU-MainPost/endpoints/scanner_auth_bataan.py` (after `login_scanner_bataan`):

```python
def check_scanner_status_bataan(cur, data, files, ts):
    """Revalidates an existing scanner-app session against the current
    app_users_scanner row. Backs the app's auto-login/Remember Me flow so
    a cached local session can never grant access after an admin
    deactivates the account -- the app must call this on every launch and
    treat only `is_valid: true` as permission to enter.

    Always responds 200 with `is_valid` (including when no matching row
    exists, or the account is inactive/deactivated) -- callers must NOT
    treat `is_valid: false` as a network/server error, only as "this
    account may no longer access the app". The `fail()` path here is
    reserved for a missing `user_profile_id` or an unexpected server
    error, both of which the caller should treat as a revalidation
    failure distinct from a confirmed rejection (fail closed, but don't
    show 'Account Inactive' for those)."""
    try:
        require(data, 'user_profile_id')
        user_profile_id = sanitize(data['user_profile_id'])

        cur.execute(
            "SELECT is_active, user_status FROM app_users_scanner WHERE id=%s LIMIT 1",
            (user_profile_id,),
        )
        row = cur.fetchone()
        if not row:
            return ok({'status': True, 'is_valid': False})

        is_active = row['is_active'] if isinstance(row, dict) else row[0]
        user_status = row['user_status'] if isinstance(row, dict) else row[1]
        is_valid = bool(is_active) and (user_status or '').strip() != 'DEACTIVATED'
        return ok({'status': True, 'is_valid': is_valid})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f"check_scanner_status_bataan error: {e}", exc_info=True)
        return fail('Server error', 500)
```

Add the route in `backend/_external_lambdas/UniversalLGU-MainPost/lambda_function.py` right after the existing scanner lines (find `'check_app_version_scanner_bataan': scanner_auth_bataan.check_app_version_scanner_bataan,` at line 360):

```python
    'login_scanner_bataan': scanner_auth_bataan.login_scanner_bataan,
    'check_app_version_scanner_bataan': scanner_auth_bataan.check_app_version_scanner_bataan,
    'check_scanner_status_bataan': scanner_auth_bataan.check_scanner_status_bataan,
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend/_external_lambdas/UniversalLGU-MainPost && python -m pytest -q`
Expected: all tests pass (existing 79 + 7 new = 86).

- [ ] **Step 5: Commit**

```bash
git add backend/_external_lambdas/UniversalLGU-MainPost/endpoints/scanner_auth_bataan.py backend/_external_lambdas/UniversalLGU-MainPost/lambda_function.py backend/_external_lambdas/UniversalLGU-MainPost/tests/test_scanner_auth_bataan.py
git commit -m "feat(backend): add check_scanner_status_bataan for scanner session revalidation"
```

---

### Task 2: Flutter — remote datasource + repository revalidation

**Files:**
- Modify: `lib/features/auth/domain/repositories/auth_repository.dart`
- Modify: `lib/features/auth/data/datasources/auth_remote_datasource.dart`
- Modify: `lib/features/auth/data/repositories/auth_repository_impl.dart`
- Test: `test/features/auth/data/repositories/auth_repository_impl_test.dart`

**Interfaces:**
- Consumes: `ApiClient.post(String endpoint, Map<String, dynamic> fields)` (`lib/core/network/api_client.dart`) — throws `ApiException` on network/server/non-200/decode failure, returns decoded JSON otherwise. `ScannerUser.id` (`int`).
- Produces: `AuthRemoteDatasource.checkStatus({required int userId}) -> Future<Map<String, dynamic>>` (raw decoded JSON with an `is_valid` bool key). `AccountInactiveException` (new, in `auth_repository.dart` alongside `AuthException`) — thrown by `AuthRepositoryImpl.restoreSession()` only when the backend confirms `is_valid: false`. `AuthRepositoryImpl.restoreSession()` keeps its existing signature `Future<ScannerUser?> restoreSession()`; on a network/server failure during revalidation it throws the existing `AuthException` (message: `'Network error — could not reach the server.'` or the wrapped `ApiException` message), leaving the cached session untouched.

- [ ] **Step 1: Write the failing tests**

Replace the `AuthRepositoryImpl.restoreSession` group in `test/features/auth/data/repositories/auth_repository_impl_test.dart` (the fake datasource also needs a `checkStatus` override — add it alongside the existing `login` override):

```dart
class _FakeAuthRemoteDatasource extends AuthRemoteDatasource {
  _FakeAuthRemoteDatasource({
    this.response,
    this.error,
    this.checkStatusResponse,
    this.checkStatusError,
  }) : super(ApiClient());
  final Map<String, dynamic>? response;
  final Object? error;
  final Map<String, dynamic>? checkStatusResponse;
  final Object? checkStatusError;
  int? lastCheckedUserId;

  @override
  Future<Map<String, dynamic>> login({required String username, required String password}) async {
    if (error != null) throw error!;
    return response!;
  }

  @override
  Future<Map<String, dynamic>> checkStatus({required int userId}) async {
    lastCheckedUserId = userId;
    if (checkStatusError != null) throw checkStatusError!;
    return checkStatusResponse!;
  }
}
```

(keep `_FakeAuthLocalDatasource` and the `login`/`logout` groups exactly as they are)

Replace the `AuthRepositoryImpl.restoreSession` group with:

```dart
  group('AuthRepositoryImpl.restoreSession', () {
    test('returns null when nothing is cached', () async {
      final repo = AuthRepositoryImpl(
        _FakeAuthRemoteDatasource(checkStatusResponse: const {'status': true, 'is_valid': true}),
        _FakeAuthLocalDatasource(),
      );

      expect(await repo.restoreSession(), isNull);
    });

    test('revalidates with the backend and returns the cached ScannerUser when still valid', () async {
      final local = _FakeAuthLocalDatasource();
      local.stored = {
        'id': 7, 'username': 'staff1', 'user_status': 'VERIFIED',
        'firstname': 'Juan', 'middlename': '', 'lastname': 'Dela Cruz', 'suffix': '',
      };
      final remote = _FakeAuthRemoteDatasource(
        checkStatusResponse: const {'status': true, 'is_valid': true},
      );
      final repo = AuthRepositoryImpl(remote, local);

      final user = await repo.restoreSession();

      expect(user, isNotNull);
      expect(user!.username, 'staff1');
      expect(remote.lastCheckedUserId, 7);
      expect(local.stored, isNotNull);
    });

    test('clears the cached session and throws AccountInactiveException when the backend rejects it', () async {
      final local = _FakeAuthLocalDatasource();
      local.stored = {
        'id': 7, 'username': 'staff1', 'user_status': 'VERIFIED',
        'firstname': 'Juan', 'middlename': '', 'lastname': 'Dela Cruz', 'suffix': '',
      };
      final repo = AuthRepositoryImpl(
        _FakeAuthRemoteDatasource(checkStatusResponse: const {'status': true, 'is_valid': false}),
        local,
      );

      expect(repo.restoreSession(), throwsA(isA<AccountInactiveException>()));
      await Future<void>.delayed(Duration.zero);
      expect(local.stored, isNull);
    });

    test('does not clear the cached session and throws AuthException on a network/server failure', () async {
      final local = _FakeAuthLocalDatasource();
      local.stored = {
        'id': 7, 'username': 'staff1', 'user_status': 'VERIFIED',
        'firstname': 'Juan', 'middlename': '', 'lastname': 'Dela Cruz', 'suffix': '',
      };
      final repo = AuthRepositoryImpl(
        _FakeAuthRemoteDatasource(checkStatusError: ApiException('Server error')),
        local,
      );

      expect(repo.restoreSession(), throwsA(isA<AuthException>()));
      await Future<void>.delayed(Duration.zero);
      expect(local.stored, isNotNull);
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/auth/data/repositories/auth_repository_impl_test.dart`
Expected: FAIL to compile (`checkStatus` doesn't exist on `AuthRemoteDatasource`, `AccountInactiveException` doesn't exist).

- [ ] **Step 3: Implement**

In `lib/features/auth/domain/repositories/auth_repository.dart`, update the doc comment and add the new exception:

```dart
import '../entities/scanner_user.dart';

abstract class AuthRepository {
  /// Authenticates against `login_scanner_bataan`. Throws
  /// [AuthException] with a human-readable reason on invalid credentials,
  /// a deactivated account, or a network failure.
  ///
  /// The session is persisted locally only when [rememberMe] is true, so
  /// the app auto-logs-in on the next launch only if the user opted in.
  Future<ScannerUser> login({
    required String username,
    required String password,
    required bool rememberMe,
  });

  /// Returns the locally cached session after revalidating it against the
  /// backend's current `is_active`/`user_status` for that account — never
  /// trusts the cached JSON by itself. Returns null if nothing is cached.
  ///
  /// Throws [AccountInactiveException] (and clears the cached session)
  /// when the backend confirms the account is no longer
  /// active/deactivated. Throws [AuthException] on a network/server
  /// failure during revalidation — the cached session is left untouched
  /// so a later retry with connectivity can still succeed.
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

/// Thrown by [AuthRepository.restoreSession] when the backend confirms
/// the cached account is no longer allowed to access the app
/// (`is_active = 0` or `user_status = 'DEACTIVATED'`). [message] is
/// user-safe (no DB/technical detail) and meant to be shown directly.
class AccountInactiveException implements Exception {
  AccountInactiveException(this.message);
  final String message;
  @override
  String toString() => message;
}
```

In `lib/features/auth/data/datasources/auth_remote_datasource.dart`, add the new method:

```dart
import '../../../../core/network/api_client.dart';

/// Talks to the scanner-staff login/session endpoints. Returns raw
/// decoded JSON — mapping to [ScannerUser] or interpreting `is_valid`
/// happens in AuthRepositoryImpl.
class AuthRemoteDatasource {
  AuthRemoteDatasource(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> login({required String username, required String password}) {
    return _apiClient.post('login_scanner_bataan', {'username': username, 'password': password});
  }

  /// Revalidates an existing session's account against
  /// `check_scanner_status_bataan`. The response always carries
  /// `is_valid` on success (200) — a thrown [ApiException] here means the
  /// backend couldn't be reached/errored, not that the account is
  /// inactive.
  Future<Map<String, dynamic>> checkStatus({required int userId}) {
    return _apiClient.post('check_scanner_status_bataan', {'user_profile_id': userId.toString()});
  }
}
```

In `lib/features/auth/data/repositories/auth_repository_impl.dart`, implement revalidation:

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
  Future<ScannerUser> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    try {
      final json = await _remote.login(username: username, password: password);
      final data = json['data'] as Map<String, dynamic>? ?? {};
      final user = ScannerUser.fromJson(data);
      if (rememberMe) {
        await _local.saveSession(data);
      } else {
        // Wipe any previously-remembered session so a stale one can't
        // auto-login next launch.
        await _local.clearSession();
      }
      return user;
    } on ApiException catch (e) {
      throw AuthException(e.message);
    } catch (_) {
      throw AuthException('Network error — could not reach the server.');
    }
  }

  @override
  Future<ScannerUser?> restoreSession() async {
    final json = await _local.getSession();
    if (json == null) return null;
    final user = ScannerUser.fromJson(json);

    final Map<String, dynamic> response;
    try {
      response = await _remote.checkStatus(userId: user.id);
    } on ApiException catch (e) {
      throw AuthException(e.message);
    } catch (_) {
      throw AuthException('Network error — could not reach the server.');
    }

    final isValid = response['is_valid'] == true;
    if (!isValid) {
      await _local.clearSession();
      throw AccountInactiveException(
        'Your account is no longer active. Please contact your administrator for assistance.',
      );
    }
    return user;
  }

  @override
  Future<void> logout() => _local.clearSession();
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/auth/data/repositories/auth_repository_impl_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/domain/repositories/auth_repository.dart lib/features/auth/data/datasources/auth_remote_datasource.dart lib/features/auth/data/repositories/auth_repository_impl.dart test/features/auth/data/repositories/auth_repository_impl_test.dart
git commit -m "feat(scanner-auth): revalidate cached session against backend before auto-login"
```

---

### Task 3: Flutter — bloc state/status handling

**Files:**
- Modify: `lib/features/auth/presentation/bloc/auth_state.dart`
- Modify: `lib/features/auth/presentation/bloc/auth_bloc.dart`
- Test: `test/features/auth/presentation/bloc/auth_bloc_test.dart`

**Interfaces:**
- Consumes: `AccountInactiveException`, `AuthException` (Task 2, `auth_repository.dart`).
- Produces: `AuthStatus.accountInactive` (new enum value on `AuthState`, `auth_state.dart`) — `AuthState(status: AuthStatus.accountInactive, errorMessage: <user-safe message>)`. Consumed by `AuthGate` in Task 4.

- [ ] **Step 1: Write the failing tests**

In `test/features/auth/presentation/bloc/auth_bloc_test.dart`, update `_FakeAuthRepository` to allow throwing on `restoreSession` (already supports `restoreSessionError`, no change needed there — it already does `if (restoreSessionError != null) throw restoreSessionError!;`). Add these tests after the existing `'AppStarted emits unauthenticated when restoreSession throws'` test:

```dart
  test('AppStarted emits accountInactive with the message and clears the session '
      'when restoreSession throws AccountInactiveException', () async {
    repository.restoreSessionError = AccountInactiveException(
      'Your account is no longer active. Please contact your administrator for assistance.',
    );
    final states = <AuthState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const AppStarted());
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(states, [
      const AuthState(
        status: AuthStatus.accountInactive,
        errorMessage: 'Your account is no longer active. Please contact your administrator for assistance.',
      ),
    ]);
    expect(repository.loggedOut, isTrue);
  });

  test('AppStarted emits unauthenticated without logging out when restoreSession '
      'throws AuthException (network/server failure)', () async {
    repository.restoreSessionError = AuthException('Server error');
    final states = <AuthState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const AppStarted());
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(states, [const AuthState(status: AuthStatus.unauthenticated)]);
    expect(repository.loggedOut, isFalse);
  });
```

Add the missing import at the top of the file: `import 'package:bataan_lgu_scanner/features/auth/domain/repositories/auth_repository.dart';` — check first, `AuthException`/`AccountInactiveException` live there and the file already imports `auth_repository.dart` for the `AuthRepository` interface, so just reference `AccountInactiveException`/`AuthException` directly, no new import needed.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/auth/presentation/bloc/auth_bloc_test.dart`
Expected: FAIL to compile (`AccountInactiveException` unknown, `AuthStatus.accountInactive` unknown) — since Task 2 already added `AccountInactiveException`, only the enum value is actually missing at this point; the two new tests fail on the missing enum value / wrong emitted status.

- [ ] **Step 3: Implement**

In `lib/features/auth/presentation/bloc/auth_state.dart`, add the enum value:

```dart
enum AuthStatus { unknown, loading, authenticated, unauthenticated, accountInactive, error }
```

(rest of the file unchanged)

In `lib/features/auth/presentation/bloc/auth_bloc.dart`, update the import and `_onAppStarted`:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/auth_repository.dart';
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
    try {
      final user = await _restoreSession();
      if (user != null) {
        emit(state.copyWith(status: AuthStatus.authenticated, user: user));
      } else {
        emit(state.copyWith(status: AuthStatus.unauthenticated));
      }
    } on AccountInactiveException catch (e) {
      // The repository already cleared the cached session on a confirmed
      // rejection; clear again here too so a bug in that layer can never
      // leave a stale session behind for the app to keep retrying.
      await _logout();
      emit(AuthState(status: AuthStatus.accountInactive, errorMessage: e.message));
    } on AuthException {
      // Revalidation couldn't reach the backend (offline/timeout/server
      // error). Fail closed -- don't authenticate off a stale cached
      // session -- but this is NOT a confirmed deactivation, so don't
      // show that dialog and don't wipe the cache; a later retry with
      // connectivity can still succeed.
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    } catch (_) {
      // Locally cached session was corrupted/unparseable.
      await _logout();
      emit(const AuthState(status: AuthStatus.unauthenticated));
    }
  }

  Future<void> _onLoginRequested(LoginRequested event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final user = await _login(
        username: event.username,
        password: event.password,
        rememberMe: event.rememberMe,
      );
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

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/auth/presentation/bloc/auth_bloc_test.dart`
Expected: PASS (all 8 tests, including the 2 new ones).

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/presentation/bloc/auth_state.dart lib/features/auth/presentation/bloc/auth_bloc.dart test/features/auth/presentation/bloc/auth_bloc_test.dart
git commit -m "feat(scanner-auth): add accountInactive auth status distinct from network failure"
```

---

### Task 4: Flutter — Account Inactive dialog in AuthGate

**Files:**
- Modify: `lib/features/auth/presentation/pages/auth_gate.dart`

**Interfaces:**
- Consumes: `AuthStatus.accountInactive` (Task 3), `showMessageDialog` (`lib/core/widgets/confirm_dialog.dart`, existing: `Future<void> showMessageDialog(BuildContext context, {required String title, required String message, String buttonLabel = 'OK'})`).

- [ ] **Step 1: Implement**

In `lib/features/auth/presentation/pages/auth_gate.dart`, add the import and swap the final `BlocBuilder` for a `BlocConsumer` that shows the dialog once on entering `accountInactive`, then routes it (like `unauthenticated`/`error`) to `LoginPage`:

Add near the other imports:

```dart
import '../../../../core/widgets/confirm_dialog.dart';
```

Replace the closing `BlocBuilder<AuthBloc, AuthState>` block in `build()`:

```dart
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          current.status == AuthStatus.accountInactive &&
          previous.status != AuthStatus.accountInactive,
      listener: (context, state) {
        showMessageDialog(
          context,
          title: 'Account Inactive',
          message: state.errorMessage ??
              'Your account is no longer active. Please contact your administrator for assistance.',
        );
      },
      builder: (context, state) {
        switch (state.status) {
          case AuthStatus.authenticated:
            return const DashboardPage();
          case AuthStatus.unknown:
          case AuthStatus.loading:
            return const SplashPage();
          case AuthStatus.unauthenticated:
          case AuthStatus.error:
          case AuthStatus.accountInactive:
            return const LoginPage();
        }
      },
    );
```

- [ ] **Step 2: Verify no analyzer errors**

Run: `flutter analyze lib/features/auth`
Expected: No issues found.

- [ ] **Step 3: Manual verification (see Task 5 for the full 4-combination + transition test)**

- [ ] **Step 4: Commit**

```bash
git add lib/features/auth/presentation/pages/auth_gate.dart
git commit -m "feat(scanner-auth): show Account Inactive dialog when auto-login is rejected"
```

---

### Task 5: Full verification pass

**Files:** none (verification only)

- [ ] **Step 1: Run the full Flutter test suite**

Run: `flutter test`
Expected: all tests pass, no regressions in unrelated features (CVL, QR, dashboard, etc.).

- [ ] **Step 2: Run `flutter analyze`**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 3: Run the full backend test suite**

Run: `cd backend/_external_lambdas/UniversalLGU-MainPost && python -m pytest -q`
Expected: all tests pass (86/86 — see Task 1).

- [ ] **Step 4: Manually verify the 4 account-state combinations against the mocked/fake layers**

Confirmed by the unit tests in Tasks 1–3:
- `is_active=1, user_status!=DEACTIVATED` → `check_scanner_status_bataan` returns `is_valid: true` → `restoreSession()` returns the user → bloc emits `authenticated`, no dialog.
- `is_active=0, user_status!=DEACTIVATED` → `is_valid: false` → `AccountInactiveException` → session cleared → bloc emits `accountInactive` → dialog shown → `LoginPage`.
- `is_active=1, user_status=DEACTIVATED` → same as above.
- `is_active=0, user_status=DEACTIVATED` → same as above.

- [ ] **Step 5: Note backend deployment requirement**

`check_scanner_status_bataan` must be deployed to the live `UniversalLGU-MainPost` Lambda (pull-live/merge-diff/deploy method, per `backend/_external_lambdas/UniversalLGU-MainPost/SNAPSHOT.md`) before the app's new auto-login revalidation call will work in production — the Flutter app change is otherwise complete but calling a route that doesn't exist live yet. Deploying is a separate, explicit step (not part of this plan) since it touches the shared production Lambda — confirm with the user before running `aws lambda update-function-code`.

- [ ] **Step 6: Final commit if any stragglers**

```bash
git status
```

If clean, nothing further to commit — Tasks 1–4 already committed the real changes.
