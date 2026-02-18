# Architecture Design

## Layer Structure

Core
- Airflow
- MLflow
- Triton
- FastAPI

Baseline
- MinIO
- Loki / Alloy

Optional
- Monitoring
- Feature Store (Feast)

Core는 항상 활성화됩니다.
Optional은 필요 시 Attach 가능합니다.

---

## Environment Isolation

- AppProject/dev
- AppProject/prod

Namespace 규칙:
- airflow-dev / airflow-prod
- mlflow-dev / mlflow-prod
- triton-dev / triton-prod
- fastapi-dev / fastapi-prod

환경 충돌을 구조적으로 차단합니다.

