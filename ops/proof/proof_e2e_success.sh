#!/usr/bin/env bash
set -euo pipefail

TS="$(date +%Y-%m-%d\ %H:%M:%S)"
OUT_DIR="docs/proof/latest/e2e_success"

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

mkdir -p "$OUT_DIR"

: "${FASTAPI_DEV_RELOAD_URL:=}"
: "${FASTAPI_PROD_RELOAD_URL:=}"
: "${FASTAPI_DEV_RELOAD_TOKEN:=}"
: "${FASTAPI_PROD_RELOAD_TOKEN:=}"

log "E2E proof start -> ${OUT_DIR}"

# --- Triton: repository index ---
capture_triton_index() {
  local ns="$1"
  local name="$2"
  local out="$3"

  kubectl -n "$ns" exec -it deploy/triton -- bash -lc "
set -e
TRITON=http://localhost:8000
echo '### ${name} ready'
curl -sS -D- \"\$TRITON/v2/health/ready\" -o /dev/null
echo
echo '### ${name} repository index (no filter)'
curl -sS -X POST \"\$TRITON/v2/repository/index\" -H 'Content-Type: application/json' -d '{}'
echo
echo '### ${name} repository index (ready=true)'
curl -sS -X POST \"\$TRITON/v2/repository/index\" -H 'Content-Type: application/json' -d '{\"ready\":true}'
echo
" | tee "$out" >/dev/null
}

log "Capture Triton dev repo index"
capture_triton_index "triton-dev"  "triton-dev"  "${OUT_DIR}/triton_dev_ready_and_repo_index.txt"

log "Capture Triton prod repo index"
capture_triton_index "triton-prod" "triton-prod" "${OUT_DIR}/triton_prod_ready_and_repo_index.txt"

# --- FastAPI snapshots ---
capture_fastapi() {
  local ns="$1"
  local deploy="$2"
  local name="$3"
  local out="$4"

  kubectl -n "$ns" exec -it "deploy/${deploy}" -- bash -lc "
set -e
API=http://localhost:8000
echo '### ${name} /health'
curl -sS \"\$API/health\"
echo
echo '### ${name} /models'
curl -sS \"\$API/models\" || true
echo
echo '### ${name} /metrics (head)'
curl -sS \"\$API/metrics\" | head -n 40 || true
" | tee "$out" >/dev/null
}

log "Capture FastAPI dev snapshot"
capture_fastapi "fastapi-dev"  "fastapi-dev"  "fastapi-dev"  "${OUT_DIR}/fastapi_dev_health_models_metrics.txt"

log "Capture FastAPI prod snapshot"
capture_fastapi "fastapi-prod" "fastapi-prod" "fastapi-prod" "${OUT_DIR}/fastapi_prod_health_models_metrics.txt"

# --- Reload via ingress (optional, best-effort) ---
reload_fastapi() {
  local name="$1"
  local url="$2"
  local token="$3"
  local out="$4"

  if [[ -z "$url" || -z "$token" ]]; then
    log "SKIP reload ${name}: FASTAPI_*_RELOAD_URL or TOKEN not set"
    return 0
  fi

  log "Reload ${name} variant A -> ${url}"
  curl -sSk -X POST "$url" -H "x-token: ${token}" | tee "$out" >/dev/null
  echo >> "$out"
}

reload_fastapi "dev"  "$FASTAPI_DEV_RELOAD_URL"  "$FASTAPI_DEV_RELOAD_TOKEN"  "${OUT_DIR}/fastapi_dev_reload_variant_a.json"
reload_fastapi "prod" "$FASTAPI_PROD_RELOAD_URL" "$FASTAPI_PROD_RELOAD_TOKEN" "${OUT_DIR}/fastapi_prod_reload_variant_a.json"

log "DONE: E2E proof files created under ${OUT_DIR}"
