# k6 부하 테스트 결과

> 실행일: 2026-03-18
> 환경: 3-node bare-metal cluster

---

## 환경

| 항목 | 값 |
|------|-----|
| k6 버전 | v0.55.0 |
| 클러스터 | 3-node bare-metal |
| FastAPI replicas | 2 |
| Triton replicas | 1 (CPU-only) |
| 대상 엔드포인트 | `POST /predict` |

---

## 시나리오

단계적 램프업 후 최대 100 VU 유지, 총 150초 실행.

| 단계 | 시간 | VU |
|------|------|----|
| 램프업 | 30s | 0 → 50 |
| 유지 | 90s | 100 |
| 램프다운 | 30s | 100 → 0 |

스크립트 위치: `ops/load-test/`

---

## 결과 요약

| 지표 | 값 |
|------|-----|
| 총 요청 수 | 20,553 |
| RPS | 136.98 |
| 에러율 | **0.00%** |
| Checks 통과율 | **100%** (41,106 / 41,106) |
| p50 latency | 126 ms |
| p90 latency | 456 ms |
| p95 latency | 553 ms |
| 최대 latency | 1,510 ms |
| 최대 VU | 100 |

수치 원본: [`results.json`](./results.json)

---

## 분석

### 긍정적 지표
- **에러율 0%**: 100 VU 최대 부하 구간에서도 요청 실패 없음.
- **Checks 100%**: status 200 및 응답 구조 검증 전량 통과.
- **p95 553ms**: FastAPI → Triton CPU 추론 경로 기준으로 허용 범위 내.

### 병목 관찰
- **p90–p95 간 격차 (456ms → 553ms)**: 일부 요청이 Triton CPU 추론 큐에서 대기하는 구간 존재. GPU 전환 시 p95가 200ms 이하로 개선될 것으로 예상.
- **max 1,510ms**: 램프업 초기 또는 큐 포화 순간에 발생한 단발성 스파이크로 추정. 지속적 패턴은 아님.

### 확장 방향
- GPU 노드 추가 시 Triton 추론 latency 대폭 감소 예상 (CPU 대비 10× 이상).
- FastAPI replica를 3개로 늘리면 p90 이상 구간의 큐 대기 감소 가능.
- 목표 SLA가 p95 < 300ms라면 GPU 전환이 필수 조건.

---

## Threshold 결과

| Threshold | 조건 | 결과 |
|-----------|------|------|
| `http_req_failed` | `rate < 1%` | PASS |
| `http_req_duration{p:95}` | `< 2000ms` | PASS |
