# ops/storage

이 디렉토리는 홈랩/로컬 환경에서 재현 가능한
**명시적 PV/PVC 정의 레이어**입니다.

GitOps Core는 apps/, charts/, envs/를 중심으로 동작하며,
ops/storage는 런타임 스토리지 의존성을 고정하기 위한 구성입니다.

---

## Currently Used

### 1) Triton Model Repository (RWX NFS)

Airflow ↔ Triton 간 모델 publish/serve 경로를 공유합니다.

- Dev:
  - PV: airflow-triton-model-repo-dev-pv
  - PVC: triton-model-repo-pvc (namespace: airflow-dev)
  - NFS Path: /mnt/nfs_share/mlops/triton/model-repo/dev

- Prod:
  - 동일 구조 (prod 경로 분리)

설계 의도:

- Airflow가 `/models`에 모델을 publish
- Triton이 동일 경로를 load/watch
- namespace는 분리, storage는 의도적으로 공유

---

## Archived (Not Used in Current Design)

- fastapi-logs PV/PVC
- monitoring PV/PVC 샘플
- legacy airflow-logs PV/PVC

이들은 현재 설계에서 사용하지 않으며 `_archive/`에 보관됩니다.

---

## Production Note

실제 운영 환경에서는:

- StorageClass 기반 동적 프로비저닝 (EBS/EFS/CEPH 등)
- 또는 Terraform 등 IaC 레이어에서 관리

ops/storage는 홈랩 재현을 위한 명시적 구성입니다.

