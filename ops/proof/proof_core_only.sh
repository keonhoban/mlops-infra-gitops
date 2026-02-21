#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="/root/mlops-infra/docs/proof/latest/core_only"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

log() { echo "[core-only] $*"; }

# Find a pod reliably for Helm-style labels.
# Prefer instance=<release> (fastapi-dev, triton-dev ...)
# Fallback to name=<chart> (fastapi, triton)
kpod() {
  local ns="$1"
  local instance="$2"   # e.g. fastapi-dev, triton-dev
  local name="$3"       # e.g. fastapi, triton

  local pod=""
  pod="$(kubectl -n "$ns" get pod -l "app.kubernetes.io/instance=$instance" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"

  if [ -z "${pod:-}" ]; then
    pod="$(kubectl -n "$ns" get pod -l "app.kubernetes.io/name=$name" \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  fi

  echo "$pod"
}

kexec() {
  local ns="$1"
  local instance="$2"
  local name="$3"
  shift 3

  local pod
  pod="$(kpod "$ns" "$instance" "$name")"
  if [ -z "${pod:-}" ]; then
    echo "ERROR: pod not found (ns=$ns, instance=$instance, name=$name)" >&2
    echo "HINT: try -> kubectl -n $ns get pod --show-labels" >&2
    return 1
  fi

  kubectl -n "$ns" exec "$pod" -- "$@"
}

log "1) Capture BEFORE app list"
argocd app list | tee "$OUT_DIR/argocd_app_list_before.txt" >/dev/null

log "2) Turn OFF optional: set root-optional to manual and prune children"
if argocd app get root-optional >/dev/null 2>&1; then
  argocd app set root-optional --sync-policy none \
    | tee "$OUT_DIR/root_optional_set_manual.txt" >/dev/null
  argocd app sync root-optional --prune \
    | tee "$OUT_DIR/root_optional_sync_prune.txt" >/dev/null || true
else
  echo "root-optional not found -> skip toggle off" \
    | tee "$OUT_DIR/root_optional_not_found.txt" >/dev/null
fi

log "3) Capture AFTER app list (optional should be gone or OutOfSync/Missing only)"
argocd app list | tee "$OUT_DIR/argocd_app_list_after.txt" >/dev/null
argocd app list | grep -E 'feast-|monitoring-|loki-|alloy-|optional-' \
  | tee "$OUT_DIR/optional_apps_after.txt" >/dev/null || true

log "4) Core health probes"
{
  echo "### fastapi-dev /health"
  kexec fastapi-dev fastapi-dev fastapi curl -sS localhost:8000/health || true
  echo
  echo "### fastapi-prod /health"
  kexec fastapi-prod fastapi-prod fastapi curl -sS localhost:8000/health || true
  echo
  echo "### triton-dev ready"
  kexec triton-dev triton-dev triton bash -lc 'set -e; curl -sS -D - localhost:8000/v2/health/ready || true'
  echo
  echo "### triton-prod ready"
  kexec triton-prod triton-prod triton bash -lc 'set -e; curl -sS -D - localhost:8000/v2/health/ready || true'
} | tee "$OUT_DIR/core_health_probes.txt" >/dev/null

log "5) Root apps snapshot"
argocd app get root-apps | tee "$OUT_DIR/root-apps.txt" >/dev/null || true

log "DONE -> $OUT_DIR"

