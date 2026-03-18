# Load Test Results — FastAPI Triton Gateway

## 테스트 개요

| 항목 | 내용 |
|------|------|
| 테스트 일시 | YYYY-MM-DD HH:MM |
| 환경 | dev / prod |
| 대상 엔드포인트 | `POST /predict` |
| 도구 | locust / k6 |
| FastAPI replicas | N |
| Triton replicas | N |
| traffic_mode | mirror / split |

---

## 부하 프로파일

| 단계 | 동시 사용자(VU) | 지속 시간 | RPS 목표 |
|------|----------------|----------|---------|
| Ramp-up | 1 → N | Xs | - |
| Steady | N | Xs | N req/s |
| Ramp-down | N → 0 | Xs | - |

---

## 결과 요약

### Latency (ms)

| Percentile | `/predict` | `/variant/{alias}/predict` |
|------------|-----------|---------------------------|
| p50 | | |
| p75 | | |
| p90 | | |
| p95 | | |
| p99 | | |
| p99.9 | | |
| max | | |

### Throughput

| 지표 | 값 |
|------|----|
| 최대 RPS (requests/sec) | |
| 평균 RPS (steady 구간) | |
| 총 요청 수 | |
| 성공률 (2xx) | % |
| 오류율 (4xx/5xx) | % |
| shadow mirror 실패 (`fastapi_shadow_mirror_failures_total`) | |

### 리소스 사용량 (Steady 구간 평균)

| 컴포넌트 | CPU (request 대비) | Memory (request 대비) |
|----------|-------------------|----------------------|
| FastAPI pod (×N) | % | % |
| Triton pod (×N) | % | % |

---

## Triton 서빙 지표 (Prometheus)

| 지표 | 값 |
|------|----|
| `nv_inference_request_success` (rate 5m) | req/s |
| `nv_inference_request_failure` (rate 5m) | req/s |
| `nv_inference_request_duration_us` 평균 | μs |
| 오류율 (`failure / (success + failure)`) | % |

---

## FastAPI 지표 (Prometheus)

| 지표 | 값 |
|------|----|
| `http_requests_total{status="200"}` (rate 5m) | req/s |
| `http_requests_total{status=~"5.."}` (rate 5m) | req/s |
| `http_request_duration_seconds` p95 | s |

---

## 테스트 스크립트 참조

### locust 예시

```python
# locustfile.py
from locust import HttpUser, task, between

class PredictUser(HttpUser):
    wait_time = between(0.1, 0.5)
    headers = {"x-client-id": "load-test-user-01"}

    @task
    def predict(self):
        self.client.post(
            "/predict",
            json={"data": [[1.0, 2.0, 3.0, 4.0]]},
            headers=self.headers,
        )
```

```bash
locust -f locustfile.py \
  --host=http://fastapi.local \
  --users=50 --spawn-rate=5 --run-time=120s \
  --headless --csv=results/load_test
```

### k6 예시

```javascript
// load_test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 50 },   // ramp-up
    { duration: '60s', target: 50 },   // steady
    { duration: '10s', target: 0 },    // ramp-down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],  // p95 < 500ms
    http_req_failed: ['rate<0.01'],    // 오류율 < 1%
  },
};

export default function () {
  const res = http.post(
    'http://fastapi.local/predict',
    JSON.stringify({ data: [[1.0, 2.0, 3.0, 4.0]] }),
    { headers: { 'Content-Type': 'application/json', 'x-client-id': 'k6-user' } },
  );
  check(res, { 'status 200': (r) => r.status === 200 });
  sleep(0.1);
}
```

```bash
k6 run load_test.js --out json=results/k6_results.json
```

---

## 판정 기준

| 지표 | 목표 | 결과 | 판정 |
|------|------|------|------|
| p95 latency | < 500ms | | ✅ / ❌ |
| p99 latency | < 1000ms | | ✅ / ❌ |
| 오류율 | < 1% | | ✅ / ❌ |
| shadow mirror 실패율 | < 5% | | ✅ / ❌ |
| Triton 오류율 | < 2% | | ✅ / ❌ |

---

## 병목 분석 (해당 시 기록)

```
- 병목 지점:
- 원인:
- 조치:
- 조치 후 결과:
```

---

## 증거 파일

| 파일 | 설명 |
|------|------|
| `results/locust_stats.csv` | locust 집계 CSV |
| `results/k6_results.json` | k6 원시 결과 JSON |
| `results/grafana_snapshot.png` | Grafana 대시보드 스냅샷 (Steady 구간) |
| `results/prometheus_query.txt` | 사용한 PromQL 쿼리 목록 |
