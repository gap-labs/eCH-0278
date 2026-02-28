# Test Schematron Rules

This directory contains Schematron rules that are used only for tests.

- They are excluded from production by default.
- The procedural smoke rule validates the end-to-end procedural pipeline.

To include these rules in the backend test image, use:

- `--build-arg SCHEMATRON_INCLUDE_GLOB=tests/rules/procedural_smoke.sch`
