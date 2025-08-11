#!/usr/bin/env bash
set -euo pipefail

NS=argocd
helm repo add argo https://argoproj.github.io/argo-helm
kubectl create ns $NS || true

helm upgrade --install argocd argo/argo-cd -n $NS \
  --set global.image.tag=v2.12.3 \
  --set configs.params."server\.insecure"=false \
  --set server.service.type=ClusterIP \
  --set dex.enabled=false \
  --set redis.enabled=true \
  --set controller.enableStatefulSet=true \
  --set repoServer.replicas=2 \
  --set controller.replicas=2 \
  --set server.replicas=2

echo "[INFO] Admin PW:"
kubectl -n $NS get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
