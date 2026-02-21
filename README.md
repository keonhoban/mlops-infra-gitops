# GitOps 기반 E2E ML Platform (Core / Baseline / Optional 분리)

Production-grade ML Platform을 GitOps(ArgoCD) 기반으로 설계·운영한 프로젝트입니다.

- **Core**: 모델 생명주기 E2E 자동화 루프 (Airflow → MLflow → Triton → FastAPI)
- **Baseline**: 운영 필수 기반층 (S3/Logging/Monitoring) — 항상 ON
- **Optional**: 실험/확장 레이어 (Feature Store 등) — Attach/Detach

---

## Why This Platform Exists

모델 성능 개선은 반복 실험으로 가능하지만,
운영 환경에서의 **모델 교체·검증·롤백·관측은 시스템적 통제**가 필요합니다.

이 플랫폼은 다음 문제를 해결하기 위해 설계되었습니다:

- 수동 배포 제거 (Git 커밋 기반 운영)
- 모델 전환 시 무중단 검증(Ready/Smoke/Reload)
- 실패 시 자동 롤백(이전 정상 버전 복원)
- dev / prod 환경 충돌 방지(AppProject/Namespace 격리)
- 변경 이력 추적 및 감사(Proof 스냅샷)

---

## Architecture Overview

GitOps(ArgoCD)를 중심으로 다음 파이프라인을 구성합니다:

**Airflow → MLflow → Triton → FastAPI**

- 모든 변경은 Git Commit에서 시작
- ArgoCD가 상태를 강제(SelfHeal/Prune)
- Airflow가 모델 생명주기(학습/등록/검증/배포/롤백)를 제어
- Triton/FastAPI는 런타임 트래픽 전환을 담당

dev / prod는 AppProject 단위로 완전 분리됩니다.

---

## Layer Definition (Core / Baseline / Optional)

### Core (E2E Model Lifecycle)

- Airflow (E2E DAG)
- MLflow (Tracking/Registry)
- Triton Inference Server (Serving)
- FastAPI (A/B alias 기반 트래픽 제어, Reload)

### Baseline (Always-on Operational Foundation)

운영 안정성에 필요한 기반층으로 **항상 활성화됩니다**.

- MinIO (S3 compatible storage)
- Logging: Loki + Alloy
- Monitoring: kube-prometheus-stack + extra rules/monitors/secrets

Monitoring ingress (실제 클러스터 기준):
- dev: grafana-dev.local / alert-dev.local / prometheus-dev.local
- prod: grafana-prod.local / alert-prod.local / prometheus-prod.local

### Optional (Attach/Detach Extensions)

필요할 때만 붙였다 떼는 확장 레이어입니다.

- Feature Store: Feast (+ Redis)
- (확장 후보) Tempo/Pyroscope 등 추가 컴포넌트

> Optional OFF는 “비파괴 Detach”입니다. feature-store-* namespace는 경계/재부착 안정성을 위해 유지되며,  
> 실제 Feast/Redis 리소스는 Optional ON에서만 생성됩니다.

---

## Deployment Success Criteria (Core 기준)

모델 배포는 아래 조건을 모두 만족할 때 성공으로 간주합니다.

1. MLflow Registry에 새로운 모델 버전 등록 성공
2. READY Sensor 통과
3. Triton Inference Smoke Test 성공
4. FastAPI Reload 성공
5. Slack 알림 전송 확인

위 단계 중 하나라도 실패하면 Rollback DAG가 실행됩니다.

---

## One Commit Flow

1. Pull Request 생성
2. GitHub Actions: Helm Lint / Render / kubeconform 검증
3. main 브랜치 머지
4. ArgoCD Auto Sync 반영
5. Airflow DAG 실행 (Train → Evaluate → Register)
6. READY Sensor 통과
7. Triton 모델 배포
8. FastAPI Reload
9. 트래픽 전환
10. 실패 시 Rollback DAG 실행

---

## Quickstart

- Core/Baseline 상태 확인(증명): `./ops/proof/proof_core_only.sh`
  - *주의*: 본 프로젝트에서 “core_only”는 **Optional이 없는 상태(Core+Baseline)** 를 의미합니다.
- Optional ON: `./ops/toggle/optional_on.sh` (Feast/feature-store 등 Attach)
- Optional OFF: `./ops/toggle/optional_off.sh` (Optional 리소스 Detach)

- Makefile shortcut: `make help` (e.g. `make proof-core`, `make optional-on`)
- GitOps 상태 확인: `argocd app list`

---

## Repository Structure

| Directory | Purpose |
| --- | --- |
| apps/ | ArgoCD ApplicationSet / AppProject 정의 |
| bootstrap/ | root-apps / root-baseline / root-optional |
| charts/ | Core Helm charts |
| envs/ | Core 운영 리소스 |
| baseline/ | Baseline stack (MinIO/Loki/Alloy/Monitoring) |
| optional/ | Optional 확장 레이어 (Feast 등) |
| ops/ | proof / toggle / security |
| docs/ | architecture / runbook / proof |
