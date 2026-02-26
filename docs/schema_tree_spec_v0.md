# eCH-0278 Architecture Explorer

## Schema Tree JSON Specification (v0.1)

Status: Draft v0.1
Scope: Backend → Frontend contract for XSD structure exploration
Principle: Preserve structural proximity to the normative XSD (no JSON-Schema abstraction layer)

---

# 1. Design Goals

The Schema Tree JSON must:

* Represent the structural model of the XSD
* Preserve element/type relationships
* Preserve cardinality (minOccurs / maxOccurs)
* Preserve attribute groups (e.g. taxProcedureGroup)
* Preserve enumeration values of simple types
* Avoid UI-specific logic
* Be deterministic and reproducible

The structure is optimized for exploration, not for form generation.

---

# 2. Top-Level API Contract

## GET /api/schema/summary

Returns minimal schema metadata.

```json
{
  "schemaVersion": "1.0.0",
  "targetNamespace": "http://www.ech.ch/xmlns/eCH-0278/1",
  "rootElements": [
    "naturalPersonTaxData"
  ]
}
```

---

## GET /api/schema/tree

Returns the full expanded structure starting from the root element.

```json
{
  "root": { SchemaNode }
}
```

---

# 3. SchemaNode Definition

Every node in the tree follows this structure.

```json
{
  "name": "naturalPersonTaxData",
  "kind": "element",
  "type": "naturalPersonTaxDataType",
  "namespace": "http://www.ech.ch/xmlns/eCH-0278/1",
  "cardinality": {
    "min": 1,
    "max": 1
  },
  "attributes": [],
  "enumeration": null,
  "children": []
}
```

---

# 4. Field Specification

## 4.1 name

String. Element or type name exactly as defined in XSD.

---

## 4.2 kind

One of:

* "element"
* "complexType"
* "simpleType"
* "attribute"

---

## 4.3 type

String or null.

For elements:

* The referenced XSD type name.

For simple types:

* null.

---

## 4.4 namespace

String.

Equal to XSD targetNamespace.

---

## 4.5 cardinality

Object or null.

```json
{
  "min": 0,
  "max": 1
}
```

If maxOccurs="unbounded":

```json
{
  "min": 0,
  "max": "unbounded"
}
```

For types: null.

---

## 4.6 attributes

Array of attribute definitions.

```json
[
  {
    "name": "taxProcedure",
    "type": "taxProcedureType",
    "enum": ["declaration", "taxation"],
    "source": "taxProcedureGroup"
  }
]
```

Fields:

| Field  | Description                                         |
| ------ | --------------------------------------------------- |
| name   | Attribute name                                      |
| type   | XSD type name                                       |
| enum   | Enumeration values if simpleType restriction exists |
| source | AttributeGroup name if derived from group           |

---

## 4.7 enumeration

Array of strings or null.

Used only for simpleType nodes.

```json
"enumeration": ["declaration", "taxation"]
```

---

## 4.8 children

Array of SchemaNode objects.

Only present for elements and complex types.

---

# 5. Expansion Rules (v0.1)

* Root element is fully expanded.
* Direct child elements are expanded.
* Complex types are expanded inline.
* Simple types include enumeration if present.
* AttributeGroups are resolved and expanded into attributes.
* No cyclic reference handling required for v0.1.
* No documentation annotations required for v0.1.

---

# 6. Example (Reduced Realistic Fragment)

```json
{
  "name": "domesticAndForeignIncome",
  "kind": "element",
  "type": "incomeType",
  "namespace": "http://www.ech.ch/xmlns/eCH-0278/1",
  "cardinality": { "min": 1, "max": 1 },
  "attributes": [],
  "enumeration": null,
  "children": [
    {
      "name": "totalAmountRevenue",
      "kind": "element",
      "type": "moneyType",
      "cardinality": { "min": 1, "max": 1 },
      "attributes": [
        {
          "name": "taxProcedure",
          "type": "taxProcedureType",
          "enum": ["declaration", "taxation"],
          "source": "taxProcedureGroup"
        }
      ],
      "enumeration": null,
      "children": []
    }
  ]
}
```

---

# 7. Non-Goals (v0.1)

* No JSON Schema transformation
* No UI generation hints
* No lifecycle semantics
* No validation logic
* No cross-reference graph

---

# 8. Rationale

The Schema Tree JSON intentionally mirrors XSD modelling decisions to:

* Preserve structural transparency
* Allow architectural discussion
* Highlight reuse via AttributeGroups
* Support lifecycle and modelling analysis in later versions

The goal is exploration, not abstraction.

---

End of Schema Tree Specification v0.1
