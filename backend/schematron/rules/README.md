# Schematron Rules (Production)

This folder contains production Schematron rules only.

Test-only smoke rules are kept in `backend/tests/rules` so they are not part of
the production rules tree by default.

To include test-only rules in dedicated test builds, pass:

- `--build-arg SCHEMATRON_INCLUDE_GLOB=tests/rules/procedural_smoke.sch`
