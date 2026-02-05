#!/usr/bin/env bash
set -euo pipefail

ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(ts)] $*"; }

PROOF_DIR="docs/proof/optional_on_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$PROOF_DIR"

# ✅ 표준 위치
ROOT_OPT_MANIFEST_PATH="${ROOT_OPT_MANIFEST_PATH:-bootstrap/root-optional.yaml}"

# ✅ 옵션: WAIT=true면 optional 전부 Healthy까지 대기
WAIT="${WAIT:-false}"
WAIT_TIMEOUT_SEC="${WAIT_TIMEOUT_SEC:-900}"  # 15분
WAIT_INTERVAL_SEC="${WAIT_INTERVAL_SEC:-5}"

run() {
  local name="$1"; shift
  log "RUN: $name"
  "$@" | tee "$PROOF_DIR/$name.txt"
}

wait_optional_ready() {
  log "[ON] WAIT=true -> waiting optional apps to be Synced+Healthy (timeout=${WAIT_TIMEOUT_SEC}s)"
  local start now elapsed
  start="$(date +%s)"

  while true; do
    now="$(date +%s)"
    elapsed=$((now - start))
    if (( elapsed > WAIT_TIMEOUT_SEC )); then
      log "[ON] TIMEOUT waiting optional apps"
      return 1
    fi

    # appsets 존재 체크 (loki/promtail은 appset 기반)
    local appset_cnt
    appset_cnt="$(kubectl -n argocd get applicationsets.argoproj.io -l scope=optional --no-headers 2>/dev/null | wc -l | tr -d ' ')"
    # apps 상태 체크
    # - Synced + Healthy 아닌 게 하나라도 있으면 대기 계속
    local not_ready
    not_ready="$(kubectl -n argocd get applications.argoproj.io -l scope=optional --no-headers 2>/dev/null \
      | awk '{print $1,$2,$3}' \
      | awk '$2!="Synced" || $3!="Healthy" {print}' || true)"

    if [[ "$appset_cnt" -ge 2 && -z "${not_ready}" ]]; then
      log "[ON] optional apps are ready (Synced/Healthy), appsets=${appset_cnt}"
      return 0
    fi

    log "[ON] still waiting... appsets=${appset_cnt}"
    if [[ -n "${not_ready}" ]]; then
      echo "$not_ready" | sed 's/^/[ON] not-ready: /'
    fi

    sleep "$WAIT_INTERVAL_SEC"
  done
}

log "[ON] proof dir: $PROOF_DIR"

run "00_before_argocd_apps"      kubectl -n argocd get applications.argoproj.io -o wide
run "00_before_argocd_appsets"   kubectl -n argocd get applicationsets.argoproj.io -o wide || true
run "00_before_optional_label_apps"    kubectl -n argocd get applications.argoproj.io -l scope=optional -o wide || true
run "00_before_optional_label_appsets" kubectl -n argocd get applicationsets.argoproj.io -l scope=optional -o wide || true
run "00_before_namespaces"       kubectl get ns

if [[ ! -f "$ROOT_OPT_MANIFEST_PATH" ]]; then
  log "ERROR: root-optional manifest not found: $ROOT_OPT_MANIFEST_PATH"
  log "Hint: set ROOT_OPT_MANIFEST_PATH env or move manifest to a standard location."
  exit 1
fi

log "[ON] apply root-optional (ArgoCD manages optional/apps)"
run "10_apply_root_optional" kubectl apply -f "$ROOT_OPT_MANIFEST_PATH"

if [[ "$WAIT" == "true" ]]; then
  # 대기 로직은 로그에 남기되, 실패해도 proof는 남기고 싶으면 || true로 바꿔도 됩니다.
  wait_optional_ready | tee "$PROOF_DIR/15_wait_optional_ready.txt"
fi

run "20_after_optional_label_apps"    kubectl -n argocd get applications.argoproj.io -l scope=optional -o wide || true
run "20_after_optional_label_appsets" kubectl -n argocd get applicationsets.argoproj.io -l scope=optional -o wide || true
run "20_after_namespaces"       kubectl get ns | egrep 'monitoring-|observability-|feature-store-' || true

log "PROOF_DIR=$PROOF_DIR"

