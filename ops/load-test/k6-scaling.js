import http from "k6/http";
import { check, sleep } from "k6";

/*
 * k6 스케일링 검증 테스트
 *
 * 목적: HPA 자동 확장 동작 확인 (FastAPI replica 2→5)
 * 시나리오: 200 VU까지 단계별 확장 → 유지 → 축소
 *   - 램프업 중 HPA가 CPU 70% 기준으로 replica 증설되는지 관찰
 *   - kubectl get hpa -w 로 병행 모니터링 권장
 *
 * 실행:
 *   k6 run --env BASE_URL=http://<fastapi-host>:8000 k6-scaling.js
 */

const BASE_URL = __ENV.BASE_URL || "http://localhost:8000";

export const options = {
  stages: [
    { duration: "30s", target: 50 },
    { duration: "30s", target: 100 },
    { duration: "30s", target: 150 },
    { duration: "30s", target: 200 },
    { duration: "120s", target: 200 },
    { duration: "30s", target: 0 },
  ],
  thresholds: {
    http_req_failed: ["rate<0.05"],
    http_req_duration: ["p(95)<3000"],
  },
};

const payload = JSON.stringify({
  features: [[5.1, 3.5, 1.4, 0.2]],
});

const params = {
  headers: { "Content-Type": "application/json" },
};

export default function () {
  const res = http.post(`${BASE_URL}/predict`, payload, params);

  check(res, {
    "status is 200": (r) => r.status === 200,
    "response has body": (r) => r.body && r.body.length > 0,
  });

  sleep(0.05);
}
