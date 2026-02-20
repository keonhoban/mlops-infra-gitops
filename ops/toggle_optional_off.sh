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

# 토글 대상(명시)
OPTIONAL_ENVS_APPS=("optional-envs-dev" "optional-envs-prod")
OPTIONAL_STACK_APPS=("feast-dev" "feast-prod")

OPTIONAL_NAMESPACES=(
  "feature-store-dev" "feature-store-prod"
)

run() {
  local name="$1"; shift
  log "RUN: $name"
  "$@" | tee "$PROOF_DIR/$name.txt"
}

app_exists() {
  local app="$1"
  argocd app get "$app" >/dev/null 2>&1
}

delete_app_if_exists() {
  local phase="$1"; shift
  local app="$1"

  if app_exists "$app"; then
    run "${phase}_delete_${app}" kubectl -n argocd delete application "$app" --ignore-not-found=true
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

wait_ns_terminated_or_force() {
  local ns="$1"
  local start now elapsed phase
  start="$(date +%s)"

  while true; do
    if ! kubectl get ns "$ns" >/dev/null 2>&1; then
      log "[OFF] ns deleted: ${ns}"
      return 0
    fi

    phase="$(kubectl get ns "$ns" -o jsonpath='{.status.phase}' 2>/dev/null || true)"

    now="$(date +%s)"
    elapsed=$((now - start))
    if (( elapsed > WAIT_TIMEOUT_SEC )); then
      log "[OFF] TIMEOUT waiting ns terminate: ${ns} (phase=${phase})"

      if [[ "$phase" == "Terminating" ]]; then
        log "[OFF] force finalize ns=${ns}"
        kubectl get ns "$ns" -o json \
          | sed 's/"finalizers": \[[^]]*\]/"finalizers": []/' \
          | kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f - \
          || true
      fi
      return 1
    fi

    log "[OFF] waiting ns=${ns} phase=${phase} ..."
    sleep 3
  done
}

log "[OFF] proof dir: $PROOF_DIR"

run "00_before_argocd_apps"    kubectl -n argocd get applications.argoproj.io -o wide || true
run "00_before_argocd_appsets" kubectl -n argocd get applicationsets.argoproj.io -o wide || true
run "00_before_namespaces"     kubectl get ns || true

log "[OFF] delete optional child apps (explicit list)"
for app in "${OPTIONAL_STACK_APPS[@]}"; do
  delete_app_if_exists "10" "$app"
done
for app in "${OPTIONAL_ENVS_APPS[@]}"; do
  delete_app_if_exists "11" "$app"
done

log "[OFF] delete root-optional (detach optional/apps management)"
delete_app_if_exists "12" "$ROOT_OPT_APP_NAME"

log "[OFF] delete optional namespaces (core-only boundary)"
run "20_delete_optional_namespaces" kubectl delete ns "${OPTIONAL_NAMESPACES[@]}" --ignore-not-found=true || true

if [[ "$WAIT" == "true" ]]; then
  wait_no_optional_apps | tee "$PROOF_DIR/30_wait_no_optional_apps.txt" || true

  log "[OFF] WAIT=true -> waiting namespaces termination (timeout=${WAIT_TIMEOUT_SEC}s each)"
  for ns in "${OPTIONAL_NAMESPACES[@]}"; do
    log "RUN: 40_wait_ns_${ns}"
    wait_ns_terminated_or_force "$ns" | tee "$PROOF_DIR/40_wait_ns_${ns}.txt" || true
  done
fi

log "[OFF] proof"
run "90_after_argocd_apps"    kubectl -n argocd get applications.argoproj.io -o wide || true
run "90_after_argocd_appsets" kubectl -n argocd get applicationsets.argoproj.io -o wide || true
run "90_optional_scope_remaining" kubectl -n argocd get applications.argoproj.io -l scope=optional -o wide || true
run "90_optional_namespaces_remaining" kubectl get ns | egrep 'baseline-|monitoring-|observability-' || true

run "95_grep_optional_left" kubectl -n argocd get applications,applicationsets \
  | egrep 'baseline|minio|loki|alloy|monitoring|observability|promtail|feast|optional' || true

log "PROOF_DIR=$PROOF_DIR"

