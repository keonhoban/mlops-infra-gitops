# Secrets Handling

- 이 리포지토리는 **Plain Kubernetes Secret(평문)** 을 커밋하지 않습니다.
- 민감정보는 **SealedSecret(kubeseal)** 형태로만 Git에 저장합니다.
- 복호화 키는 클러스터(SealedSecrets Controller)에만 존재합니다.

---

## Where Things Live

- SealedSecrets (Git):
  - `envs/*/support/sealed-secrets/**`
  - `baseline/envs/*/baseline/monitoring/extra/sealed-secrets/**`
  - `optional/envs/*/sealed-secrets/**`

- Rotation / Reseal scripts:
  - `ops/security/`

---

## Operational Rules

- Secret 변경은 “직접 kubectl apply”가 아니라,
  **rotate/reseal 스크립트 → Git 커밋 → ArgoCD 반영** 흐름을 기본으로 합니다.
