#!/usr/bin/env bash
# ops/seal/rotate-controller-key.sh
# Bitnami Sealed Secrets 컨트롤러 공개키 "추가" + "백업" + "검증" + "자동 롤백"
# - 새 키를 추가해 컨트롤러가 새 키로 암호화하도록 유도(구키는 계속 복호화 가능)
# - 기존 키는 삭제하지 않고 전량 백업. 문제 시 자동/수동 롤백 경로 제공
# - 라벨키 2종(하이픈 유무) 모두 처리하여 배포/버전 차이 안전 대응

set -euo pipefail

# ===== 사용자/환경 설정 =====
SS_NS="${SS_NS:-kube-system}"                 # 컨트롤러 네임스페이스
SS_DEPLOY="${SS_DEPLOY:-sealed-secrets}"      # 컨트롤러 Deployment 이름
SS_CTL="${SS_CTL:-sealed-secrets}"            # kubeseal --controller-name
LABEL_KEYS=("sealed-secrets.bitnami.com/sealed-secrets-key" "sealedsecrets.bitnami.com/sealed-secrets-key")
LABEL_VALUE="active"

TS="$(date +%F-%H%M%S)"
BACKUP_DIR="${BACKUP_DIR:-/root/backup/sealed-secrets-keys/$TS}"
mkdir -p "$BACKUP_DIR"

need(){ command -v "$1" >/dev/null 2>&1 || { echo "❌ need $1"; exit 1; }; }
need kubectl; need openssl; need kubeseal; need sed; need awk

info(){ echo "[$(date +%H:%M:%S)] $*"; }

# ===== 0) 배포체 확인 =====
if ! kubectl -n "$SS_NS" get deploy/"$SS_DEPLOY" >/dev/null 2>&1; then
  echo "❌ 컨트롤러 배포체가 없습니다: ns=$SS_NS deploy=$SS_DEPLOY"
  echo "   예: SS_DEPLOY=sealed-secrets-controller 로 다시 실행해 보세요."
  exit 1
fi
info "컨트롤러 배포체: $SS_DEPLOY (ns=$SS_NS)"

# ===== 1) 구키 백업 =====
info "백업 디렉터리: $BACKUP_DIR"
mapfile -t ALL_KEYS < <(kubectl -n "$SS_NS" get secret -l "${LABEL_KEYS[0]},${LABEL_KEYS[1]}" \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)

