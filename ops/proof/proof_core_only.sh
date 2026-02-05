#!/usr/bin/env bash
set -euo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="docs/proof/core_only/$TS"
mkdir -p "$OUT_DIR"

log() { echo "[core-only] $*"; }

kexec() {
  ns="$1"; app_label="$2"; shift 2
  pod="$(kubectl -n "$ns" get pod -l "app=$app_label" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [ -z "${pod:-}" ]; then
    echo "ERROR: pod not found (ns=$ns, app=$app_label)" >&2
    return 1
  fi
  kubectl -n "$ns" exec "$pod" -- "$@"
}

log "1) Capture BEFORE app list"
argocd app list | tee "$OUT_DIR/argocd_app_list_before.txt" >/dev/null

log "2) Turn OFF optional: set root-optional to manual and prune children"
# root-optional이 없을 수도 있으니 방어
if argocd app get root-optional >/dev/null 2>&1; then
  argocd app set root-optional --sync-policy none | tee "$OUT_DIR/root_optional_set_manual.txt" >/dev/null
  # prune로 실제 optional 리소스(자식 app/appset) 내려가게
  argocd app sync root-optional --prune | tee "$OUT_DIR/root_optional_sync_prune.txt" >/dev/null || true
else
  echo "root-optional not found -> skip toggle off" | tee "$OUT_DIR/root_optional_not_found.txt" >/dev/null
fi

log "3) Capture AFTER app list (optional should be gone or OutOfSync/Missing only)"
argocd app list | tee "$OUT_DIR/argocd_app_list_after.txt" >/dev/null
argocd app list | egrep 'feast-|monitoring-|loki-|promtail-|optional-' | tee "$OUT_DIR/optional_apps_after.txt" >/dev/null || true

log "4) Core health probes"
{
  echo "### fastapi-dev /health"
  kexec fastapi-dev fastapi-dev curl -sS localhost:8000/health || true
  echo
  echo "### fastapi-prod /health"
  kexec fastapi-prod fastapi-prod curl -sS localhost:8000/health || true
  echo
  echo "### triton-dev ready"
  kexec triton-dev triton curl -sS localhost:8000/v2/health/ready || true
  echo
  echo "### triton-prod ready"
  kexec triton-prod triton curl -sS localhost:8000/v2/health/ready || true
} | tee "$OUT_DIR/core_health_probes.txt" >/dev/null

log "5) Root apps snapshot"
argocd app get root-apps | tee "$OUT_DIR/root-apps.txt" >/dev/null || true

log "DONE -> $OUT_DIR"
