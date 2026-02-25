# Optional Toggle Runbook

Optional은 “삭제”가 아니라 **비파괴 Detach**로 운영합니다.
Core/Baseline은 항상 유지되고, Optional만 attach/detach 됩니다.

---

## Optional ON/OFF의 의미

- Optional ON: Feast(feature-store) 등 확장 컴포넌트를 Attach
- Optional OFF: Optional 리소스를 Detach하여 클러스터를 Core+Baseline 상태로 복귀

### 토글 대상(Attach/Detach로 변화하는 것)
- ArgoCD Applications:
  - root-optional
  - optional-envs-dev / optional-envs-prod
  - feast-dev / feast-prod

### 토글 대상이 아닌 것(항상 유지)
- Baseline: MinIO / Loki / Alloy / Monitoring
- Core: Airflow / MLflow / Triton / FastAPI
- Kubernetes namespaces (항상 유지: 경계/재부착 안정성 목적)
  - feature-store-dev / feature-store-prod
  - Optional OFF에서도 namespace는 “경계 컨테이너”로 유지됩니다.
    실제 Feast/Redis 리소스는 Attach 시에만 생성됩니다.

---

## Commands (추천: Makefile)

### Optional ON
- `make optional-on`

### Optional OFF
- `make optional-off`

### Proof (Core-only / Optional-on 스냅샷)
- Core-only: `make proof-core`
- Optional-on: `make proof-optional`

---

## Commands (대체: Script)

### Optional ON
- `./ops/toggle/optional_on.sh`

### Optional OFF
- `./ops/toggle/optional_off.sh`

---

## Proof 산출물

토글 실행 시 `docs/proof/optional_on_*`, `docs/proof/optional_off_*`에 로그가 남습니다.
또한 최신 스냅샷은 `docs/proof/latest/`에서 확인합니다.
