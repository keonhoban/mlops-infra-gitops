# Secrets Handling

- 본 리포지토리는 **Plain Kubernetes Secret(평문)** 을 커밋하지 않습니다.
- 민감정보는 SealedSecret(Kubeseal) 형태로만 관리하며, 복호화 키는 클러스터 컨트롤러에만 존재합니다.
- Rotation/Reseal 스크립트는 `ops/rotate`, `ops/seal` 를 참고합니다.
