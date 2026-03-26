import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Counter, Rate } from 'k6/metrics';

const p99Latency  = new Trend('p99_latency', true);
const errorRate   = new Rate('error_rate');
const requestCount = new Counter('request_count');

export const options = {
  stages: [
    { duration: '30s', target: 10  },
    { duration: '60s', target: 50  },
    { duration: '30s', target: 100 },
    { duration: '30s', target: 0   },
  ],
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    error_rate:        ['rate<0.05'],
  },
};

const FASTAPI_URL = 'http://10.103.211.177';

export default function () {
  const clientId = `client-${__VU}-${__ITER}`;
  const payload = JSON.stringify({
    data: [[Math.random(), Math.random(), Math.random()]],
  });
  const params = {
    headers: {
      'Content-Type': 'application/json',
      'x-client-id': clientId,
    },
  };
  const res = http.post(`${FASTAPI_URL}/predict`, payload, params);
  const success = check(res, {
    'status 200':       (r) => r.status === 200,
    'has label output': (r) => {
      try { return JSON.parse(r.body).outputs !== undefined; }
      catch { return false; }
    },
  });
  p99Latency.add(res.timings.duration);
  errorRate.add(!success);
  requestCount.add(1);
  sleep(0.1);
}
