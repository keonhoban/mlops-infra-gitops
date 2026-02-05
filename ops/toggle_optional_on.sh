#!/usr/bin/env bash
# toggle_optional_on.sh
#
# 목적:
# - Core(E2E) 유지한 채 Optional(Proof/확장)을 다시 ON
# - "서류 제출 + 면접 설명 + 실무 유지보수" 기준으로:
#   1) root-optional을 apply 해서 optional/apps를 ArgoCD가 다시 관리하게 함
#   2) sync(optional)로 실제 리소스가 복구되는 것까지 한 번에 확인 가능
#   3) 증명(Proof) 로그 자동 저장
#
# 전제:
# - root-optional Application manifest가 존재해야 함 (예: optional/apps/root-optional.yaml 또는 apps/root-optional.yaml)
# - optional/apps 아래의 Application/ApplicationSet들이 scope=optional 라벨을 가지고 있으면 유지보수성이 올라감
#
# 주의:
# - 이 스크립트는 "생성"만 담당하고, 실제 배포 결과는 argocd sync로 확인
# - argocd CLI 세션 만료 시 argocd login 필요 (운영에서는 SSO/토큰 권장)

set -Eeuo pipefail

########################################
# Config (필요 시 환경변수로 덮어쓰기)
########################################
PROOF_BASE_DIR="${PROOF_BASE_DIR:-docs/proof}"
PROOF_DIR="${PROOF_DIR:-${PROOF_BASE_DIR}/optional_on_$(date +%Y%m%d_%H%M%S)}"

ARGOCD_NS="${ARGOCD_NS:-argocd}"
ROOT_OPT_APP_NAME="${ROOT_OPT_APP_NAME:-root-optional}"

# root-optional manifest 경로 (repo 구조에 맞게 1곳만 표준화 추천)
# 예시:
# - apps/root-optional.yaml
# - optional/apps/root-optional.yaml
ROOT_OPT_MANIFEST_PATH="${ROOT_OPT_MANIFEST_PATH:-apps/root-optional.yaml}"

# Optional label selector (Proof 용)
OPTIONAL_LABEL_SELECTOR="${OPTIONAL_LABEL_SELECTOR:-scope=optional}"

# optional apps가 사용하는 boundary namespace가 필요하다면 여기에 추가 가능
# (일반적으로 optional-envs-dev/prod 같은 App이 namespace를 만들기 때문에 비워둬도 됩니다.)
OPTIONAL_NAMESPACES_HINT=(
  "monitoring-dev" "monitoring-prod"
  "observability-dev" "observability-prod"
)

########################################
# Helpers
########################################
mkdir -p "$PROOF_DIR"

log() { echo -e "[$(date +%F\ %T)] $*"; }

run() {
  local name="$1"; shift
  log "RUN: $name"
  {
    echo "+ $*"
    "$@"
  } &> "${PROOF_DIR}/${name}.txt" || true
}

########################################
# Main
########################################
log "[ON] proof dir: $PROOF_DIR"

# (0) 현재 상태 스냅샷
run "00_before_argocd_apps" kubectl -n "$ARGOCD_NS" get applications.argoproj.io -o wide
run "00_before_argocd_appsets" kubectl -n "$ARGOCD_NS" get applicationsets.argoproj.io -o wide
run "00_before_optional_label_apps" kubectl -n "$ARGOCD_NS" get applications.argoproj.io -l "$OPTIONAL_LABEL_SELECTOR" -o wide
run "00_before_optional_label_appsets" kubectl -n "$ARGOCD_NS" get applicationsets.argoproj.io -l "$OPTIONAL_LABEL_SELECTOR" -o wide
run "00_before_namespaces" kubectl get ns -o wide

# (1) root-optional 적용 (optional/apps를 다시 관리하도록 붙이기)
if [[ ! -f "$ROOT_OPT_MANIFEST_PATH" ]]; then
  log "ERROR: root-optional manifest not found: $ROOT_OPT_MANIFEST_PATH"
  log "Hint: set ROOT_OPT_MANIFEST_PATH env or move manifest to a standard location."
  exit 1
fi

run "01_apply_root_optional" kubectl apply -f "$ROOT_OPT_MANIFEST_PATH"

# (2) root-optional이 등록되었는지 확인
run "02_get_root_optional" kubectl -n "$ARGOCD_NS" get application "$ROOT_OPT_APP_NAME" -o wide

# (3) Optional이 실제 생성되기까지 약간 텀(ArgoCD reconcile) 필요할 수 있음
sleep 2

# (4) Proof: optional app/appset이 올라오기 시작했는지 확인
run "03_optional_label_apps" kubectl -n "$ARGOCD_NS" get applications.argoproj.io -l "$OPTIONAL_LABEL_SELECTOR" -o wide
run "03_optional_label_appsets" kubectl -n "$ARGOCD_NS" get applicationsets.argoproj.io -l "$OPTIONAL_LABEL_SELECTOR" -o wide

# (5) 사람이 보는 quick check
{
  echo "=== QUICK CHECK ==="
  echo "[A] root-optional exists?"
  kubectl -n "$ARGOCD_NS" get application "$ROOT_OPT_APP_NAME" 2>/dev/null || true
  echo
  echo "[B] optional apps/appsets (by label: $OPTIONAL_LABEL_SELECTOR)"
  kubectl -n "$ARGOCD_NS" get applications,applicationsets -l "$OPTIONAL_LABEL_SELECTOR" 2>/dev/null || true
  echo
  echo "[C] optional namespaces hint (might appear after sync)"
  kubectl get ns | egrep 'monitoring-|observability-' || true
} > "${PROOF_DIR}/quick_check.txt" 2>&1 || true

log "[ON] done"
log "PROOF_DIR=${PROOF_DIR}"

