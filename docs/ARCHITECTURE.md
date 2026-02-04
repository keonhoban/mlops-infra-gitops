# Architecture

## E2E Flow
GitOps(Helm→ArgoCD)로 런타임(Infra)을 고정하고,
Airflow(DAG)가 모델 아티팩트 생성/등록/배포 트리거를 수행합니다.

GitOps → Airflow → MLflow → Triton → FastAPI

## Responsibility Boundary
- GitOps: 서비스/권한/스토리지(틀) 배포 및 상태 고정(SelfHeal/Prune)
- Airflow: feature/train/register/sensor/deploy/reload/rollback 파이프라인 실행
