# Core vs Optional

## Core (제출/면접 기준 필수)
- GitOps: bootstrap/root-app → apps/appset-core.yaml → charts/*
- Components: airflow, mlflow, triton, fastapi
- envs/dev|prod: namespaces, certificates, sealed-secrets, feature-store(contract)

## Optional (Proof/확장)
- monitoring (Prometheus/Grafana/Alertmanager)
- observability (Loki/Promtail)
- feast (+redis)
- (선택) storage 자동화
