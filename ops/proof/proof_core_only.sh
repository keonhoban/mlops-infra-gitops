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

# Print optional scope apps in a human-friendly way:
# - if none -> write "OK: scope=optional apps = 0"
dump_optional_scope_apps() {
  local out="$1"
  local has_any="false"

  if kubectl -n argocd get applications.argoproj.io -l scope=optional --no-headers 2>/dev/null | grep -q .; then
    has_any="true"
  fi

  if [[ "$has_any" == "true" ]]; then
    kubectl -n argocd get applications.argoproj.io -l scope=optional -o wide \
      | tee "$out" >/dev/null
  else
    echo "OK: scope=optional apps = 0" | tee "$out" >/dev/null
  fi
}

log "1) Capture BEFORE app list"
argocd app list | tee "$OUT_DIR/argocd_app_list_before.txt" >/dev/null

log "2) Turn OFF optional (standard toggle script)"
# NOTE:
# - optional_off.sh 자체도 docs/proof/optional_off_* 에 상세 proof를 남깁니다.
# - 여기서는 제출/시연용 latest/core_only에 실행 로그와 요약을 남깁니다.
if [[ -x ./ops/toggle/optional_off.sh ]]; then
  ./ops/toggle/optional_off.sh >"$OUT_DIR/optional_off_run.txt" 2>&1 || true
else
  echo "WARN: ./ops/toggle/optional_off.sh not found or not executable" \
    | tee "$OUT_DIR/optional_off_run.txt" >/dev/null
fi

# (선택이지만 강추) toggle proof_dir 추출해서 latest에 링크 남기기
# optional_off.sh 맨 마지막에 "PROOF_DIR=..." 형태로 출력합니다.
{
  proof_dir="$(grep -oE 'PROOF_DIR=.*' "$OUT_DIR/optional_off_run.txt" | tail -n 1 | cut -d= -f2- || true)"
  if [[ -n "${proof_dir:-}" ]]; then
    echo "$proof_dir" > "$OUT_DIR/toggle_proof_dir.txt"
  else
    echo "WARN: toggle proof dir not found in optional_off_run.txt" > "$OUT_DIR/toggle_proof_dir.txt"
  fi
} || true

log "3) Capture AFTER app list (optional scope should be 0)"
argocd app list | tee "$OUT_DIR/argocd_app_list_after.txt" >/dev/null
dump_optional_scope_apps "$OUT_DIR/optional_scope_apps_after.txt"

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
