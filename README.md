# GitOps 기반 E2E MLOps Core Platform

> **One Commit Flow — Build → Register → Deploy → Switch**
> 

## Core가 증명하는 것

- GitOps(ArgoCD)로 **dev/prod 분리** 및 자동 동기화(SelfHeal/Prune)
- PR 단계에서 Helm Lint / Render / kubeconform 기반 **사전 검증(CI)**
- Airflow(DAG gitSync) → MLflow Registry → Triton Deploy → FastAPI Reload
- 실패 시 Sensor / Smoke Test 기반 **자동 Rollback 가능**

## 빠른 증명(Proof)

- Core only 증명 스크립트: `./ops/proof/proof_core_only.sh`
- Optional ON/OFF 토글:
    - ON: `./ops/toggle_optional_on.sh`
    - OFF: `./ops/toggle_optional_off.sh`
- 실행 증적은 `docs/proof/` 하위에 자동 저장됩니다.

## Repo 안내

- `apps/` : ArgoCD ApplicationSet / AppProject
- `charts/` : Core Helm charts (airflow / mlflow / triton / fastapi)
- `envs/` : dev/prod 공통 운영 리소스
    
    (네임스페이스, certificates, sealed-secrets, feature-store contract 등)
    
- `optional/` : Monitoring / Logging / Feature Store 등 **운영 확장 영역**
- `docs/runbook/` : 운영 절차 및 토글 가이드

> **Git 커밋 한 번으로
학습 → 등록 → 배포 → 실험 전환까지 자동 순환되는
GitOps 기반 MLOps Core 플랫폼**
> 

---

## 1. What This Project Proves

이 프로젝트는 단순한 ML 파이프라인 구현이 아니라,

**프로덕션 환경에서 요구되는 MLOps Core 요건을
GitOps 기반으로 “운영 가능하게” 증명하는 것**을 목표로 합니다.

- 수동 배포 / 수동 롤백 없는 **완전 자동화 흐름**
- dev / prod 환경 분리와 상태 고정
- 실패 시 즉시 복원 가능한 운영 구조
- 코드가 아니라 **동작으로 증명되는 인프라**

---

## 2. Core Architecture

### 핵심 구성 요소

| 영역 | 스택 | 역할 |
| --- | --- | --- |
| Orchestration | **Airflow (KubernetesExecutor)** | 학습 → 평가 → 등록 → 롤백 제어 |
| Experiment | **MLflow (Tracking + Registry)** | 실험 / 모델 버전 관리 |
| Model Serving | **Triton Inference Server** | 고성능 모델 서빙, 런타임 분리 |
| API Layer | **FastAPI** | A/B · Canary · Blue-Green 트래픽 제어 |
| Deployment | **ArgoCD (GitOps)** | Auto Sync · SelfHeal · Prune |
| Storage | **S3 + NFS + PostgreSQL** | 모델 / 로그 / 메타데이터 관리 |

---

## 3. One Commit Flow

(설계 의도상 Mermaid 다이어그램은 제거하고, 흐름을 문장으로 고정합니다)

1. Pull Request 생성
2. GitHub Actions에서 Helm Lint / Render / kubeconform 검증
3. main 브랜치 머지
4. ArgoCD Auto Sync로 dev/prod 환경 반영
5. Airflow DAG 실행
    
    (Train → Evaluate → Register)
    
6. Model READY Sensor 통과
7. Triton 모델 배포 (model repo 갱신)
8. FastAPI Reload
9. 트래픽 전환 (A/B · Canary · Blue-Green)
10. 실패 시 Rollback DAG 실행

> **코드 변경 → 자동 배포 → 자동 실험 전환**
> 
> 
> 운영 개입 없이 반복 가능한 MLOps 루프
> 

---

## 4. Proof of Operation

### ✅ One-command Proof (Core)

```bash
./ops/proof/proof_core_only.sh

```

- Core(E2E) 상태 점검 및 증적을 자동 수집합니다.
- 결과는 `docs/proof/` 하위에 텍스트로 저장됩니다.
- Optional 컴포넌트는 토글 스크립트로 별도 제어합니다.

---

### ① dev / prod 환경 분리

```bash
kubectl get ns | egrep "airflow-|mlflow-|fastapi-|triton-"

```

---

### ② Feature Store Contract GitOps 관리

```bash
kubectl get cm -A -l mlops.keonho.io/env=dev
kubectl get cm -A -l mlops.keonho.io/env=prod

```

---

### ③ Runtime Mount 검증 (Airflow)

```bash
kubectl -n airflow-dev exec <scheduler-pod> -- \
ls /opt/airflow/feature-store

```

---

### ④ GitOps Sync 상태 확인

```bash
argocd app list

```

→ **설명 없이도 동작으로 증명 가능한 상태**

---

## 5. Repository Structure (Core 기준)

```bash
mlops-infra/
├── charts/            # airflow / mlflow / triton / fastapi
├── apps/              # root-app, namespaces, appset-core
├── envs/              # dev / prod 환경 정의
├── ops/               # secret rotation / reseal / proof scripts
└── (external) airflow-dags repo
     └── DAGs pulled via gitSync

```

---

## 6. Operational Principles

| 항목 | 설계 원칙 |
| --- | --- |
| 배포 | GitOps 기반 Auto Sync + SelfHeal |
| 안정성 | Sensor READY 후 Reload |
| 롤백 | DAG 기반 이전 정상 버전 복원 |
| 환경 | dev / prod 완전 분리 |
| 검증 | kubectl / argocd / proof script로 확인 |

---

## 7. Tech Stack

**Helm · Kubernetes · ArgoCD · GitHub Actions · Airflow · MLflow · Triton · FastAPI · S3 · PostgreSQL · NFS**

- CI 정의: `.github/workflows/ci-helm-validate.yaml`

---

## 8. Operational Maturity (Optional, Toggleable)

Core MLOps 파이프라인 위에,

**실제 운영 환경에서 요구되는 관측·알림·피처 관리 기능을
Optional 레이어로 분리해 구현했습니다.**

이 레이어는 GitOps 기준으로 **완전히 분리되어 있으며**,

토글 스크립트로 언제든지 활성화/비활성화 가능합니다.

### Included Optional Components

- **Monitoring / Alerting**
    - Prometheus / Grafana / Alertmanager
    - dev / prod 환경 분리
    - FastAPI / Triton 지표 기반 알람 규칙 구성
- **Logging**
    - Loki / Promtail
    - AppSet 기반 배포
    - 서비스별 로그 수집 및 조회 파이프라인 구성
- **Feature Store (Feast)**
    - Feature Contract GitOps 관리
    - Offline / Online Store 분리
    - Materialize DAG 구현 및 검증 완료

### Why Optional?

- Core 파이프라인의 **개념적 단순성 유지**
- 제출/면접 시 **E2E 자동화 흐름을 명확히 설명**
- 프로덕션 환경에서는 **필요에 따라 단계적으로 확장 가능**

Optional 레이어는

기능 나열이 아니라

**운영 성숙도(Operational Maturity)를 증명하기 위한 계층**입니다.

---

## Core vs Optional 명확화

- **Core**
    
    필수 MLOps 뼈대
    
    (GitOps · Airflow · MLflow · Triton · FastAPI · Rollback)
    
- **Optional**
    
    운영 성숙도 및 확장 증명
    
    (Monitoring · Logging · Feature Store 등, 토글로 분리)
    

Core만으로도 E2E 자동화 증명이 완결되며,

Optional로 프로덕션 운영까지 고려했습니다
