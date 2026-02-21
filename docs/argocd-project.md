# Architecture

이 문서는 GitOps(ArgoCD) 기반으로 운영되는 **E2E ML Platform**의 전체 구조를 설명합니다.

핵심은 다음 3가지입니다.

- **Core**: 모델 생명주기 E2E 자동화 (Train → Register → Deploy → Reload)
- **Baseline**: 운영 필수 기반층 (Storage/Logging/Monitoring) — Always-on
- **Optional**: 실험/확장 레이어 (Feature Store 등) — Attach/Detach

---

## 1. High-level Topology

### GitOps Control Plane
- 모든 변경은 Git Commit에서 시작
- ArgoCD가 선언 상태를 강제(SelfHeal/Prune)
- dev / prod는 **AppProject + Namespace 규칙**으로 구조적으로 격리

### Runtime Data Plane (Core)
- Airflow: 학습/평가/등록/배포/롤백 흐름 제어
- MLflow: Tracking/Registry
- Triton: 모델 서빙 (Load/Ready/Inference)
- FastAPI: alias 기반 요청 라우팅 + Reload API 제공

---

## 2. Environment Isolation (dev / prod)

- Namespace 규칙:
  - dev: `*-dev`
  - prod: `*-prod`

- ArgoCD AppProject:
  - `dev` / `prod` 프로젝트에서 repo/destination 범위를 분리
  - 잘못된 환경 배포를 구조적으로 차단

---

## 3. Optional Attach/Detach Boundary

Optional은 “삭제”가 아니라 **비파괴 Detach**를 목표로 합니다.

- Optional OFF:
  - Optional scope 앱(root-optional, optional-envs-*, feast-*)은 제거
  - `feature-store-dev/prod` namespace는 경계/재부착 안정성을 위해 유지
- Optional ON:
  - root-optional을 통해 optional 앱들이 다시 생성되고, Feast/Redis 리소스가 재생성

> Optional 토글의 증거(Proof)는 `docs/proof/` 하위에 스냅샷으로 남습니다.

---

## Monitoring & Logging (Baseline)

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
