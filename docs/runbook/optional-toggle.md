# Optional Toggle Runbook

## Optional ON/OFF의 의미

- Optional ON: feature-store(Feast) 등 확장 컴포넌트를 Attach
- Optional OFF: Optional 리소스를 Detach하여 클러스터를 Core+Baseline 상태로 복귀

### 토글 대상(삭제/생성되는 것)
- ArgoCD Applications:
  - root-optional
  - optional-envs-dev / optional-envs-prod
  - feast-dev / feast-prod
- Kubernetes namespaces:
  - feature-store-dev / feature-store-prod

### 토글 대상이 아닌 것(항상 유지)
- Baseline: MinIO / Loki / Alloy / Monitoring
- Core: Airflow / MLflow / Triton / FastAPI

---

## Commands

### Optional ON
`./ops/toggle/optional_on.sh`

### Optional OFF
`./ops/toggle/optional_off.sh`

---

## Proof

토글 실행 시 `docs/proof/optional_on_*`, `docs/proof/optional_off_*`에 로그가 남습니다.
(“Optional OFF 시 Optional scope=0”을 증거로 제시)
