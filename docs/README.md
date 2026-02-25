# Docs Index

## 읽는 순서

1) 전체 구조 한 장 요약
- `overview/architecture.md`

2) 실제 E2E 흐름(정의/의존성/성공 조건)
- `overview/e2e-flow.md`

3) GitOps 경계(실수 방지 장치) + Optional 토글 철학
- `overview/argocd-boundary.md`

4) 운영 동선(Optional ON/OFF)
- `runbook/optional-toggle.md`

5) 관측/장애 대응 Quick checks
- `runbook/observability.md`

6) 민감정보/키 관리(SealedSecrets)
- `security/secrets.md`

---

## 읽는 순서

1) Optional 토글
- `runbook/optional-toggle.md`

2) 관측/장애 대응
- `runbook/observability.md`

3) 보안/키 운영
- `security/secrets.md`

---

## Proof (증거)

- `proof/latest/` : 최신 스냅샷 인덱스
- `proof/latest/core_only/` : Optional OFF(Core+Baseline) 증거
- `proof/latest/optional_on/` : Optional ON 증거
- `proof/latest/e2e_success/` : E2E Success(서빙 런타임) 증거

시작점:
- `proof/latest/INDEX.md`
