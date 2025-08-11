#!/usr/bin/env bash
set -euo pipefail

NS=argocd
MAX_WAIT=120  # 최대 대기 시간 (초)
WAIT_INTERVAL=5
WAITED=0

echo "[INFO] Adding Argo Helm repo..."
helm repo add argo https://argoproj.github.io/argo-helm

echo "[INFO] Creating namespace '$NS' if not exists..."
kubectl create ns $NS || true

echo "[INFO] Installing Argo CD via Helm..."
helm upgrade --install argocd argo/argo-cd -n $NS \
  --set global.image.tag=v2.12.3 \
  --set configs.params."server\.insecure"=false \
  --set server.service.type=ClusterIP \
  --set dex.enabled=false \
  --set redis.enabled=true \
  --set controller.enableStatefulSet=true \
  --set repoServer.replicas=2 \
  --set controller.replicas=2 \
  --set server.replicas=2 \
  --set configs.cm.url="https://argocd.local"

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

echo "[INFO] Admin PW:"
kubectl -n $NS get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
