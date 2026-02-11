# ops/ (운영 스크립트)

이 디렉토리는 “GitOps는 선언, ops는 실행”이라는 원칙에 따라,

운영 시 재현/증명/유지보수에 필요한 스크립트를 모아둡니다.

## 포함 내용

- toggle: Optional Attach/Detach
- proof: Core-only / Optional-on 재현 가능한 스냅샷 생성
- rotate/seal: SealedSecret 운영(로테이션/재실링)
- storage: 스토리지 관련 운영 메모/가이드

## 핵심 규칙 (경계)

- ops는 “배포 정의”가 아니라 “운영 실행”만 담당합니다.
- 실행 결과는 docs/proof 하위에 남겨 재현성을 보장합니다.

## 추천 사용 순서

- Core 상태 증명: ops/proof/proof_core_only.sh
- Optional ON: ops/toggle_optional_on.sh
- Optional OFF: ops/toggle_optional_off.sh

## 다음으로 볼 곳

- Proof 산출물: docs/proof/
- 보안 정책: docs/security/secrets.md
