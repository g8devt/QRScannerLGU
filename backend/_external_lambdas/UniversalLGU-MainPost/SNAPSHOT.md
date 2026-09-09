# UniversalLGU-MainPost — Lambda Snapshot

- **Account:** 425605448087
- **Region:** ap-southeast-1
- **Pulled:** 2026-09-09 (previously 2026-08-26, 2026-08-25, 2026-08-19, 2026-08-10)
- **Deployed from this repo:** 2026-09-09 (fourth deploy same day, commit
  `d680675`) — reworked `check_scanner_status_bataan` in
  `endpoints/scanner_auth_bataan.py` so the auto-login/session-revalidation
  path returns a `reason` (`'INACTIVE'` | `'DEACTIVATED'`) alongside
  `is_valid: false`, mirroring `login_scanner_bataan`'s `login_status`
  discriminant, instead of only ever returning `is_valid: false` with no
  reason. Root cause of a real production bug: this fix had been committed
  to the repo mirror but never deployed, so the live Lambda still returned
  bare `is_valid: false` (no `reason` field, and a not-found row returned
  no `reason` either) — the app's `restoreSession` only special-cases
  `reason == 'DEACTIVATED'` and otherwise falls back to the generic
  `AccountInactiveException`, so a deactivated staff account's cached
  session showed "Account Inactive" on auto-login instead of "Account
  Deactivated", even though the DB and the manual-login path (already
  fixed by the `b8b0c70` deploy below) were both correct. Found by pulling
  the live package fresh and diffing against this mirror: confirmed the
  live `check_scanner_status_bataan` predated this fix (old
  `is_valid = bool(is_active) and user_status != 'DEACTIVATED'`
  one-liner, no `reason` key at all) while every other file — including
  `lambda_function.py`'s `ROUTES` and `helpers/` — was byte-identical to
  this mirror (116/116 file-count parity). Applied only this file's
  current mirror content into the freshly pulled package and deployed via
  `aws lambda update-function-code`. Verified post-deploy:
  `LastUpdateStatus: Successful`, `State: Active`,
  `CodeSha256: icTNSdOt9IEX3eVcUQTD6SEtgLLEyNqMtvnF9MfT6To=`. Not
  independently re-verified against a real deactivated scanner account's
  live session (would require that account's actual cached
  `user_profile_id`); covered instead by the existing unit tests for this
  function plus the pre-deploy diff review above.
