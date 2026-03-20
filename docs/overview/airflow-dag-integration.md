# Airflow DAG Integration (레포 분리 구조)

이 문서는 `mlops-infra-gitops`(인프라/GitOps)와 `airflow-dags-dev`(DAG 코드)가
왜 분리되어 있는지, 두 레포가 어떻게 연결되는지를 설명합니다.

핵심 목표:
- 인프라 변경과 DAG 변경의 영향 범위를 분리
- Git Sync가 DAG을 Airflow Pod에 자동으로 마운트하는 구조를 명확히
- E2E 파이프라인에서 Airflow의 역할과 의존 서비스를 한눈에 파악

---

## 1) 레포 분리 이유

| 관심사 | 레포 | 변경 주체 |
|--------|------|-----------|
| Helm chart, values, ArgoCD App | `mlops-infra-gitops` | 인프라/플랫폼 엔지니어 |
| DAG Python 코드, 파이프라인 로직 | `airflow-dags-dev` | ML 엔지니어 / 데이터 엔지니어 |

분리 원칙:
- DAG 코드 수정이 인프라 ArgoCD sync를 트리거하지 않음
- 인프라 변경(Helm values, Secret, PVC)이 DAG 코드 히스토리를 오염시키지 않음
- 역할별 접근 권한을 레포 단위로 분리

---

## 2) 두 레포 연결 구조도

```
[mlops-infra-gitops]                        [airflow-dags-dev]
  apps/appset-core.yaml                        main branch
  charts/airflow/ (Helm chart)                   dags/
  envs/dev/airflow/values.yaml                     mlops_pipeline.py
         │                                          ...
         │  ArgoCD sync                         │
         ▼                                      │ git-sync (SSH)
  ┌─────────────────────────────────────────┐   │
  │         Kubernetes: airflow-dev          │   │
  │                                          │   │
  │  ┌──────────────┐   ┌─────────────────┐ │   │
  │  │  Scheduler   │   │  git-sync       │◄├───┘
  │  │  (KubeExec)  │   │  sidecar        │ │
  │  └──────┬───────┘   └────────┬────────┘ │
  │         │  reads DAGs         │ writes   │
  │         └──────────┬──────────┘          │
  │               /opt/airflow/dags/repo/    │
  └──────────────────────────────────────────┘
```

흐름 요약:
1. ArgoCD가 `mlops-infra-gitops`를 감시하고 Airflow Helm chart를 sync
2. Airflow Pod 기동 시 `git-sync` sidecar가 `airflow-dags-dev` 레포를 SSH로 clone
3. DAG 코드가 `/opt/airflow/dags/repo/dags`에 마운트 → Scheduler가 인식

---

## 3) 인프라 연결 상세

### 3-1) ArgoCD sync wave 순서

ArgoCD는 `apps/appset-core.yaml`의 `sync-wave` 어노테이션으로 배포 순서를 제어합니다.

| wave | 서비스 | 이유 |
|------|--------|------|
| 10 | mlflow | 모델 등록/추적 backend — Airflow보다 먼저 기동 |
| 20 | airflow | DAG이 mlflow에 의존 |
| 30 | triton | 모델 서빙 — Airflow DAG이 load API 호출 |
| 40 | fastapi | 추론 API — Triton 이후 기동 |

### 3-2) Git Sync (DAG 마운트)

`envs/dev/airflow/values.yaml`의 실제 설정:

```yaml
dags:
  gitSync:
    enabled: true
    repo: git@github.com:keonhoban/airflow-dags-dev.git
    branch: main
    subPath: dags
    depth: 1
    wait: 10
    sshKeySecret: airflow-git-ssh-secret
```

- `sshKeySecret: airflow-git-ssh-secret` — SealedSecret으로 관리되는 SSH 비공개 키
- `wait: 10` — 10초 주기로 원격 레포를 폴링, DAG 변경이 자동 반영
- `depth: 1` — shallow clone으로 초기 기동 속도 최적화

