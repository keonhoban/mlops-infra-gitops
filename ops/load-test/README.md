# k6 부하 테스트

FastAPI → Triton 추론 경로의 성능 검증 및 HPA 스케일링 테스트.

## 전제 조건

- [k6](https://grafana.com/docs/k6/latest/set-up/install-k6/) v0.55.0+
- FastAPI 서비스 접근 가능 (NodePort 또는 port-forward)
- Triton에 모델이 로드된 상태 (`explicit` 모드)

## 스크립트

| 파일 | 목적 | 최대 VU | 소요 시간 |
|------|------|---------|-----------|
| `k6-predict.js` | 기본 성능 측정 (RPS, latency, 에러율) | 100 | 150초 |
| `k6-scaling.js` | HPA 자동 확장 검증 | 200 | 270초 |

## 실행

```bash
# 기본 부하 테스트
k6 run --env BASE_URL=http://<fastapi-host>:8000 k6-predict.js

# 스케일링 테스트 (HPA 활성화 필요)
k6 run --env BASE_URL=http://<fastapi-host>:8000 k6-scaling.js

# port-forward 사용 시
kubectl port-forward svc/fastapi-dev-service 8000:8000 -n fastapi-dev
k6 run --env BASE_URL=http://localhost:8000 k6-predict.js
```

## HPA 모니터링 (스케일링 테스트 시)

```bash
# 별도 터미널에서 HPA 상태 실시간 관찰
kubectl get hpa -n fastapi-dev -w
```

## 결과 기록

테스트 결과는 `docs/proof/load-test/`에 기록.
JSON 출력: `k6 run --out json=results.json k6-predict.js`