- **Deployed from this repo:** 2026-09-09 (third deploy same day, commit
  `b8b0c70`) — reworked `login_scanner_bataan` in
  `endpoints/scanner_auth_bataan.py` (no `ROUTES`/`lambda_function.py`
  change — same action name) so manual login distinguishes an
  inactive/deactivated account from a wrong password instead of
  collapsing both into a generic "Invalid Credential": now fetches the
  account by `username` alone, verifies the password with
  `hmac.compare_digest` in Python BEFORE ever inspecting
  `is_active`/`user_status` (the safety property -- a wrong password
  always resolves to `INVALID_CREDENTIAL` regardless of account status,
  so this can't become an unauthenticated status oracle), then always
  responds 200 with a `login_status` discriminant (`SUCCESS` |
  `INVALID_CREDENTIAL` | `INACTIVE` | `DEACTIVATED`, `DEACTIVATED` taking
  priority when both apply) instead of `fail()`/400, mirroring
  `check_scanner_status_bataan`'s pattern. Same pull-live/merge-diff/
  deploy method: pulled the live package fresh immediately before
  deploying, confirmed the only diff from this mirror was this one file
  (116/116 file-count parity against the fresh pull, `lambda_function.py`
  and `helpers/` byte-identical), applied only this change, and deployed
  via `aws lambda update-function-code`. Verified post-deploy:
  `LastUpdateStatus: Successful`, `State: Active`. Live verification via
  the public API (valid staff token): an unknown username still returns
  `{"status": true, "login_status": "INVALID_CREDENTIAL"}` (200, not a
  `fail()`/400 as before -- confirms the new response contract is live);
  a missing `password` still returns the unaffected `400 Missing:
  password`; an invalid app token still returns `403 Access Denied`.
  The `SUCCESS`/`INACTIVE`/`DEACTIVATED`/combined-status and
  correct-password-on-a-blocked-account cases were NOT independently
  live-verified against real accounts -- doing so requires a real
  scanner-staff account's actual password, which this environment does
  not have and should not guess; those branches are covered instead by 8
  dedicated unit tests against mocked DB rows (all passing, part of the
  92/92 backend suite) and the pre-deploy diff review above.
- **Deployed from this repo:** 2026-09-09 (second deploy same day, commit
  `01f8440`) — added `check_scanner_status_bataan` to
  `endpoints/scanner_auth_bataan.py` + its `ROUTES` entry (backs the
  scanner app's new auto-login/Remember Me session revalidation: the app
  now calls this on every launch with the cached user's `id` and treats
  only `is_valid: true` as permission to enter, instead of trusting the
  locally cached session by itself). Always responds 200 with `is_valid`
  (including "user not found") so the app can tell a confirmed
  is_active=0/DEACTIVATED rejection apart from a network/server failure;
  `login_scanner_bataan`'s existing SQL-level gate is unchanged. Same
  pull-live/merge-diff/deploy method: pulled the live package fresh
  immediately before deploying, confirmed the only diff from this mirror
  was this one addition (`endpoints/scanner_auth_bataan.py` +
  `lambda_function.py`'s one new `ROUTES` line; file-count parity 116/116
  against the fresh pull, all `cebu_*` files intact), and deployed via
  `aws lambda update-function-code`. Verified post-deploy:
  `LastUpdateStatus: Successful`, `State: Active`. Live functional
  verification via the public API (valid staff token): an invalid token
  still returns `403 Access Denied`; a missing `user_profile_id` returns
  `400 Missing: user_profile_id`; probing real `user_profile_id` values
  1-10 returned a genuine mix — `id=2` → `is_valid: true` (an active,
  non-deactivated account), `id=1` and others → `is_valid: false`
  (inactive/deactivated/nonexistent) — confirming the endpoint's is_valid
  logic runs correctly against live data, not just that it imports/routes.
  Contrasted against an unrouted action name, which correctly returns
  `Unknown endpoint: ...` (proving `check_scanner_status_bataan` is
  genuinely dispatched, not falling through). Manual login
  (`login_scanner_bataan`) and the sibling
  `check_app_version_scanner_bataan` endpoint re-verified unaffected
  (bogus credentials still return `Invalid Credential`; version check
  still returns a normal `update_required` response).
- **Pulled from live:** 2026-09-09 — live had drifted since the 2026-09-02
  pull (`LastModified` 2026-09-02 -> 2026-09-09, `CodeSha256` changed).
  Downloaded the live package fresh and diffed it (line-ending-insensitive,
  Bataan/shared code only) against this mirror. Found and synced 6 changed
  files, all citizen-app (not scanner-app) features deployed from elsewhere
  outside this repo's workflow: new `endpoints/app_version_bataan.py`
  (`check_app_version_bataan` — optional update check for the main citizen
  app, `app_code='MAIN_APP'`, mirrors the existing scanner-app version-check
  pattern) plus its `ROUTES`/import entry in `lambda_function.py`; a major
  rework of `endpoints/card_request.py`'s `request_card_link` (now resolves
  an optional `qr_code` through `app_cvl_list`/`app_qr_code`, auto-approves
  the link when the CVL record's name+birthdate match the caller's
  `app_users` row, otherwise falls back to the existing PENDING/manual-review
  path) and `get_card_link_status` (now checks `app_users.assign_card`
  first, includes `decline_reason` for DECLINED/REJECTED); new
  `helpers/password.py` (PBKDF2-HMAC-SHA256 password hashing, `hash_password`
  /`verify_password`, unrelated to the scanner app's own
  `helpers/scanner_auth_bataan.py` hasher); and a liveness-check addition
  to `helpers/rekognition.py`'s `detect_face_liveness` (server-side sanity
  check on the account-creation selfie capture — confidence/sharpness/
  brightness/pose/eyes-open thresholds, fails open to `needs_review` on a
  Rekognition-side error). `endpoints/scanner_auth_bataan.py` only reordered
  (functions swapped position, `login_scanner_bataan` unchanged content) —
  not a real code change. Verified: mirror's own test suite (79/79) still
  passes after the sync.
- **Verified live (no drift):** 2026-08-26 (second pull same day) — pulled
  the live package again before deploying `remove_cvl_qr_bataan`;
  `CodeSha256`/`LastModified` matched this file exactly, and a full
  file-list + content diff (line-ending-insensitive, Bataan/shared code
  only) found nothing beyond the not-yet-deployed local addition below.
