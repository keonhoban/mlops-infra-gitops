#!/usr/bin/env bash
set -euo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="docs/audit/$TS"
mkdir -p "$OUT_DIR"

log() { echo "[audit] $*"; }

kexec() {
  ns="$1"; app_label="$2"; shift 2
  pod="$(kubectl -n "$ns" get pod -l "app=$app_label" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [ -z "${pod:-}" ]; then
    echo "ERROR: pod not found (ns=$ns, app=$app_label)" >&2
    return 1
  fi
  kubectl -n "$ns" exec "$pod" -- "$@"
}

log "argocd app list"
argocd app list | tee "$OUT_DIR/argocd_app_list.txt" >/dev/null

log "root-apps detail"
argocd app get root-apps | tee "$OUT_DIR/root-apps.txt" >/dev/null || true

log "root-optional detail (if exists)"
argocd app get root-optional | tee "$OUT_DIR/root-optional.txt" >/dev/null || true

log "namespaces (optional-related)"
kubectl get ns | grep -E 'feature-store|monitoring|loki|promtail' | tee "$OUT_DIR/namespaces_optional.txt" >/dev/null || true

log "PVC/PV sanity (triton/airflow model repo)"
{
  echo "### airflow-dev pvc"
  kubectl -n airflow-dev get pvc triton-model-repo-pvc -o yaml 2>/dev/null | grep -E 'name:|namespace:|storageClassName|volumeName' || true
  echo
  echo "### triton-dev pvc"
  kubectl -n triton-dev get pvc triton-model-repo-pvc -o yaml 2>/dev/null | grep -E 'name:|namespace:|storageClassName|volumeName' || true
  echo
  echo "### triton-prod pvc"
  kubectl -n triton-prod get pvc triton-model-repo-pvc -o yaml 2>/dev/null | grep -E 'name:|namespace:|storageClassName|volumeName' || true
  echo
  echo "### pv triton-model-repo-dev-pv"
  kubectl get pv triton-model-repo-dev-pv -o yaml 2>/dev/null | grep -E 'storageClassName|persistentVolumeReclaimPolicy|path:|server:' || true
  echo
  echo "### pv airflow-triton-model-repo-dev-pv"
  kubectl get pv airflow-triton-model-repo-dev-pv -o yaml 2>/dev/null | grep -E 'storageClassName|persistentVolumeReclaimPolicy|path:|server:' || true
} | tee "$OUT_DIR/pvc_pv_sanity.txt" >/dev/null

log "Core runtime probes (fastapi/triton/mlflow)"
{
  echo "### fastapi-dev /health"
  kexec fastapi-dev fastapi-dev curl -sS localhost:8000/health || true
  echo
  echo "### fastapi-dev /models"
  kexec fastapi-dev fastapi-dev curl -sS localhost:8000/models || true
  echo
  echo "### fastapi-prod /health"
  kexec fastapi-prod fastapi-prod curl -sS localhost:8000/health || true
  echo
  echo "### fastapi-prod /models"
  kexec fastapi-prod fastapi-prod curl -sS localhost:8000/models || true
  echo
  echo "### triton-dev ready"
  kexec triton-dev triton curl -sS localhost:8000/v2/health/ready || true
  echo
  echo "### triton-prod ready"
  kexec triton-prod triton curl -sS localhost:8000/v2/health/ready || true
  echo
  echo "### mlflow-dev runtime env (top + env grep)"
  kexec mlflow-dev mlflow-dev sh -lc 'ps aux | head -n 5; echo "---"; printenv | grep -E -i "DB_|MLFLOW|ARTIFACT|S3" ' || true
  echo
  echo "### mlflow-prod runtime env (top + env grep)"
  kexec mlflow-prod mlflow-prod sh -lc 'ps aux | head -n 5; echo "---"; printenv | grep -E -i "DB_|MLFLOW|ARTIFACT|S3" ' || true
} | tee "$OUT_DIR/core_runtime_probes.txt" >/dev/null

log "DONE -> $OUT_DIR"
