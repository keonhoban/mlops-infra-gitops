# Architecture Overview

이 문서는 본 ML Platform의 **전체 구조(Core / Baseline / Optional)** 와  
**dev/prod 완전 격리**, 그리고 **Baseline Always-on** 원칙을 한 장으로 설명합니다.

---

## 1) Layer Model (Core / Baseline / Optional)

### Core (E2E Model Lifecycle)
모델 생명주기를 “운영 배포 가능한 형태”로 자동화합니다.

- Airflow: 학습/평가/등록/배포/롤백 흐름 제어
- MLflow: Tracking/Registry
- Triton: 모델 서빙(Load/Ready/Inference)
- FastAPI: Alias(A/B) 라우팅 + Reload API

핵심 흐름 정의: `e2e-flow.md`

---

### Baseline (Always-on Operational Foundation)
운영 안정성에 필요한 기반층으로 **항상 활성화**됩니다.  
Optional 토글과 무관하게 유지되며, Core-only 상태에서도 동일하게 남습니다.

- Storage: MinIO(S3 compatible)
- Logging: Loki + Alloy
- Monitoring: kube-prometheus-stack + extra rules/monitors/secrets

---

### Optional (Attach/Detach Extensions)
필요할 때만 붙였다 떼는 확장 레이어입니다.

- Feature Store: Feast (+ Redis)

> Optional OFF는 “비파괴 Detach”입니다.  
> `feature-store-dev/prod` namespace는 경계/재부착 안정성을 위해 유지되며,  
> 실제 Feast/Redis 리소스는 Optional ON에서만 생성됩니다.

---

## 2) Environment Isolation (dev / prod)

- Namespace 규칙:
  - dev: `*-dev`
  - prod: `*-prod`

- ArgoCD AppProject:
  - `dev` / `prod` 프로젝트에서 repo/destination 범위를 분리
  - 잘못된 환경 배포를 구조적으로 차단

경계/정책 정의: `argocd-boundary.md`

---

## 3) Monitoring & Logging (Baseline)

Monitoring과 Logging은 Baseline 레이어에 속하며 항상 활성화됩니다.  
Optional 토글과 무관하게 유지됩니다.

---

### Monitoring Stack

Helm Chart:
- kube-prometheus-stack (65.5.0)

Ingress Endpoints:

#### dev
- Grafana: https://grafana-dev.local
- Prometheus: https://prometheus-dev.local
- Alertmanager: https://alert-dev.local

#### prod
- Grafana: https://grafana-prod.local
- Prometheus: https://prometheus-prod.local
- Alertmanager: https://alert-prod.local

Grafana datasource 구성:

- Prometheus:
  http://monitoring-dev-kube-promet-prometheus.monitoring-dev:9090/
- Alertmanager:
  http://monitoring-dev-kube-promet-alertmanager.monitoring-dev:9093/

PrometheusRule / ServiceMonitor / PodMonitor는
`baseline/envs/*/baseline/monitoring/extra` 경로에서 관리됩니다.

---

### Logging Flow

Logging은 Grafana Alloy + Loki 조합으로 구성됩니다.

Flow:

Pod Logs
   ↓
Alloy (DaemonSet)
   ↓
Loki (SingleBinary, TSDB)
   ↓
Grafana (Loki datasource)

---

### Alloy Configuration (dev 기준)

- DaemonSet 형태
- 수집 대상 namespace 필터링:

  airflow-dev
  mlflow-dev
  fastapi-dev
  triton-dev
  feature-store-dev

Loki Push Endpoint:

http://loki-dev.baseline-dev.svc.cluster.local:3100/loki/api/v1/push

---

### Loki Configuration (dev 기준)

Deployment Mode: SingleBinary

Storage:
- Backend: S3 (MinIO)
- Endpoint:
  http://minio-dev.baseline-dev.svc.cluster.local:9000

Buckets:
- loki-chunks
- loki-ruler
- loki-admin

Retention:
- 168h (7 days)

Persistence:
- 20Gi PVC
- whenDeleted: Retain
- enableStatefulSetAutoDeletePVC: false

→ Optional 토글 / ArgoCD prune에도 로그 데이터는 보존됩니다.
