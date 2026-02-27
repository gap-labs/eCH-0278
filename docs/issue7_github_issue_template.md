# Issue #7: Production Readiness Baseline

## Goal

Establish a minimum production baseline for CI/CD, deployment safety, runtime configuration, and verification for the eCH-0278 stack.

---

## Scope

- Build and publish reproducible backend/frontend images from CI
- Deploy from CI to cluster with environment-gated credentials
- Add deployment safety controls (probes/resources/rolling strategy)
- Separate runtime config/secrets from image and source
- Add minimal security and post-deploy smoke checks

Out of scope for this issue:
- Canary/blue-green rollout
- Advanced performance testing
- Full observability platform expansion

---

## Tasks (Must-have)

### CI/CD
- [ ] GitHub Actions builds backend image
- [ ] GitHub Actions builds frontend image
- [ ] Images tagged with immutable tag (git SHA)
- [ ] Images pushed to registry
- [ ] Deployment job to cluster added (protected environment)

### Kubernetes Safety
- [ ] Backend `readinessProbe` and `livenessProbe`
- [ ] Frontend `readinessProbe` and `livenessProbe`
- [ ] CPU/memory `requests` and `limits` defined
- [ ] Rolling update settings configured
- [ ] Deploy uses immutable image references

### Runtime Config & Secrets
- [ ] Production config values externalized (env/configmap/secret)
- [ ] Secrets removed from code/image
- [ ] CI deploy secrets stored in GitHub Environments (or equivalent)

### Security Baseline
- [ ] Container vulnerability scan in CI
- [ ] Non-root runtime where feasible
- [ ] TLS enabled at ingress
- [ ] Upload/request limits configured for XML endpoints

### Post-Deploy Verification
- [ ] Smoke check frontend route availability
- [ ] Smoke check `/api/schema/summary`
- [ ] Smoke check `/api/validate` (happy-path fixture)
- [ ] Deployment fails if smoke checks fail
- [ ] Rollback procedure documented

---

## Acceptance Criteria

- A `main` merge can trigger a full CI pipeline that builds, publishes, and deploys both services.
- Deployment uses immutable image references and rolls out without avoidable downtime.
- Secrets are not embedded in code or container images.
- Smoke checks pass automatically after deploy; failures are visible and block success.

---

## Definition of Done

- All Must-have tasks above are completed and validated in one end-to-end cycle:
  - `main` merge -> CI build/push -> deploy -> smoke checks green.

---

## Suggested labels

- `production`
- `devops`
- `ci-cd`
- `security`

---

## Optional follow-up issues

- Observability hardening (structured logs, alerts)
- SBOM + image signing
- Progressive delivery strategy
