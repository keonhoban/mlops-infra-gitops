#!/usr/bin/env bash
# ops/rotate/rotate-aws-credentials.sh
set -euo pipefail

# ===== 기본 파라미터 =====
ENV="${1:-dev}"                              # dev | prod
REGION="${REGION:-ap-northeast-2}"
SS_CTL="${SS_CTL:-sealed-secrets}"
SS_NS="${SS_NS:-kube-system}"
ARGO_APP="${ENV}-secrets"

info(){ echo "[$(date +%H:%M:%S)] $*"; }
kseal(){ kubeseal --controller-name "$SS_CTL" --controller-namespace "$SS_NS" -o yaml; }

# ===== 사전 점검 =====
for bin in aws jq kubectl kubeseal git; do
  command -v "$bin" >/dev/null || { echo "ERROR: $bin 필요"; exit 1; }
done

# ===== ENV → 프로필 자동결정(외부에서 AWS_PROFILE_ROTATOR 주면 그 값 우선) =====
: "${AWS_PROFILE_PREFIX:=rotator}"   # 접두어 바꾸고 싶으면 export AWS_PROFILE_PREFIX=myrotator
if [[ -z "${AWS_PROFILE_ROTATOR:-}" ]]; then
  case "$ENV" in
    dev)  AWS_PROFILE_ROTATOR="${AWS_PROFILE_PREFIX}-dev"  ;;
    prod) AWS_PROFILE_ROTATOR="${AWS_PROFILE_PREFIX}-prod" ;;
    *)    echo "❌ 지원하지 않는 ENV: $ENV (dev|prod)"; exit 1 ;;
  esac
fi

# ===== 레포 루트 고정 =====
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"
APP_GIT_PATH="$REPO_ROOT/envs/${ENV}/sealed-secrets"
mkdir -p "$APP_GIT_PATH/airflow" "$APP_GIT_PATH/fastapi" "$APP_GIT_PATH/mlflow" /root/backup

# ===== AWS 호출 모드 결정 =====
# 1) NEW_ID/NEW_SECRET 미제공 => IAM API로 새 키 생성(프로필 검증 필요)
# 2) NEW_ID/NEW_SECRET 제공   => 주어진 값으로 진행(프로필 검증 없이도 가능)
USE_AWS_API=1
if [[ -n "${NEW_ID:-}" && -n "${NEW_SECRET:-}" ]]; then
  USE_AWS_API=0
  info "Use provided NEW_ID/NEW_SECRET (IAM API 호출 없이 진행)"
fi

AWS_CLI=(aws --profile "$AWS_PROFILE_ROTATOR")

# ===== (API 모드일 때만) 프로필 사전 검증 =====
if [[ "$USE_AWS_API" -eq 1 ]]; then
  if ! "${AWS_CLI[@]}" sts get-caller-identity >/dev/null 2>&1; then
    echo "❌ AWS 프로필('$AWS_PROFILE_ROTATOR')로 STS 확인 실패"
    echo "   아래 중 하나로 준비 후 재시도하세요:"
    echo "   1) aws configure --profile $AWS_PROFILE_ROTATOR (액세스키/시크릿 등록)"
    echo "   2) SSO/Assume-Role 등 조직 표준 방식으로 프로필을 구성"
    echo "   3) 또는 NEW_ID/NEW_SECRET를 환경변수로 직접 전달하여 실행 (IAM API 건너뜀)"
    exit 1
  fi
fi

# ===== 대상 IAM 사용자 / 구 키 파악 & 새 키 생성 (API 모드일 때만) =====
OLD_KEY_ID=""
TARGET_USER="${TARGET_USER:-}"

if [[ "$USE_AWS_API" -eq 1 ]]; then
  if [[ -z "$TARGET_USER" ]]; then
    TARGET_USER="$("${AWS_CLI[@]}" sts get-caller-identity --query 'Arn' --output text | awk -F'/' '{print $NF}')"
  fi
  info "IAM user: $TARGET_USER"

  OLD_KEY_ID="$("${AWS_CLI[@]}" iam list-access-keys --user-name "$TARGET_USER" | jq -r '.AccessKeyMetadata[0].AccessKeyId // empty')"
  if [[ -n "${OLD_KEY_ID}" ]]; then
    info "Old key detected: ${OLD_KEY_ID:0:4}********${OLD_KEY_ID: -4}"
  else
    info "No existing access key found (slot empty)"
  fi

  COUNT="$("${AWS_CLI[@]}" iam list-access-keys --user-name "$TARGET_USER" | jq '.AccessKeyMetadata | length')"
  if [[ "$COUNT" -ge 2 ]]; then
    echo "ERROR: ${TARGET_USER} 에 이미 키 2개 존재. 하나 비활성/삭제 후 재시도."; exit 1
  fi

  NEW_JSON="$("${AWS_CLI[@]}" iam create-access-key --user-name "$TARGET_USER")"
  export NEW_ID="$(echo "$NEW_JSON" | jq -r .AccessKey.AccessKeyId)"
  export NEW_SECRET="$(echo "$NEW_JSON" | jq -r .AccessKey.SecretAccessKey)"
  info "Created new key: ${NEW_ID:0:4}********${NEW_ID: -4}"

  BK="/root/backup/${TARGET_USER}-${ENV}-new-access-key-$(date +%F-%H%M%S).json"
  umask 077; echo "$NEW_JSON" > "$BK"
  info "Backed up new key JSON -> $BK (600)"
else
  info "TARGET_USER 미사용(이미 발급된 자격증명 사용)"
fi

