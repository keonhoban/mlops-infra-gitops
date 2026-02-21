# E2E Model Lifecycle Flow

이 문서는 Core 레이어의 E2E 흐름을 정의합니다.

핵심 목표:
- 학습 결과를 **운영 배포 가능한 형태로 등록/검증/전환**
- 실패 시 **자동 중단/복원(rollback)** 으로 운영 안정성을 보장

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

이 플랫폼은 “항상 운영 반영”이 아니라, **품질 기준을 만족할 때만 promotion** 합니다.

- 기준 예시: `accuracy_threshold`
- 분기:
  - **promotion**: 기준 통과 → 운영 경로로 배포/전환
  - **shadow**: 기준 미달/검증 실패 → 운영 혼선 방지를 위해 별도 경로로 배포(또는 실패 알림 후 종료)

> 목적: “실험 결과”와 “운영 반영”을 시스템적으로 분리

---

## 3. Deployment Success Criteria

배포 성공은 아래 조건을 모두 만족할 때로 정의합니다.

1) MLflow Registry 등록 성공
2) READY Sensor 통과
3) Triton Load 성공
4) Triton Smoke Test 성공
5) FastAPI Reload 성공
6) Slack 알림 전송 확인

---

## 4. Failure Handling / Rollback

- READY 실패 → 배포 중단
- Smoke 실패 → Rollback 실행
- Reload 실패 → Rollback 실행

Rollback의 의미:
- “이전 정상 상태(마지막 성공 배포)”로 복원하여
  운영 트래픽이 깨지지 않도록 보장합니다.

---

## 5. Proof

실제 실행/토글/스냅샷 증거는 `docs/proof/` 에 남깁니다.
