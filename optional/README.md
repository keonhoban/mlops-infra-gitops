# optional/ (운영 성숙도 레이어)

Optional은 Core E2E에 필수인 구성요소가 아니라,

운영 성숙도를 증명하기 위한 확장 스택입니다.

핵심은 “항상 켜두는 기능”이 아니라,

필요할 때 붙였다가 완전히 제거할 수 있는 Attach/Detach 구조입니다.

## 포함 내용

- optional/apps: Optional ApplicationSet/App 선언
- optional/charts: Optional Helm charts
- optional/envs: Optional 환경별 values 및 운영 리소스

## 동작 방식

- Optional ON: root-optional을 연결하여 ArgoCD가 optional/apps를 관리
- Optional OFF: root-optional 제거 + Optional 네임스페이스 정리

## 핵심 규칙 (경계)

- Core의 성공/실패는 Optional과 독립적이어야 합니다.
- Optional이 죽어도 Core E2E는 계속 돌아가야 합니다.

## 다음으로 볼 곳

- 스위치 문서: docs/runbook/optional-toggle.md
- 토글 스크립트: ops/toggle_optional_on.sh, ops/toggle_optional_off.sh
