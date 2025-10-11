#!/usr/bin/env bash
set -euo pipefail

# 사용법:
#   bash ops/seal/re-seal.sh dev --dry-run
#   DRY_RUN=1 bash ops/seal/re-seal.sh dev
#   bash ops/seal/re-seal.sh dev

ENV="${1:-dev}"
DRY_RUN="${DRY_RUN:-0}"
if [[ "${2:-}" == "--dry-run" ]]; then DRY_RUN=1; fi

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
OUT_BASE="$ROOT/envs/$ENV/sealed-secrets"
: "${SS_CTL:=sealed-secrets}"
: "${SS_NS:=kube-system}"

need(){ command -v "$1" >/dev/null 2>&1 || { echo "❌ need $1"; exit 1; }; }
need kubeseal; need git; command -v openssl >/dev/null 2>&1 || true

echo "🔑 controller cert fingerprint:"
kubeseal --controller-name "$SS_CTL" --controller-namespace "$SS_NS" --fetch-cert \
| openssl x509 -noout -fingerprint -sha256 || true

changed=0
processed=0
shopt -s nullglob
for appdir in "$OUT_BASE"/*; do
  [[ -d "$appdir" ]] || continue
  for f in "$appdir"/*.yaml; do
    [[ -f "$f" ]] || continue
    processed=$((processed+1))

    tmpdir="$(mktemp -d)"
    tmp_reenc="$tmpdir/$(basename "$f").reenc"

    # 1) 최신 공개키로 재암호화만 수행 (정규화/주석 편집 없음)
    if ! kubeseal --controller-name "$SS_CTL" --controller-namespace "$SS_NS" \
                  --re-encrypt < "$f" > "$tmp_reenc" 2>/dev/null; then
      echo "❌ kubeseal --re-encrypt 실패: $f"
      rm -rf "$tmpdir"; continue
    fi

    # 2) 드라이런: 비교만
    if [[ "$DRY_RUN" -eq 1 ]]; then
      if cmp -s "$f" "$tmp_reenc"; then
        echo "⏭️  unchanged:   $f"
      else
        echo "🧪 would re-encrypt: $f"
        command -v diff >/dev/null 2>&1 && diff -u --label "old:$f" --label "new:$f" "$f" "$tmp_reenc" | sed -n '1,80p' || true
      fi
      rm -rf "$tmpdir"
      continue
    fi

    # 3) 실제 적용: 원자적 교체
    if cmp -s "$f" "$tmp_reenc"; then
      echo "⏭️  unchanged:   $f"
      rm -rf "$tmpdir"; continue
    fi

    # 퍼미션 유지하며 원자 교체
    perms=$(stat -c '%a' "$f" 2>/dev/null || echo 644)
    install -m "$perms" "$tmp_reenc" "$f"
    rm -rf "$tmpdir"
    echo "🔁 re-encrypted: $f"
    changed=1
  done
done
shopt -u nullglob

# 4) 커밋/푸시
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "✅ dry-run 완료 (검사 파일 수=$processed). 변경사항 미적용."
  exit 0
fi

if [[ "$changed" -eq 1 ]]; then
  git add "$OUT_BASE"
  git commit -m "reseal(${ENV}): re-encrypt all SealedSecrets with current controller key"
  git push
  echo "🚀 pushed resealed secrets."
else
  echo "✅ 변경 없음 (검사 파일 수=$processed)."
fi
