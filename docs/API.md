# API Reference

The app talks to a single shared, multi-tenant AWS Lambda (`UniversalLGU-MainPost`,
fronted by API Gateway) that serves many LGU tenants and client apps. This
document covers only the endpoints **this app (Bataan Scanner)** calls, plus
the shared request/response envelope.

A read-only mirror of the backend source this app depends on lives at
`backend/_external_lambdas/UniversalLGU-MainPost/endpoints/` — see
`cvl_records_bataan.py`, `social_services_bataan.py`, and
`scanner_auth_bataan.py`.

## Base URL

```
POST https://h9yltujhgi.execute-api.ap-southeast-1.amazonaws.com/Prod/main
```

Configurable at build time via `--dart-define=API_BASE_URL=...`
(`lib/core/config/app_config.dart`). Every action is dispatched through this
one URL — the specific operation is selected by the `endpoint` field in the
request body, not by the URL path.

## Request envelope

Every request is `POST` with `Content-Type: application/json` (or
`multipart/form-data` for endpoints that upload files) and always includes:

| Field | Description |
|---|---|
| `endpoint` | Action name, e.g. `login_scanner_bataan` |
| `token` | Staff session token. Fixed app-level value (`AppConfig.staffToken`), not per-user — gates reaching the backend at all, distinct from per-staff username/password login |
| `db_name` | Tenant database name, always `bataan_db` for this app |

Endpoint-specific parameters are merged into the same top-level object
(JSON body) or as additional form fields (multipart).

## Response envelope

All responses are JSON with an HTTP status code and a `status` boolean:

**Success** (HTTP 200):
```json
{ "status": true, "data": { "...": "..." } }
```
(Some endpoints add fields alongside `data`, or return primitives instead —
noted per endpoint below.)

**Failure** (HTTP 400 / 403 / 404 / 409 / 500, `status: false`):
```json
{ "status": false, "message": "human-readable error" }
```

Common failure cases across every endpoint:

| HTTP | Cause |
|---|---|
| 400 | Missing/invalid required field (`"Missing: <field>"`), or `ValueError` raised by validation |
| 403 | `token` doesn't match any live value in `app_user_operations_tbl` (`"Access Denied"`) |
| 404 | Unknown `endpoint` name, or record/QR/application not found |
| 409 | Conflicting state (e.g. QR already assigned, application already claimed) |
| 500 | Unhandled server error (`"Server error: ..."`) |

`ApiClient._decode` (`lib/core/network/api_client.dart`) throws an
`ApiException` with the `message` field whenever `status` is `false` or the
HTTP code is outside 2xx — feature repositories/Blocs catch this to show the
error to the user.

---

## Auth

### `login_scanner_bataan`

Authenticates scanner-app staff by username/password against
`app_users_scanner` (separate from the citizen mobile app's mobile+PIN
login).

**Request**
| Field | Type | Required |
|---|---|---|
| `username` | string | yes |
| `password` | string | yes |

**Success**
```json
{
  "status": true,
  "message": "Login Successfully",
  "user_profile_id": "12",
  "username": "jdoe",
  "user_status": "ACTIVE",
  "data": { "...": "full app_users_scanner row, minus password" }
}
```

**Failures**: `"Invalid Credential"` (400) if username is blank, no matching
active/non-deactivated user, or wrong password.

Called from `lib/features/auth/data/datasources/auth_remote_datasource.dart`.

---

## App update gate

### `check_app_version_scanner_bataan`

Compares the installed app version against the latest `ACTIVE` version row
for `app_code='SCANNER'`, used by `AuthGate` to block staff from logging in
on an outdated build.

**Request**
| Field | Type | Required |
|---|---|---|
| `os_type` | string | yes — e.g. `ANDROID`, `IOS` (uppercased server-side) |
| `current_version` | string | yes — `major.minor.patch` |

**Success**
```json
{ "status": true, "update_required": false }
```
or, when an update is required:
```json
{ "status": true, "update_required": true, "latest_version": "1.1.0", "url": "https://..." }
```
If no active version row exists for the OS, responds `update_required: false`.
Version comparison is numeric (`1.9 < 1.10.0`), not string ordering.

