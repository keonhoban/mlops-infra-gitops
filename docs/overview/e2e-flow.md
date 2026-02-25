# E2E Model Lifecycle Flow

이 문서는 Core 레이어의 E2E 흐름과,
운영 환경에서의 Runtime/Storage 의존성을 함께 정의합니다.

핵심 목표:
- 학습 결과를 “운영 배포 가능한 형태”로 등록/검증/전환
- 실패 시 자동 중단/복원(rollback)으로 운영 안정성 보장
- 모델 publish(Airflow)와 serving lifecycle(Triton/FastAPI)을 분리

---

## 1) End-to-End Flow (Core)

1) Feature 준비
2) Train & Evaluate
3) MLflow Registry 등록 (version/run_id trace)
4) READY Sensor (운영 반영 가능한 상태인지 확인)
5) Triton Load (explicit model control)
6) FastAPI Reload (alias A/B 전환 동선)
7) Slack Notification (운영 흔적)

---

## 2) Promotion vs Shadow

이 플랫폼은 “항상 운영 반영”이 아니라,
품질 기준을 만족할 때만 promotion 합니다.

- 기준 예시: `accuracy_threshold`
- 분기:
  - promotion: 기준 통과 → 운영 경로로 배포/전환
  - shadow: 기준 미달/검증 실패 → 운영 반영 중단 또는 별도 경로로 유지

목적:
- 실험 결과와 운영 반영을 시스템적으로 분리
- 운영은 “검증된 변경”만 받도록 통제

운영 흔적:
- promotion/shadow 결과는 MLflow run tag 및 Slack 알림으로 남길 수 있습니다.
- 서빙 런타임 증거는 `docs/proof/latest/e2e_success/`에 저장됩니다.

---

## 3) Storage & Runtime Dependency

E2E는 단순 API 체인이 아니라,
Object Storage + Shared Model Repository 의존 구조 위에서 동작합니다.

### 3-1) Airflow Logs (Remote Logging)

- `AIRFLOW__LOGGING__REMOTE_LOGGING=True`
- `REMOTE_BASE_LOG_FOLDER=s3://mlflow-artifacts-keonho/<env>/airflow-logs`
- Connection: `aws_default (region: ap-northeast-2)`

의도:
- Pod 재시작과 무관한 로그 보존
- PVC 의존성 제거
- 운영 감사/보관 정책 분리

원칙:
- 로그: Object Storage (immutable, append-only)
- 모델: Shared RWX Storage (mutable, versioned directory)

---

### 3-2) Triton Model Repository (Shared RWX NFS)

Airflow와 Triton은 동일 NFS 경로를 공유합니다.

- NFS Server: `192.168.18.141`
- Dev Path: `/mnt/nfs_share/mlops/triton/model-repo/dev`
- Prod Path: `/mnt/nfs_share/mlops/triton/model-repo/prod`
- Airflow Mount: `/models`
- Access Mode: RWX

의도:
- Airflow: 모델 publish(쓰기)
- Triton: serving lifecycle(로드/언로드/서빙)

운영 환경에서는 StorageClass 기반 동적 프로비저닝으로 대체 가능하지만,
본 프로젝트는 “운영 데이터 보호”를 위해 정적 PV/PVC로 고정합니다.

#### Static PV/PVC (운영 데이터 보호)

- PVC:
  - `storageClassName: ""` (Static)
  - `volumeName`으로 PV 명시
- PV:
  - `persistentVolumeReclaimPolicy: Retain`
  - `argocd.argoproj.io/sync-options: Prune=false`

---

## 4) Deployment Success Criteria

서빙 런타임 성공은 아래 조건을 모두 만족할 때로 정의합니다.

1) Triton READY + repository index에서 READY 모델 확인
2) FastAPI `/health` OK
3) FastAPI `/models`에 alias별 version/run_id 노출
4) FastAPI reload 성공

증거:
- `docs/proof/latest/e2e_success/`

---

## 5) Failure Handling / Rollback

- READY 실패 → 배포 중단
- Triton load 실패 → 롤백/중단
- Reload 실패 → 롤백/중단

Rollback 의미:
- “이전 정상 상태”로 복원하여 운영 트래픽 안정성을 보장합니다.
