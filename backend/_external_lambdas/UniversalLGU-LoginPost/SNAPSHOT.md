# UniversalLGU-LoginPost — Lambda Snapshot

- **Account:** 425605448087
- **Region:** ap-southeast-1
- **Pulled:** 2026-08-25 (previously 2026-08-10)
- **Checked:** 2026-08-26 — live `CodeSha256`/`LastModified` unchanged
  since the 2026-08-25 pull; no drift, nothing to sync.

## Configuration

```json
{
    "Runtime": "python3.12",
    "Handler": "lambda_function.lambda_handler",
    "Timeout": 15,
    "MemorySize": 1769,
    "LastModified": "2026-08-23T09:27:27.000+0000",
    "CodeSha256": "bZO43WwX9nFv82AKnyRAsLOI758R/HmS3m041vu5RYU="
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