Called from `lib/features/app_update/data/datasources/app_update_remote_datasource.dart`,
which treats *any* failure (network, non-2xx, unexpected shape) as
`checkFailed` rather than throwing — callers never have to distinguish
"couldn't check" from "up to date".

---

## CVL (Community Vulnerability List) lookup

Backing `lib/features/cvl_lookup/`. All defined in
`endpoints/cvl_records_bataan.py` against the `app_cvl_list` table.

### `find_cvl_by_qr_bataan`

Looks up a CVL record by its assigned QR code (scan flow).

**Request**: `qr_code` (string, required)

**Success**: `{ "status": true, "data": { ...full app_cvl_list row... } }`

**Failures**: 404 `"No CVL record was found for this QR code."`

### `get_cvl_by_id_bataan`

Looks up a CVL record by its numeric id.

**Request**: `id` (string/int, required)

**Success**: `{ "status": true, "data": { ...full row... } }`

**Failures**: 404 `"CVL record not found"`

### `search_cvl_by_name_bataan`

Staff-facing "Search CVL Record" list — searches by name and/or filters,
paginated.

**Request**
| Field | Type | Required |
|---|---|---|
| `name` | string | optional, but ≥2 chars if given; either `name` or a filter must be present |
| `offset` | string/int | optional, default `0` |
| `mun`, `brgy`, `precinct` | string | optional exact-match filters |
| `secondary_position`, `sector` | string | optional exact-match filters |
| `position_code` | string | optional — matches "Major Position" (`leader_structure_tbl.leader_structure_name`) |
| `leader` | string | optional — matches "Leader Title" (`leader_structure_tbl.leader_title`), cascades from `position_code` |
| `has_photo` | `"1"` / `"0"` | optional tri-state (any if omitted) |
| `has_card` | `"1"` / `"0"` | optional tri-state — whether a QR/Kabaka Card is tagged |

Name matching: keywords ≥3 alphanumeric chars use fulltext prefix match
(`ft_cvl_fullname` index); any shorter keyword falls back to `LIKE '%word%'`
for the whole query.

**Success**
```json
{
  "status": true,
  "data": {
    "results": [
      { "id": 1, "cvl_fullname": "...", "cvl_mun": "...", "cvl_brgy": "...", "cvl_qr_code": "..." }
    ],
    "has_more": false
  }
}
```
Page size is 25. `results` rows are lightweight (id, name, location, QR code
if any) — not the full record.

**Failures**: 400 `"Enter at least 2 characters to search"`, `"Enter a search
term or choose at least one filter"`, `"Invalid offset"`.

### `get_cvl_filter_options_bataan`

Returns dropdown option lists for the search filter sheet. No request
parameters.

**Success**
```json
{
  "status": true,
  "data": {
    "mun": ["..."],
    "brgy": ["..."],
    "precinct": ["..."],
    "major_positions": ["ATR", "KABAKA", "..."],
    "leader_titles_by_position": { "ATR": ["MAIN COORDINATOR", "PUROK COORDINATOR"], "...": ["..."] }
  }
}
```
`mun`/`brgy`/`precinct` are distinct live values from `app_cvl_list`.
`secondary_position`/`sector` are NOT included — the app hardcodes those
fixed, admin-defined option sets instead (`lib/core/constants/claimant_options.dart`
equivalent for CVL). `major_positions`/`leader_titles_by_position` come from
`leader_structure_tbl`, cascading (a position can have several leader
titles).

### `set_cvl_qr_bataan`

Assigns a QR code to a CVL record ("Set QR" action).

**Request**: `id` (required), `qr_code` (required)

**Success**: `{ "status": true, "data": { "cvl_qr_code": "..." } }`

**Failures**: 404 `"CVL record not found"` / `"This QR code is not
registered."`; 409 `"This record already has a QR code assigned."` /
`"This QR code is already in use."`

### `remove_cvl_qr_bataan`

Unassigns whatever QR code is currently set on a CVL record, freeing the
code for reuse ("Remove QR" action — counterpart to `set_cvl_qr_bataan`).

**Request**: `id` (required)

**Success**: `{ "status": true, "data": { "id": <id> } }`

