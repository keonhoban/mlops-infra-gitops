#!/usr/bin/env bash
# ops/security/re-seal.sh
# 사용법:
#   bash ops/security/re-seal.sh dev
#   SHOW_DIFF=1 bash ops/security/re-seal.sh prod
# 옵션:
#   INCLUDE_BOOTSTRAP=1  # bootstrap/notifications까지 같이 처리
#   DRY_RUN=1            # 실행 대신 계획만 출력

set -euo pipefail

ENV="${1:-dev}"  # dev | prod
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TARGET_DIR="$ROOT/envs/$ENV/sealed-secrets"
SS_NS="${SS_NS:-kube-system}"
SS_CTL="${SS_CTL:-sealed-secrets}"
DRY_RUN="${DRY_RUN:-0}"
SHOW_DIFF="${SHOW_DIFF:-0}"
INCLUDE_BOOTSTRAP="${INCLUDE_BOOTSTRAP:-0}"

need(){ command -v "$1" >/dev/null 2>&1 || { echo "❌ need $1"; exit 1; }; }
need kubectl; need kubeseal; need yq; need git; command -v openssl >/dev/null || true

# 현재 컨트롤러 공개키 지문(커밋 메시지 참고용)
CERT="/tmp/ss-cert.pem"
kubeseal --controller-namespace "$SS_NS" --controller-name "$SS_CTL" --fetch-cert > "$CERT"
FPR=$(openssl x509 -in "$CERT" -noout -fingerprint -sha256 | sed 's/^.*=//')
echo "[info] controller fingerprint: $FPR"
echo "[info] ENV=$ENV DRY_RUN=$DRY_RUN INCLUDE_BOOTSTRAP=$INCLUDE_BOOTSTRAP"
[[ -d "$TARGET_DIR" ]] || echo "⚠️  $TARGET_DIR 디렉터리가 없습니다(계속 진행)."

mapfile -d '' FILES < <(find "$TARGET_DIR" -type f -name '*.yaml' -print0 2>/dev/null || true)
echo "[info] sealed files to process: ${#FILES[@]}"

reseal_file () {
  local f="$1"
  # name/ns 추출
  local name ns scope comp
  name=$(yq -r '.metadata.name // .spec.template.metadata.name' "$f")
  ns=$(yq -r '.metadata.namespace // .spec.template.metadata.namespace' "$f")
  if yq -e '.metadata.annotations."sealedsecrets.bitnami.com/namespace-wide" == "true" or .spec.template.metadata.annotations."sealedsecrets.bitnami.com/namespace-wide" == "true"' "$f" >/dev/null 2>&1; then
    scope="namespace-wide"
  else
    scope=""
  fi
  # ns 추론 (envs/<env>/sealed-secrets/<comp>/...)
  if [[ -z "${ns:-}" || "$ns" == "null" ]]; then
    if [[ "$f" =~ /sealed-secrets/([^/]+)/ ]]; then
      comp="${BASH_REMATCH[1]}"
      ns="${comp}-${ENV}"
      echo "[hint] ns 추론: $f → $ns"
    else
      echo "⚠️  $f: namespace를 찾을 수 없어 건너뜀."; return 0
    fi
  fi
  if [[ -z "${name:-}" || "$name" == "null" ]]; then
    echo "⚠️  $f: metadata.name 없음. 건너뜀."; return 0
  fi
  echo "[reseal] ns=$ns name=$name file=$f scope=${scope:-default}"

  if ! kubectl -n "$ns" get secret "$name" >/dev/null 2>&1; then
    echo "⚠️  $ns/$name: 클러스터 Secret 없음 → 재발급/평문 필요. 건너뜀."
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "  (dry-run) kubectl -n $ns get secret $name -o yaml | kubeseal ..."
    return 0
  fi

  if [[ -n "$scope" ]]; then
    kubectl -n "$ns" get secret "$name" -o yaml \
      | kubeseal --controller-namespace "$SS_NS" --controller-name "$SS_CTL" \
                 --scope namespace-wide --format yaml > "$f"
  else
    kubectl -n "$ns" get secret "$name" -o yaml \
      | kubeseal --controller-namespace "$SS_NS" --controller-name "$SS_CTL" \
                 --format yaml > "$f"
  fi

  if [[ "${SHOW_DIFF:-0}" == "1" ]]; then
    git --no-pager diff -- "" || true
  fi
}

# 1) env re-seal
for f in "${FILES[@]}"; do
  reseal_file "$f"
done

# 2) (옵션) notifications bootstrap 포함
if [[ "$INCLUDE_BOOTSTRAP" == "1" ]]; then
  BOOT_DIR="$ROOT/bootstrap/notifications"
  PLAIN="$BOOT_DIR/argocd-notifications-secret.yaml"   # 있으면 평문
  SEALED="$BOOT_DIR/secret-sealed.yaml"
  echo "[info] INCLUDE_BOOTSTRAP=1 → $SEALED 갱신 시도"
  if [[ "$DRY_RUN" != "1" ]]; then
    if [[ -f "$PLAIN" ]]; then
      kubeseal --controller-namespace "$SS_NS" --controller-name "$SS_CTL" \
        --format yaml < "$PLAIN" > "$SEALED"
    elif kubectl -n argocd get secret argocd-notifications-secret >/dev/null 2>&1; then
      kubectl -n argocd get secret argocd-notifications-secret -o yaml \
        | kubeseal --controller-namespace "$SS_NS" --controller-name "$SS_CTL" \
                   --format yaml > "$SEALED"
    else
      echo "⚠️  argocd/argocd-notifications-secret 없음. bootstrap 건너뜀."
    fi
  fi
  if [[ "${SHOW_DIFF:-0}" == "1" ]]; then
    git --no-pager diff -- "" || true
  fi
  git add "$SEALED" 2>/dev/null || true
fi

if [[ "$DRY_RUN" != "1" ]]; then
  git add "$TARGET_DIR" 2>/dev/null || true
  git commit -m "re-seal($ENV): sealed secrets with current controller key [$FPR]" || true
fi

echo "✅ done. (ENV=$ENV, DRY_RUN=$DRY_RUN, INCLUDE_BOOTSTRAP=$INCLUDE_BOOTSTRAP)"
echo "→ 필요 시: git push"
