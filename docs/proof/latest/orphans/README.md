# Orphans / Released PV Notes

- `airflow-logs-pv`, `fastapi-logs-pv`는 과거 실험(초기 PVC 로그 보존) 단계에서 사용되던 PV가 Retain 정책으로 남아 `Released` 상태로 관측될 수 있습니다.
- 현재 운영 설계는 Airflow 로그를 S3-compatible Object Storage(Remote Logging)로 전환하여, 로그 보존을 애플리케이션 라이프사이클(Pod/PVC)과 분리합니다.
- 정리 계획: 해당 PV는 운영 영향이 없으므로, 필요 시 `kubectl delete pv <name>`로 정리 가능하되(데이터 정책 확인 후), 현재는 Retain 정책 검증용 흔적으로 유지합니다.
