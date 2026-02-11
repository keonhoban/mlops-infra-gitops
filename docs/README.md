# GitOps 기반 E2E MLOps Platform (Core + Optional Layer)

이 프로젝트는 GitOps(ArgoCD)로 런타임을 고정하고,

Airflow DAG가 모델 생명주기(학습 → 등록 → 배포 트리거 → 서빙 반영)를 자동화하는

E2E MLOps 플랫폼입니다.

핵심 목표는 3가지입니다.

- 서류 제출: “무엇을 만들었는지”가 1페이지에서 명확히 보일 것
- 면접 설명: 핵심 경로(Core)와 확장(Optional)의 경계가 분명할 것
- 실무 유지보수: Optional은 단순 기능 토글이 아니라,
    
    Core와 분리된 “운영 레이어”를 필요 시 붙였다가 완전히 제거하는 구조일 것
    

---

## 1) 한 줄 요약

Core(E2E Serving Loop)는 항상 유지하고,

Observability/Feast 같은 확장은 Optional 레이어로 분리하여

- ON 상태에서는 운영 자동 복구(GitOps Automated)
- OFF 상태에서는 완전 분리(root-optional 제거)

가 가능한 구조입니다.

- Core: Airflow → MLflow → Triton → FastAPI
- Optional: Monitoring/Logging/Feast 등 “증명/확장” 구성

---

## 2) E2E 흐름 (Core)

1. GitOps(ArgoCD)가 런타임(네임스페이스/서비스/스토리지/권한/차트)을 배포하고 상태를 고정합니다.
2. Airflow DAG가 feature → train → register → (ready/sensor) → deploy trigger → reload 를 실행합니다.
3. MLflow가 Tracking + Registry를 담당하고, alias(A/B) 전환으로 모델 릴리즈를 제어합니다.
4. Triton이 모델 repo(PV/PVC) 기반으로 서빙 준비/추론을 수행합니다.
5. FastAPI가 alias 기반으로 A/B 모델 상태를 노출하고(health/models), 요청을 서빙합니다.

---

## 3) 책임 경계

- GitOps: “틀(런타임)”을 배포/고정(Self-heal/Prune), 재현 가능한 상태를 보장
- Airflow: “행동(파이프라인)”을 실행/통제(학습/등록/배포/롤백)
- MLflow: 모델/실험/레지스트리를 단일 진실원천으로 관리
- Triton/FastAPI: 서빙 런타임(ready/smoke/모델 로딩 상태)을 명확히 제공

이 분리를 지키면, 기능이 늘어나도 “어디가 책임인지”가 흔들리지 않아

디버깅/운영 비용이 폭증하지 않습니다.

---

## 4) Core vs Optional

### Core

- ArgoCD App-of-Apps + Core ApplicationSet
- Airflow / MLflow / Triton / FastAPI
- 모델 repo PV/PVC + NFS 기반 저장 경로
- dev/prod 환경 분리

### Optional (Proof/확장)

- Monitoring: Prometheus / Grafana / Alertmanager
- Logging: Loki / Promtail(또는 Alloy)
- Feature Store 확장: Feast(+Redis)
- 기타 실험/확장 스택

Optional은 “있으면 좋은 것”이지, Core E2E가 돌아가는 데 필수 조건이 아닙니다.

---

## 5) Proof (재현 가능성)

이 프로젝트는 Core-only / Optional-on 전환을 스크립트로 재현 가능하게 설계했습니다.

- Optional OFF:
    - root-optional 제거 + Optional 네임스페이스 정리로 운영 경계(Core-only)를 명확히 함
    - 확장 스택을 제거해도 Core E2E가 정상 동작함을 증명
- Optional ON:
    - root-optional 연결로 Optional/apps를 GitOps 관리 대상으로 편입
    - 확장 스택이 GitOps 기준으로 자동 복구 가능함을 증명

모든 전환 결과는 실행 로그로 남아 재현성과 운영 감각을 함께 보여줍니다.

---

## 6) 운영 문서

- Optional 스택 토글(runbook): docs/runbook/optional-toggle.md
