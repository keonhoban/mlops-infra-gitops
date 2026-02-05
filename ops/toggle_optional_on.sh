#!/usr/bin/env bash
set -euo pipefail

ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(ts)] $*"; }

PROOF_DIR="docs/proof/optional_on_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$PROOF_DIR"

# ✅ 표준 위치: bootstrap/root-optional.yaml
ROOT_OPT_MANIFEST_PATH="${ROOT_OPT_MANIFEST_PATH:-bootstrap/root-optional.yaml}"

run() {
  local name="$1"; shift
  log "RUN: $name"
  "$@" | tee "$PROOF_DIR/$name.txt"
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

# 생성/동기화는 ArgoCD가 처리하므로, 여기서는 '증명(Proof)'만 확보
run "20_after_optional_label_apps"    kubectl -n argocd get applications.argoproj.io -l scope=optional -o wide || true
run "20_after_optional_label_appsets" kubectl -n argocd get applicationsets.argoproj.io -l scope=optional -o wide || true
run "20_after_namespaces"       kubectl get ns | egrep 'monitoring-|observability-|feature-store-' || true

log "PROOF_DIR=$PROOF_DIR"

