# Schematron Rules (Test Artifacts)

`procedural_smoke.sch` is a test-only smoke rule used to validate the procedural pipeline end-to-end:

- Schematron source detection in Docker build stage
- SchXslt transpilation to runtime XSLT
- Saxon/C execution in `POST /api/validate?procedural=true`
- Mapping of SVRL output into `proceduralFindings`

This file is not a domain/business rule set for v0.2 production behavior.