# ===== SealedSecret 생성/갱신 =====
AF_FILE="$APP_GIT_PATH/airflow/sealed-aws-credentials-secret.yaml"
cat > /tmp/aws.ini <<EOF_INI
[default]
aws_access_key_id = ${NEW_ID}
aws_secret_access_key = ${NEW_SECRET}
region = ${REGION}
EOF_INI
kubectl -n "airflow-${ENV}" create secret generic aws-credentials-secret \
  --from-file=credentials=/tmp/aws.ini \
  --dry-run=client -o yaml \
| kubeseal --controller-name "$SS_CTL" --controller-namespace "$SS_NS" --scope namespace-wide -o yaml \
> "$AF_FILE"

FA_FILE="$APP_GIT_PATH/fastapi/sealed-aws-credentials-secret.yaml"
kubectl -n "fastapi-${ENV}" create secret generic aws-credentials-secret \
  --from-literal=AWS_ACCESS_KEY_ID="$NEW_ID" \
  --from-literal=AWS_SECRET_ACCESS_KEY="$NEW_SECRET" \
  --from-literal=AWS_DEFAULT_REGION="$REGION" \
  --dry-run=client -o yaml | kseal > "$FA_FILE"

MF_FILE="$APP_GIT_PATH/mlflow/sealed-aws-credentials-secret.yaml"
kubectl -n "mlflow-${ENV}" create secret generic aws-credentials-secret \
  --from-literal=AWS_ACCESS_KEY_ID="$NEW_ID" \
  --from-literal=AWS_SECRET_ACCESS_KEY="$NEW_SECRET" \
  --from-literal=AWS_DEFAULT_REGION="$REGION" \
  --dry-run=client -o yaml | kseal > "$MF_FILE"

# ===== Git 커밋/푸시 =====
git add "$AF_FILE" "$FA_FILE" "$MF_FILE"
git commit -m "feat(${ENV}): rotate AWS credentials across airflow/fastapi/mlflow"
git push

## ===== ArgoCD 동기화 (선택) =====
#if command -v argocd >/dev/null 2>&1; then
#  if [[ -n "${ARGOCD_HOST:-}" && -n "${ARGOCD_USERNAME:-}" && -n "${ARGOCD_PASSWORD:-}" ]]; then
#    argocd login "$ARGOCD_HOST" \
#      --username "$ARGOCD_USERNAME" --password "$ARGOCD_PASSWORD" \
#      --insecure --grpc-web || true
#  fi
#  argocd app sync "$ARGO_APP" --grpc-web || {
#    echo "HINT: 'argocd login <HOST> --username ... --password ... --insecure --grpc-web' 후"
#    echo "      'argocd app sync ${ARGO_APP} --grpc-web' 실행하세요."
#  }
#fi

# ===== 로컬 AWS credentials 업데이트(선택) =====
: "${UPDATE_LOCAL:=1}"   # 1=업데이트 수행, 0=건너뜀
PROFILE="$AWS_PROFILE_ROTATOR"      # default로 떨어지지 않도록 고정

if [[ "$UPDATE_LOCAL" -eq 1 ]]; then
  CRED_FILE="${AWS_SHARED_CREDENTIALS_FILE:-$HOME/.aws/credentials}"
  CRED_DIR="$(dirname "$CRED_FILE")"

  mkdir -p "$CRED_DIR"
  [[ -f "$CRED_FILE" ]] && cp -p "$CRED_FILE" "$CRED_FILE.bak.$(date +%F-%H%M%S)"

  tmpfile="$(mktemp)"
  if [[ -f "$CRED_FILE" ]]; then
    awk -v p="[$PROFILE]" -v id="$NEW_ID" -v sec="$NEW_SECRET" -v reg="$REGION" '
      BEGIN { in_target=0 }
      {
        if ($0 ~ /^[[:space:]]*\[.*\][[:space:]]*$/) {
          if (in_target==1) in_target=0
        }
        if ($0 ~ "^[[:space:]]*\\[" && $0 ~ "\\]") {
          in_target = ($0 == p) ? 1 : 0
          if (!in_target) print $0
        } else if (!in_target) {
          print $0
        }
      }
      END {
        print p
        print "aws_access_key_id = " id
        print "aws_secret_access_key = " sec
        print "region = " reg
      }
    ' "$CRED_FILE" > "$tmpfile"
  else
    cat > "$tmpfile" <<EOF
[$PROFILE]
aws_access_key_id = $NEW_ID
aws_secret_access_key = $NEW_SECRET
region = $REGION
EOF
  fi

  umask 077
  mv "$tmpfile" "$CRED_FILE"
  chmod 600 "$CRED_FILE"

  info "Updated local AWS credentials: file=$CRED_FILE profile=$PROFILE"

  if AWS_PROFILE="$PROFILE" aws sts get-caller-identity >/dev/null 2>&1; then
    info "Local AWS CLI verification OK (profile=$PROFILE)"
  else
    echo "WARN: Local AWS CLI verification FAILED (profile=$PROFILE)."
    echo "      Check $CRED_FILE. You can restore from backup: ${CRED_FILE}.bak.*"
  fi
else
  info "Skipped local credentials update (UPDATE_LOCAL=0)"
fi

# ===== 적용 확인 =====
for ns in "airflow-${ENV}" "fastapi-${ENV}" "mlflow-${ENV}"; do
  rv="$(kubectl -n "$ns" get secret aws-credentials-secret -o jsonpath='{.metadata.resourceVersion}' 2>/dev/null || true)"
  echo "$ns resourceVersion=$rv"
done

if [[ -n "${OLD_KEY_ID:-}" ]]; then
  info "서비스 정상 확인 후, 구 키(${OLD_KEY_ID:0:4}********${OLD_KEY_ID: -4}) Inactive→삭제하세요."
else
  info "구 키 없음(or 제공 ID/SECRET 사용 모드)."
fi
