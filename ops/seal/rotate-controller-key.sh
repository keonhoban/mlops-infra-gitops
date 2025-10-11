#!/usr/bin/env bash
# ops/seal/rotate-controller-key.sh
# Bitnami Sealed Secrets 컨트롤러 공개키 "추가" + "백업" + "재시작"
# - 새 키 추가 후 컨트롤러는 최신 키로 암호화, 구키들로 복호화 가능 (무중단)
# - 구키는 삭제하지 않음(검증 후 별도 삭제), 대신 전량 백업 보관

set -euo pipefail

# ===== 환경 변수 (귀하의 환경과 일치) =====
SS_NS="${SS_NS:-kube-system}"
SS_DEPLOY="${SS_DEPLOY:-sealed-secrets-controller}"
SS_CTL="${SS_CTL:-sealed-secrets}"  # kubeseal --controller-name
LABEL_KEY="sealedsecrets.bitnami.com/sealed-secrets-key"
LABEL_VALUE="active"

# ===== 출력/백업 경로 =====
TS="$(date +%F-%H%M%S)"
BACKUP_DIR="${BACKUP_DIR:-/root/backup/sealed-secrets-keys/$TS}"
mkdir -p "$BACKUP_DIR"

need() { command -v "$1" >/dev/null 2>&1 || { echo "❌ need $1"; exit 1; }; }
need kubectl; need openssl; need kubeseal

info(){ echo "[$(date +%H:%M:%S)] $*"; }

# ===== 0) 사전 정보 & 구키 백업 =====
info "백업 디렉터리: $BACKUP_DIR"

info "기존 활성 키 목록 확인 및 백업 중..."
mapfile -t OLD_KEYS < <(kubectl -n "$SS_NS" get secret -l "$LABEL_KEY=$LABEL_VALUE" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

if (( ${#OLD_KEYS[@]} > 0 )); then
  for s in "${OLD_KEYS[@]}"; do
    kubectl -n "$SS_NS" get secret "$s" -o yaml > "$BACKUP_DIR/$s.yaml"
    info "백업 완료: $BACKUP_DIR/$s.yaml"
  done
else
  info "활성 키가 없습니다(초기 설치 상태일 수 있음)."
fi

# ===== 1) 현재 공개키 Fingerprint (회전 전) =====
info "기존 컨트롤러 공개키(Fingerprint, 회전 전):"
kubeseal --controller-name "$SS_CTL" --controller-namespace "$SS_NS" --fetch-cert \
| openssl x509 -noout -fingerprint -sha256 || true

# ===== 2) 새 키 생성 & Secret 생성 =====
NEW_NAME="sealed-secrets-key-${TS}"
TMP_KEY="/tmp/${NEW_NAME}.key"
TMP_CRT="/tmp/${NEW_NAME}.crt"

info "새 공개키/개인키 생성: $NEW_NAME"
openssl req -x509 -nodes -days 3650 -newkey rsa:4096 \
  -subj "/CN=sealed-secrets/O=sealedsecrets" \
  -keyout "$TMP_KEY" -out "$TMP_CRT" >/dev/null 2>&1

info "컨트롤러 네임스페이스(${SS_NS})에 Secret 생성 및 활성 라벨 부여"
kubectl -n "$SS_NS" create secret tls "$NEW_NAME" \
  --cert="$TMP_CRT" --key="$TMP_KEY"

kubectl -n "$SS_NS" label secret "$NEW_NAME" "$LABEL_KEY=$LABEL_VALUE"

# 보안상 즉시 삭제(로컬 사본)
shred -u "$TMP_KEY" || true
rm -f "$TMP_CRT" || true

# ===== 3) 컨트롤러 재시작 & 대기 =====
info "컨트롤러 롤아웃 재시작: $SS_DEPLOY"
kubectl -n "$SS_NS" rollout restart "deploy/$SS_DEPLOY"
kubectl -n "$SS_NS" rollout status "deploy/$SS_DEPLOY" --timeout=120s

# ===== 4) 새로운 공개키 Fingerprint (회전 후) =====
info "신규 컨트롤러 공개키(Fingerprint, 회전 후):"
kubeseal --controller-name "$SS_CTL" --controller-namespace "$SS_NS" --fetch-cert \
| openssl x509 -noout -fingerprint -sha256 || true

info "✅ 새 공개키 적용 완료 (구키는 유지 중)."
info "👉 다음 단계: ops/seal/re-seal.sh <env> 실행으로 모든 SealedSecret을 새 공개키로 재암호화하세요."
info "   검증 완료 후, 필요 시 구키 삭제 가능(백업: $BACKUP_DIR)."
