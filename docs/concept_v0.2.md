# eCH-0278 Architecture Explorer

## Concept v0.2 – Procedural Consistency Layer

Status: Draft (Refined, pre-implementation)
Scope: Conceptual extension of v0.1
Principle: No business logic. No tax calculation. Structural + procedural consistency only.

---

# 1. Motivation

Version v0.1 established:

* Deterministic XSD validation
* Structural lifecycle detection (`taxProcedure` overlay)
* Structural comparison between documents

v0.2 adds a second deterministic analysis layer:

> Formalized procedural consistency between schema-valid XML and lifecycle/actor assumptions.

Goal:

* Make implicit procedural assumptions explicit and testable
* Keep interpretation descriptive (not legal, not fiscal)

---

# 2. Layer Model and Boundaries

## Layer 1 – Structural Validity (XSD)

* Element existence
* Cardinality
* Type constraints
* Enumerations

## Layer 2 – Procedural Consistency (Schematron)

* Lifecycle-phase consistency
* Actor-dependent constraints
* Cross-field dependencies
* Contextual structure rules

## Layer 3 – Material Law (Out of Scope)

* Tax calculation logic
* Legal interpretation
* Cantonal policy enforcement

v0.2 explicitly includes only Layers 1 and 2.

---

# 3. Evaluation Axes

## 3.1 Horizontal Axis – Time (Lifecycle Stability)

Evaluation questions:

* Is temporal context explicit (for example tax year/version markers)?
* Is the tax year structurally mandatory for lifecycle interpretation?
* Are external references version-aware?
* Are lifecycle transitions structurally coherent?

Typical checks (examples):

* Taxation-value presence must be consistent with declared lifecycle phase.
* Mixed declaration/taxation states must be explicitly detectable.
* Required temporal markers must be present.

## 3.2 Vertical Axis – Transfer (Actor Consistency)

Evaluation questions:

* Can authority-only data appear in taxpayer submissions?
* Is authority metadata structurally separable?
* Are actor-specific states distinguishable?

Typical checks (examples):

* Taxation-specific blocks must not appear in pre-submission declaration packages.
* Archive/finalized states may include taxation values.
* Authority metadata must remain structurally separated from taxpayer declaration data.

---

# 4. Backend Integration Concept (FastAPI in GKE)

This project already runs a FastAPI backend pod in GKE. v0.2 extends that backend conceptually with a procedural validation endpoint.

## 4.1 Endpoint Strategy (Conceptual)

Preferred option for clarity and compatibility:

* Keep a single entry point: `POST /api/validate`.
* Add query parameter `procedural=true|false` (default: `false`).
* Extend response envelope with `structuralErrors` and `proceduralFindings`.
* When `procedural=false`, `proceduralFindings` is always `[]`.

Rationale:

* No contract break for existing clients.
* Clean rollout path behind feature flag/UI toggle.
* Same pipeline entry for structural and procedural modes.

## 4.2 Processing Pipeline (Conceptual)

1. Receive XML upload (multipart)
2. Parse + fail fast on malformed XML
3. Run XSD validation (layer 1 gate)
4. Run Schematron rules (layer 2)
5. Merge findings into deterministic report envelope
6. Return structured response (no persistence of source XML)

## 4.3 Runtime/Platform Constraints

* Runs in existing backend pod model (no new service required for v0.2)
* Respect existing upload/rate limits unless explicitly revised
* Deterministic and bounded processing time per request
* No storage of uploaded XML beyond request lifecycle

---

# 5. Schematron as Procedural Bridge

Schematron is used as declarative rule layer that:

* References the same XML structure already validated by XSD
* Expresses context-sensitive procedural constraints
* Produces deterministic machine-readable findings

Schematron does not:

* Replace XSD
* Implement tax law
* Infer economic meaning

---

# 6. Findings Model (Normative for v0.2 API)

Findings must be descriptive, deterministic and stable across runs for identical input.

## 6.1 Finding Fields

Minimum field set:

