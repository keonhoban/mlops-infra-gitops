# Proof Index (latest)

이 폴더는 **Core/Baseline/Optional 경계**, **Optional 토글**, 그리고 **E2E 동작**을
“말이 아닌 파일”로 증명하기 위한 최신 스냅샷입니다.

---

## 0) E2E Success Proof (Serving Runtime)

경로: `e2e_success/`

이 폴더는 “서빙 런타임 관점”에서 아래를 **끝까지** 증명합니다.

### 이 폴더가 직접 증명하는 것
1) Triton READY + 모델이 READY 상태로 로드됨 (`/v2/repository/index`)
2) FastAPI가 active 모델(version/run_id)을 조회함 (`/models`)
3) FastAPI reload 동선이 정상 동작함 (`/variant/{alias}/reload`)

### 핵심 파일
- `triton_dev_ready_and_repo_index.txt`
- `triton_prod_ready_and_repo_index.txt`
- `fastapi_dev_health_models_metrics.txt`
- `fastapi_prod_health_models_metrics.txt`
- `reload_dev_variant_A.json`, `reload_prod_variant_A.json`

### 생성
- `make proof-e2e`
- 또는 `./ops/proof/proof_e2e_success.sh`

> Note:
> Triton 모델 목록 확인은 `GET /v2/models`가 아니라
> `POST /v2/repository/index`가 표준 확인 동선입니다.

---

## 1) Core-only 증거 (Core + Baseline, Optional OFF)

경로: `core_only/`

핵심 증거(이 3개만 보면 됩니다):
1. `optional_off_run.txt` : Optional OFF 실행 로그
2. `optional_scope_apps_after.txt` : Optional scope 앱이 0개임을 증명
3. `core_health_probes.txt` : Core 서비스 헬스 체크 결과

보조 증거:
- `argocd_app_list_before.txt` / `argocd_app_list_after.txt`

---

## 2) Optional ON 증거 (Feast attach)

경로: `optional_on/`

핵심 증거:
1. `optional_on_run.txt`
2. `optional_scope_apps_after.txt`
3. `optional_apps_after_grep.txt`

보조 증거:
- `argocd_app_list_before.txt` / `argocd_app_list_after.txt`

---

## 3) Root 상태/프로젝트/스토리지 증거 (클러스터 전체)

- `root-apps.txt`, `root-baseline.txt`, `root-optional.txt`
- `projects.txt`, `apps.txt`, `namespaces.txt`
- `pv.txt`, `pvc_all.txt`
- `sealed-controller.txt`, `sealedsecrets.txt`

---

## Observability

- `observability/metrics_api.txt`
- `observability/top_nodes.txt`
- `observability/top_pods_head.txt`
- `observability/monitoring_dev_objects.txt`
- `observability/monitoring_prod_objects.txt`
- `observability/metrics_server_deploy.yaml`

---

## Load Test (TBD)

k6 시나리오: N VU, 60s, 목표 RPS X, 실행 예정

- 대상 엔드포인트: `POST /predict` (FastAPI → Triton 추론 경로)
- 측정 항목: RPS, P50/P95/P99 latency, error rate, Triton inference queue depth
- 스크립트 위치: `ops/load-test/` (작성 예정)
- 결과 위치: `docs/proof/latest/load_test/` (실행 후 스냅샷 추가 예정)
