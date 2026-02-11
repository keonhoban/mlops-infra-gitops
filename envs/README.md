# envs/ (환경별 운영 리소스)

이 디렉토리는 dev/prod 환경별 “운영 리소스와 값(Values)”을 보관합니다.

Core 서비스의 설정은 여기서 환경별로 확정됩니다.

## 포함 내용

- dev/, prod/ 하위에 서비스별 values 및 운영 리소스
- 네임스페이스/서포트 리소스와 연동되는 환경 고정 값

## 핵심 규칙 (경계)

- 공통값은 charts/*/values/base.yaml에 둡니다.
- envs에는 “환경별 차이만” 둡니다.
- 평문 Secret은 커밋하지 않습니다(SealedSecret만 허용).

## 자주 하는 오해

- envs는 “차트 템플릿”이 아닙니다.
    
    템플릿은 charts에 있고, envs는 오버레이 값만 둡니다.
    

## 다음으로 볼 곳

- charts/*/values/base.yaml
- 보안 정책: docs/security/secrets.md
