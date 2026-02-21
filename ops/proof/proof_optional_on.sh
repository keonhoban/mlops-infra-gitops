#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="/root/mlops-infra/docs/proof/latest/optional_on"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

log() { echo "[optional-on] $*"; }

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

log "0) Pre-snapshot"
argocd app list | tee "$OUT_DIR/argocd_app_list_before.txt" >/dev/null
dump_optional_scope_apps "$OUT_DIR/optional_scope_apps_before.txt"

log "1) Turn ON optional (standard toggle script)"
if [[ -x ./ops/toggle/optional_on.sh ]]; then
  ./ops/toggle/optional_on.sh >"$OUT_DIR/optional_on_run.txt" 2>&1
else
  echo "ERROR: ./ops/toggle/optional_on.sh not found or not executable" \
    | tee "$OUT_DIR/optional_on_run.txt" >/dev/null
  exit 1
fi

# (선택이지만 강추) toggle proof_dir 추출해서 latest에 링크 남기기
# optional_on.sh는 "[ON] DONE (proof_dir=...)" 형태로 출력합니다.
{
  proof_dir="$(grep -oE 'proof_dir=.*' "$OUT_DIR/optional_on_run.txt" | tail -n 1 | cut -d= -f2- || true)"
  if [[ -n "${proof_dir:-}" ]]; then
    echo "$proof_dir" > "$OUT_DIR/toggle_proof_dir.txt"
  else
    echo "WARN: toggle proof dir not found in optional_on_run.txt" > "$OUT_DIR/toggle_proof_dir.txt"
  fi
} || true

log "2) Post-snapshot"
argocd app get root-optional | tee "$OUT_DIR/root-optional.txt" >/dev/null || true
argocd app list | tee "$OUT_DIR/argocd_app_list_after.txt" >/dev/null
dump_optional_scope_apps "$OUT_DIR/optional_scope_apps_after.txt"

# Optional 관련 key apps만 따로 보기 좋게
argocd app list | grep -E 'feast-|optional-|root-optional' \
  | tee "$OUT_DIR/optional_apps_after_grep.txt" >/dev/null || true

log "DONE -> $OUT_DIR"
