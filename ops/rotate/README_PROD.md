# airflow
bash ops/rotate/rotate-sealed.sh prod airflow airflow-db-prod-secret \
  DB_USER=? DB_PASSWORD=?

bash ops/rotate/rotate-sealed.sh prod airflow airflow-prod-api-secret-key \
  API_SECRET_KEY=$(openssl rand -hex 32)

bash ops/rotate/rotate-sealed.sh prod airflow airflow-prod-jwt-secret \
  JWT_SECRET=$(openssl rand -hex 32)

bash ops/rotate/rotate-sealed.sh prod airflow airflow-fernet-prod-secret \
  FERNET_KEY=$(openssl rand -base64 32)

bash ops/rotate/rotate-sealed.sh prod airflow airflow-git-ssh-prod-secret \
  ssh-privatekey=@/secure/path/id_rsa known_hosts=@/secure/path/known_hosts

bash ops/rotate/rotate-sealed.sh prod airflow aws-credentials-prod-secret \
  AWS_ACCESS_KEY_ID=? AWS_SECRET_ACCESS_KEY=?

bash ops/rotate/rotate-sealed.sh prod airflow fastapi-token-prod-secret \
  FASTAPI_TOKEN=?

bash ops/rotate/rotate-sealed.sh prod airflow slack-webhook-prod-secret \
  SLACK_WEBHOOK_URL=?

# fastapi
bash ops/rotate/rotate-sealed.sh prod fastapi aws-credentials-prod-secret \
  AWS_ACCESS_KEY_ID=? AWS_SECRET_ACCESS_KEY=?

bash ops/rotate/rotate-sealed.sh prod fastapi fastapi-token-prod-secret \
  FASTAPI_TOKEN=?

bash ops/rotate/rotate-sealed.sh prod fastapi slack-webhook-prod-secret \
  SLACK_WEBHOOK_URL=?

# mlflow
bash ops/rotate/rotate-sealed.sh prod mlflow aws-credentials-prod-secret \
  AWS_ACCESS_KEY_ID=? AWS_SECRET_ACCESS_KEY=?

bash ops/rotate/rotate-sealed.sh prod mlflow mlflow-db-prod-secret \
  DB_USER=? DB_PASSWORD=?

