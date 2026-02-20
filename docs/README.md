# Documentation Guide

이 디렉토리는 본 ML Platform의 설계 의도, 운영 정책, 증명 산출물을 정리한 문서 허브입니다.

문서는 “설계 → 운영 → 증명” 순서로 읽는 것을 권장합니다.

---

## 1. Architecture

- architecture.md  
  Core / Baseline / Optional 레이어 구조 및 dev / prod 분리 전략 설명

- e2e-flow.md  
  모델 학습 → 등록 → 배포 → 전환 → 롤백까지의 E2E 흐름 정의  
  Deployment Success Criteria 포함

---

## 2. GitOps / ArgoCD 정책

- argocd-project.md  
  AppProject 설계 의도  
  orphan 정책  
  Secret / PVC / Admission 리소스 관리 전략

---

## 3. Runbook

- runbook/optional-toggle.md  
  Optional ON / OFF 절차  
  Core-only 상태 유지 전략  
  운영 시연 및 증명 방법

---

## 4. Security

- security/secrets.md  
  SealedSecret 기반 민감정보 관리 정책  
  Rotation 및 Reseal 원칙

---

## 5. Proof Artifacts

- proof/latest/  
  현재 상태 기준 증명 스냅샷

- proof/optional_on_<timestamp>/  
- proof/optional_off_<timestamp>/  

Optional Attach / Detach 결과 로그

Proof 디렉토리는 다음 목적을 가집니다:

- 운영 이력 추적
- 면접 시 재현 증명
- GitOps 경계 검증

주의: Baseline(Logging/Monitoring/S3)은 Always-on이며 Optional 토글로 제거되지 않습니다.
Optional 토글은 feature-store(Feast) 등 확장 레이어에만 적용됩니다.

---

## Reading Flow (면접 시 권장 동선)

1. 루트 README (전체 철학)
2. architecture.md (레이어 구조)
3. e2e-flow.md (모델 생명주기)
4. argocd-project.md (운영 정책)
5. proof/ 디렉토리 (실제 증거)

본 문서 구조는 “설계 → 운영 → 증명”을 분리하여  
설명력과 유지보수성을 동시에 확보하는 것을 목표로 합니다.

