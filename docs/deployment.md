# Deployment Guide

This document contains the operational deployment information that is intentionally not kept in `README.md`.

---

## 1. Runtime Topology

- Kubernetes namespace: `ech-0278`
- Public host: `ech-0278.gap-labs.net`
- Ingress class: GKE (`gce`)
- TLS: GKE `ManagedCertificate`
- HTTP -> HTTPS redirect: GKE `FrontendConfig`
- Frontend service is the public ingress target; frontend proxies `/api` to backend

---

## 2. CI/CD Workflow

Workflow: `.github/workflows/deploy.yml`

Triggers:
- `push` on `main`
- `workflow_dispatch`

Pipeline flow:
1. Authenticate to Google Cloud via Workload Identity Federation
2. Build backend/frontend images
3. Push images to Artifact Registry with immutable SHA tags
4. Apply Kubernetes manifests in `infra/k8s`
5. Update deployment images (`kubectl set image`)
6. Wait for rollout (`backend`, `frontend`)
7. Smoke checks via service port-forward

---

## 3. Required GitHub Secrets

- `GCP_WORKLOAD_IDENTITY_PROVIDER`
- `GCP_SERVICE_ACCOUNT`
- `GCP_PROJECT_ID`
- `GKE_CLUSTER`
- `GKE_LOCATION`

---

## 4. Kubernetes Manifests

Directory: `infra/k8s`

- `namespace.yaml`
- `resource-quota.yaml`
- `limit-range.yaml`
- `backend.yaml`
- `frontend.yaml`
- `backendconfig.yaml`
- `frontendconfig.yaml`
- `managed-certificate.yaml`
- `ingress.yaml`
- `network-policy-default-deny.yaml`
- `network-policy-frontend-ingress.yaml`
- `network-policy-backend-ingress.yaml`
- `pod-disruption-budget.yaml`
- `hpa.yaml`
- `pod-monitoring.yaml`
- `alerts-rules.yaml`

---

## 5. Cloud Armor Setup (one-time, outside CI)

CI does not create security policies. The `BackendConfig` references `ech-0278-armor`, which must exist once.

Create policy:

```powershell
gcloud compute security-policies create ech-0278-armor `
  --description="Baseline protection for eCH-0278"
```

Add baseline throttle rule:

```powershell
gcloud compute security-policies rules create 1000 `
  --security-policy=ech-0278-armor `
  --expression="request.method == 'POST' && (request.path == '/api/validate' || request.path == '/api/compare')" `
  --action=throttle `
  --rate-limit-threshold-count=20 `
  --rate-limit-threshold-interval-sec=60 `
  --conform-action=allow `
  --exceed-action=deny-429 `
  --enforce-on-key=IP
```

---

## 6. DNS and TLS Notes

- Point `ech-0278.gap-labs.net` to the ingress external address.
- Keep Cloudflare SSL mode on `Full (strict)` if Cloudflare proxy is enabled.
- TLS certificate readiness depends on DNS visibility.

---

## 7. Frontend Cache Strategy

`frontend/nginx.conf` is configured so that:
- `index.html` is not cached (`no-store`) to avoid stale app shell issues
- hashed static assets (`*.css`, `*.js`, etc.) are long-lived and immutable

This reduces stale UI states after deployments.
