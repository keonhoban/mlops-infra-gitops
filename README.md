# GitOps 기반 E2E MLOps Core Platform

One Commit Flow — Build → Register → Deploy → Switch

---

## Architecture Snapshot

GitOps(ArgoCD)를 중심으로

Airflow → MLflow → Triton → FastAPI가 단일 파이프라인으로 연결된

E2E MLOps Core Platform입니다.

- 모든 변경은 Git Commit에서 시작
- ArgoCD가 상태를 강제
- Airflow가 모델 라이프사이클을 제어
- Triton/FastAPI는 트래픽 전환만 담당

---

## What This Project Proves (TL;DR)

이 프로젝트는

**“ML 모델을 운영 가능한 시스템으로 만드는 데 필요한 최소 MLOps Core”**를

GitOps 기반으로 자동화해 증명합니다.

- PR 단계에서 CI로 사전 검증
- Git 머지 → ArgoCD 자동 배포
- Airflow → MLflow → Triton → FastAPI 자동 연결
- Sensor / Smoke Test 기반 무중단 전환 및 자동 Rollback
- dev / prod 환경 완전 분리

**수동 배포·수동 롤백 없이**,

코드 변경만으로 모델 학습부터 트래픽 전환까지 반복 가능한 구조를 목표로 합니다.

---

## Core가 증명하는 것

- GitOps(ArgoCD) 기반 dev / prod 분리 및 Auto Sync
- SelfHeal / Prune를 통한 상태 고정
- CI 단계에서 Helm Lint / Render / kubeconform 검증
- Airflow DAG 기반 학습 → 등록 → 배포 자동화
- 실패 시 Sensor / Smoke Test 기반 Rollback 가능

---

## One Commit Flow

Mermaid 다이어그램 대신, 실제 운영 흐름을 문장으로 고정합니다.

1. Pull Request 생성
2. GitHub Actions에서 Helm Lint / Render / kubeconform 검증
3. main 브랜치 머지
4. ArgoCD Auto Sync로 dev / prod 환경 반영
5. Airflow DAG 실행 (Train → Evaluate → Register)
6. Model READY Sensor 통과
7. Triton 모델 배포 (model repository 갱신)
8. FastAPI Reload
9. 트래픽 전환 (A/B · Canary · Blue-Green)
10. 실패 시 Rollback DAG 실행

코드 변경 → 자동 배포 → 자동 실험 전환

운영 개입 없이 반복 가능한 MLOps 루프를 구성합니다.

---

## Quick Proof

### Core only 증명

- Core 상태 점검 스크립트
    
    ./ops/proof/proof_core_only.sh
    
- 실행 결과는 docs/proof/ 하위에 자동 저장됩니다.

### Optional 토글

- Optional ON
    
    ./ops/toggle_optional_on.sh
    
- Optional OFF
    
    ./ops/toggle_optional_off.sh
    

Optional 레이어는 Core와 완전히 분리되어 있으며,

GitOps 기준으로 언제든지 활성화 / 비활성화 가능합니다.

---

## Repository Overview

- apps/
    
    GitOps 선언 계층 (무엇을 배포할지)
    
    ArgoCD ApplicationSet / AppProject 정의
    
- charts/
    
    Core 서비스 배포 방법 (어떻게 배포할지)
    
    Core Helm charts
    
    (airflow / mlflow / triton / fastapi)
    
- envs/
    
    환경별 공통 리소스 (dev/prod 차이)
    
    dev / prod 공통 운영 리소스
    
    (namespaces, certificates, sealed-secrets, feature-store contract 등)
    
- baseline/
    
    Optional에서 공통 재사용하는 운영 기본값
    
    Optional에서 공통으로 사용하는 baseline values
    
    (minio / loki / alloy 등)
    
- optional/
    
    Core 외 운영 성숙도 증명 레이어 (토글 가능)
    
    Monitoring / Logging / Feature Store 등 운영 확장 레이어
    
