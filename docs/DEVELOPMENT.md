# Development

## Project layout

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full layering explanation.
Quick map:

```
lib/
  core/         # ApiClient, AppConfig, theme, shared widgets, constants
  features/     # One folder per vertical feature (data/domain/presentation)
  main.dart     # Manual DI wiring + MultiBlocProvider + MaterialApp
backend/
  _external_lambdas/   # Read-only mirror of the AWS Lambda source (see each
                        # Lambda's SNAPSHOT.md for deploy/drift history)
  database/             # bataan_db.sql schema dump + migrations/
test/           # Mirrors lib/ structure
docs/           # This documentation
```

## Adding a feature

Follow the existing pattern under `lib/features/<name>/`:
1. `domain/entities` — plain value objects (extend `Equatable`)
2. `domain/repositories` — abstract interface
3. `domain/usecases` — one class per use case, thin wrapper calling the repo
4. `data/datasources` — talks to `ApiClient` (or local storage)
5. `data/repositories` — implements the domain interface, maps JSON <-> entities
6. `presentation/bloc` — `Bloc` or `Cubit` driving the UI
7. `presentation/pages` / `presentation/widgets` — UI

Wire the new dependencies by hand in `lib/main.dart`, following the existing
construction order (datasource → repository → usecases → Bloc/Cubit →
`MultiBlocProvider`).

## Backend changes

This app's backend lives outside this repo (a shared multi-tenant Lambda).
`backend/_external_lambdas/` is a **read-only reference mirror**, not a
deployable source — do not assume editing it deploys anything. Each Lambda
directory's `SNAPSHOT.md` documents the manual pull/diff/deploy process used
to keep the mirror in sync with the live function. If you need to change
backend behavior, coordinate with whoever owns that deploy process (see
`SNAPSHOT.md` for the account/region and verification steps).

## Linting

```bash
flutter analyze
```

Uses `package:flutter_lints/flutter.yaml` (see `analysis_options.yaml`) with
no project-specific rule overrides currently enabled.

## Formatting

```bash
dart format .
```

## Building

```bash
flutter build apk        # Android
flutter build ios        # iOS
flutter build windows    # Windows
```

App icon generation (from `assets/logo/app_launcher.png`) is configured via
`flutter_launcher_icons` in `pubspec.yaml`:

```bash
dart run flutter_launcher_icons
```
