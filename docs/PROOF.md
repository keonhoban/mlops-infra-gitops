# Proof (재현 루프)

## 1) ArgoCD Sync
- root-app synced/healthy
- core appset synced/healthy

## 2) Airflow DAG Trigger
- e2e_full.py 실행

## 3) MLflow Registry 확인
- 모델 등록 + alias 전환 확인

## 4) Triton Smoke Test
- ready 확인 + infer 확인

## 5) FastAPI 확인
- /health
- /models
- (옵션) /predict
