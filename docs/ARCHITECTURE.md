# Architecture

Bataan LGU Scanner is a Flutter app used by LGU field staff to scan QR codes on
Kabaka Cards / CVL (Community Vulnerability List) records, verify social-service
claims, and capture claim documentation (ID, signature, face photo). It talks to
a single shared multi-tenant AWS Lambda backend over HTTP.

## Layering (Clean Architecture per feature)

Each folder under `lib/features/` is a self-contained vertical slice with three
layers:

```
lib/features/<feature>/
├── data/
│   ├── datasources/   # Talks to ApiClient (remote) or shared_preferences (local)
│   └── repositories/  # Implements the domain repository interface, maps
│                       # raw JSON <-> domain entities
├── domain/
│   ├── entities/       # Plain Dart value objects (Equatable)
│   ├── repositories/    # Abstract repository interfaces
│   └── usecases/       # One class per use case, calls into a repository
└── presentation/
    ├── bloc/            # flutter_bloc Bloc/Cubit + events/states
    ├── pages/           # Full-screen widgets
    └── widgets/         # Reusable feature-local widgets
```

Dependencies point inward: `presentation -> domain <- data`. Domain never
imports `data` or `presentation`. There is no DI framework — every dependency
(`ApiClient`, datasources, repositories, use cases, Blocs) is constructed and
wired by hand in `lib/main.dart`, then handed to `MultiBlocProvider`.

## Features

| Feature | Purpose |
|---|---|
| `auth` | Scanner-staff username/password login, session persistence (`shared_preferences`), logout |
| `app_update` | Mandatory pre-login version-gate check against the backend |
| `splash` | Initial loading screen while session/app-update checks run |
| `qr_scanner` | Camera-based QR scanning (`mobile_scanner`) and gallery image picking, used by both CVL and claim flows |
| `cvl_lookup` | Search/scan a CVL record, view/edit it, assign or remove its QR code, update its photo |
| `social_service_claim` | Scan a claim QR, verify eligibility, capture claimant ID/signature/face photo, submit the claim |
| `dashboard` | Landing page after login, routes into the other features |

`core/` holds cross-feature building blocks: `AppConfig` (backend URL, tenant
DB name, staff token), `ApiClient` (HTTP envelope), `AppTheme`, shared widgets
(`ConfirmDialog`, `InfoCard`), and `claimant_options.dart` (fixed dropdown
option lists mirroring the admin EMS).

## State management

`flutter_bloc` is used throughout — `Bloc` for flows with discrete
event-driven transitions (`AuthBloc`, `ScannerBloc`, `ClaimBloc`), `Cubit` for
simpler load/mutate state holders (`CvlLookupCubit`, `CvlSearchCubit`,
`ServiceDetailsCubit`). All Blocs/Cubits are provided at the app root via
`MultiBlocProvider` in `main.dart` and are long-lived for the app's lifetime.

## Backend integration

The app is a thin client over one HTTP endpoint (`AppConfig.apiBaseUrl`, an
AWS API Gateway route in front of a shared multi-tenant Lambda,
`UniversalLGU-MainPost`). Every request is a `POST` with a JSON (or
multipart, for file uploads) body:

```json
{ "endpoint": "<action_name>", "token": "<staff token>", "db_name": "bataan_db", "...": "..." }
```

`ApiClient` (`lib/core/network/api_client.dart`) is the only place in the app
that performs HTTP calls — every feature's remote datasource depends on it.
See [API.md](API.md) for the full request/response contract of every
endpoint this app calls.

A mirror of the Lambda's Bataan/shared source lives at
`backend/_external_lambdas/UniversalLGU-MainPost/` (and the separate login
Lambda at `backend/_external_lambdas/UniversalLGU-LoginPost/`) for reference
and local diffing — it is not deployed from this repo automatically; see each
Lambda directory's `SNAPSHOT.md` for the manual pull/deploy history and
drift-check process.

## Local session

`AuthLocalDatasource` persists the logged-in scanner user's JSON via
`shared_preferences` so the app can skip the login screen on relaunch, until
`logout` clears it. This is app-level UI convenience, not a security boundary
— every backend request still carries the fixed `AppConfig.staffToken`
regardless of which staff member is "logged in" on the device.
