# Observability Runbook

## Scope
- Cluster-level metrics: metrics-server (`kubectl top`)
- App/K8s metrics + alerts: kube-prometheus-stack (Prometheus Operator)

---

## 운영 판단 기준 (3대 축)

### 1) FastAPI (Serving Gateway)
- 신호:
  - `/health` 비정상
  - 5xx 증가, latency(p95) 급증
- 1차:
  - FastAPI logs에서 최근 reload 시점/에러 확인
  - `/models`로 active version/run_id 확인
- 2차:
  - 이전 정상 모델로 롤백(또는 임시 차단)

### 2) Triton (Inference Runtime)
- 신호:
  - ready 실패
  - model load 실패 / inference error 증가
- 1차:
  - `/v2/health/ready`
  - `/v2/repository/index`
  - pod logs 확인
- 2차:
  - 모델 repo(파일/권한/경로) 점검 → 마지막 정상 버전으로 복원

### 3) Airflow (Pipeline Control Plane)
- 신호:
  - DAG 실패/재시도 증가, 특정 task 반복 실패
- 1차:
  - 실패 task 로그 확인(READY sensor / load / reload 등)
- 2차:
  - 배포 중단 + 롤백 동선/안전장치 검증

---

## Quick checks

### Metrics API
kubectl get apiservices v1beta1.metrics.k8s.io -o wide

### Node/Pod usage
kubectl top nodes
kubectl top pods -A | head -n 40

### Monitoring objects
kubectl -n monitoring-dev  get prometheus,alertmanager,servicemonitor,prometheusrule
kubectl -n monitoring-prod get prometheus,alertmanager,servicemonitor,prometheusrule

---

## Notes
- metrics-server는 lab 환경에서 kubelet TLS 검증 이슈를 피하기 위해 `--kubelet-insecure-tls`를 사용합니다.
  Production에서는 proper CA trust / kubelet serving cert 관리가 필요합니다.
