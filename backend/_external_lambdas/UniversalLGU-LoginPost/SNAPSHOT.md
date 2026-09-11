# UniversalLGU-LoginPost — Lambda Snapshot

- **Account:** 425605448087
- **Region:** ap-southeast-1
- **Pulled:** 2026-09-09 (previously 2026-08-25, 2026-08-10)
- **Checked:** 2026-08-26 — live `CodeSha256`/`LastModified` unchanged
  since the 2026-08-25 pull; no drift, nothing to sync.
- **Checked:** 2026-08-29 — live `CodeSha256`/`LastModified` still unchanged;
  also pulled the live package fresh and diffed file contents directly
  against this mirror (line-ending-insensitive), confirming zero drift.
- **Checked:** 2026-08-30 — live `CodeSha256`/`LastModified` unchanged
  since the 2026-08-25 pull; no drift, nothing to sync.
- **Checked:** 2026-08-31 — live `CodeSha256`/`LastModified` unchanged
  since the 2026-08-25 pull; no drift, nothing to sync.
- **Checked:** 2026-09-02 — live `CodeSha256`/`LastModified` unchanged
  since the 2026-08-25 pull; no drift, nothing to sync.
- **Checked:** 2026-09-11 — live `CodeSha256`/`LastModified` unchanged
  since the 2026-09-09 pull; no drift, nothing to sync.
- **Pulled from live:** 2026-09-09 — live had drifted since the 2026-08-25
  pull (`LastModified` 2026-08-23 -> 2026-09-03, `CodeSha256` changed).
  Downloaded the live package fresh and diffed it (line-ending-insensitive)
  against this mirror. Found and synced one change in `lambda_function.py`:
  a browser-CORS `OPTIONS` preflight short-circuit added right after
  `lambda_handler` starts (returns a bare 200 with wildcard
  `Access-Control-Allow-*` headers before `parse_event` runs, so a
  bodyless preflight request from a browser client no longer hits
  `parse_event`'s "Unexpected mimetype" error — native mobile clients
  never send a preflight and are unaffected). `helpers.py` unchanged.
  Not used by this Flutter app (native, no browser CORS concerns) — kept
  in sync for backend reference only, per the Scope note below.

## Configuration

```json
{
    "Runtime": "python3.12",
    "Handler": "lambda_function.lambda_handler",
    "Timeout": 15,
    "MemorySize": 1769,
    "LastModified": "2026-09-03T13:45:31.000+0000",
    "CodeSha256": "fRTau1CwycMvp3GyQEHBsDwpcMRjpW2JTAo0cecZY3I="
}
```

Environment variables were intentionally not pulled or recorded (contain secrets).

## Scope note

`lambda_function.py` was rewritten upstream (562 → 427 lines) and split out
a new `helpers.py` module — both are mirrored here. This Lambda is also
shared with other LGU tenants: `cebu_auth.py` (Cebu-tenant `_cebu`-suffixed
endpoints, imported by `lambda_function.py`) is intentionally NOT pulled, as
it's unrelated to this project.

Not used by this Flutter app directly — the scanner talks only to
`UniversalLGU-MainPost` (see `lib/core/config/app_config.dart`). Kept here
for backend reference only.
