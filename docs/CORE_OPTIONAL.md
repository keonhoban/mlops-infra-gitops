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

## Interview Notes (방어 포인트)
- Core는 E2E 서빙 루프(Airflow→MLflow→Triton→FastAPI)에 필요한 런타임만 포함합니다.
- Observability(Loki/Promtail)는 Helm values로 관리되며, ArgoCD ApplicationSet이 valuesPath로 참조합니다(=kustomize 대상 아님).
- Optional envs는 sync-wave=-1로 네임스페이스/룰/시크릿을 먼저 적용하여, Optional 앱 배포 순서를 안전하게 보장합니다.
