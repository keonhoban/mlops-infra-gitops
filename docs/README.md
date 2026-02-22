# Docs Hub

이 디렉토리는 본 ML Platform의 **설계(설명용) + 운영(운영용) + 증거(Proof)** 를 분리하여 정리합니다.

권장 읽기 순서:

1. Overview(구조/흐름/경계) → 2) Runbook/Security(운영) → 3) Proof(증거)

---

## 1) Overview (설명용)

- `overview/architecture.md`
    - Core / Baseline / Optional 레이어 정의
    - Baseline(Logging/Monitoring/S3) Always-on 근거
- `overview/e2e-flow.md`
    - Core E2E 흐름(Train → Register → Ready → Deploy → Smoke → Reload → Notify)
    - Deployment Success Criteria / Rollback 정책
- `overview/argocd-boundary.md`
    - dev/prod 격리(AppProject + Namespace 규칙)
    - Optional Attach/Detach 경계(“비파괴 Detach”)
    - orphan 정책의 목적(Secret/PVC 등 운영 리소스 보호)

---

## 2) Runbook (운영용)

- `runbook/optional-toggle.md`
    - Optional ON/OFF 절차
    - 증명(Proof) 산출 방법

---

## 3) Security (운영용)

- `security/secrets.md`
    - SealedSecret 정책(평문 Secret 미커밋)
    - Rotation/Reseal 운영 규칙

---

## 4) Proof (증거)

- `proof/latest/`
    - 현재 상태 기준 스냅샷
- `proof/optional_on_<timestamp>/`, `proof/optional_off_<timestamp>/`
    - Optional Attach/Detach 실행 로그(재현/감사)

Proof의 목적:

- 운영 이력 추적
- 재현 증명
- GitOps 경계 검증
