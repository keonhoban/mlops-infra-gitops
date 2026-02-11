# apps/ (GitOps 선언 계층)

이 디렉토리는 ArgoCD가 읽는 “선언(Declaration)” 계층입니다.

여기서 Core와 Optional의 경계가 결정됩니다.

## 포함 내용

- AppProject: dev / prod / optional / bootstrap 프로젝트 경계
- Namespace scaffolding: dev/prod 공통 네임스페이스/지원 리소스
- Core ApplicationSet: mlflow/airflow/triton/fastapi를 env(dev/prod)로 확장 생성

## 핵심 규칙 (경계)

- charts, values, 비밀정보는 여기로 들어오지 않습니다.
- “서비스 설정”이 아니라 “배포 경계/정책”만 둡니다.

## 자주 하는 오해

- apps는 서비스 배포 파일을 직접 담는 곳이 아닙니다.
    
    서비스는 ApplicationSet이 charts + envs 값을 조합해서 생성합니다.
    

## 다음으로 볼 곳

- Core AppSet: apps/appset-core.yaml
- AppProject 정책: apps/project-*.yaml
- 루트 부트스트랩: bootstrap/root-app.yaml
