# bootstrap/ (루트 앱 부트스트랩)

이 디렉토리는 “ArgoCD 자체를 켜고”, 루트 앱(root-apps/root-optional)을 연결하는 초기 계층입니다.

즉, 클러스터에서 GitOps를 시작시키는 진입점입니다.

## 포함 내용

- root-apps: apps/ 경로를 ArgoCD에 연결하는 App-of-Apps
- root-optional: optional/apps 경로를 Attach/Detach 하는 스위치
- ArgoCD 설치/Ingress/부가 구성(환경에 따라)

## 핵심 규칙 (경계)

- 여기서는 서비스(airflow/mlflow/...)를 직접 배포하지 않습니다.
- “GitOps의 루트 연결”만 담당합니다.

## 자주 하는 오해

- Optional OFF는 optional 폴더를 지우는 것이 아니라,
    
    root-optional을 떼어내서 ArgoCD 관리 대상에서 제외하는 방식입니다.
    

## 다음으로 볼 곳

- Core 루트: bootstrap/root-app.yaml
- Optional 스위치: bootstrap/root-optional.yaml
- 토글 Runbook: docs/runbook/optional-toggle.md
