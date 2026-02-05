# Optional Stack Toggle (Core vs Optional)

## 목적

이 프로젝트는 **“서류 제출 + 면접 설명 + 실무 유지보수”** 기준으로

복잡도를 통제하면서도 운영 감각을 보여주기 위한 구조를 갖는다.

- **Core**
    - 항상 켜져 있는 최소 E2E
    - Airflow / MLflow / Triton / FastAPI
    - dev / prod 분리
    - 제출 · 면접 · 유지보수 기준의 기준선
- **Optional**
    - Observability, Logging, Feast 등 확장/증명용 스택
    - 필요할 때만 활성화
    - 활성화 시에는 운영 수준의 자동 회복 보장

핵심 원칙은

**“운영은 자동화하되, 설명과 유지보수는 단순하게”** 이다.

---

## Optional ON (운영 모드)

Optional ON은 Optional 스택을 **운영 리소스처럼 다루는 상태**이다.

동작 개념:

- `root-optional` Application을 ArgoCD에 연결
- `optional/apps` 경로가 ArgoCD 관리 대상이 됨
- Optional 리소스가 GitOps 기준으로 자동 동기화 및 자동 회복(Self-heal)됨

실행 방법:

- ops/toggle_optional_on.sh 실행

결과 상태:

- Optional 스택이 ArgoCD에 의해 관리됨
- 장애/드리프트 발생 시 자동 복구 가능
- 운영 시연 또는 Proof 목적에 적합한 상태

---

## Optional OFF (Core-only 상태)

Optional OFF는 **제출/면접/유지보수 최적 상태**를 만드는 단계이다.

동작 개념:

- `root-optional` Application을 ArgoCD 관리 대상에서 제거
- Optional 네임스페이스를 삭제하여 리소스 자체를 제거
- Core E2E만 남김

실행 방법:

- ops/toggle_optional_off.sh 실행

결과 상태:

- ArgoCD에 Optional Application 없음
- Optional 네임스페이스 없음
- Core E2E만 남은 가장 단순한 구조
- 설명·디버깅·유지보수에 최적화된 상태

---

## 왜 ON/OFF 토글 구조인가

Optional 스택을 항상 켜두는 것은 운영에는 자연스럽지만,

다음 문제를 만든다.

- 제출 시 구조가 과도하게 복잡해짐
- 면접 설명 시 핵심 E2E 흐름이 묻힘
- 유지보수 시 디버깅 범위가 불필요하게 커짐

그래서 이 프로젝트는 다음 기준을 따른다.

- Core는 항상 자동 회복
- Optional은 필요할 때만 자동 회복
- Optional을 끄면 흔적 없이 사라짐
