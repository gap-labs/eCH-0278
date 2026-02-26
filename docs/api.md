# API Contract (v0.1)

This document describes the current backend API contract for XML schema validation and snapshot comparison.

---

## POST /api/validate

Validate an uploaded XML file against the normative eCH-0278 XSD.

### Request

- Method: `POST`
- Content-Type: `multipart/form-data`
- Form field: `file` (XML file)

### Success Response (`200 OK`)

```json
{
  "xsdValid": true,
  "errors": [],
  "namespaces": [
    {
      "prefix": "eCH-0278",
      "uri": "http://www.ech.ch/xmlns/eCH-0278/1"
    }
  ],
  "analysis": {
    "taxProceduresFound": ["declaration"],
    "phaseDetected": "declaration",
    "snapshotWarning": false
  }
}
```

### Validation Error Response (`200 OK`)

The endpoint reports validation or parse issues in `errors` while returning `xsdValid: false`.

```json
{
  "xsdValid": false,
  "errors": [
    "XML parse error: ..."
  ],
  "namespaces": [
    {
      "prefix": "eCH-0278",
      "uri": "http://www.ech.ch/xmlns/eCH-0278/1"
    }
  ],
  "analysis": {
    "taxProceduresFound": [],
    "phaseDetected": "unknown",
    "snapshotWarning": false
  }
}
```

### Notes

- The XSD is loaded at backend startup (fail fast on schema load errors).
- XML input is not persisted to disk.
- `namespaces` contains detected XML namespace declarations (`prefix`, `uri`).
- `analysis` is non-normative lifecycle interpretation based on `taxProcedure` attributes:
  - `phaseDetected`: `declaration | taxation | mixed | unknown`
  - `snapshotWarning`: `true` only for `mixed`
- `errors` may include:
  - XML parse errors
  - XSD structure/content errors
  - Validation processing errors

---

## POST /api/compare

Compare two uploaded XML snapshot documents with a minimal leaf-value diff.

### Request

- Method: `POST`
- Content-Type: `multipart/form-data`
- Form fields:
  - `xml1` (XML file)
  - `xml2` (XML file)

### Success Response (`200 OK`)

```json
{
  "xml1Valid": true,
  "xml2Valid": true,
  "diffSummary": {
    "changedValues": 3,
    "addedNodes": 1,
    "removedNodes": 0
  }
}
```

### Notes

- Both files are validated against the normative XSD first.
- `xml1Valid` and `xml2Valid` report XSD validation outcome per file.
- The diff is intentionally minimal for v0.1:
  - compares only leaf node values
  - counts added/removed leaf nodes by path and occurrence
  - does not provide a full structural diff
