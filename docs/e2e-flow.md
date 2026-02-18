# E2E Model Lifecycle Flow

1. Feature 준비
2. Model Train
3. MLflow Registry 등록
4. READY Sensor 확인
5. Triton Load
6. Smoke Test
7. FastAPI Reload
8. Slack Notification

Failure Handling:

- READY 실패 → 배포 중단
- Smoke 실패 → Rollback DAG 실행
- Reload 실패 → 이전 정상 버전 복원

