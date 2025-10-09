#!/usr/bin/env bash
set -euo pipefail
# 사용법:
#   bash ops/rotate/rotate-sealed.sh <env> <app> <secret-name> [KEY=VALUE ...]
# 예시:
#   bash ops/rotate/rotate-sealed.sh dev airflow slack-webhook-dev-secret SLACK_WEBHOOK_URL=?
#   bash ops/rotate/rotate-sealed.sh dev airflow airflow-dev-jwt-secret JWT_SECRET=$(openssl rand -hex 32)
#   bash ops/rotate/rotate-sealed.sh dev airflow airflow-git-ssh-secret gitSshKey=@/secure/id_rsa
#     - "KEY=?"   : 프롬프트로 안전 입력(숨김)
#     - "KEY=@p"  : 파일에서 읽어 --from-file
#     - "KEY=@-"  : STDIN에서 읽어 임시 파일 후 --from-file
#     - "KEY=val" : --from-literal

ENV="${1:?env(dev|prod)}"; shift
APP="${1:?app}"; shift
NAME="${1:?secret name}"; shift

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
OUT_DIR="$ROOT/envs/$ENV/sealed-secrets/$APP"
OUT_FILE="$OUT_DIR/sealed-$NAME.yaml"

: "${SS_CTL:=sealed-secrets}"
: "${SS_NS:=kube-system}"

need(){ command -v "$1" >/dev/null 2>&1 || { echo "❌ need $1"; exit 1; }; }
need kubectl; need kubeseal; need yq; need git

# 기본 네임스페이스
NS_DEFAULT="${APP}-${ENV}"
NS="$NS_DEFAULT"

# 기존 파일 메타 우선 사용(이름/네임스페이스)
if [[ -f "$OUT_FILE" ]]; then
  NAME_IN_FILE="$(yq -r '.metadata.name // ""' "$OUT_FILE")"
  NS_IN_FILE="$(yq -r '.metadata.namespace // ""' "$OUT_FILE")"
  [[ -n "$NAME_IN_FILE" ]] && NAME="$NAME_IN_FILE"
  [[ -n "$NS_IN_FILE" ]] && NS="$NS_IN_FILE"
fi

mkdir -p "$OUT_DIR"

# namespace-wide 여부 감지(기존 파일 기준)
SCOPE_ARGS=()
if [[ -f "$OUT_FILE" ]]; then
  if yq -e '.metadata.annotations."sealedsecrets.bitnami.com/namespace-wide" == "true"' "$OUT_FILE" >/dev/null 2>&1; then
    SCOPE_ARGS=(--scope namespace-wide)
  fi
fi

# KEY=VALUE 파싱
LITS=()
FILES=()
cleanup=()
for pair in "$@"; do
  key="${pair%%=*}"
  val="${pair#*=}"
  if [[ "$val" == "?" ]]; then
    read -r -s -p "[$NAME] $key: " v; echo
    LITS+=( "--from-literal=${key}=${v}" )
  elif [[ "$val" == @* ]]; then
    src="${val#@}"
    if [[ "$src" == "-" ]]; then
      tmp="$(mktemp)"; cleanup+=("$tmp"); cat > "$tmp"
      FILES+=( "--from-file=${key}=${tmp}" )
    else
      FILES+=( "--from-file=${key}=${src}" )
    fi
  else
    LITS+=( "--from-literal=${key}=${val}" )
  fi
done
if [[ ${#LITS[@]} -eq 0 && ${#FILES[@]} -eq 0 ]]; then
  echo "❌ 최소 1개 이상의 KEY=VALUE 를 입력하세요"; exit 1
fi

# 이전 리소스버전(검증용)
PRE=$(kubectl -n "$NS" get secret "$NAME" -o jsonpath='{.metadata.resourceVersion}' 2>/dev/null || echo "none")

# 평문 없이 파이프 → kubeseal (scope 유지)
kubectl -n "$NS" create secret generic "$NAME" \
  "${LITS[@]}" "${FILES[@]}" \
  --dry-run=client -o yaml \
| kubeseal --controller-name "$SS_CTL" --controller-namespace "$SS_NS" "${SCOPE_ARGS[@]}" -o yaml \
> "$OUT_FILE"

# ArgoCD 선반영
yq -i '.metadata.annotations."argocd.argoproj.io/sync-wave" = "-1"' "$OUT_FILE" || true

# 임시파일 정리
for f in "${cleanup[@]:-}"; do rm -f "$f"; done

# 커밋/푸시 + 동기화(자동 동기화면 생략 가능)
git add "$OUT_FILE"
git commit -m "rotate(${ENV}): ${APP}/${NAME} resealed (controller-direct, scope-preserved)"
git push
argocd app sync "${ENV}-secrets" --prune --grpc-web || true

# 검증
POST=$(kubectl -n "$NS" get secret "$NAME" -o jsonpath='{.metadata.resourceVersion}')
echo "✅ $NS/$NAME resourceVersion: $PRE -> $POST"
kubectl -n "$NS" get secret "$NAME" -o go-template='{{range $k,$v := .data}}{{printf "%s\n" $k}}{{end}}' | sort
