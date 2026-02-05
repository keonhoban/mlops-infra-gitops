#!/usr/bin/env bash
# toggle_optional_off.sh
#
# 목적:
# - Core(E2E) 유지한 채 Optional(Proof/확장)만 깔끔하게 OFF
# - "서류 제출 + 면접 설명 + 실무 유지보수" 기준으로:
#   1) 라벨(scope=optional) 기반으로 Optional App/AppSet 일괄 정리
#   2) Optional boundary namespace 제거(관측/로깅 등)
#   3) 증명(Proof) 로그 자동 저장
#
# 전제:
# - optional/apps 이하의 Application/ApplicationSet에 metadata.labels.scope=optional 이 부여되어 있어야 함
# - root-optional(ArgoCD Application)이 optional/apps를 관리하는 루트 역할
#
# 주의:
# - feature-store-dev/prod 는 Core에서 필요할 수 있어 기본적으로 삭제하지 않음
#   (Feast App은 라벨 기반 삭제로만 정리)

set -Eeuo pipefail

########################################
# Config (필요 시 환경변수로 덮어쓰기)
########################################
PROOF_BASE_DIR="${PROOF_BASE_DIR:-docs/proof}"
PROOF_DIR="${PROOF_DIR:-${PROOF_BASE_DIR}/optional_off_$(date +%Y%m%d_%H%M%S)}"

ARGOCD_NS="${ARGOCD_NS:-argocd}"
ROOT_OPT_APP_NAME="${ROOT_OPT_APP_NAME:-root-optional}"

# Optional boundary namespaces (Core-only 경계)
# - 지금 repo 기준으로 optional은 monitoring/observability만 boundary로 정리
OPTIONAL_NAMESPACES=(
  "monitoring-dev" "monitoring-prod"
  "observability-dev" "observability-prod"
)

# Optional label selector
OPTIONAL_LABEL_SELECTOR="${OPTIONAL_LABEL_SELECTOR:-scope=optional}"

########################################
# Helpers
########################################
mkdir -p "$PROOF_DIR"

log() { echo -e "[$(date +%F\ %T)] $*"; }

run() {
  # stdout/stderr 모두 proof에 남기고, 실행 로그도 남김
  local name="$1"; shift
  log "RUN: $name"
  {
    echo "+ $*"
    "$@"
  } &> "${PROOF_DIR}/${name}.txt" || true
}

# namespace terminating stuck 처리(로컬랩 대응)
force_finalize_namespace_if_terminating() {
  local ns="$1"
  if kubectl get ns "$ns" >/dev/null 2>&1; then
    local phase
    phase="$(kubectl get ns "$ns" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
    if [[ "$phase" == "Terminating" ]]; then
      log "Namespace $ns is Terminating -> force finalize (best-effort)"
      kubectl get ns "$ns" -o json \
        | sed 's/"finalizers": \[[^]]*\]/"finalizers": []/' \
        | kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f - \
        >/dev/null 2>&1 || true
    fi
  fi
}

########################################
# Main
########################################
log "[OFF] proof dir: $PROOF_DIR"

# (0) 현재 상태 스냅샷
run "00_before_argocd_apps" kubectl -n "$ARGOCD_NS" get applications.argoproj.io -o wide
run "00_before_argocd_appsets" kubectl -n "$ARGOCD_NS" get applicationsets.argoproj.io -o wide
run "00_before_optional_label_apps" kubectl -n "$ARGOCD_NS" get applications.argoproj.io -l "$OPTIONAL_LABEL_SELECTOR" -o wide
run "00_before_optional_label_appsets" kubectl -n "$ARGOCD_NS" get applicationsets.argoproj.io -l "$OPTIONAL_LABEL_SELECTOR" -o wide
run "00_before_namespaces" kubectl get ns -o wide

# (1) Optional AppSet 먼저 제거 (생산자부터 끊기)
# - AppSet이 남아있으면 Application이 재생성될 수 있음
run "01_delete_optional_appsets_by_label" \
  kubectl -n "$ARGOCD_NS" delete applicationset -l "$OPTIONAL_LABEL_SELECTOR" --ignore-not-found=true

# (2) Optional Application 제거 (라벨 기반)
run "02_delete_optional_apps_by_label" \
  kubectl -n "$ARGOCD_NS" delete application -l "$OPTIONAL_LABEL_SELECTOR" --ignore-not-found=true

# (3) root-optional 제거 (optional/apps 관리 루트)
# - 루트 앱을 제일 먼저 지우면 Orphan/Missing 형태로 남을 수 있어 뒤로 배치
run "03_delete_root_optional" \
  kubectl -n "$ARGOCD_NS" delete application "$ROOT_OPT_APP_NAME" --ignore-not-found=true

# (4) Optional boundary namespace 삭제 (Core-only 경계 정리)
# - 모니터링/로깅 계열은 PV/PVC/CRD 등으로 Terminating이 걸릴 수 있어 best-effort finalize 포함
run "04_delete_optional_namespaces" \
  kubectl delete ns "${OPTIONAL_NAMESPACES[@]}" --ignore-not-found=true

sleep 2
for ns in "${OPTIONAL_NAMESPACES[@]}"; do
  force_finalize_namespace_if_terminating "$ns"
done

# (5) 최종 Proof
run "99_after_argocd_apps" kubectl -n "$ARGOCD_NS" get applications.argoproj.io -o wide
run "99_after_argocd_appsets" kubectl -n "$ARGOCD_NS" get applicationsets.argoproj.io -o wide
run "99_after_optional_label_apps" kubectl -n "$ARGOCD_NS" get applications.argoproj.io -l "$OPTIONAL_LABEL_SELECTOR" -o wide
run "99_after_optional_label_appsets" kubectl -n "$ARGOCD_NS" get applicationsets.argoproj.io -l "$OPTIONAL_LABEL_SELECTOR" -o wide
run "99_after_namespaces" kubectl get ns -o wide

# (6) 사람 눈으로 바로 확인 가능한 한 줄 요약도 남김
{
  echo "=== QUICK CHECK ==="
  echo "[A] remaining optional apps/appsets (by label: $OPTIONAL_LABEL_SELECTOR)"
  kubectl -n "$ARGOCD_NS" get applications,applicationsets -l "$OPTIONAL_LABEL_SELECTOR" 2>/dev/null || true
  echo
  echo "[B] remaining optional boundary namespaces"
  kubectl get ns | egrep 'monitoring-|observability-' || true
} > "${PROOF_DIR}/quick_check.txt" 2>&1 || true

log "[OFF] done"
log "PROOF_DIR=${PROOF_DIR}"

