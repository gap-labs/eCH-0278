# Backend test scripts

This directory contains executable backend test/verification scripts.

## Run all key checks

From repository root:

```powershell
./backend/tests/run_schema_vendor_guard.ps1
./backend/tests/run_procedural_checks.ps1
./backend/tests/run_schema_checks.ps1
./backend/tests/run_validation_checks.ps1
```

## Scripts

- `run_schema_vendor_guard.ps1`
  - Verifies that all remote XSD imports (including transitive imports) are vendored locally.
  - Calls `backend/tools/check_schema_vendor.ps1`.

- `run_procedural_checks.ps1`
  - Builds backend image with test Schematron rule include.
  - Verifies procedural validation behavior and procedural error fallback path.

- `run_schema_checks.ps1`
  - Validates schema explorer endpoints (`/api/schema/summary`, `/api/schema/tree`).
  - Checks expected root nodes and attribute source groups.

- `run_validation_checks.ps1`
  - Runs fixture-based validation and compares `actual` results against snapshot files in `expected`.

- `auto_complete_golden_declaration.ps1`
  - Utility script to iteratively auto-fix a golden declaration fixture based on current validation errors.

## Inputs/outputs

- Fixtures: `backend/tests/fixtures`
- Expected snapshots: `backend/tests/expected`
- Generated test results: `backend/tests/results`

## Notes

- Most scripts build and run a Docker container and remove it afterwards.
- Use each script's `-KeepContainer` switch when available for debugging.
