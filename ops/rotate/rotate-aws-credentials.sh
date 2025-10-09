# ops/rotate/rotate-aws-credentials.sh
#!/usr/bin/env bash
set -euo pipefail

# ===== 기본 파라미터 =====
ENV="${1:-dev}"                              # dev / prod
REGION="${REGION:-ap-northeast-2}"
SS_CTL="${SS_CTL:-sealed-secrets}"
SS_NS="${SS_NS:-kube-system}"
ARGO_APP="${ENV}-secrets"

# (옵션) AWS CLI 프로필: export AWS_PROFILE_ROTATOR=rotator-dev
AWS_PROFILE_ROTATOR="${AWS_PROFILE_ROTATOR:-}"
if [[ -n "$AWS_PROFILE_ROTATOR" ]]; then
  AWS_CLI=(aws --profile "$AWS_PROFILE_ROTATOR")
else
  AWS_CLI=(aws)
fi

# (옵션) ArgoCD 자동 로그인: 아래 3개 환경변수 세팅 시 로그인 시도
# export ARGOCD_HOST=argocd.local
# export ARGOCD_USERNAME=admin
# export ARGOCD_PASSWORD=argo1234
ARGOCD_HOST="${ARGOCD_HOST:-}"
ARGOCD_USERNAME="${ARGOCD_USERNAME:-}"
ARGOCD_PASSWORD="${ARGOCD_PASSWORD:-}"

info(){ echo "[$(date +%H:%M:%S)] $*"; }
kseal(){ kubeseal --controller-name "$SS_CTL" --controller-namespace "$SS_NS" -o yaml; }

# ===== 사전 점검 =====
for bin in aws jq kubectl kubeseal git; do
  command -v "$bin" >/dev/null || { echo "ERROR: $bin 필요"; exit 1; }
done

# 레포 루트 고정
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

APP_GIT_PATH="$REPO_ROOT/envs/${ENV}/sealed-secrets"
mkdir -p "$APP_GIT_PATH/airflow" "$APP_GIT_PATH/fastapi" "$APP_GIT_PATH/mlflow" /root/backup

# ===== 대상 IAM 사용자 / 구 키 파악 =====
TARGET_USER="${TARGET_USER:-}"
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

# ===== 새 키 생성 (NEW_ID/NEW_SECRET 미지정 시) =====
if [[ -z "${NEW_ID:-}" || -z "${NEW_SECRET:-}" ]]; then
  COUNT="$("${AWS_CLI[@]}" iam list-access-keys --user-name "$TARGET_USER" | jq '.AccessKeyMetadata | length')"
  if [[ "$COUNT" -ge 2 ]]; then
    echo "ERROR: ${TARGET_USER} 에 이미 키 2개 존재. 하나 비활성/삭제 후 재시도."; exit 1
  fi
  NEW_JSON="$("${AWS_CLI[@]}" iam create-access-key --user-name "$TARGET_USER")"
  export NEW_ID="$(echo "$NEW_JSON" | jq -r .AccessKey.AccessKeyId)"
  export NEW_SECRET="$(echo "$NEW_JSON" | jq -r .AccessKey.SecretAccessKey)"
  info "Created new key: ${NEW_ID:0:4}********${NEW_ID: -4}"

  # 민감정보 백업(권한 600)
  BK="/root/backup/${TARGET_USER}-${ENV}-new-access-key-$(date +%F-%H%M%S).json"
  umask 077; echo "$NEW_JSON" > "$BK"
  info "Backed up new key JSON -> $BK (600)"
else
  info "Using provided NEW_ID/NEW_SECRET (환경변수로 전달됨)"
fi

# ===== SealedSecret 생성/갱신 =====
# airflow-<env>: INI blob + namespace-wide
AF_FILE="$APP_GIT_PATH/airflow/sealed-aws-credentials-${ENV}-secret.yaml"
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

# fastapi-<env>: 분리 키
FA_FILE="$APP_GIT_PATH/fastapi/sealed-aws-credentials-${ENV}-secret.yaml"
kubectl -n "fastapi-${ENV}" create secret generic aws-credentials-secret \
  --from-literal=AWS_ACCESS_KEY_ID="$NEW_ID" \
  --from-literal=AWS_SECRET_ACCESS_KEY="$NEW_SECRET" \
  --from-literal=AWS_DEFAULT_REGION="$REGION" \
  --dry-run=client -o yaml | kseal > "$FA_FILE"

# mlflow-<env>: 분리 키
MF_FILE="$APP_GIT_PATH/mlflow/sealed-aws-credentials-${ENV}-secret.yaml"
kubectl -n "mlflow-${ENV}" create secret generic aws-credentials-secret \
  --from-literal=AWS_ACCESS_KEY_ID="$NEW_ID" \
  --from-literal=AWS_SECRET_ACCESS_KEY="$NEW_SECRET" \
  --from-literal=AWS_DEFAULT_REGION="$REGION" \
  --dry-run=client -o yaml | kseal > "$MF_FILE"

# ===== Git 커밋/푸시 =====
git add "$AF_FILE" "$FA_FILE" "$MF_FILE"
git commit -m "feat(${ENV}): rotate AWS credentials across airflow/fastapi/mlflow"
git push

# ===== ArgoCD 동기화 =====
if command -v argocd >/dev/null 2>&1; then
  if [[ -n "$ARGOCD_HOST" && -n "$ARGOCD_USERNAME" && -n "$ARGOCD_PASSWORD" ]]; then
    argocd login "$ARGOCD_HOST" \
      --username "$ARGOCD_USERNAME" --password "$ARGOCD_PASSWORD" \
      --insecure --grpc-web || true
  fi
  argocd app sync "$ARGO_APP" --grpc-web || {
    echo "HINT: 'argocd login <HOST> --username ... --password ... --insecure --grpc-web' 후"
    echo "      'argocd app sync ${ARGO_APP} --grpc-web' 실행하세요."
  }
fi

# ===== 적용 확인 =====
for ns in "airflow-${ENV}" "fastapi-${ENV}" "mlflow-${ENV}"; do
  rv="$(kubectl -n "$ns" get secret aws-credentials-secret -o jsonpath='{.metadata.resourceVersion}' 2>/dev/null || true)"
  echo "$ns resourceVersion=$rv"
done

info "Done. 서비스 정상 확인 후, 구 키(${OLD_KEY_ID:0:4}********${OLD_KEY_ID: -4}) Inactive→삭제하세요."
