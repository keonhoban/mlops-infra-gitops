# ArgoCD Boundary & Policy (dev/prod + Optional)

이 문서는 GitOps(ArgoCD) 운영에서 가장 중요한 **경계(guardrail)** 를 정의합니다.

핵심 목표:
- dev/prod 환경 충돌을 구조적으로 차단
- Optional 레이어를 “삭제”가 아닌 **비파괴 Detach**로 운영
- Secret/PVC 등 운영 리소스는 orphan 정책으로 보호

---

## 1) Environment Isolation (dev / prod)

### Namespace 규칙
- dev: `*-dev`
- prod: `*-prod`

### AppProject 격리
- `dev` / `prod` AppProject는 **destination namespace 패턴**으로 환경을 제한합니다.
- 결과: 잘못된 환경으로의 배포가 “실수로는 불가능”한 구조가 됩니다.

---

## 2) Source of Truth (GitOps)

- 모든 변경은 Git Commit에서 시작
- ArgoCD가 선언 상태를 강제(SelfHeal/Prune)
- syncPolicy(Automated, Prune, SelfHeal)를 통해 “수동 drift”를 최소화

---

## 3) Optional Attach/Detach Boundary

Optional은 “삭제”가 아니라 **비파괴 Detach**를 목표로 합니다.

### Optional ON
- `root-optional`을 통해 optional 앱들이 생성됩니다.
- Feast/Redis 리소스가 `feature-store-*` namespace에 생성됩니다.

### Optional OFF
- Optional scope 앱(root-optional, optional-envs-*, feast-*)은 제거됩니다.
- 단, `feature-store-dev/prod` namespace는 경계/재부착 안정성을 위해 유지됩니다.
  - namespace는 “빈 컨테이너(경계)”로 남고
  - 실제 리소스는 Optional ON에서만 생성됩니다.

> Optional 토글 증거는 `docs/proof/` 하위 스냅샷으로 남습니다.

---

## 4) Orphaned Resources Policy (운영 리소스 보호)

orphan 정책은 “삭제되면 위험한 운영 리소스”를 보호하기 위한 장치입니다.

대표 보호 대상:
- Secret (TLS, DB credential, API key, Slack webhook 등)
- SealedSecret (Git에 저장되는 암호화 Secret)
- PVC (예: triton model repo, fastapi logs 등)
- (Optional) ConfigMap 등 운영 경계 리소스

목적:
- 실수/Prune/재배포로 인한 운영 데이터/자격증명 손실 방지
- GitOps 경계 내에서 “안전한 자동화”를 지속하기 위함
