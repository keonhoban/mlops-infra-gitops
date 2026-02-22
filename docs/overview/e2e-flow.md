# E2E Model Lifecycle Flow

이 문서는 Core 레이어의 E2E 흐름과,
실제 운영 환경에서의 Runtime/Storage 의존성을 함께 정의합니다.

핵심 목표:

- 학습 결과를 **운영 배포 가능한 형태로 등록/검증/전환**
- 실패 시 **자동 중단/복원(rollback)** 으로 운영 안정성 보장
- 모델 publish와 serving lifecycle을 시스템적으로 분리

---

## 1. Flow (Core)

1) Feature 준비  
2) Model Train & Evaluate  
3) MLflow Registry 등록  
4) READY Sensor 확인  
5) Triton Load  
6) Smoke Test (Inference)  
7) FastAPI Reload  
8) Slack Notification  

---

## 2. Promotion vs Shadow (분기)

이 플랫폼은 “항상 운영 반영”이 아니라,
**품질 기준을 만족할 때만 promotion** 합니다.

- 기준 예시: `accuracy_threshold`
- 분기:
  - **promotion**: 기준 통과 → 운영 경로로 배포/전환
  - **shadow**: 기준 미달/검증 실패 → 별도 경로 배포 또는 중단

> 목적: “실험 결과”와 “운영 반영”을 시스템적으로 분리

---

## 3. Storage & Runtime Dependency

E2E는 단순 API 체인이 아니라,
Object Storage + Shared Model Repository 의존 구조 위에서 동작합니다.

### 3-1) Airflow Logs (Remote Logging)

- `AIRFLOW__LOGGING__REMOTE_LOGGING=True`
- `REMOTE_BASE_LOG_FOLDER=s3://mlflow-artifacts-keonho/<env>/airflow-logs`
- Connection: `aws_default (region: ap-northeast-2)`

Airflow 로그는 PVC가 아닌 **S3-compatible Object Storage**에 저장됩니다.

- 로컬 `/opt/airflow/logs` → EmptyDir (ephemeral)
- 운영 보존 로그 → Object Storage 기준

의도:
- Pod 재시작과 무관한 로그 보존
- PVC 의존성 제거
- 운영 감사/보관 정책 분리

설계 원칙:

- 로그는 Object Storage (immutable, append-only)
- 모델은 Shared RWX Storage (mutable, versioned directory)
- 성격이 다른 데이터를 서로 다른 스토리지 계층으로 분리

---

### 3-2) Triton Model Repository (Shared RWX NFS)

Airflow와 Triton은 동일 NFS 경로를 공유합니다.

- NFS Server: `192.168.18.141`
- Dev Path: `/mnt/nfs_share/mlops/triton/model-repo/dev`
- Airflow Mount: `/models`
- Access Mode: RWX

Flow:

Airflow → `/models/<model_version>` write  
Triton → 동일 경로 watch/load

설계 의도:

- Airflow = 모델 publish 주체
- Triton = serving lifecycle 담당
- namespace는 분리하지만 storage는 의도적으로 공유

운영 환경에서는 StorageClass 기반 동적 프로비저닝으로 대체 가능.

---

## 4. Deployment Success Criteria

배포 성공은 아래 조건을 모두 만족할 때로 정의합니다.

1) MLflow Registry 등록 성공  
2) READY Sensor 통과  
3) Triton Load 성공  
4) Triton Smoke Test 성공  
5) FastAPI Reload 성공  
6) Slack 알림 전송 확인  

---

## 5. Failure Handling / Rollback

- READY 실패 → 배포 중단  
- Smoke 실패 → Rollback 실행  
- Reload 실패 → Rollback 실행  

Rollback 의미:

- “이전 정상 상태”로 복원
- 운영 트래픽 안정성 보장

---

## 6. Proof

실제 실행/토글/스토리지 마운트 증거는 `docs/proof/`에 저장합니다.
