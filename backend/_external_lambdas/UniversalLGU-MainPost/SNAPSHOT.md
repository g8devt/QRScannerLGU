# UniversalLGU-MainPost — Lambda Snapshot

- **Account:** 425605448087
- **Region:** ap-southeast-1
- **Pulled:** 2026-08-26 (previously 2026-08-25, 2026-08-19, 2026-08-10)
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

## Configuration

```json
{
    "Runtime": "python3.12",
    "Handler": "lambda_function.lambda_handler",
    "Timeout": 300,
    "MemorySize": 512,
    "LastModified": "2026-08-26T08:44:39.000+0000",
    "CodeSha256": "IvyGgtWfi7WV8kqULlprf0jbQhbkpanGM4sa4ByDjxU="
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
