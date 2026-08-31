# Bataan LGU Scanner

A Flutter app for Bataan LGU field staff to scan QR codes on CVL
(Community Vulnerability List) records and Kabaka Cards, look up and edit
CVL records, and process social-service claim verification/capture
(ID photo, signature, face photo). It is a thin client over a shared,
multi-tenant AWS Lambda backend.

## Documentation

- [Getting Started](docs/GETTING-STARTED.md) — install, run, first login
- [Architecture](docs/ARCHITECTURE.md) — layering, features, state management
- [API Reference](docs/API.md) — backend endpoints this app calls
- [Configuration](docs/CONFIGURATION.md) — build-time settings (backend URL, tokens)
- [Development](docs/DEVELOPMENT.md) — workflow, linting, building
- [Testing](docs/TESTING.md) — running and writing tests

## Quick start

```bash
flutter pub get
flutter run
```

See [docs/GETTING-STARTED.md](docs/GETTING-STARTED.md) for prerequisites and
login requirements.
