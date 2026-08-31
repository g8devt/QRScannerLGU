# Configuration

All runtime configuration lives in `lib/core/config/app_config.dart` and is
resolved via `String.fromEnvironment`, so it's set at **build time**, not
via a `.env` file or runtime settings screen.

| Setting | Dart-define key | Default | Notes |
|---|---|---|---|
| Backend base URL | `API_BASE_URL` | `https://h9yltujhgi.execute-api.ap-southeast-1.amazonaws.com/Prod/main` | API Gateway `/main` route (Prod stage) in front of the shared `UniversalLGU-MainPost` Lambda |
| Staff/app token | `STAFF_TOKEN` | `1234567890123universal_lgu_app_token_2025` | Sent as `token` on every request. The backend's `check_token` strips the first 13 characters before comparing against `app_user_operations_tbl` — the stripped suffix (`universal_lgu_app_token_2025`) is the value that must match a live row. This is a fixed app-level gate, distinct from per-staff username/password login. |
| Tenant database | (hardcoded) | `bataan_db` | Sent as `db_name` on every request; not overridable via dart-define |
| App version | (runtime) | — | Read from platform package metadata via `package_info_plus` in `AppConfig.initPackageInfo()`, called once in `main()` before the UI reads `AppConfig.appVersion` |

## Overriding at build/run time

```bash
flutter run --dart-define=API_BASE_URL=https://staging.example.com/main --dart-define=STAFF_TOKEN=some-other-token
```

<!-- VERIFY: Confirm with the backend owner whether a staging/non-prod
deployment of UniversalLGU-MainPost actually exists before pointing a build
at a URL other than the documented production default. -->

## App version gate (`app_version` table)

The backend's `check_app_version_scanner_bataan` endpoint (see
[API.md](API.md#app-update-gate)) reads the latest `ACTIVE` row from the
`app_version` table for `app_code='SCANNER'` per `os_type`. This is server-
side configuration, not app-side — bumping the minimum required version is
done by inserting/activating a row in that table, not by changing app code.

## Android/iOS/Windows platform config

Standard Flutter platform folders (`android/`, `ios/`, `windows/`, etc.)
carry platform-specific settings (app id, permissions, signing). No
project-specific environment files were found beyond the dart-defines above.
