# E2E Success Proof (Serving Runtime)

이 폴더는 Core E2E 흐름 중 “서빙 런타임 구간”이 정상 동작했음을 파일로 증명합니다.

## What this proves
- Triton은 READY 상태이며, READY 모델이 로드됨
- FastAPI는 alias(A/B) 기준 active 모델(version/run_id)을 노출함
- FastAPI reload API를 통해 운영 전환 동선이 정상 동작함

## Files (핵심만)
### Triton
- `triton_dev_ready_and_repo_index.txt`
- `triton_prod_ready_and_repo_index.txt`

확인 포인트:
- `HTTP/1.1 200 OK`
- `repository index (ready=true)` 결과에 `state":"READY"` 포함

### FastAPI
- `fastapi_dev_health_models_metrics.txt`
- `fastapi_prod_health_models_metrics.txt`

확인 포인트:
- `/health` => `{"status":"ok"...}`
- `/models` => alias별 `version`, `run_id` 존재
- `/metrics` => 요청 카운터 및 프로세스 메트릭 노출

### Reload
- `reload_dev_variant_A.json`
- `reload_prod_variant_A.json`

확인 포인트:
- `status: success`
- reload 이후 version/run_id 갱신(또는 유지) 확인 가능

## How to generate
- `make proof-e2e`
- 또는 `./ops/proof/proof_e2e_success.sh`

## Notes
- Triton 모델 조회는 `GET /v2/models`가 아니라 `POST /v2/repository/index`를 사용합니다.
- 본 폴더는 “서빙 런타임 증거”이며, MLflow 등록/READY sensor/Slack 알림 증거는
  Airflow DAG 로그 및 별도 proof 산출물로 확장 가능합니다.