- ops/
    
    proof / toggle / rotate / seal / storage 관련 스크립트
    
- docs/
    
    runbook / proof / architecture 문서
    

외부 Airflow DAG repo는 gitSync 방식으로 주입됩니다.

---

## Proof of Operation

### dev / prod 환경 분리 확인

```
kubectl get ns | egrep"airflow-|mlflow-|fastapi-|triton-"
```

---

### Feature Store Contract GitOps 관리 확인

```
kubectl get cm -A -l mlops.keonho.io/env=dev
kubectl get cm -A -l mlops.keonho.io/env=prod
```

---

### Runtime Mount 검증 (Airflow)

아래 <scheduler-pod> 는 실제 scheduler Pod 이름으로 치환합니다.

```
kubectl -n airflow-devexec <scheduler-pod> --ls /opt/airflow/feature-store
```

---

### GitOps Sync 상태 확인

```
argocd app list
```

---

## Core Architecture

### 핵심 구성 요소

| 영역 | 스택 | 역할 |
| --- | --- | --- |
| Orchestration | Airflow (KubernetesExecutor) | 학습 → 평가 → 등록 → 롤백 제어 |
| Experiment | MLflow (Tracking + Registry) | 실험 / 모델 버전 관리 |
| Model Serving | Triton Inference Server | 고성능 모델 서빙, 런타임 분리 |
| API Layer | FastAPI | A/B · Canary · Blue-Green 트래픽 제어 |
| Deployment | ArgoCD (GitOps) | Auto Sync · SelfHeal · Prune |
| Storage | S3 + NFS + PostgreSQL | 모델 / 로그 / 메타데이터 관리 |

---

## Operational Principles

| 항목 | 설계 원칙 |
| --- | --- |
| 배포 | GitOps 기반 Auto Sync |
| 안정성 | Sensor READY 이후 Reload |
| 롤백 | DAG 기반 이전 정상 버전 복원 |
| 환경 | dev / prod 완전 분리 |
| 검증 | kubectl / argocd / proof script |

---

## Tech Stack

Helm

Kubernetes

ArgoCD

GitHub Actions

Airflow

MLflow

Triton

FastAPI

S3

PostgreSQL

NFS

CI 정의 파일:

```
.github/workflows/ci-helm-validate.yaml
```

---

## Operational Maturity (Optional, Toggleable)

Core MLOps 파이프라인 위에

실제 운영 환경에서 요구되는 기능을 Optional 레이어로 분리했습니다.

Optional 레이어는 **기능 나열이 아니라 운영 성숙도 증명**을 목표로 합니다.

### Included Optional Components

- Monitoring / Alerting
    
    Prometheus / Grafana / Alertmanager
    
    dev / prod 환경 분리
    
    FastAPI / Triton 지표 기반 알람 구성
    
- Logging
    
    Loki + Alloy(Promtail) 기반 로그 수집
    
    AppSet 기반 배포
    
    서비스별 로그 조회 파이프라인 구성
    
- Feature Store (Feast)
    
    Feature Contract GitOps 관리
    
    Offline / Online Store 분리
    
    Materialize 및 조회 검증(Proof)
    

---

## Core vs Optional 명확화

- Core
    
    필수 MLOps 뼈대
    
    (GitOps · Airflow · MLflow · Triton · FastAPI · Rollback)
    
- Optional
    
    운영 성숙도 및 확장 증명
    
    (Monitoring · Logging · Feature Store 등, 토글 분리)
    

Core만으로도 E2E 자동화는 완결되며,

Optional 레이어를 통해 실제 프로덕션 운영까지 고려했습니다.

---

### 최종 코멘트

이 README는

**“이 프로젝트를 왜 만들었는지”**,

**“어디까지 자동화되었는지”**,

**“실제 운영을 고려했는지”**를

말이 아니라 구조와 실행으로 증명하는 문서입니다.
