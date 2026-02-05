# ops/storage

이 디렉토리는 **로컬/홈랩 환경에서만 필요한 PV/PVC 샘플**을 보관합니다.

- 목적: NFS/Local-path 기반으로 Triton model repo, FastAPI logs 등 **로컬 환경에서 재현 가능한 스토리지 의존성**을 고정
- 운영(회사) 환경에서는 보통:
  - StorageClass 기반 동적 프로비저닝(EBS/EFS/CEPH 등)
  - 또는 별도 IaC(Terraform) 레이어로 분리
- 따라서 이 리포지토리의 GitOps Core는 `apps/`, `charts/`, `envs/`를 중심으로 보며,
  `ops/storage`는 "환경 의존 샘플"로 취급합니다.
