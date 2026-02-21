# Optional Toggle Runbook

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
  - (설명) Optional OFF에서도 namespace는 “경계/재부착 안정성” 목적의 빈 컨테이너로 유지됩니다.
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

> Makefile이 없는 환경이라면 아래 스크립트를 직접 실행해도 됩니다.

---

## Commands (대체: Script)

### Optional ON
`./ops/toggle/optional_on.sh`

### Optional OFF
`./ops/toggle/optional_off.sh`

---

## Proof 산출물

토글 실행 시 `docs/proof/optional_on_*`, `docs/proof/optional_off_*`에 로그가 남습니다.
(“Optional OFF 시 Optional scope=0”을 증거로 제시)
