#!/usr/bin/env bash
# ops/seal/re-seal.sh (fixed)
# - SealedSecrets를 "현재 컨트롤러 공개키"로 재암호화(re-encrypt)
# - JSON/YAML 혼재 입력을 YAML로 정규화(yq 있으면), 없으면 원본 그대로 처리
# - DRY_RUN=1  : 실제 파일 미변경, 변경될 항목만 표시
# - SHOW_DIFF=1: DRY_RUN 시 unified diff(최대 200줄) 출력
#
# 사용법:
#   bash ops/seal/re-seal.sh dev
#   DRY_RUN=1 bash ops/seal/re-seal.sh dev
#   DRY_RUN=1 SHOW_DIFF=1 bash ops/seal/re-seal.sh dev
#
# 환경변수:
#   SS_CTL    (기본: sealed-secrets)
#   SS_NS     (기본: kube-system)
#   REPO_ROOT (기본: git repo root or $PWD)
#   COMMIT_MSG_PREFIX (기본: reseal)
#   FILE_GLOB (기본: *.yaml)  # 공백으로 구분해 여러 패턴 지정 가능: "*.yaml *.yml"

set -euo pipefail

ENV="${1:-dev}"
: "${DRY_RUN:=0}"
: "${SHOW_DIFF:=0}"
: "${SS_CTL:=sealed-secrets}"
: "${SS_NS:=kube-system}"
: "${COMMIT_MSG_PREFIX:=reseal}"
: "${FILE_GLOB:=*.yaml}"

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
BASE_DIR="$REPO_ROOT/envs/$ENV/sealed-secrets"

need(){ command -v "$1" >/dev/null 2>&1 || { echo "❌ need $1"; exit 1; }; }
need kubeseal
need git
command -v yq >/dev/null 2>&1 || echo "ℹ️  yq 미설치: JSON을 YAML로 정규화하지 않고 원본으로 처리합니다."
command -v openssl >/dev/null 2>&1 || true
command -v diff >/dev/null 2>&1 || true

echo "[info] env=$ENV base_dir=$BASE_DIR"
[[ -d "$BASE_DIR" ]] || { echo "❌ 대상 디렉터리 없음: $BASE_DIR"; exit 1; }

echo "[info] controller fingerprint:"
kubeseal --controller-name "$SS_CTL" --controller-namespace "$SS_NS" --fetch-cert \
  | openssl x509 -noout -fingerprint -sha256 || true

# ---------- 대상 파일 수집(파이프 오류 수정: 동적 -name 생성 로직 제거) ----------
# FILE_GLOB 내 패턴(공백 구분)을 배열로 읽기
read -r -a GLOBS <<< "$FILE_GLOB"
# find 명령을 배열로 구성하여 안전하게 실행
find_cmd=(find "$BASE_DIR" -type f \( )
for i in "${!GLOBS[@]}"; do
  (( i > 0 )) && find_cmd+=(-o)
  find_cmd+=(-name "${GLOBS[$i]}")
done
find_cmd+=( \) -print0 )

# 실행해서 파일 목록 확보
mapfile -d '' -t FILES < <("${find_cmd[@]}")

echo "[info] target files: ${#FILES[@]}"
(( ${#FILES[@]} > 0 )) || { echo "✅ 처리할 파일 없음."; exit 0; }

changed=0
processed=0
failed=0

for f in "${FILES[@]}"; do
  ((processed++))
  tmpdir="$(mktemp -d)"
  src="$tmpdir/src.yaml"
  out="$tmpdir/out.yaml"

  # 입력을 YAML로 고정: yq 있으면 정규화, 없으면 원본 그대로
  if command -v yq >/dev/null 2>&1; then
    if ! yq -P '.' < "$f" > "$src" 2>/dev/null; then
      echo "❌ yq 변환 실패(원본으로 진행): $f"
      cp -f "$f" "$src"
    fi
  else
    cp -f "$f" "$src"
  fi

  echo "[..] re-encrypt: $f"
  if ! kubeseal \
        --controller-name "$SS_CTL" \
        --controller-namespace "$SS_NS" \
        --re-encrypt -o yaml \
        < "$src" > "$out" 2>/dev/null; then
    echo "❌ kubeseal --re-encrypt 실패: $f"
    rm -rf "$tmpdir"
    ((failed++))
    continue
  fi

  if cmp -s "$f" "$out"; then
    echo "⏭️  unchanged: $f"
    rm -rf "$tmpdir"
    continue
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "🧪 would update: $f"
    if [[ "$SHOW_DIFF" -eq 1 && -x "$(command -v diff)" ]]; then
      diff -u --label "old:$f" --label "new:$f" "$f" "$out" | sed -n '1,200p' || true
    fi
    rm -rf "$tmpdir"
    continue
  fi

  # 실제 적용(퍼미션 유지)
  install -m "$(stat -c '%a' "$f" 2>/dev/null || echo 644)" "$out" "$f"
  rm -rf "$tmpdir"
  echo "🔁 re-encrypted → $f"
  changed=1
done

# 결과 요약 및 커밋
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "✅ dry-run 완료 (총 파일=$processed, 실패=$failed). 변경사항은 적용하지 않았습니다."
  exit 0
fi

if (( failed > 0 )); then
  echo "⚠️  일부 파일에서 re-encrypt 실패가 있었습니다. (실패=$failed)"
fi

if (( changed > 0 )); then
  (
    cd "$REPO_ROOT"
    git add "$BASE_DIR"
    git commit -m "${COMMIT_MSG_PREFIX}(${ENV}): re-encrypt SealedSecrets with current controller key" || true
    git push || true
  )
  echo "🚀 pushed resealed secrets. (총 파일=$processed, 실패=$failed)"
else
  echo "✅ 변경 없음 (총 파일=$processed, 실패=$failed)."
fi
