# CLAUDE.md

이 파일은 Claude Code(claude.ai/code)가 이 저장소에서 작업할 때 참고하는 가이드입니다.

## 주요 명령어

### Helm / CI 검증
```bash
# 차트 린트 (strict 모드)
helm lint charts/<service>/ -f envs/dev/<service>/values.yaml --strict

# 매니페스트 렌더링 (확인용)
helm template <release-name> charts/<service>/ -f envs/dev/<service>/values.yaml

# 렌더링된 매니페스트를 K8s 1.30.0 스키마로 검증
helm template <release-name> charts/<service>/ -f envs/dev/<service>/values.yaml \
  | kubeconform -kubernetes-version 1.30.0 -strict

# YAML 스타일 체크 (PR 전 필수 통과)
yamllint -c .yamllint apps/ charts/ envs/ baseline/ bootstrap/ optional/
```

### 운영 Make 타겟
```bash
make optional-on       # Optional 레이어(Feast/Redis) 활성화 (ArgoCD 수동 동기화)
make optional-off      # Optional 레이어 비활성화 (비파괴적)
make proof-core        # 상태 스냅샷 캡처: Core+Baseline, Optional OFF
make proof-optional    # 상태 스냅샷 캡처: Core+Baseline+Optional ON
make proof-e2e         # E2E 서빙 증거 캡처 (Triton + FastAPI)
make audit             # 전체 시스템 감사 덤프
make reseal-dev        # dev 환경 SealedSecrets 재암호화
make reseal-prod       # prod 환경 SealedSecrets 재암호화
make rotate-aws-dev    # AWS 자격증명 교체 (dev)
make rotate-aws-prod   # AWS 자격증명 교체 (prod)
make rotate-ss-key     # SealedSecrets 컨트롤러 키 교체
```

## 아키텍처 개요

### 레이어 구조

플랫폼은 독립적으로 배포 가능한 세 가지 레이어로 구성됩니다:

| 레이어 | 경로 | 동기화 방식 | 목적 |
|---|---|---|---|
| **Core** | `apps/`, `charts/`, `envs/` | 자동 | E2E 모델 라이프사이클 (학습 → 서빙) |
| **Baseline** | `baseline/` | 자동 | 상시 가동 관찰성 (MinIO, Loki, Prometheus) |
| **Optional** | `optional/` | **수동** | 탈부착 가능 확장 기능 (Feast 피처 스토어) |

Optional은 ArgoCD에서 의도적으로 **수동 동기화**로 설정(`bootstrap/root-optional.yaml`)되어 있어 실수로 토글되는 것을 방지합니다. `make optional-on/off`로 관리합니다.

### Core 서비스 기동 순서 (Sync Waves)

ArgoCD는 `apps/appset-core.yaml`의 sync wave를 통해 기동 순서를 강제합니다:

```
Wave 10: MLflow   → 최초 기동 필수 (모델 레지스트리)
Wave 20: Airflow  → MLflow에 의존
Wave 30: Triton   → MLflow/NFS에서 검증된 모델 로드
Wave 40: FastAPI  → Triton을 래핑하여 트래픽 서빙
```

### E2E 모델 파이프라인 (Airflow DAG)

```
학습 → 평가 → 등록(MLflow) → 검증 → 배포(NFS) → 리로드(Triton API)
```

**Triton은 `explicit` 모델 제어 모드로 실행됩니다** — 모델 디렉토리를 자동으로 폴링하지 않습니다. DAG가 NFS에 모델을 기록한 후 반드시 Triton 리로드 API를 명시적으로 호출해야 합니다. 이를 통해 부분적으로 기록된 모델이 자동 로드되는 것을 방지합니다.

### 환경 격리

