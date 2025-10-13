#!/usr/bin/env bash
set -euo pipefail

NS=argocd
MAX_WAIT=120
WAIT_INTERVAL=5
WAITED=0

echo "[INFO] Adding Argo Helm repo..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

echo "[INFO] Creating namespace '$NS' if not exists..."
kubectl create ns $NS || true

echo "[INFO] Installing Argo CD via Helm (GitOps values)..."
helm upgrade --install argocd argo/argo-cd -n $NS \
  -f bootstrap/argocd/values.yaml

echo "[INFO] Waiting for Argo CD admin secret to be created (max ${MAX_WAIT}s)..."
until kubectl -n $NS get secret argocd-initial-admin-secret &> /dev/null; do
  if [ "$WAITED" -ge "$MAX_WAIT" ]; then
    echo "[ERROR] Timeout waiting for admin secret."
    exit 1
  fi
  echo "  → Secret not yet available. Retrying in ${WAIT_INTERVAL}s..."
  sleep $WAIT_INTERVAL
  WAITED=$((WAITED + WAIT_INTERVAL))
done

echo "[INFO] Check Admin PW CMD"
