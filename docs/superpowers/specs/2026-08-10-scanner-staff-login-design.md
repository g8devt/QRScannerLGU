# Scanner-staff login (username/password)

## Context

`bataan_lgu_scanner` is a single-purpose LGU-staff scanner app. Today it has
no login: [`AppConfig`](../../../lib/core/config/app_config.dart) sends a
hardcoded `staffToken` on every request, and `main.dart` opens straight into
`ScannerPage`. This spec adds real per-staff authentication (username +
password) in front of the scanner, backed by a new table and endpoint.

The app calls the `UniversalLGU-MainPost` Lambda (API Gateway `/main` route)
for everything — this feature is added there, not in the separate
`UniversalLGU-LoginPost` Lambda used by the citizen-facing app.

## Backend

### Table: `app_users_scanner`

New migration `backend/database/migrations/032_app_users_scanner.sql`, run
manually against `bataan_db` (no migration runner exists in this repo),
following `app_users`'s column conventions:

```sql
-- Migration 032: Scanner-staff accounts for the bataan_lgu_scanner app's
-- login_scanner_bataan endpoint. Separate from app_users (citizen accounts) —
-- staff log in with username/password, not mobile+PIN.

CREATE TABLE app_users_scanner (
  id            BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_status   ENUM('VERIFIED','PENDING','NOT_VERIFIED','DEACTIVATED')
                  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
                  NOT NULL DEFAULT 'PENDING',
  username      VARCHAR(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  password      VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL, -- SHA-256 hex, static salt
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

`date_created`/`date_modified` are added beyond the originally-listed columns
for consistency with every other table in this schema (and for basic
auditability); `username` gets a UNIQUE constraint since login looks it up
directly. No account-creation endpoint is in scope — rows are inserted
directly for now.

### Endpoint: `login_scanner_bataan`

New file `endpoints/scanner_auth.py`, registered in `UniversalLGU-MainPost`'s
`lambda_function.py` `ROUTES` dict (signature `(cur, data, files, ts)` like
every other endpoint in that file — it rides the existing app-level
`token`/`db_name` envelope check, no `NO_TOKEN_ENDPOINTS` bypass needed).

- **Request:** `{ endpoint: 'login_scanner_bataan', token, db_name, username, password }`
- **Behavior:**
  1. `require(data, 'username', 'password')`.
  2. Normalize username: `sanitize(data['username']).lower()`.
  3. Hash the password with a new `hash_scanner_password()` helper
     (`helpers/scanner_auth.py`), mirroring `helpers/pin.py`'s static-salt
     SHA-256 pattern but with its own distinct salt constant (separate
     credential domain from the citizen PIN hash).
  4. `SELECT * FROM app_users_scanner WHERE username=%s AND password=%s
     AND is_active=1 AND user_status != 'DEACTIVATED'`.
  5. No match → `{status: False, message: 'Invalid Credential'}` (HTTP 200,
     same convention as `ep_login`).
  6. Match → `{status: True, message: 'Login Successfully', user_profile_id,
     username, user_status, data: {...row, password removed...}}`.

## Frontend (Flutter)

New feature slice `lib/features/auth/`, matching the existing clean
architecture + bloc structure used by `qr_scanner`/`social_service_claim`:

```
lib/features/auth/
  domain/entities/scanner_user.dart
  domain/repositories/auth_repository.dart
  domain/usecases/login_usecase.dart
  domain/usecases/logout_usecase.dart
  data/datasources/auth_remote_datasource.dart   -- calls apiClient.post('login_scanner_bataan', {...})
  data/datasources/auth_local_datasource.dart     -- shared_preferences read/write of cached session
  data/repositories/auth_repository_impl.dart
  presentation/bloc/auth_bloc.dart
  presentation/bloc/auth_event.dart
  presentation/bloc/auth_state.dart
  presentation/pages/login_page.dart
```

- **`AuthBloc` states:** `AuthInitial` (checking local session on startup),
  `AuthLoading`, `AuthAuthenticated(ScannerUser user)`, `AuthUnauthenticated`,
  `AuthError(String message)`.
- **`login_page.dart`:** username + password `TextFormField`s (password
  obscured, visibility toggle), a login button (disabled while loading, shows
  a spinner), inline error text below the form on failure.
- **Session persistence:** add `shared_preferences` to `pubspec.yaml`. On
  successful login, cache the returned user JSON. On app start, `AuthBloc`
  checks local storage first — if present, emits `AuthAuthenticated`
  immediately and the login page is skipped.
- **Wiring in `main.dart`:** replace `home: const ScannerPage()` with a small
  gate widget doing `BlocBuilder<AuthBloc, AuthState>` → `LoginPage` when
  `AuthUnauthenticated`/`AuthError`, a loading spinner on `AuthInitial`, and
  `ScannerPage` on `AuthAuthenticated`.
- **Logout:** `ScannerPage` has no `AppBar` today (full-screen camera view).
  Add a small logout icon button overlaid in a corner alongside the existing
  overlay widgets (`info_banner.dart`/`scanner_overlay.dart`), dispatching a
  logout event that clears local storage and returns to `LoginPage`.

## Error handling

- Invalid credentials / deactivated account → inline error text on the login
  page, sourced from the existing `ApiException` thrown by `ApiClient`.
- Network/timeout errors → same `ApiException` surface, shown inline with a
  retry-friendly message.

## Testing

- `AuthBloc` unit tests: successful login, invalid credentials, deactivated
  account, network error, and "restores session from local storage on
  startup" — following whatever test conventions `ScannerBloc`/`ClaimBloc`
  already use in this repo.
