# Testing

## Running tests

```bash
flutter test
```

Run a single file:

```bash
flutter test test/features/auth/presentation/bloc/auth_bloc_test.dart
```

## Structure

`test/` mirrors `lib/`'s feature-first layout:

```
test/
  core/
    theme/app_theme_test.dart
    widgets/confirm_dialog_test.dart
    widgets/info_card_test.dart
  features/
    auth/
      data/repositories/auth_repository_impl_test.dart
      domain/entities/scanner_user_test.dart
      presentation/bloc/auth_bloc_test.dart
    cvl_lookup/
      cvl_edit_page_gender_test.dart
      cvl_filter_sheet_cascade_test.dart
      cvl_lookup_cubit_shared_state_test.dart
      cvl_search_page_dispose_test.dart
  widget_test.dart
```

Coverage today is concentrated on `auth` (repository, entity, Bloc) and
`cvl_lookup` (cubit/widget behavior) — other features (`qr_scanner`,
`social_service_claim`, `dashboard`, `app_update`) do not yet have dedicated
tests.

## Conventions

- Bloc/Cubit tests use `flutter_test`'s standard widget/unit test APIs
  (no `bloc_test` package dependency — check an individual test file for the
  exact pattern before adding a new one).
- Repository tests fake the remote datasource rather than hitting the real
  backend — there is no live-network test suite for `ApiClient` itself.
- When adding a new use case or repository method, add a corresponding unit
  test in the mirrored `test/` path rather than only relying on manual
  device testing.
