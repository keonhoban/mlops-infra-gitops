# ops/ (운영 스크립트)

이 디렉토리는 “GitOps는 선언, ops는 실행” 원칙으로,
운영 시 재현/증명/유지보수에 필요한 스크립트만 모아둡니다.

## 디렉토리 구성

- toggle/: Optional Attach/Detach (root-optional 기반)
- proof/: Core-only / Optional-on 상태를 재현 가능한 스냅샷으로 남김
- security/: SealedSecret 운영(로테이션/재실링/키 교체 등)
- storage/: PV/PVC 등 스토리지 운영 메모/가이드

> Feature schema/metadata 같은 “규격 산출물”은 ops가 아니라 docs로 이동합니다.
> - docs/feature-store/

## 핵심 규칙 (경계)

- ops는 “배포 정의”가 아니라 “운영 실행”만 담당합니다.
- 실행 결과는 docs/proof 하위에 남겨 재현성을 보장합니다.

## 추천 사용 순서

- Core 상태 증명: `ops/proof/proof_core_only.sh`
- Optional ON: `ops/toggle/optional_on.sh`
- Optional OFF: `ops/toggle/optional_off.sh`

## 다음으로 볼 곳

- Proof 산출물: `docs/proof/`
- 보안 정책: `docs/security/secrets.md`
- Optional 토글 런북: `docs/runbook/optional-toggle.md`
