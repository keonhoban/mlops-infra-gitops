# Operations & Proof Loop

이 문서는 “실무 유지보수 관점에서” 플랫폼을 다루는 방법을 정리합니다.  
특히 **Core-only / Optional-on 스위치 증명**을 스크립트로 재현 가능한 형태로 유지합니다.

---

## 1) 스크립트 구성

- `./ops/proof/audit_dump.sh`  
  - ArgoCD 앱 목록 / root-apps, root-optional 상세 / 네임스페이스 / PVC·PV 바인딩 / Core 런타임 probe 를 한 번에 덤프

- `./ops/proof/proof_core_only.sh`  
  - root-optional을 manual로 전환 + prune 시도  
  - Optional이 내려간 상태에서도 Core health probe 로 “Core-only”를 증명

- `./ops/proof/proof_optional_on.sh`  
  - root-optional을 다시 apply + automated/prune/self-heal + sync  
  - Optional이 스위치 방식으로 복구됨을 증명

---

## 2) 권장 실행 순서 (제출/면접용)

아래 순서를 그대로 실행하면, “OFF → ON → 감사”가 한 흐름으로 남습니다.

1. 운영 스냅샷(현재 상태)
2. Optional OFF (Core-only 증명)
3. Optional ON (복구 증명)
4. 운영 스냅샷(최종 상태)

실행:

- `./ops/proof/audit_dump.sh`
- `./ops/proof/proof_core_only.sh`
- `./ops/proof/proof_optional_on.sh`
- `./ops/proof/audit_dump.sh`

---

## 3) 증거(Proof) 디렉토리 구조

### Core-only 증거

- `docs/proof/core_only/<timestamp>/`
  - `argocd_app_list_before.txt`
  - `argocd_app_list_after.txt`
  - `optional_apps_after.txt`
  - `core_health_probes.txt`
  - `root-apps.txt`

핵심은 “Optional이 내려간 흔적”과 “Core가 멀쩡한 증거”가 같은 폴더에 함께 남는 것입니다.

### Optional-on 증거

- `docs/proof/optional_on/<timestamp>/`
  - `root-optional.txt`
  - `optional_apps_after.txt`
  - `argocd_app_list_after.txt`
  - `root_optional_sync.txt`

핵심은 “root-optional이 Healthy/Synced로 복구”되고, optional 앱들이 다시 살아난다는 증거입니다.

### Audit 스냅샷

- `docs/audit/<timestamp>/`
  - `argocd_app_list.txt`
  - `root-apps.txt`
  - `root-optional.txt`
  - `namespaces_optional.txt`
  - `pvc_pv_sanity.txt`
  - `core_runtime_probes.txt`

Audit은 면접에서 “운영 관점으로 무엇을 봤는지”를 보여주기 좋습니다.

---

## 4) 운영 주의사항 (실무형 체크리스트)

### A. root-optional 삭제/재생성 이슈(Deleting + finalizer)
- root-optional이 `deleting` 상태로 묶이면 sync가 실패할 수 있습니다.
- 이 경우 finalizer 제거 후 재생성하는 방식이 가장 빠르게 복구됩니다.
- 이미 건호님이 하신 것처럼:
  - finalizer patch → delete(force) → apply → sync

### B. Optional OFF는 “삭제”가 아니라 “토글 + prune”
- 운영 목적은 “없애기”가 아니라 “필요할 때만 켜기”입니다.
- 따라서 manual(OFF) / automated(ON) 전환은 유지보수 관점에서 더 안전합니다.

### C. 스토리지 바인딩(PV/PVC) 불변성 유지
- Triton model repo는 dev/prod 분리 NFS 경로에 고정되어야 합니다.
- reclaimPolicy=Retain 을 통해 “앱 토글”로 인해 모델 repo 데이터가 유실되지 않게 유지합니다.

---

## 5) 면접에서 바로 쓰는 설명 문장

- “Core는 E2E 서빙 루프에 필요한 런타임만 남겨 복잡도를 제한했습니다.”
- “관측/로그/피처스토어는 Optional로 분리해 운영 부담을 낮추고, 필요할 때만 스위치로 켤 수 있습니다.”
- “토글 전후 상태를 스크립트로 재현하고, 증거 스냅샷을 docs/에 남겨 재현성을 증명했습니다.”