if (( ${#ALL_KEYS[@]} == 0 )); then
  # 레이블 없는 기존 키까지 포함해 모두 백업
  mapfile -t ALL_KEYS < <(kubectl -n "$SS_NS" get secret -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
    | grep -E '^sealed-secrets-key' || true)
fi
for s in "${ALL_KEYS[@]:-}"; do
  kubectl -n "$SS_NS" get secret "$s" -o yaml > "$BACKUP_DIR/$s.yaml" && \
  info "백업 완료: $BACKUP_DIR/$s.yaml"
done

# 현재 active 라벨 붙은 키 목록 저장(롤백 대비)
mapfile -t OLD_ACTIVE < <(kubectl -n "$SS_NS" get secret \
  -l "${LABEL_KEYS[0]}=$LABEL_VALUE" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
if (( ${#OLD_ACTIVE[@]} == 0 )); then
  mapfile -t OLD_ACTIVE < <(kubectl -n "$SS_NS" get secret \
    -l "${LABEL_KEYS[1]}=$LABEL_VALUE" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
fi
PREV_ACTIVE="${OLD_ACTIVE[0]:-}"

# ===== 2) 현재 컨트롤러 공개키 Fingerprint =====
info "컨트롤러 공개키 Fingerprint (회전 전):"
OLD_FPR_CTRL="$(kubeseal --controller-name "$SS_CTL" --controller-namespace "$SS_NS" --fetch-cert \
  | openssl x509 -noout -fingerprint -sha256 | awk -F= '{print $2}')"
echo "${OLD_FPR_CTRL:-<unknown>}"

# ===== 3) 새 키 생성 및 Secret YAML 준비 =====
NEW_NAME="sealed-secrets-key-${TS}"
TMP_KEY="/tmp/${NEW_NAME}.key"
TMP_CRT="/tmp/${NEW_NAME}.crt"
info "새 공개키/개인키 생성: $NEW_NAME"

openssl req -x509 -nodes -days 3650 -newkey rsa:4096 \
  -subj "/CN=sealed-secrets/O=sealedsecrets" \
  -keyout "$TMP_KEY" -out "$TMP_CRT" >/dev/null 2>&1

# Secret 매니페스트 생성 및 백업 저장
cat > "$BACKUP_DIR/$NEW_NAME.yaml" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${NEW_NAME}
  namespace: ${SS_NS}
  labels:
    ${LABEL_KEYS[0]}: ${LABEL_VALUE}
    ${LABEL_KEYS[1]}: ${LABEL_VALUE}
type: kubernetes.io/tls
data:
  tls.crt: $(base64 -w0 < "$TMP_CRT")
  tls.key: $(base64 -w0 < "$TMP_KEY")
EOF
info "새 키 yaml 백업: $BACKUP_DIR/$NEW_NAME.yaml"

# 보안상 로컬 키 파일 제거
shred -u "$TMP_KEY" || true
rm -f "$TMP_CRT" || true

# 적용
kubectl apply -f "$BACKUP_DIR/$NEW_NAME.yaml" >/dev/null

# ===== 4) 기존 active 라벨 제거(두 라벨키 모두) =====
if (( ${#OLD_ACTIVE[@]} > 0 )); then
  for s in "${OLD_ACTIVE[@]}"; do
    for LK in "${LABEL_KEYS[@]}"; do
      kubectl -n "$SS_NS" label secret "$s" "$LK"- --overwrite 2>/dev/null || true
    done
  done
fi

# ===== 5) 컨트롤러 재시작 & 대기 =====
info "컨트롤러 롤아웃 재시작: $SS_DEPLOY"
kubectl -n "$SS_NS" rollout restart "deploy/$SS_DEPLOY"
kubectl -n "$SS_NS" rollout status  "deploy/$SS_DEPLOY" --timeout=180s

# ===== 6) Fingerprint 비교 (검증) =====
info "컨트롤러 공개키 Fingerprint (회전 후):"
NEW_FPR_CTRL="$(kubeseal --controller-name "$SS_CTL" --controller-namespace "$SS_NS" --fetch-cert \
  | openssl x509 -noout -fingerprint -sha256 | awk -F= '{print $2}')"
echo "${NEW_FPR_CTRL:-<unknown>}"

NEW_FPR_SECRET="$(kubectl -n "$SS_NS" get secret "$NEW_NAME" -o jsonpath='{.data.tls\.crt}' \
  | base64 -d | openssl x509 -noout -fingerprint -sha256 | awk -F= '{print $2}')"

echo "controller: ${NEW_FPR_CTRL:-<unknown>}"
echo " new cert : ${NEW_FPR_SECRET:-<unknown>}"

rollback_labels() {
  info "❌ 지문 불일치 또는 추출 실패 → 라벨 롤백"
  # 새 키 active 라벨 제거(두 라벨키 모두)
  for LK in "${LABEL_KEYS[@]}"; do
    kubectl -n "$SS_NS" label secret "$NEW_NAME" "$LK"- --overwrite 2>/dev/null || true
  done
  # 이전 active 키 복귀
  if [[ -n "${PREV_ACTIVE:-}" ]]; then
    for LK in "${LABEL_KEYS[@]}"; do
      kubectl -n "$SS_NS" label secret "$PREV_ACTIVE" "$LK=$LABEL_VALUE" --overwrite 2>/dev/null || true
    done
  fi
  # 컨트롤러 재시작
  kubectl -n "$SS_NS" rollout restart "deploy/$SS_DEPLOY"
  kubectl -n "$SS_NS" rollout status  "deploy/$SS_DEPLOY" --timeout=180s
}

if [[ -z "${NEW_FPR_CTRL:-}" || -z "${NEW_FPR_SECRET:-}" || "$NEW_FPR_CTRL" != "$NEW_FPR_SECRET" ]]; then
  rollback_labels
  echo "↩︎ 롤백 완료. 현재 컨트롤러 지문:"
  kubeseal --controller-name "$SS_CTL" --controller-namespace "$SS_NS" --fetch-cert \
  | openssl x509 -noout -fingerprint -sha256
  exit 1
fi

info "✅ 새 공개키 적용 완료 (구키는 유지 중, 복호화 가능)."
info "👉 다음 단계: DRY_RUN=1 bash ops/seal/re-seal.sh <env> 로 변경 여부 확인 후, 문제 없으면 reseal 실행"
info "   필요시 이전 키로 되돌리려면 백업 yaml을 적용하고( $BACKUP_DIR ), 이전 키에 두 라벨키 모두 active 부여 후 재시작하세요."
