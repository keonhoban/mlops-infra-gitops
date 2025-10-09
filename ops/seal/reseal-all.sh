#!/usr/bin/env bash
set -euo pipefail

# 사용법:
#   DRY_RUN=1 bash ops/seal/reseal-all.sh dev   # 변경만 확인
#   bash ops/seal/reseal-all.sh dev             # 실제 반영 (prod도 동일)

ENV="${1:-dev}"   # dev | prod
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
OUT_BASE="$ROOT/envs/$ENV/sealed-secrets"

: "${SS_CTL:=sealed-secrets}"
: "${SS_NS:=kube-system}"

need(){ command -v "$1" >/dev/null 2>&1 || { echo "❌ need $1"; exit 1; }; }
need kubeseal; need yq; need git; command -v openssl >/dev/null 2>&1 || true

echo "🔑 controller cert fingerprint:"
kubeseal --controller-name "$SS_CTL" --controller-namespace "$SS_NS" --fetch-cert \
| openssl x509 -noout -fingerprint -sha256 || true

changed=0
for appdir in "$OUT_BASE"/*; do
  [ -d "$appdir" ] || continue
  for f in "$appdir"/*.yaml; do
    [ -f "$f" ] || continue
    tmp="$(mktemp)"

    # 1) 최신 공개키로 재암호화(값 불변, scope/메타 보존)
    kubeseal --controller-name "$SS_CTL" --controller-namespace "$SS_NS" \
             --re-encrypt < "$f" > "$tmp"

    # 2) Secret이 앱보다 먼저 적용되도록 권장 애노테이션
    yq -i '.metadata.annotations."argocd.argoproj.io/sync-wave" = "-1"' "$tmp" || true

    # 3) 바뀐 경우만 교체
    if ! cmp -s "$f" "$tmp"; then
      mv "$tmp" "$f"
      echo "🔁 re-encrypted: $f"
      changed=1
    else
      rm -f "$tmp"
      echo "⏭️  unchanged:   $f"
    fi
  done
done

# 4) 커밋/푸시
if [[ "${DRY_RUN:-0}" -eq 0 && "$changed" -eq 1 ]]; then
  git add "$OUT_BASE"
  git commit -m "reseal(${ENV}): re-encrypt all SealedSecrets with current controller key"
  git push
  # 필요 시 수동 동기화:
  # argocd app sync "${ENV}-secrets" --prune --grpc-web || true
fi

echo "✅ done (env=$ENV, changed=$changed)"
