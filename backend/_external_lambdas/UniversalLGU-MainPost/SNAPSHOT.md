# UniversalLGU-MainPost — Lambda Snapshot

- **Account:** 425605448087
- **Region:** ap-southeast-1
- **Pulled:** 2026-08-26 (previously 2026-08-25, 2026-08-19, 2026-08-10)
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

## Configuration

```json
{
    "Runtime": "python3.12",
    "Handler": "lambda_function.lambda_handler",
    "Timeout": 300,
    "MemorySize": 512,
    "LastModified": "2026-08-26T13:24:28.000+0000",
    "CodeSha256": "gyYfCuR2Z7awC6t34cK25+nrMHGAba4RKUwrIaxCKAI="
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
