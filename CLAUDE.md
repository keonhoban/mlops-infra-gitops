# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

### Helm / CI Validation
```bash
# Lint a chart (strict mode)
helm lint charts/<service>/ -f envs/dev/<service>/values.yaml --strict

# Render manifests for inspection
helm template <release-name> charts/<service>/ -f envs/dev/<service>/values.yaml

# Validate rendered manifests against K8s 1.30.0 schema
helm template <release-name> charts/<service>/ -f envs/dev/<service>/values.yaml \
  | kubeconform -kubernetes-version 1.30.0 -strict

# YAML style check (must pass before PR)
yamllint -c .yamllint apps/ charts/ envs/ baseline/ bootstrap/ optional/
```

### Operational Make Targets
```bash
make optional-on       # Attach Feast/Redis Optional layer (ArgoCD manual sync)
make optional-off      # Detach Optional layer (non-destructive)
make proof-core        # Capture state snapshot: Core+Baseline, Optional OFF
make proof-optional    # Capture state snapshot: Core+Baseline+Optional ON
make proof-e2e         # Capture E2E serving evidence (Triton + FastAPI)
make audit             # Full system audit dump
make reseal-dev        # Re-seal SealedSecrets for dev
make reseal-prod       # Re-seal SealedSecrets for prod
make rotate-aws-dev    # Rotate AWS credentials (dev)
make rotate-aws-prod   # Rotate AWS credentials (prod)
make rotate-ss-key     # Rotate SealedSecrets controller key
```

## Architecture Overview

### Layer Model

The platform uses three independent, separately-deployable layers:

| Layer | Path | Sync | Purpose |
|---|---|---|---|
| **Core** | `apps/`, `charts/`, `envs/` | Automated | E2E model lifecycle (train → serve) |
| **Baseline** | `baseline/` | Automated | Always-on observability (MinIO, Loki, Prometheus) |
| **Optional** | `optional/` | **Manual** | Attach/detach extensions (Feast feature store) |

Optional is intentionally **manual sync** in ArgoCD (`bootstrap/root-optional.yaml`) to prevent accidental toggling. Use `make optional-on/off` to manage it.

### Core Service Startup Order (Sync Waves)

ArgoCD enforces startup ordering via sync waves in `apps/appset-core.yaml`:

```
Wave 10: MLflow   → must be up first (model registry)
Wave 20: Airflow  → depends on MLflow
Wave 30: Triton   → loads validated models from MLflow/NFS
Wave 40: FastAPI  → wraps Triton, serves traffic
```

### E2E Model Pipeline (Airflow DAG)

```
train → evaluate → register (MLflow) → validate → deploy (NFS) → reload (Triton API)
```

**Triton runs in `explicit` model-control mode** — it never auto-polls the model directory. The DAG must call the Triton reload API explicitly after writing the model to NFS. This prevents partially-written models from being auto-loaded.

### Environment Isolation

- Namespaces follow `{service}-{env}` (e.g., `airflow-dev`, `mlflow-prod`)
- AppProjects (`apps/project-dev.yaml`, `apps/project-prod.yaml`) enforce namespace whitelisting — no cross-environment deployments possible
- Environment overlays live in `envs/{dev|prod}/{service}/values.yaml` and are merged with base `charts/{service}/values.yaml` at sync time (multi-source ApplicationSet)

### Storage Architecture

- **MinIO** (Baseline): S3-compatible object store for Airflow remote logs and MLflow artifacts
- **NFS PV/PVC** (`envs/{env}/support/`): Shared `ReadWriteMany` volume for Triton model repository — `persistentVolumeReclaimPolicy: Retain` protects data during ArgoCD prune
- Both Airflow (write) and Triton (read) mount the same NFS PVC

### Secrets Management

All secrets are encrypted as **SealedSecrets** and committed to the repo. Plaintext secrets must never appear in Git.

- Sealed secret files live in `envs/{env}/*/sealed-secrets/`
- Use `ops/security/re-seal.sh` to re-encrypt after rotating values
- The SealedSecrets controller key is cluster-scoped — rotating it (`make rotate-ss-key`) requires re-sealing all secrets

### CI Pipeline

GitHub Actions (`.github/workflows/ci-helm-validate.yaml`) runs on PRs touching `charts/`, `envs/`, `apps/`, `baseline/`, `optional/`, `bootstrap/`:

1. `yamllint` — style check
2. `helm lint --strict` — per chart × {dev, prod}
3. `helm template` + `kubeconform` — schema validation against K8s 1.30.0
4. Validate env-specific resources and ArgoCD objects

Helm is pinned to **3.18.3** locally and in CI. Use this version to avoid template drift.

### Chart Structure

Each service chart in `charts/{service}/` wraps either an upstream dependency (Airflow uses the official Apache chart as a subchart) or is fully custom (MLflow, Triton, FastAPI). `charts/fastapi/app/` contains the embedded Python FastAPI source code.

### Optional Layer (Feast)

Feast is deployed via `optional/` with Redis as the online store. The documented migration path is Redis → ScyllaDB (Cassandra-compatible) for production scale. Toggle via `make optional-on/off` — toggling is non-destructive.

## Key File Locations

| Purpose | Path |
|---|---|
| Root ArgoCD bootstrap | `bootstrap/root-app.yaml` |
| Core ApplicationSet (all envs × services) | `apps/appset-core.yaml` |
| Environment AppProjects | `apps/project-dev.yaml`, `apps/project-prod.yaml` |
| Chart base values | `charts/{service}/values.yaml` |
| Env overlay values | `envs/{dev\|prod}/{service}/values.yaml` |
| Namespace / PV / PVC resources | `envs/{dev\|prod}/support/` |
| Baseline observability | `baseline/` |
| Optional toggle scripts | `ops/toggle/optional_on.sh`, `ops/toggle/optional_off.sh` |
| Proof capture scripts | `ops/proof/` |
| Security / secret rotation | `ops/security/` |
| Architecture docs | `docs/overview/` |
| Runbooks | `docs/runbook/` |
| Evidence snapshots | `docs/proof/latest/` |
