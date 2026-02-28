# Schema dependencies

The backend validates XML against `eCH-0278-1-0.xsd`.

To avoid flaky startup/validation caused by transient remote schema imports,
all externally imported eCH schemas are vendored under `schema/vendor/`.

At runtime, `app/validation.py` builds a namespace-to-local-file map from
`schema/vendor/**/*.xsd` and passes it to `xmlschema.XMLSchema(...)` as
`locations`, so imports resolve locally instead of over HTTP.

## Refresh vendored schemas

When `eCH-0278-1-0.xsd` imports change, refresh vendored files with:

```powershell
Set-Location backend
./tools/refresh_schema_vendor.ps1 -CleanVendor
```

Notes:

- `-CleanVendor` removes old vendored files before download.
- Without `-CleanVendor`, new files are added/updated in place.

## Guard vendored schemas

Run the guard to ensure all remote imports referenced by the root schema
(including transitive imports) are present in `schema/vendor`:

```powershell
Set-Location backend
./tools/check_schema_vendor.ps1
```

The guard exits with code `1` if files are missing or invalid.

Test wrapper (same style as other backend checks):

```powershell
Set-Location backend/tests
./run_schema_vendor_guard.ps1
```
