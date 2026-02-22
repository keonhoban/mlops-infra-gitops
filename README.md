# GitOps 기반 E2E ML Platform (Core / Baseline / Optional)

이 프로젝트는 **GitOps(ArgoCD)** 를 운영 중심축으로 삼아,
**모델 학습 → 등록 → 검증 → 배포 → 트래픽 전환 → 실패 시 롤백**까지를 **재현 가능하게 자동화**한 ML Platform입니다.

핵심 키워드:

- **Separation**: dev/prod, Core/Baseline/Optional 경계가 구조적으로 분리됨
- **Automation**: Airflow → MLflow → Triton → FastAPI E2E 루프 자동화
- **Proof**: 토글/경계/헬스 상태를 스냅샷으로 남겨 “말이 아닌 증거”로 제시

---

## TL;DR (요약)

- **Core**: Airflow가 모델 생명주기(학습/등록/검증/배포/롤백)를 통제하고
Triton/FastAPI가 런타임 전환(Load/Ready/Smoke/Reload)을 수행합니다.
- **Baseline**: 운영 필수 기반(Storage/Logging/Monitoring)은 **항상 ON** 입니다.
- **Optional**: Feature Store(Feast 등)는 **Attach/Detach** 하며, OFF 시에는 “비파괴 Detach”로 경계를 유지합니다.
- Optional 토글 및 Core-only 경계는 `docs/proof/` 산출물로 증명합니다.

---

## Why (이 플랫폼이 필요한 이유)

모델 성능 개선은 반복 실험으로 가능하지만,
운영 환경에서의 **모델 교체·검증·롤백·관측은 시스템적 통제**가 필요합니다.

이 플랫폼은 다음을 목표로 설계되었습니다:

- 수동 배포 제거: **Git 커밋 기반 운영**
- 모델 전환 시 무중단 검증: **Ready/Smoke/Reload**
- 실패 시 안전장치: **Rollback(마지막 정상 상태 복원)**
- 환경 충돌 방지: **dev/prod AppProject + Namespace 격리**
- 변경 이력 추적: **Proof 스냅샷으로 감사 가능**

---

## Architecture (설계)

### Core (E2E Model Lifecycle)

- Airflow (E2E DAG)
- MLflow (Tracking/Registry)
- Triton Inference Server (Serving)
- FastAPI (Alias A/B 라우팅 + Reload API)

### Baseline (Always-on Operational Foundation)

운영 안정성에 필요한 기반층으로 **항상 활성화**됩니다.

- MinIO (S3 compatible storage)
- Logging: Loki + Alloy
- Monitoring: kube-prometheus-stack + extra rules/monitors/secrets

### Optional (Attach/Detach Extensions)

필요할 때만 붙였다 떼는 확장 레이어입니다.

- Feature Store: Feast (+ Redis)

> Optional OFF는 “비파괴 Detach”입니다.
`feature-store-dev/prod` namespace는 경계/재부착 안정성을 위해 유지되며,
실제 Feast/Redis 리소스는 Optional ON에서만 생성됩니다.
> 

---

## E2E Flow (Core)

Airflow → MLflow → Triton → FastAPI

배포 성공 기준(모두 만족해야 성공):

1. MLflow Registry 등록 성공
2. READY Sensor 통과
3. Triton Load 성공
4. Triton Smoke Test(Inference) 성공
5. FastAPI Reload 성공
6. Slack 알림 전송 확인

실제 흐름 정의: `docs/overview/e2e-flow.md`

---

## Proof (증거)

### 1) Core-only(=Core+Baseline) 경계 증명

- Optional OFF 이후 Optional scope=0 확인 로그 포함
- `/health`, Triton ready probe 결과 포함

경로:

- `docs/proof/latest/core_only/`

### 2) Optional ON 증명

- optional-envs-dev/prod + feast-dev/prod attach 성공 로그 포함

경로:

- `docs/proof/latest/optional_on/`

---

## Quickstart (데모 동선)

- Core-only 증명: `make proof-core` (또는 `./ops/proof/proof_core_only.sh`)
- Optional ON: `make optional-on` (또는 `./ops/toggle/optional_on.sh`)
- Optional OFF: `make optional-off` (또는 `./ops/toggle/optional_off.sh`)
- GitOps 상태 확인: `argocd app list`

---

## Docs (읽는 순서)

1. Overview (구조/흐름)
- `docs/overview/architecture.md`
- `docs/overview/e2e-flow.md`
- `docs/overview/argocd-boundary.md`
1. Runbook / Security (운영)
- `docs/runbook/optional-toggle.md`
- `docs/security/secrets.md`
1. Proof (증거)
- `docs/proof/`

---

## Repository Map

| Directory | Purpose |
| --- | --- |
| apps/ | ArgoCD ApplicationSet / AppProject 정의 |
| bootstrap/ | root-apps / root-baseline / root-optional |
| charts/ | Core Helm charts |
| envs/ | Core 운영 리소스 (dev/prod values & support) |
| baseline/ | Baseline stack (MinIO/Loki/Alloy/Monitoring) |
| optional/ | Optional 확장 레이어 (Feast 등) |
| ops/ | proof / toggle / security (운영 스크립트) |
| docs/ | overview / runbook / security / proof |
