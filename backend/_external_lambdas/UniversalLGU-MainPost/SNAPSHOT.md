# UniversalLGU-MainPost — Lambda Snapshot

- **Account:** 425605448087
- **Region:** ap-southeast-1
- **Pulled:** 2026-08-25 (previously 2026-08-19, 2026-08-10)

## Configuration

```json
{
    "Runtime": "python3.12",
    "Handler": "lambda_function.lambda_handler",
    "Timeout": 300,
    "MemorySize": 512,
    "LastModified": "2026-08-25T12:05:46.000+0000",
    "CodeSha256": "uljATMq/yuYRFOntMOeMeEcez1JOtRwlKC/GZXM307c="
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
