# GitOps 기반 E2E ML Platform (Core / Optional 분리 구조)

Production-grade ML Platform을 GitOps 기반으로 설계·운영한 프로젝트입니다.

Core는 최소 E2E 자동화 루프를 고정하고,

Optional은 운영 성숙도 레이어를 Attach / Detach 가능한 구조로 분리했습니다.

---

## Why This Platform Exists

모델 성능 개선은 반복 실험을 통해 발전시킬 수 있지만, 

운영 환경에서의 모델 교체·검증·롤백·관측은 시스템적 통제가 필요합니다.

이 플랫폼은 다음 문제를 해결하기 위해 설계되었습니다:

- 수동 배포 제거
- 모델 전환 시 무중단 요청 처리 검증
- 실패 시 자동 롤백
- dev / prod 환경 충돌 방지
- Git 기반 변경 추적 및 감사 가능성 확보

Core는 최소 E2E를 고정하고,

Optional은 운영 성숙도 계층을 분리하여 복잡도를 통제합니다.

---

## Architecture Overview

GitOps(ArgoCD)를 중심으로 다음 파이프라인을 구성합니다:

Airflow → MLflow → Triton → FastAPI

- 모든 변경은 Git Commit에서 시작
- ArgoCD가 상태를 강제(SelfHeal / Prune)
- Airflow가 모델 생명주기를 제어
- Triton/FastAPI는 런타임 트래픽 전환 담당

dev / prod는 AppProject 단위로 완전 분리됩니다.

---

## Deployment Success Criteria

모델 배포는 아래 조건을 모두 만족할 때 성공으로 간주합니다.

1. MLflow Registry에 새로운 모델 버전 등록 성공
2. Model READY Sensor 통과
3. Triton Inference Smoke Test 성공
4. FastAPI Reload 성공
5. Slack 알림 전송 확인

위 단계 중 하나라도 실패하면 Rollback DAG가 실행됩니다.

---

## One Commit Flow

1. Pull Request 생성
2. GitHub Actions에서 Helm Lint / Render / kubeconform 검증
3. main 브랜치 머지
4. ArgoCD Auto Sync 반영
5. Airflow DAG 실행 (Train → Evaluate → Register)
6. READY Sensor 통과
7. Triton 모델 배포
8. FastAPI Reload
9. 트래픽 전환
10. 실패 시 Rollback DAG 실행

코드 변경만으로 모델 학습부터 트래픽 전환까지 반복 가능한 구조입니다.

---

## Core vs Optional

### Core

- GitOps 런타임 고정
- Airflow 기반 E2E 자동화
- MLflow Registry
- Triton 서빙
- FastAPI 트래픽 제어
- Rollback DAG

Core만으로도 E2E는 완전히 동작합니다.

### Optional

- Monitoring (Prometheus / Grafana / Alertmanager)
- Logging (Loki + Alloy)
- Feature Store (Feast)

Optional은 GitOps 기준으로 Attach / Detach 가능합니다.

---

## 60초 Quickstart

Core-only 확인: `./ops/proof/proof_core_only.sh`

Optional ON: `./ops/toggle_optional_on.sh`

Optional OFF:  `./ops/toggle_optional_off.sh`

GitOps 상태 확인:  `argocd app list`

---

## Operational Principles

| 항목 | 설계 원칙 |
| --- | --- |
| 배포 | GitOps Auto Sync |
| 안정성 | READY Sensor 이후 Reload |
| 롤백 | DAG 기반 이전 정상 버전 복원 |
| 환경 | dev / prod 완전 분리 |
| 검증 | Smoke Test + Slack Alert |

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

---

## Repository Structure

| Directory | Purpose |
| --- | --- |
| apps/ | ArgoCD ApplicationSet / AppProject 정의 |
| bootstrap/ | root-apps / root-optional |
| charts/ | Core Helm charts |
| envs/ | Core 운영 리소스 |
| optional/ | Optional 확장 레이어 |
| ops/ | proof / toggle / rotate |
| docs/ | architecture / runbook / proof |

---

## What This Project Demonstrates

- GitOps 기반 운영 통제
- 모델 라이프사이클 자동화
- 실패 수렴 및 자동 롤백
- 환경 격리 설계
- Optional 분리 기반 복잡도 통제
