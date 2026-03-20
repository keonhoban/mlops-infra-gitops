# SealedSecrets — Optional Stack (dev)

Optional 레이어(Feast/Redis)에서 사용하는 민감정보를 SealedSecret 형태로 관리합니다.
평문 Secret은 Git에 커밋하지 않습니다.

## 생성 / 교체 절차

1. 평문 Secret YAML 작성 (Git에 커밋하지 않음)
2. `kubeseal`로 암호화:
   ```bash
   kubeseal --controller-namespace kube-system \
     --format yaml < secret.yaml > sealed-secret.yaml
   ```
3. 암호화된 파일을 이 디렉토리에 저장 후 Git 커밋
4. ArgoCD 동기화로 클러스터에 반영

## 일괄 재암호화

컨트롤러 키 교체 또는 값 변경 시:

```bash
make reseal-dev
```

## 참조

- 전체 시크릿 운영 정책: [docs/security/secrets.md](../../../docs/security/secrets.md)
- 키 교체 절차: `make rotate-ss-key`
