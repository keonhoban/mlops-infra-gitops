import http from "k6/http";
import { check, sleep } from "k6";

/*
 * k6 부하 테스트: POST /predict
 *
 * 시나리오: 단계별 램프업 → 유지 → 램프다운 (총 150초)
 * 대상: FastAPI /predict 엔드포인트 (Triton 추론 프록시)
 *
 * 실행:
 *   k6 run --env BASE_URL=http://<fastapi-host>:8000 k6-predict.js
 */

const BASE_URL = __ENV.BASE_URL || "http://localhost:8000";

export const options = {
  stages: [
    { duration: "30s", target: 50 },
    { duration: "90s", target: 100 },
    { duration: "30s", target: 0 },
  ],
  thresholds: {
    http_req_failed: ["rate<0.01"],
    http_req_duration: ["p(95)<2000"],
  },
};

// Iris 4-feature 샘플 페이로드
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
    "has prediction": (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.prediction !== undefined || body.predictions !== undefined;
      } catch {
        return false;
      }
    },
  });

  sleep(0.1);
}
