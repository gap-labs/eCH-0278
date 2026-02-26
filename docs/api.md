# API Contract (v0.1)

This document describes the current backend API contract for XML schema validation.

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
  ]
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
  ]
}
```

### Notes

- The XSD is loaded at backend startup (fail fast on schema load errors).
- XML input is not persisted to disk.
- `namespaces` contains detected XML namespace declarations (`prefix`, `uri`).
- `errors` may include:
  - XML parse errors
  - XSD structure/content errors
  - Validation processing errors

---

## Future Endpoints (planned)

- `POST /api/compare` (planned for v0.1, not implemented yet)
