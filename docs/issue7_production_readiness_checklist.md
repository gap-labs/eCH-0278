# Issue #7 – Production Readiness Checklist

Status: Draft  
Scope: Delivery pipeline and runtime hardening for production deployment

---

## Goal

Bring the current backend/frontend stack from development-ready to production-ready with a clear minimum baseline and phased rollout.

---

## A) Must-have (v1 rollout gate)

These items should be completed before declaring production readiness.

### 1) CI/CD baseline

- [ ] Build backend and frontend images in GitHub Actions
- [ ] Tag images with immutable tags (e.g. git SHA)
- [ ] Push images to target registry
- [ ] Deploy to cluster from CI (environment-gated)
- [ ] Store deploy credentials/secrets in GitHub Environments or secret manager

**Acceptance:** A merge to `main` can produce and deploy reproducible images without local/manual docker builds.

### 2) Kubernetes deployment safety

- [ ] Add `readinessProbe` and `livenessProbe` for backend and frontend
- [ ] Define CPU/memory `requests` and `limits`
- [ ] Set rolling update strategy (`maxUnavailable: 0`, `maxSurge: 1` for frontend/backend where appropriate)
- [ ] Configure explicit image pull policy and immutable image tags

**Acceptance:** Rolling deploy has no avoidable downtime and pods recover automatically on failure.

### 3) Runtime configuration and secrets

- [ ] Separate production config from development defaults
- [ ] Keep secrets out of repo/images
- [ ] Wire all runtime-sensitive settings via env/configmap/secret

**Acceptance:** No prod credentials or sensitive values are baked into code or container image.

### 4) Basic security baseline

- [ ] Enable container image vulnerability scan in CI
- [ ] Enforce non-root container runtime where feasible
- [ ] Configure ingress TLS and baseline security headers
- [ ] Define request body limits for upload endpoints (XML upload/compare)

**Acceptance:** Pipeline blocks critical vulnerabilities (or requires explicit override) and ingress is TLS-protected.

### 5) Post-deploy verification

- [ ] Add smoke checks after deployment (`/api/schema/summary`, `/api/validate`, frontend route availability)
- [ ] Fail deployment if smoke checks fail
- [ ] Keep rollback command/path documented

**Acceptance:** Deploy success means service is actually reachable and functional.

---

## B) Should-have (shortly after go-live)

### 6) Observability

- [ ] Structured logs (request id, path, status, duration)
- [ ] Centralized log collection in cluster
- [ ] Minimal alerting (pod crash loops, high error rates, failing probes)

### 7) Supply-chain improvements

- [ ] Generate SBOM for built images
- [ ] Sign images and verify signature at deploy time (if policy supports it)

### 8) Operational runbook

- [ ] "How to deploy" and "how to rollback" steps
- [ ] "What to check first" troubleshooting section

---

## C) Nice-to-have

- [ ] Progressive delivery (canary/blue-green)
- [ ] Performance budgets and synthetic checks
- [ ] Periodic dependency update automation

---

## Proposed Implementation Order

1. CI image build + registry push
2. K8s probes/resources/rolling strategy
3. Secrets + runtime config cleanup
4. Post-deploy smoke checks + rollback procedure
5. Security scan gate
6. Observability and runbook

---

## Definition of Done for Issue #7

Issue #7 is complete when all **Must-have** items are checked and validated in one full `main -> CI -> cluster` cycle.
