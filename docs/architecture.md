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
