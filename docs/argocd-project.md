## ArgoCD AppProject 운영 정책 (dev / prod)

이 문서는 본 MLOps 플랫폼에서 사용하는 **ArgoCD AppProject 설계 의도와 운영 정책**을 설명합니다.

목표는 **GitOps 기반 안정성 + 자동화 + 실무 유지보수 용이성**입니다.

---

## 1. 환경 분리 전략 (dev / prod)

### 프로젝트 단위 분리

- `AppProject/dev`
- `AppProject/prod`

각 프로젝트는 **소스 접근, 배포 대상, 리소스 범위**가 분리됩니다.

### Namespace 규칙

- dev: `-dev`
- prod: `-prod`

이를 통해:

- 잘못된 환경 배포를 구조적으로 차단
- GitOps에서 환경 간 충돌 방지
- 면접/설명 시 “환경 격리”를 명확히 증명 가능

---

## 2. Source Repository 제한 정책

각 AppProject는 **명시적으로 허용된 Repo만 접근 가능**합니다.

### 허용 Repo

- 내부 GitOps Repo
    - `https://github.com/keonhoban/mlops-infra-gitops`
- 외부 Helm Chart Repo
    - Bitnami
    - Prometheus Community
    - Grafana
    - OCI(bitnamicharts)

➡️ **임의의 외부 Repo 배포를 구조적으로 차단**하여

보안·재현성·감사 가능성을 확보합니다.

---

## 3. Orphaned Resources 정책

본 프로젝트는 `orphanedResources.warn = true` 를 기본으로 하되,

**의도적으로 GitOps가 직접 관리하지 않는 리소스는 ignore**합니다.

이는 “방치”가 아니라 **운영 안전성을 위한 명시적 설계**입니다.

### 3-1. TLS / Admission / 인증서 계열

외부 컨트롤러(cert-manager, admission webhook 등)가

**동적으로 생성·갱신**하는 리소스입니다.

예시:

- `-tls`
- `monitoring-*-admission`

➡️ GitOps가 직접 제어하지 않는 것이 정상이며,

삭제 시 서비스 중단 위험이 있음

---

### 3-2. 보안 / Secret 계열 (SealedSecret 패턴)

본 플랫폼은 **SealedSecret → Secret 복호화 구조**를 사용합니다.

- Git에는 SealedSecret만 존재
- 클러스터에는 Secret이 생성됨

예시:

- `airflow-*-secret`
- `mlflow-db-*-secret`
- `aws-credentials*`
- `slack-webhook*`

➡️ 복호화 결과물은 **의도적으로 GitOps 추적 대상에서 제외**

---

### 3-3. Stateful 데이터 (PVC)

운영 데이터 손실 방지를 위해 PVC는 보호 대상입니다.

예시:

- `triton-model-repo-pvc`
- `fastapi-logs-pvc-*`

➡️ GitOps sync/prune 과정에서 **데이터 삭제를 방지**

---

## 4. Helm Hook Job 운영 정책 (Airflow 사례)

Airflow 설치 시 다음 Job은 **Helm Hook으로 1회 실행**됩니다.

- DB Migration Job
- Admin User 생성 Job (`create-user`)

### 동작 방식

1. ArgoCD Sync 중 Hook Job 실행
2. 정상 완료
3. Job / Pod 자동 정리

### 관측 포인트

- ArgoCD App 상태: `Succeeded`
- Kubernetes Event에 실행/완료 로그 존재
- `kubectl get job` 에는 남지 않음

➡️ 이는 **정상 동작이며, 운영 노이즈를 남기지 않는 설계**

---

## 5. Cluster Resource 접근 정책

현재 AppProject는 다음을 허용합니다:

```yaml
clusterResourceWhitelist:
  - group: '*'
    kind: '*'

```

### 설계 의도

- Monitoring Stack, CRD, Admission Controller 등
    
    **클러스터 레벨 리소스 사용 필요**
    
- 개인/학습/포트폴리오 환경에서
    
    **구성 복잡도보다 안정성을 우선**
    

➡️ 실무 환경에서는 점진적으로 Scope 축소 가능

➡️ 현재는 **“명확히 설명 가능한 합리적 선택”**

---

## 6. 요약 (면접용 핵심 문장)

- dev/prod AppProject 분리로 환경 충돌을 구조적으로 차단
- orphan ignore는 방치가 아니라 **운영 안전을 위한 명시적 정책**
- Secret, PVC, Admission 리소스는 GitOps 보호 대상
- Helm hook job은 실행 후 정리되어 클러스터를 깨끗하게 유지
