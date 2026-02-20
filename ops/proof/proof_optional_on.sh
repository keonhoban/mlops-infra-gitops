#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="docs/proof/latest/optional_on"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

log() { echo "[optional-on] $*"; }

log "0) Pre-snapshot"
argocd app list | tee "$OUT_DIR/argocd_app_list_before.txt" >/dev/null

log "1) Ensure root-optional exists (apply bootstrap manifest)"
if [ ! -f bootstrap/root-optional.yaml ]; then
  echo "ERROR: bootstrap/root-optional.yaml not found (run from repo root)" >&2
  exit 1
fi
kubectl apply -f bootstrap/root-optional.yaml | tee "$OUT_DIR/kubectl_apply_root_optional.txt" >/dev/null

log "2) Ensure root-optional is automated (prune/self-heal) + sync"
# 앱이 생성되는 타이밍 때문에 잠깐 재시도
for _ in {1..10}; do
  if argocd app get root-optional >/dev/null 2>&1; then break; fi
  sleep 1
done

argocd app set root-optional --sync-policy automated --self-heal --auto-prune \
  | tee "$OUT_DIR/root_optional_set_automated.txt" >/dev/null || true

argocd app sync root-optional | tee "$OUT_DIR/root_optional_sync.txt" >/dev/null

log "3) Post-snapshot"
argocd app get root-optional | tee "$OUT_DIR/root-optional.txt" >/dev/null || true
argocd app list | tee "$OUT_DIR/argocd_app_list_after.txt" >/dev/null
argocd app list | grep -E 'feast-|monitoring-|loki-|alloy-|optional-' \
  | tee "$OUT_DIR/optional_apps_after.txt" >/dev/null || true

log "DONE -> $OUT_DIR"