* `code` (stable rule identifier)
* `ruleVersion` (optional, semantic rule-set or rule revision version)
* `severity` (`info | warning | error`)
* `layer` (`structural | procedural`)
* `message` (human-readable, non-legal wording)
* `paths` (0..n XPath-like references)
* `axis` (`time | transfer | none`)

Versioning note:

* `ruleVersion` enables clean evolution of procedural rules and reproducible findings across releases.

## 6.2 Envelope Separation

Response separates at least:

* `structuralErrors` (XSD/parser)
* `proceduralFindings` (Schematron-derived)
* Informational lifecycle indicators

Processing rule:

* Procedural `error` findings are analysis outcomes and do not imply HTTP transport failure.

## 6.3 Example Finding

```json
{
	"code": "taxation_values_in_declaration_phase",
	"ruleVersion": "1.0.0",
	"severity": "error",
	"layer": "procedural",
	"axis": "time",
	"message": "Taxation values are present while the document is marked as declaration phase.",
	"paths": [
		"/naturalPersonTaxData/taxData/taxation/.../totalAmountRevenue"
	]
}
```

---

# 7. Minimal Rule Baseline (v0.2.0)

v0.2 starts with a deliberately small procedural rule set.

Target baseline for first cut:

* 6–10 rules total
* Coverage of both axes (`time`, `transfer`)
* At least one rule per severity class
* All rule codes documented in API contract

Rule quality requirements:

* Deterministic output for identical input
* No dependence on external online services
* No legal interpretation language in findings

## 7.1 Rule Catalog v0.2.0 (Draft)

The following starter set defines the initial 8 procedural rules.

| Code | Axis | Severity | Intent |
|---|---|---|---|
| `taxation_values_in_declaration_phase` | `time` | `error` | Flag taxation-value presence in documents marked as declaration phase. |
| `declaration_values_in_taxation_phase` | `time` | `warning` | Flag declaration-only markers in taxation phase where mixed state is likely. |
| `mixed_taxprocedure_state_detected` | `time` | `info` | Detect coexistence of declaration and taxation markers in one document. |
| `missing_temporal_context_marker` | `time` | `warning` | Require core temporal context markers needed for lifecycle interpretation. |
| `authority_block_in_submission_context` | `transfer` | `error` | Flag authority-only blocks in taxpayer-submission context. |
| `taxpayer_block_in_authority_finalize_context` | `transfer` | `warning` | Flag taxpayer-editable blocks in authority finalization context. |
| `authority_metadata_not_separated` | `transfer` | `warning` | Detect insufficient structural separation of authority metadata. |
| `actor_context_not_derivable` | `transfer` | `info` | Report when actor context cannot be inferred from structural markers. |

Catalog constraints:

* Each rule must map to one primary axis (`time` or `transfer`).
* Each rule code must remain stable across patch releases.
* Breaking semantic changes require `ruleVersion` increment.

---

# 8. Operational Positioning

v0.2 remains architecture-focused and minimal:

From:

"Schema Visualization Tool"

To:

"Structural + Procedural Determinism Evaluator"

Deployment model remains unchanged (Angular frontend + FastAPI backend in GKE).

---

# 9. Non-Goals of v0.2

* No tax calculation engine
* No legal reasoning automation
* No cantonal rule implementation
* No dynamic rule editor
* No policy optimization/evaluation

---

# 10. Definition of Done (Concept v0.2)

v0.2 concept is considered implementation-ready when:

1. Endpoint strategy is fixed (`POST /api/validate` with `procedural` query parameter)
2. Minimal rule baseline is documented with stable rule codes
3. Findings envelope is documented in `docs/api.md`
4. UI behavior is decided (procedural checks optional vs default)
5. Performance target is stated (for example response budget at nominal file size)

---

# 11. Open Questions

* Should procedural validation be enabled by default in UI?
* Which response-time budget is acceptable under current pod sizing?
* Should any `warning` in the starter catalog be promoted to `error` before implementation?

---

End of Concept v0.2 (Refined Draft)
