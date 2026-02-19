#!/usr/bin/env bash
set -euo pipefail

ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(ts)] $*"; }

# -----------------------------
# Config
# -----------------------------
PROOF_DIR="docs/proof/optional_on_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$PROOF_DIR"

ROOT_OPT_MANIFEST_PATH="${ROOT_OPT_MANIFEST_PATH:-bootstrap/root-optional.yaml}"

WAIT="${WAIT:-true}"
WAIT_TIMEOUT_SEC="${WAIT_TIMEOUT_SEC:-900}"

# 출력 제어
QUIET="${QUIET:-true}"          # true면 성공/진행 로그 최소화
TAIL_EVENTS="${TAIL_EVENTS:-60}" # 실패 시 이벤트 tail 개수
TAIL_LOGS="${TAIL_LOGS:-80}"     # 실패 시 argocd app logs tail 개수

OPTIONAL_ENVS_APPS=("optional-envs-dev" "optional-envs-prod")
OPTIONAL_STACK_APPS=("monitoring-dev" "monitoring-prod" "feast-dev" "feast-prod")

# app -> namespace 매핑 (실패 시 kubectl 이벤트/파드 수집용)
app_ns() {
  case "$1" in
    optional-envs-dev)  echo "bootstrap-dev" ;;
    optional-envs-prod) echo "bootstrap-prod" ;;
    monitoring-dev)     echo "monitoring-dev" ;;
    monitoring-prod)    echo "monitoring-prod" ;;
    feast-dev)          echo "feature-store-dev" ;;
    feast-prod)         echo "feature-store-prod" ;;
    root-optional)      echo "argocd" ;;
    *)                  echo "" ;;
  esac
}

# -----------------------------
# Helpers
# -----------------------------
run_to_file() {
  local name="$1"; shift
  # stdout/stderr 모두 파일로 저장
  ( "$@" ) >"$PROOF_DIR/${name}.txt" 2>&1 || return $?
}

print_file_tail() {
  local file="$1"
  local n="${2:-120}"
  [[ -f "$file" ]] || return 0
  echo "----- tail -n $n $file -----"
  tail -n "$n" "$file" || true
}

wait_app_exists() {
  local app="$1"
  local start now elapsed
  start="$(date +%s)"
  while true; do
    if argocd app get "$app" >/dev/null 2>&1; then
      return 0
    fi
    now="$(date +%s)"
    elapsed=$((now - start))
    if (( elapsed > WAIT_TIMEOUT_SEC )); then
      log "[ON] TIMEOUT waiting app to exist: ${app}"
      return 1
    fi
    sleep 2
  done
}

# 실패 시 “필요한 것만” 수집
collect_failure_bundle() {
  local app="$1"
  local ns
  ns="$(app_ns "$app")"

  log "[ON][FAIL] collecting debug bundle for app=${app} ns=${ns:-unknown}"

  run_to_file "fail_${app}_argocd_get"  argocd app get "$app" || true
  run_to_file "fail_${app}_argocd_diff" argocd app diff "$app" || true
  run_to_file "fail_${app}_argocd_logs" argocd app logs "$app" --tail "$TAIL_LOGS" || true

  if [[ -n "$ns" ]]; then
    run_to_file "fail_${app}_kubectl_pods"   kubectl -n "$ns" get pods -o wide || true
    run_to_file "fail_${app}_kubectl_events" bash -lc "kubectl -n \"$ns\" get events --sort-by=.lastTimestamp | tail -n \"$TAIL_EVENTS\"" || true
    run_to_file "fail_${app}_kubectl_deploy" kubectl -n "$ns" get deploy,sts,ds,svc,ing,pvc -o wide || true
  fi
}

# 에러를 “짧게” 보여주고 종료
fail_fast() {
  local app="$1"
  local step="$2"
  local code="$3"

  collect_failure_bundle "$app"

  echo
  echo "================= OPTIONAL ON FAILED ================="
  echo "app : $app"
  echo "step: $step"
  echo "code: $code"
  echo "proof_dir: $PROOF_DIR"
  echo

  # 화면에는 “핵심 상태/이벤트 tail”만 보여주기
  print_file_tail "$PROOF_DIR/fail_${app}_argocd_get.txt" 120
  print_file_tail "$PROOF_DIR/fail_${app}_kubectl_events.txt" 120
  print_file_tail "$PROOF_DIR/fail_${app}_kubectl_pods.txt" 80

  echo "======================================================"
  exit "$code"
}

sync_and_wait_quiet() {
  local app="$1"
  wait_app_exists "$app"

  local sync_rc=0
  local wait_rc=0

  # set -e 때문에 중간에 죽지 않게 보호
  set +e
  run_to_file "sync_${app}" argocd app sync "$app" --prune --timeout 600
  sync_rc=$?

  if [[ "$WAIT" == "true" ]]; then
    run_to_file "wait_${app}" argocd app wait "$app" --sync --health --timeout 600
    wait_rc=$?
  fi
  set -e

  # 최종 판정은 wait 기준(=실제 운영 판정)
  if (( wait_rc != 0 )); then
    fail_fast "$app" "wait" "$wait_rc"
  fi

  # sync는 참고값: 종종 비정상 rc가 나와도 결국 Healthy로 수렴함
  if (( sync_rc != 0 )); then
    log "[ON] WARN: ${app} sync rc=${sync_rc}, but wait succeeded (soft-pass)"
  else
    log "[ON] OK: ${app}"
  fi
}

# -----------------------------
# Main
# -----------------------------
log "[ON] proof dir: $PROOF_DIR"

if [[ ! -f "$ROOT_OPT_MANIFEST_PATH" ]]; then
  log "ERROR: root-optional manifest not found: $ROOT_OPT_MANIFEST_PATH"
  exit 1
fi

# 사전 상태는 optional만 간단히(파일로만 저장)
run_to_file "00_before_optional_apps" kubectl -n argocd get applications.argoproj.io -l scope=optional -o wide || true
run_to_file "00_before_optional_ns"   bash -lc "kubectl get ns | egrep 'monitoring-|observability-|feature-store-' || true" || true

# root-optional apply/sync
if ! run_to_file "10_apply_root_optional" kubectl apply -f "$ROOT_OPT_MANIFEST_PATH"; then
  print_file_tail "$PROOF_DIR/10_apply_root_optional.txt" 120
  exit 1
fi

if ! run_to_file "12_sync_root_optional" argocd app sync root-optional --prune --timeout 600; then
  # root-optional 실패도 번들 수집
  fail_fast "root-optional" "sync" "$?"
fi

# envs 먼저
for app in "${OPTIONAL_ENVS_APPS[@]}"; do
  sync_and_wait_quiet "$app"
done

# stack
for app in "${OPTIONAL_STACK_APPS[@]}"; do
  sync_and_wait_quiet "$app"
done

# 마지막 요약도 파일로만
run_to_file "90_after_optional_apps" kubectl -n argocd get applications.argoproj.io -l scope=optional -o wide || true
run_to_file "90_after_optional_ns"   bash -lc "kubectl get ns | egrep 'monitoring-|observability-|feature-store-' || true" || true

log "[ON] DONE (proof_dir=$PROOF_DIR)"

