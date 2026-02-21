#!/usr/bin/env bash
set -euo pipefail

ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(ts)] $*"; }

PROOF_DIR="docs/proof/optional_off_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$PROOF_DIR"

ROOT_OPT_APP_NAME="${ROOT_OPT_APP_NAME:-root-optional}"

WAIT="${WAIT:-true}"
WAIT_TIMEOUT_SEC="${WAIT_TIMEOUT_SEC:-900}"
WAIT_INTERVAL_SEC="${WAIT_INTERVAL_SEC:-5}"

# 토글 대상(명시) - monitoring 제외!
OPTIONAL_ENVS_APPS=("optional-envs-dev" "optional-envs-prod")
OPTIONAL_STACK_APPS=("feast-dev" "feast-prod")

run() {
  local name="$1"; shift
  log "RUN: $name"
  "$@" | tee "$PROOF_DIR/$name.txt"
}

app_exists() {
  local app="$1"
  argocd app get "$app" >/dev/null 2>&1
}

# 1) 가능하면 argocd app delete --cascade (리소스 정리까지 깔끔)
# 2) 안되면 kubectl delete application fallback
delete_app_if_exists() {
  local phase="$1"; shift
  local app="$1"

  if app_exists "$app"; then
    log "[OFF] deleting app=${app} (prefer: argocd app delete --cascade)"

    set +e
    run "${phase}_argocd_delete_${app}" argocd app delete "$app" --cascade --yes
    local rc=$?
    set -e

    if (( rc != 0 )); then
      log "[OFF] argocd app delete failed (rc=${rc}) -> fallback kubectl delete application ${app}"
      run "${phase}_kubectl_delete_${app}" kubectl -n argocd delete application "$app" --ignore-not-found=true
    fi
  else
    log "[OFF] skip delete (app not found): ${app}"
  fi
}

wait_no_optional_apps() {
  log "[OFF] WAIT=true -> waiting optional apps to be gone (timeout=${WAIT_TIMEOUT_SEC}s)"
  local start now elapsed
  start="$(date +%s)"

  while true; do
    now="$(date +%s)"
    elapsed=$((now - start))
    if (( elapsed > WAIT_TIMEOUT_SEC )); then
      log "[OFF] TIMEOUT waiting optional apps deletion"
      return 1
    fi

    local left
    left="$(kubectl -n argocd get applications.argoproj.io -l scope=optional --no-headers 2>/dev/null | wc -l | tr -d ' ')"

    if [[ "$left" == "0" ]]; then
      log "[OFF] optional apps are removed (scope=optional=0)"
      return 0
    fi

    log "[OFF] still waiting... remaining optional apps=${left}"
    kubectl -n argocd get applications.argoproj.io -l scope=optional --no-headers 2>/dev/null \
      | awk '{print $1,$2,$3}' \
      | sed 's/^/[OFF] remaining: /' \
      | tee -a "$PROOF_DIR/15_wait_no_optional_apps_progress.txt" >/dev/null || true

    sleep "$WAIT_INTERVAL_SEC"
  done
}

log "[OFF] proof dir: $PROOF_DIR"

run "00_before_argocd_apps"    kubectl -n argocd get applications.argoproj.io -o wide || true
run "00_before_argocd_appsets" kubectl -n argocd get applicationsets.argoproj.io -o wide || true
run "00_before_optional_scope" kubectl -n argocd get applications.argoproj.io -l scope=optional -o wide || true
run "00_before_feature_store_ns" bash -lc "kubectl get ns | grep -E 'feature-store-(dev|prod)' || true" || true

log "[OFF] delete optional child apps (explicit list)"
for app in "${OPTIONAL_STACK_APPS[@]}"; do
  delete_app_if_exists "10" "$app"
done
for app in "${OPTIONAL_ENVS_APPS[@]}"; do
  delete_app_if_exists "11" "$app"
done

log "[OFF] delete root-optional (detach optional/apps management)"
delete_app_if_exists "12" "$ROOT_OPT_APP_NAME"

if [[ "$WAIT" == "true" ]]; then
  wait_no_optional_apps | tee "$PROOF_DIR/30_wait_no_optional_apps.txt" || true
fi

# ✅ 핵심: bootstrap이 namespace를 소유하므로 OFF에서 namespace를 삭제하지 않는다.
# 제출용 증거는 "ns는 남아있고(optional boundary), optional scope apps는 0개"로 남긴다.

log "[OFF] proof"
run "90_after_argocd_apps"    kubectl -n argocd get applications.argoproj.io -o wide || true
run "90_after_argocd_appsets" kubectl -n argocd get applicationsets.argoproj.io -o wide || true
run "90_optional_scope_remaining" kubectl -n argocd get applications.argoproj.io -l scope=optional -o wide || true
run "90_feature_store_ns" bash -lc "kubectl get ns | grep -E 'feature-store-(dev|prod)' || true" || true
run "91_feature_store_dev_empty"  kubectl -n feature-store-dev  get all,pvc,cm,secret -o wide || true
run "92_feature_store_prod_empty" kubectl -n feature-store-prod get all,pvc,cm,secret -o wide || true

run "95_grep_optional_left" kubectl -n argocd get applications,applicationsets \
  | grep -E 'optional|feast|feature-store' || true

log "PROOF_DIR=$PROOF_DIR"
