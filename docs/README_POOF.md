# Proof of Core / Optional Switchable MLOps Platform

본 문서는 GitOps 기반 E2E MLOps 플랫폼이

**Core 기능만으로도 안정적으로 동작하며**,

**Optional 구성요소를 스위치 방식으로 안전하게 On/Off 할 수 있음**을

실제 실행 로그와 상태 스냅샷으로 증명합니다.

---

## 전체 구조 개요

본 플랫폼은 **App-of-Apps 패턴(ArgoCD)** 기반으로 구성되어 있으며,

구성 요소를 아래 두 계층으로 명확히 분리합니다.

### Core (항상 유지되는 핵심 경로)

- Airflow (Feature → Train → Register → Deploy)
- MLflow (Tracking + Model Registry)
- Triton Inference Server
- FastAPI (Alias 기반 A/B 모델 서빙)
- 공통 인프라 (Namespace / PV / NFS)

### Optional (확장 / 검증 목적)

- Feature Store (Feast)
- Monitoring (Prometheus / Alertmanager)
- Logging (Loki / Promtail)
- Observability 전반

Optional 구성요소는 **삭제가 아닌 토글 방식(manual ↔ automated)** 으로 제어됩니다.

---

## 1. Core-only 모드 증명 (Optional OFF)

Optional 구성요소를 **중단(prune)** 한 상태에서도

Core E2E 파이프라인이 정상 동작함을 증명합니다.

### 실행 스크립트

```
./ops/proof/proof_core_only.sh

```

### 증거 디렉토리

```
docs/proof/core_only/<timestamp>/

```

### 증명 포인트

- ArgoCD 앱 목록에서 Optional App/AppSet 제거 확인
- FastAPI / Triton / MLflow Core 서비스 정상 동작
- root-apps 기준 Core ApplicationSet 정상 유지

### 주요 증거 파일

- argocd_app_list_after.txt
- optional_apps_after.txt
- core_health_probes.txt
- root-apps.txt

### 결론

Optional(App/AppSet)이 내려간 상태에서도

Core E2E 파이프라인은 **영향 없이 정상 동작**하며,

Core와 Optional의 **운영 분리가 명확히 보장됨**을 증명합니다.

---

## 2. Optional-on 모드 증명 (Optional ON)

Optional 구성요소를 다시 **자동 동기화(Automated + Prune)** 로 전환하여

전체 스택이 정상적으로 재구성됨을 증명합니다.

### 실행 스크립트

```
./ops/proof/proof_optional_on.sh

```

### 증거 디렉토리

```
docs/proof/optional_on/<timestamp>/

```

### 증명 포인트

- root-optional Application 정상 동기화
- Optional App/AppSet 복구 확인
- 전체 ArgoCD 상태 Healthy / Synced

### 주요 증거 파일

- root-optional.txt
- optional_apps_after.txt
- argocd_app_list_after.txt

### 결론

Optional 구성요소가 **스위치 방식으로 안전하게 재구동**되며,

재배포 없이 GitOps 기준 상태 복구가 가능함을 증명합니다.

---

## 3. Audit 스냅샷 (운영 상태 덤프)

플랫폼의 **운영 상태 / 런타임 / 스토리지 바인딩**을

한 번에 스냅샷으로 남깁니다.

### 실행 스크립트

```
./ops/proof/audit_dump.sh

```

### 증거 디렉토리

```
docs/audit/<timestamp>/

```

### 포함 항목

- ArgoCD 전체 Application 상태
- root-apps / root-optional 상세 정보
- Optional 관련 Namespace 상태
- Triton / Airflow 모델 Repo PVC·PV 바인딩
- FastAPI / Triton / MLflow 런타임 상태