### 3-3) DAG 변경 → Airflow 반영 흐름

```
[airflow-dags-dev 레포]
  git push → main 브랜치
        │
        │ (최대 10초 대기)
        ▼
  git-sync sidecar가 변경 감지
        │
        ▼
  /opt/airflow/dags/repo/dags/ 갱신
        │
        ▼
  Airflow Scheduler가 DAG 파일 재인식
        │
        ▼
  다음 scheduled run 또는 manual trigger 시 새 코드 실행
```

인프라 레포 변경 없이 DAG 코드만 push해도 반영됩니다.

---

## 4) E2E 파이프라인에서 Airflow 역할

Scheduler Pod은 DAG 실행 시 아래 환경변수로 서비스를 호출합니다.

| 환경변수 | 값 | 출처 |
|----------|----|------|
| `MLFLOW_TRACKING_URI` | `http://mlflow-dev-service.mlflow-dev.svc.cluster.local:5000` | values.yaml 직접 주입 |
| `FASTAPI_BASE_URL` | `http://fastapi-dev-service.fastapi-dev.svc.cluster.local:8000` | values.yaml 직접 주입 |
| `RELOAD_SECRET_TOKEN` | (비공개) | SealedSecret `fastapi-token-dev-secret` |
| `SLACK_WEBHOOK_URL` | (비공개) | SealedSecret `slack-webhook-dev-secret` |

### DAG 태스크별 역할

```
[mlops_pipeline DAG]
  Task 1: Feature 준비 (Feature Store / 전처리)
  Task 2: Train & Evaluate
            → MLFLOW_TRACKING_URI로 run 기록
  Task 3: MLflow Registry 등록 (version / run_id)
  Task 4: READY Sensor
            → MLflow에서 alias가 "READY"인지 폴링
  Task 5: Triton Model Publish
            → /models (triton-model-repo PVC) 에 모델 파일 write
            → POST triton-svc/v2/repository/models/{name}/load
  Task 6: FastAPI Reload
            → POST FASTAPI_BASE_URL/variant/A/reload
            → Header: x-token: RELOAD_SECRET_TOKEN
  Task 7: Slack Notification
            → SLACK_WEBHOOK_URL로 결과 전송 (운영 흔적)
```

### Executor: KubernetesExecutor

- 태스크마다 독립적인 Pod을 생성하고 완료 후 삭제
- Scheduler에 선언된 `extraVolumes`/`extraVolumeMounts`가 각 Task Pod에도 동일하게 적용

### 마운트된 볼륨

| 볼륨 | 마운트 경로 | 용도 |
|------|-------------|------|
| `triton-model-repo-pvc` (RWX NFS) | `/models` | Triton과 모델 파일 공유 — DAG이 write, Triton이 load |
| `aws-credentials-secret` | `/home/airflow/.aws` | S3/MinIO 접근 (모델 아티팩트, 원격 로그) |
| `feature-store-resources` ConfigMap | `/opt/airflow/feature-store` | Feature schema 참조 |

원격 로그:
- `AIRFLOW__LOGGING__REMOTE_BASE_LOG_FOLDER=s3://<S3_BUCKET>/dev/airflow-logs`  *(dev 환경 예시: `mlflow-artifacts-keonho`)*
- Pod 재시작과 무관하게 로그 보존 (PVC 의존성 없음)

---

## 5) 연관 레포 링크

| 레포 | 역할 |
|------|------|
| [`keonhoban/mlops-infra-gitops`](https://github.com/keonhoban/mlops-infra-gitops) | 인프라/GitOps (이 레포) — Helm chart, ArgoCD, Secret, PVC |
| [`keonhoban/airflow-dags-dev`](https://github.com/keonhoban/airflow-dags-dev) | DAG 코드 — `dags/` 하위에 Python DAG 파일 위치 |