- 네임스페이스는 `{service}-{env}` 패턴을 따릅니다 (예: `airflow-dev`, `mlflow-prod`)
- AppProject(`apps/project-dev.yaml`, `apps/project-prod.yaml`)가 네임스페이스 허용 목록을 강제 — 환경 간 배포 불가
- 환경별 오버레이는 `envs/{dev|prod}/{service}/values.yaml`에 위치하며, 동기화 시 `charts/{service}/values.yaml` 기본값과 병합됩니다 (멀티소스 ApplicationSet)

### 스토리지 아키텍처

- **MinIO** (Baseline): Airflow 원격 로그 및 MLflow 아티팩트를 위한 S3 호환 오브젝트 스토어
- **NFS PV/PVC** (`envs/{env}/support/`): Triton 모델 리포지토리용 `ReadWriteMany` 공유 볼륨 — `persistentVolumeReclaimPolicy: Retain`으로 ArgoCD prune 시 데이터 보호
- Airflow(쓰기)와 Triton(읽기)이 동일한 NFS PVC를 마운트

### 시크릿 관리

모든 시크릿은 **SealedSecrets**으로 암호화되어 저장소에 커밋됩니다. 평문 시크릿은 Git에 절대 포함하면 안 됩니다.

- 봉인된 시크릿 파일 위치: `envs/{env}/*/sealed-secrets/`
- 값 교체 후 재암호화: `ops/security/re-seal.sh` 사용
- SealedSecrets 컨트롤러 키는 클러스터 범위 — 키 교체(`make rotate-ss-key`) 시 모든 시크릿 재봉인 필요

### CI 파이프라인

GitHub Actions(`.github/workflows/ci-helm-validate.yaml`)는 `charts/`, `envs/`, `apps/`, `baseline/`, `optional/`, `bootstrap/` 변경 PR에서 실행됩니다:

1. `yamllint` — 스타일 체크
2. `helm lint --strict` — 차트별 × {dev, prod}
3. `helm template` + `kubeconform` — K8s 1.30.0 스키마 검증
4. 환경별 리소스 및 ArgoCD 오브젝트 검증

Helm은 로컬과 CI 모두 **3.18.3**으로 고정되어 있습니다. 템플릿 드리프트를 방지하기 위해 이 버전을 사용하세요.

### 차트 구조

`charts/{service}/`의 각 서비스 차트는 업스트림 의존성을 래핑하거나(Airflow는 공식 Apache 차트를 서브차트로 사용) 완전 커스텀으로 작성됩니다(MLflow, Triton, FastAPI). `charts/fastapi/app/`에는 FastAPI Python 소스 코드가 포함되어 있습니다.

### Optional 레이어 (Feast)

Feast는 `optional/`을 통해 배포되며 Redis를 온라인 스토어로 사용합니다. 프로덕션 규모를 위한 마이그레이션 경로는 Redis → ScyllaDB(Cassandra 호환)입니다. `make optional-on/off`로 토글 — 비파괴적입니다.

## 주요 파일 위치

| 목적 | 경로 |
|---|---|
| ArgoCD 루트 부트스트랩 | `bootstrap/root-app.yaml` |
| Core ApplicationSet (전 환경 × 서비스) | `apps/appset-core.yaml` |
| 환경별 AppProject | `apps/project-dev.yaml`, `apps/project-prod.yaml` |
| 차트 기본값 | `charts/{service}/values.yaml` |
| 환경 오버레이 값 | `envs/{dev\|prod}/{service}/values.yaml` |
| 네임스페이스 / PV / PVC 리소스 | `envs/{dev\|prod}/support/` |
| Baseline 관찰성 | `baseline/` |
| Optional 토글 스크립트 | `ops/toggle/optional_on.sh`, `ops/toggle/optional_off.sh` |
| 증거 캡처 스크립트 | `ops/proof/` |
| 보안 / 시크릿 교체 | `ops/security/` |
| 아키텍처 문서 | `docs/overview/` |
| 운영 런북 | `docs/runbook/` |
| 증거 스냅샷 | `docs/proof/latest/` |
