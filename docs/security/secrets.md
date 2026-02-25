# Secrets Handling (SealedSecrets)

이 리포지토리는 Plain Kubernetes Secret(평문)을 커밋하지 않습니다.
민감정보는 SealedSecret(kubeseal) 형태로만 Git에 저장합니다.

- Git에는 “암호문(SealedSecret)”만 존재
- 복호화 키는 클러스터(SealedSecrets Controller)에만 존재

---

## Controller Location

본 클러스터에서는 SealedSecrets controller가 `kube-system` namespace에서 동작합니다.
따라서 `sealed-secrets` namespace가 존재하지 않을 수 있습니다.

---

## Disaster Recovery (가장 중요한 운영 포인트)

- 새 클러스터로 복구 시 controller master key 백업이 없으면 기존 SealedSecret 복호화는 불가합니다.
- 즉, “master key 백업/보관”은 SealedSecrets 운영의 필수 조건입니다.

원칙:
- master key는 별도 안전 저장소(offline storage 등)에 백업
- 키 교체(rotation)가 필요하면 reseal로 전체 SealedSecret을 재암호화

---

## Where Things Live

### SealedSecrets (Git)
- `envs/*/support/sealed-secrets/**`
- `baseline/envs/*/baseline/monitoring/extra/sealed-secrets/**`
- `optional/envs/*/sealed-secrets/**`

### Ops scripts
- `ops/security/`

---

## Operational Rules (GitOps)

Secret 변경은 “직접 kubectl apply”가 아니라,
rotate/reseal 스크립트 → Git commit → ArgoCD 반영 흐름을 기본으로 합니다.

- `make reseal-dev` / `make reseal-prod`
- `make rotate-aws-dev` / `make rotate-aws-prod`
- `make rotate-ss-key`