**Failures**: 404 `"CVL record not found"`; 409 `"This record has no QR code
assigned."`

### `update_cvl_info_bataan`

Updates a CVL record's contact number, email, and/or gender — at least one
required.

**Request**
| Field | Type | Required |
|---|---|---|
| `id` | string/int | yes |
| `contact_no` | string | one of these three required |
| `email` | string | " |
| `gender` | string | " |
| `updated_by` | string | optional |

**Success**: `{ "status": true, "data": { ...updated row... } }`

**Failures**: 404 `"CVL record not found"`; 400 `"Nothing to update —
provide contact_no, email, and/or gender."`

### `update_cvl_photo_bataan` (multipart)

Uploads/replaces a CVL record's photo.

**Request** (multipart/form-data)
| Field | Type | Required |
|---|---|---|
| `id` | form field | yes |
| `updated_by` | form field | optional |
| `cvl_photo` | file | yes |

**Success**: `{ "status": true, "data": { "cvl_img_path": "<uploaded URL>" } }`

**Failures**: 404 `"CVL record not found"`; 400 `"Missing: cvl_photo"`;
500 `"Photo upload failed"` or a max-path-length guard error.

---

## Social service claims

Backing `lib/features/social_service_claim/`, defined in
`endpoints/social_services_bataan.py` against `app_social_services`.

### `verify_qr_bataan`

Scans a claim QR and checks it's eligible to be claimed right now (status
gate). Used by the scan step before showing service details.

**Request**: `qr_code` (required)

**Success**: `{ "status": true, "data": { id, application_number,
beneficiary_name, status, requested_for_*, date_approved, date_released,
date_claimed } }`

**Failures**: 404 `"QR code not found"`; 409 `"Already claimed[ on <date>]"`
or `"Not yet eligible for claim — status is <status>"`.

### `get_service_details_bataan`

Read-only full-detail lookup by QR code, for staff to view an application
regardless of status (unlike `verify_qr_bataan`, never gates on eligibility).

**Request**: `qr_code` (required)

**Success**: `{ "status": true, "data": { ...full application detail row,
columns vary slightly by tenant DB schema... } }`

**Failures**: 404 `"QR code not found"`

### `submit_claim_bataan` (multipart)

Submits the physical claim: claimant info plus captured ID photos,
signature, and face photo. Marks the application `CLAIMED`.

**Request** (multipart/form-data)
| Field | Type | Required |
|---|---|---|
| `id` | form field | yes — application id |
| `claim_method` | form field | fixed `"QR"` |
| `claimant_type` | form field | yes — `SELF` or `REPRESENTATIVE` |
| `claimant_name` | form field | required if `claimant_type=REPRESENTATIVE` |
| `claimant_relation` | form field | required if `claimant_type=REPRESENTATIVE` |
| `claimant_id_type` | form field | yes |
| `claimant_id_number` | form field | yes |
| `claimed_amount` | form field | optional, must be > 0 if present |
| `users_scanner_id` | form field | optional — id of the logged-in staff |
| `claimant_id_front` | file | yes |
| `claimant_id_back` | file | optional |
| `claimant_signature` | file | yes |
| `claimant_face_photo` | file | yes |

**Success**: `{ "status": true, "id": "<application id>" }`

**Failures**: 400 invalid `claimant_type`, missing required fields for
`REPRESENTATIVE`, invalid `claimed_amount`, missing required files; 404
`"Application not found"`; 409 `"Not eligible for claim — status is
<status>"` or `"Already claimed by another session"` (race-safe: the update
is conditioned on the row still being in an eligible status).

Called from `lib/features/social_service_claim/data/datasources/claim_remote_datasource.dart`.

---

## Scope note

`UniversalLGU-MainPost` is shared by multiple LGU tenants and apps (Bataan,
Cebu, admin web, citizen mobile app, etc.) — this document intentionally
covers only the `*_bataan` / scanner-specific actions this app uses. See
`backend/_external_lambdas/UniversalLGU-MainPost/lambda_function.py`'s
`ROUTES` dict for the full action list if working on the shared backend
directly, and that Lambda's `SNAPSHOT.md` for deploy/drift history.
