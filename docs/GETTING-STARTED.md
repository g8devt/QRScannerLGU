# Getting Started

## Prerequisites

- Flutter SDK matching `environment.sdk: ^3.10.7` in `pubspec.yaml`
- A configured platform toolchain for whichever target you're building
  (Android Studio/SDK for Android, Xcode for iOS/macOS, or Visual Studio for
  Windows)

## Install dependencies

```bash
flutter pub get
```

## Run the app

```bash
flutter run
```

Pick a connected device/emulator when prompted. By default the app points at
the live production backend (`AppConfig.apiBaseUrl` in
`lib/core/config/app_config.dart`) — see [CONFIGURATION.md](CONFIGURATION.md)
to point it elsewhere.

## Logging in

The app requires:
1. A passing app-version check (`check_app_version_scanner_bataan`) — see
   [API.md](API.md#app-update-gate).
2. Valid scanner-staff credentials (`app_users_scanner` row) — this app does
   not self-register staff; accounts are provisioned on the backend/admin
   side.

## Where to go next

- [ARCHITECTURE.md](ARCHITECTURE.md) — how the codebase is organized
- [API.md](API.md) — every backend endpoint this app calls
- [DEVELOPMENT.md](DEVELOPMENT.md) — day-to-day workflow, lint rules
- [TESTING.md](TESTING.md) — running and writing tests
- [CONFIGURATION.md](CONFIGURATION.md) — build-time configuration