- **Pulled from live:** 2026-08-26 — synced `set_cvl_qr_bataan`
  (`endpoints/cvl_records_bataan.py` + its `ROUTES` entry in
  `lambda_function.py`), which had been deployed live in an earlier
  session without updating this mirror. Straight pull, no other drift
  found.
- **Deployed from this repo:** 2026-08-25 — added `find_cvl_by_qr_bataan`
  (`endpoints/cvl_records_bataan.py` + its `ROUTES`/import entry in
  `lambda_function.py`). Built by downloading the live package fresh
  (not this repo's incomplete mirror — see Scope note), applying only
  that diff, and deploying via `aws lambda update-function-code`. Verified
  post-deploy: `LastUpdateStatus: Successful`, and two clean invokes with
  `FunctionError: null` (proves the new module imports cleanly at cold
  start — an import/syntax error there would break every tenant's every
  request, not just this endpoint).
- **Deployed from this repo:** 2026-08-26 — added `update_cvl_photo_bataan`
  to the same `cvl_records_bataan.py` + its `ROUTES` entry. Same
  pull-live/merge-diff/deploy method as above (drift-checked against the
  repo first via a line-ending-insensitive diff — none found). Verified
  post-deploy: `LastUpdateStatus: Successful`, clean invoke with
  `FunctionError: null`.
- **Deployed from this repo:** 2026-08-26 — added `get_cvl_by_id_bataan`
  and `search_cvl_by_name_bataan` to the same `cvl_records_bataan.py` +
  their `ROUTES` entries (search-by-name flow). Same pull-live/merge-diff
  /deploy method (drift-checked, none found). Verified post-deploy:
  `LastUpdateStatus: Successful`, two clean invokes with
  `FunctionError: null`.
- **Deployed from this repo:** 2026-08-26 — reworked `search_cvl_by_name_bataan`
  in the same `cvl_records_bataan.py` for pagination: accepts an
  `offset` param, fetches one extra row past the 25-row page to compute
  `has_more` (replacing the old `truncated` field, whose "== 25"
  inference misreported an exact-multiple-of-25 result count as final),
  and enables the app's search list to lazy-load further pages on
  scroll. No `ROUTES`/`lambda_function.py` change — same action name.
  Same pull-live/merge-diff/deploy method (drift-checked, none found).
  Verified post-deploy: `LastUpdateStatus: Successful`, two clean
  invokes with `FunctionError: null`.
- **Deployed from this repo:** 2026-08-26 — added `remove_cvl_qr_bataan`
  to the same `cvl_records_bataan.py` + its `ROUTES` entry (the "Search
  CVL Record" list's Remove QR action — the counterpart to
  `set_cvl_qr_bataan`; frees the code in `app_qr_code` back to
  `AVAILABLE` and clears `app_cvl_list.cvl_qr`). Same pull-live/merge-
  diff/deploy method: pulled the live package fresh immediately before
  deploying, confirmed it had zero drift from this mirror, applied only
  this addition, and deployed via `aws lambda update-function-code`.
  Verified post-deploy: `LastUpdateStatus: Successful`, two clean
  invokes (`remove_cvl_qr_bataan` and `set_cvl_qr_bataan`, both with a
  deliberately invalid token) returning a normal `403 Access Denied`
  body with `FunctionError: null` — proves the new module imports and
  routes cleanly at cold start.
- **Deployed from this repo:** 2026-08-26 — added `update_cvl_info_bataan`
  to the same `cvl_records_bataan.py` + its `ROUTES` entry (the "Search
  CVL Record" list's Edit action — updates `cvl_contact_no`/`cvl_email`/
  `cvl_gender` individually, each optional but at least one required).
  Same pull-live/merge-diff/deploy method: pulled the live package fresh
  immediately before deploying, confirmed zero drift from this mirror
  beyond this not-yet-deployed addition, applied only it, and deployed
  via `aws lambda update-function-code`. Verified post-deploy:
  `LastUpdateStatus: Successful`, two clean invokes (`update_cvl_info_bataan`
  and `remove_cvl_qr_bataan`, both with a deliberately invalid token)
  returning a normal `403 Access Denied` body with `FunctionError: null`.
- **Deployed from this repo:** 2026-08-26 — fixed a real production bug in
  `update_cvl_photo_bataan` (same `cvl_records_bataan.py`, no `ROUTES`
  change — same action name): removed a duplicated `record_id` segment
  from the uploaded S3 key (`cvl/<id>/<id>/...` -> `cvl/<id>/...`), and
  added an explicit `_MAX_IMG_PATH_LENGTH` guard that fails the request
  with a clear error if a URL would exceed `cvl_img_path`'s column
  width, instead of ever again relying on silent DB-level truncation
  (root cause of a broken, extension-less `cvl_img_path` found in
  production — the stored URL was exactly 100 characters, the old
  column's exact width). Same pull-live/merge-diff/deploy method
  (drift-checked, none found beyond this change). Verified post-deploy:
  `LastUpdateStatus: Successful`, clean invoke with `FunctionError: null`.
  Paired DB migration `034_widen_cvl_img_path.sql` (widens
  `cvl_img_path` to `varchar(512)`) was applied separately and directly
  by the project owner against live `bataan_db` — this dev machine has
  no network path to the RDS instance (VPC-private, connection times
  out), so it could not be run or independently re-verified from here.
  The owner confirmed via `SHOW COLUMNS` that `cvl_img_path` now reads
  `varchar(512)`, matching this deploy's `_MAX_IMG_PATH_LENGTH = 512`
  guard.

- **Checked:** 2026-08-29 — live `CodeSha256`/`LastModified` unchanged
  since the 2026-08-26 pull; also pulled the live package fresh and
  diffed file contents directly against this mirror (line-ending-
  insensitive, Bataan/shared code only), confirming zero drift.
- **Deployed from this repo:** 2026-08-29 — added the "Search CVL
  Record" filter feature: a new `get_cvl_filter_options_bataan`
  endpoint (returns distinct live values for `cvl_mun`, `cvl_brgy`,
  `cvl_precinct_no`, `cvl_position_code`, `cvl_leader`, `cvl_sector`
  for the app's filter-sheet dropdowns) plus its `ROUTES` entry, and
  extended `search_cvl_by_name_bataan` (same `cvl_records_bataan.py`)
  to accept optional exact-match filters (`mun`, `brgy`, `precinct`,
  `position_code`, `leader`, `secondary_position`, `sector`) and
  tri-state `has_photo`/`has_card` params, AND-ed with the name match;
  `name` is now optional as long as at least one filter is set (still
  rejects an entirely empty request). Same pull-live/merge-diff/deploy
  method: pulled the live package fresh immediately before deploying,
  confirmed zero drift from this mirror, applied only this addition,
  and deployed via `aws lambda update-function-code`. Verified
  post-deploy: `LastUpdateStatus: Successful`, two clean invokes
  (`get_cvl_filter_options_bataan` and `search_cvl_by_name_bataan`
  with a filter and no name, both with a deliberately invalid token)
  returning a normal `403 Access Denied` body — proves the new
  endpoint and the relaxed name requirement import and route cleanly
  at cold start.
- **Deployed from this repo:** 2026-08-29 — narrowed
  `get_cvl_filter_options_bataan` (same `cvl_records_bataan.py`) to
  only fetch `mun`/`brgy`/`precinct`, dropping `position_code`/
  `leader`/`sector`. Those three turned out to be fixed, admin-defined
  dropdown option sets in `bataan_lgu_admin`'s EMS (confirmed via
  screenshots of that UI), not organically-varying free text as
  originally assumed — the app now hardcodes their option lists
  instead (matching the EMS dropdowns exactly), so fetching distinct
  live values for them would have silently omitted any option not yet
  used by an existing record. Same pull-live/merge-diff/deploy method
  (drift-checked against the prior deploy, none found). Verified
  post-deploy: `LastUpdateStatus: Successful`, clean invoke
  (`get_cvl_filter_options_bataan`, deliberately invalid token)
  returning a normal `403 Access Denied` body.
- **Deployed from this repo:** 2026-08-29 — fixed the Major
  Position/Leader Title filters returning zero results (same
  `cvl_records_bataan.py`, no `ROUTES` change). Root cause:
  `app_cvl_list.cvl_position_code` is a `leader_structure_tbl
  .leader_unique_id` code, not the major-position/leader-title text
  itself, and `cvl_leader` is an unrelated column — matching either
  filter directly against `app_cvl_list` (the original implementation)
  silently matched nothing for every value. `search_cvl_by_name_bataan`
  now joins `leader_structure_tbl` (only when either filter is set) on
  `leader_unique_id = c.cvl_position_code` and matches `position_code`
  against that row's `leader_structure_name`, `leader` against its
  `leader_title`. No app change needed — the app already sent the same
  `position_code`/`leader` param names. Same pull-live/merge-diff/
  deploy method (drift-checked against the prior deploy, none found).
  Verified post-deploy: `LastUpdateStatus: Successful`, clean invoke
  (`search_cvl_by_name_bataan` with both filters set, deliberately
  invalid token) returning a normal `403 Access Denied` body.
- **Deployed from this repo:** 2026-08-29 — fixed Major Position and
  Leader Title filter options showing the wrong/incomplete choices
  (same `cvl_records_bataan.py`, no `ROUTES` change): the app's
  previously hardcoded Leader Title list didn't cascade from the
  selected Major Position, and one major position (`leader_structure_name`)
  can have several leader titles under it (e.g. ATR has both MAIN
  COORDINATOR and PUROK COORDINATOR) — confirmed against the live admin
  EMS UI. `get_cvl_filter_options_bataan` now also queries
  `leader_structure_tbl` directly for `major_positions` (every distinct
  `leader_structure_name`) and `leader_titles_by_position` (each
  `leader_structure_name` mapped to its own distinct `leader_title`
  values), replacing the two hardcoded app-side lists so they can't
  drift from the live data again the same way. Same pull-live/merge-
  diff/deploy method (drift-checked, none found). Verified post-deploy:
  `LastUpdateStatus: Successful`, clean invoke
  (`get_cvl_filter_options_bataan`, deliberately invalid token)
  returning a normal `403 Access Denied` body.
- **Deployed from this repo:** 2026-08-29 — fixed a `Server error: (1267,
  "Illegal mix of collations (utf8mb4_general_ci,IMPLICIT) and
  (utf8mb4_unicode_ci,IMPLICIT) for operation '='")` thrown by
  `search_cvl_by_name_bataan` (same `cvl_records_bataan.py`, no
  `ROUTES` change) whenever Major Position or Leader Title was used —
  the new `leader_structure_tbl` join compared
  `ls.leader_unique_id` (`utf8mb4_general_ci`) directly against
  `c.cvl_position_code` (`utf8mb4_unicode_ci`), which MySQL rejects
  outright rather than silently mismatching. Added an explicit
  `COLLATE utf8mb4_general_ci` on the `c.cvl_position_code` side of the
  join condition. Same pull-live/merge-diff/deploy method (drift-
  checked, none found). Verified post-deploy: `LastUpdateStatus:
  Successful`, clean invoke (`search_cvl_by_name_bataan` with
  `position_code`, deliberately invalid token) returning a normal `403
  Access Denied` body — this only confirms the code imports/routes
  cleanly (auth rejects before the query runs); the actual collation
  fix could only be confirmed from the app itself, not from here (no
  valid session token available in this environment).

- **Checked:** 2026-08-30 — live `CodeSha256`/`LastModified` unchanged
  since the 2026-08-29 pull; no drift, nothing to sync.
- **Deployed from this repo:** 2026-08-30 — added
  `check_app_version_scanner_bataan` to `endpoints/scanner_auth_bataan.py`
  + its `ROUTES` entry (mandatory Scanner-app update check: compares the
  installed app version against the latest `ACTIVE` `app_version` row for
  `app_code='SCANNER'`, numeric major.minor.patch comparison, backing
  `AuthGate`'s pre-login update-block dialog on the Flutter side). Same
  pull-live/merge-diff/deploy method: pulled the live package fresh
  immediately before deploying, confirmed zero drift from this mirror
  (`lambda_function.py` and `scanner_auth_bataan.py` byte-identical
  line-ending-insensitive, endpoints file listing identical apart from a
  local-only `__pycache__` dir), applied only this addition, and deployed
  via `aws lambda update-function-code`. Verified post-deploy:
  `LastUpdateStatus: Successful`, two clean invokes
  (`check_app_version_scanner_bataan` and `login_scanner_bataan`, both
  with a deliberately invalid token) returning a normal `403 Access
  Denied` body with `FunctionError: None` — proves the new endpoint
  imports and routes cleanly at cold start without breaking the existing
  login action.
- **Checked:** 2026-08-31 — live `CodeSha256`/`LastModified` unchanged
  since last pull; no drift, nothing to sync.
- **Checked:** 2026-09-02 — live `CodeSha256`/`LastModified` unchanged
  since last pull; no drift, nothing to sync.
- **Deployed from this repo:** 2026-09-02 — added `c.cvl_status` to
  `_CVL_DETAIL_COLUMNS` in `endpoints/cvl_records_bataan.py` (plus a
  docstring note on `find_cvl_by_qr_bataan`), so `find_cvl_by_qr_bataan`
  and `get_cvl_by_id_bataan` now return the CVL record's status —
  backs the scanner app's new "only ACTIVE records may be scanned" gate
  (the app itself enforces the gate; this endpoint still doesn't filter
  on status). Same pull-live/merge-diff/deploy method: pulled the live
  package fresh immediately before deploying, confirmed zero drift from
  this mirror (full file-list + content diff, Bataan/shared code only,
  found nothing beyond this one not-yet-deployed local change), applied
  only this addition onto the freshly-pulled package (kept all 26
  `cebu_*`-prefixed files intact — an earlier local diff step had
  stripped them from a scratch copy for comparison purposes only; that
  copy was discarded and re-pulled fresh before packaging so nothing
  Cebu-tenant-specific was ever at risk of being deployed), and deployed
  via `aws lambda update-function-code`. Verified post-deploy:
  `LastUpdateStatus: Successful`, two clean invokes
  (`find_cvl_by_qr_bataan` and `get_cvl_by_id_bataan`, both with a
  deliberately invalid token) returning a normal `403 Access Denied`
  body with no `FunctionError` — proves the edited module imports and
  routes cleanly at cold start.

- **Deployed from this repo:** 2026-09-02 (second deploy same day) —
  `search_cvl_by_name_bataan` now always applies `c.cvl_status =
  'ACTIVE'` (not caller-controllable — added directly to the query's
  `conditions` list, not `filter_conditions`, so it can't be surfaced or
  overridden as a request param); `get_cvl_filter_options_bataan`'s
  `mun`/`brgy`/`precinct` dropdown option queries got the same `AND
  cvl_status = 'ACTIVE'` restriction, so the filter sheet can't offer a
  location combination search would then return zero results for.
  Backs "Search CVL Record only searches/filters ACTIVE records". Same
  pull-live/merge-diff/deploy method: pulled the live package fresh,
  confirmed zero drift against this mirror using a disposable copy for
  the comparison (not the copy that got zipped — a prior deploy this
  session had briefly stripped the 26 `cebu_*` files from the wrong
  copy for a diff and nearly zipped that one; this time the diff copy
  and the deploy copy were kept strictly separate, and file-listing
  parity (111/111) with the fresh download was verified right before
  upload), applied only this change, and deployed via `aws lambda
  update-function-code`. Verified post-deploy: `LastUpdateStatus:
  Successful`, two clean invokes (`search_cvl_by_name_bataan` and
  `get_cvl_filter_options_bataan`, both with a deliberately invalid
  token) returning a normal `403 Access Denied` body with no
  `FunctionError` — proves the edited module imports and routes cleanly
  at cold start. Added 4 new tests to
  `tests/test_cvl_records_bataan.py` (79/79 passing).

## Configuration

```json
{
    "Runtime": "python3.12",
    "Handler": "lambda_function.lambda_handler",
    "Timeout": 300,
    "MemorySize": 512,
    "LastModified": "2026-09-09T13:02:12.000+0000",
    "CodeSha256": "icTNSdOt9IEX3eVcUQTD6SEtgLLEyNqMtvnF9MfT6To="
}
```

Environment variables were intentionally not pulled or recorded (contain secrets).

## Scope note

This Lambda is shared by multiple LGU tenants (Bataan, Cebu, ...). Only
Bataan/shared code is mirrored here — endpoint modules with a `cebu_*`
prefix (e.g. `endpoints/cebu_kyc.py`, `endpoints/cebu_analytics.py`) are
Cebu-tenant-only and intentionally NOT pulled, even though `lambda_function.py`
imports and routes to them for that tenant's `_cebu`-suffixed actions.
`endpoints/admin_kyc.py` was removed from this pull — upstream renamed it to
`endpoints/kyc_review.py` (already present).
