#!/usr/bin/env bash
# ops/seal/rotate-controller-key.sh
# 사용법:
#   bash ops/seal/rotate-controller-key.sh
# 옵션:
#   INCLUDE_BOOTSTRAP=1  # notifications 같이 re-seal
#   DRY_RUN=1            # 실제 패치/봉인/커밋 없이 흐름만
# 주의:
#   구키를 먼저 삭제하지 말 것! (복호화 실패 발생)

set -euo pipefail

SS_NS="${SS_NS:-kube-system}"
DEPLOY="${DEPLOY:-sealed-secrets}"
RENEW_SHORT="${RENEW_SHORT:-1m}"   # 임시 단축 주기
RENEW_NORMAL="${RENEW_NORMAL:-720h}"  # 원복 주기(30일)
INCLUDE_BOOTSTRAP="${INCLUDE_BOOTSTRAP:-0}"
DRY_RUN="${DRY_RUN:-0}"
TIMEOUT="${TIMEOUT:-420}"  # 신키 추가 대기(초)

need(){ command -v "$1" >/dev/null 2>&1 || { echo "❌ need $1"; exit 1; }; }
need kubectl; need yq; command -v argocd >/dev/null 2>&1 || true

say(){ echo -e "$*"; }

backup_keys () {
  mkdir -p /root/backup
  local out="/root/backup/sealed-secrets-keys-$(date +%F-%H%M%S).yaml"
  say "[1/6] 기존 키 백업 → $out"
  if [[ "$DRY_RUN" != "1" ]]; then
    kubectl -n "$SS_NS" get secret -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > "$out"
  fi
}

get_key_count () {
  kubectl -n "$SS_NS" get secret -l sealedsecrets.bitnami.com/sealed-secrets-key -o json \
    | yq '.items | length'
}

patch_args_temp_short () {
  say "[2/6] 컨트롤러에 신키 추가 유도(renew period 임시 단축: $RENEW_SHORT)"
  if [[ "$DRY_RUN" == "1" ]]; then
    say "  (dry-run) patch args to --key-renew-period=$RENEW_SHORT"
    return 0
  fi

  # 현재 args 백업(원복용)
  kubectl -n "$SS_NS" get deploy "$DEPLOY" -o json | yq '.spec.template.spec.containers[0].args' > /tmp/ss-args-backup.json

  # args가 없거나 기존에 renew arg가 없으면 추가, 있으면 교체
  if yq -e '.[0]' /tmp/ss-args-backup.json >/dev/null 2>&1; then
    # 배열 존재 → renew 인자 교체/추가
    if yq -e 'map(select(test("^--key-renew-period="))) | length > 0' /tmp/ss-args-backup.json >/dev/null 2>&1; then
      NEW_ARGS=$(yq "(map(if test(\"^--key-renew-period=\") then \"--key-renew-period=$RENEW_SHORT\" else . end))" /tmp/ss-args-backup.json -o=json)
    else
      NEW_ARGS=$(yq ". + [\"--key-renew-period=$RENEW_SHORT\"]" /tmp/ss-args-backup.json -o=json)
    fi
  else
    # args가 비어있음 → 새 배열 생성
    NEW_ARGS=$(printf '["--key-renew-period=%s"]' "$RENEW_SHORT")
  fi

  kubectl -n "$SS_NS" patch deploy "$DEPLOY" \
    --type='json' \
    -p="[ {\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/args\",\"value\": $NEW_ARGS } ]"

  # 신키 생성 대기: 기존 키 개수 대비 +1
  local before after waited=0
  before=$(get_key_count)
  say "  현재 키 개수: $before → 새 키 생성 대기..."
  until [[ $waited -ge $TIMEOUT ]]; do
    sleep 6; waited=$(( waited + 6 ))
    after=$(get_key_count)
    if (( after > before )); then
      say "  ✅ 새 키 감지: $before → $after (경과 ${waited}s)"
      return 0
    fi
    say "  ...대기중(${waited}s) (키 개수 $after)"
  done
  say "⚠️  제한 시간 초과: 새 키 생성 확인 실패. (컨트롤러 로그/설정 확인 필요)"
  exit 1
}

reseal_all () {
  say "[3/6] dev re-seal (검증)"
  local cmd="SHOW_DIFF=1 INCLUDE_BOOTSTRAP=${INCLUDE_BOOTSTRAP} bash ops/seal/re-seal.sh dev"
  if [[ "$DRY_RUN" == "1" ]]; then
    say "  (dry-run) $cmd"
  else
    eval "$cmd"
    git push || true
  fi

  # (있으면) argocd로 빠르게 상태 점검
  if command -v argocd >/dev/null 2>&1; then
    argocd app get dev-secrets || true
    [[ "$INCLUDE_BOOTSTRAP" == "1" ]] && argocd app get notifications || true
  fi

  say "[4/6] prod re-seal (반영)"
  cmd="SHOW_DIFF=1 INCLUDE_BOOTSTRAP=${INCLUDE_BOOTSTRAP} bash ops/seal/re-seal.sh prod"
  if [[ "$DRY_RUN" == "1" ]]; then
    say "  (dry-run) $cmd"
  else
    eval "$cmd"
    git push || true
  fi

  if command -v argocd >/dev/null 2>&1; then
    argocd app get prod-secrets || true
  fi
}

restore_args_normal () {
  say "[5/6] renew period 원복: $RENEW_NORMAL"
  if [[ "$DRY_RUN" == "1" ]]; then
    say "  (dry-run) restore args to $RENEW_NORMAL"
    return 0
  fi
  if [[ -s /tmp/ss-args-backup.json ]]; then
    # 백업 args에서 renew 인자 교체/추가해 원복
    if yq -e '.[0]' /tmp/ss-args-backup.json >/dev/null 2>&1; then
      if yq -e 'map(select(test("^--key-renew-period="))) | length > 0' /tmp/ss-args-backup.json >/dev/null 2>&1; then
        NEW_ARGS=$(yq "(map(if test(\"^--key-renew-period=\") then \"--key-renew-period=$RENEW_NORMAL\" else . end))" /tmp/ss-args-backup.json -o=json)
      else
        NEW_ARGS=$(yq ". + [\"--key-renew-period=$RENEW_NORMAL\"]" /tmp/ss-args-backup.json -o=json)
      fi
    else
      NEW_ARGS=$(printf '["--key-renew-period=%s"]' "$RENEW_NORMAL")
    fi

    kubectl -n "$SS_NS" patch deploy "$DEPLOY" \
      --type='json' \
      -p="[ {\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/args\",\"value\": $NEW_ARGS } ]"
  else
    echo "⚠️  /tmp/ss-args-backup.json 없음(원복 스킵). 수동 확인 권장."
  fi
}

final_check () {
  say "[6/6] 최종 점검"
  if command -v argocd >/dev/null 2>&1; then
    argocd app get dev-secrets || true
    argocd app get prod-secrets || true
    [[ "$INCLUDE_BOOTSTRAP" == "1" ]] && argocd app get notifications || true
  fi
  say "✅ 키 회전 & re-seal 절차 완료"
  say "ℹ️ (선택) 구키 정리는 전환경 Healthy + 여러 배포 사이클 통과 후에 수행 권장"
}

# 실행 플로우
backup_keys
patch_args_temp_short
reseal_all
restore_args_normal
final_check
