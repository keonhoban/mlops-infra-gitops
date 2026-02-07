#!/usr/bin/env bash
set -euo pipefail

ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(ts)] $*"; }

PROOF_DIR="docs/proof/optional_off_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$PROOF_DIR"

ROOT_OPT_APP_NAME="${ROOT_OPT_APP_NAME:-root-optional}"

OPTIONAL_NAMESPACES=(
  "baseline-dev" "baseline-prod"
  "monitoring-dev" "monitoring-prod"
  "observability-dev" "observability-prod"
)

run() {
  local name="$1"; shift
  log "RUN: $name"
  "$@" | tee "$PROOF_DIR/$name.txt"
}

log "[OFF] proof dir: $PROOF_DIR"

run "00_before_argocd_apps"    kubectl -n argocd get applications.argoproj.io -o wide || true
run "00_before_argocd_appsets" kubectl -n argocd get applicationsets.argoproj.io -o wide || true

log "[OFF] detach root-optional (stop managing optional/apps)"
run "10_delete_root_optional" kubectl -n argocd delete application "$ROOT_OPT_APP_NAME" --ignore-not-found=true || true

log "[OFF] delete optional ArgoCD ApplicationSets by label (best-effort)"
run "20_delete_optional_appsets_by_label" kubectl -n argocd delete applicationset -l scope=optional --ignore-not-found=true || true

log "[OFF] delete optional ArgoCD Applications by label (best-effort)"
run "21_delete_optional_apps_by_label" kubectl -n argocd delete application -l scope=optional --ignore-not-found=true || true

log "[OFF] delete optional namespaces (core-only boundary)"
run "30_delete_optional_namespaces" kubectl delete ns "${OPTIONAL_NAMESPACES[@]}" --ignore-not-found=true || true

sleep 2
for ns in "${OPTIONAL_NAMESPACES[@]}"; do
  if kubectl get ns "$ns" >/dev/null 2>&1; then
    phase="$(kubectl get ns "$ns" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
    if [[ "$phase" == "Terminating" ]]; then
      log "[OFF] force finalize ns=$ns"
      kubectl get ns "$ns" -o json \
        | sed 's/"finalizers": \[[^]]*\]/"finalizers": []/' \
        | kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f - \
        || true
    fi
  fi
done

log "[OFF] proof"
run "90_after_argocd_apps"    kubectl -n argocd get applications.argoproj.io -o wide || true
run "90_after_argocd_appsets" kubectl -n argocd get applicationsets.argoproj.io -o wide || true
run "90_optional_apps_remaining_by_label"    kubectl -n argocd get applications.argoproj.io -l scope=optional -o wide || true
run "90_optional_appsets_remaining_by_label" kubectl -n argocd get applicationsets.argoproj.io -l scope=optional -o wide || true
run "90_optional_namespaces_remaining" kubectl get ns | egrep 'baseline-|monitoring-|observability-' || true

run "95_grep_optional_left" kubectl -n argocd get applications,applicationsets \
  | egrep 'baseline|minio|loki|alloy|monitoring|observability|promtail|feast|optional' || true

log "PROOF_DIR=$PROOF_DIR"

