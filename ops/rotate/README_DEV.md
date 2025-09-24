# airflow
bash ops/rotate/rotate-sealed.sh dev airflow airflow-db-dev-secret \
  DB_USER=? DB_PASSWORD=?

bash ops/rotate/rotate-sealed.sh dev airflow airflow-dev-api-secret-key \
  API_SECRET_KEY=$(openssl rand -hex 32)

bash ops/rotate/rotate-sealed.sh dev airflow airflow-dev-jwt-secret \
  JWT_SECRET=$(openssl rand -hex 32)

bash ops/rotate/rotate-sealed.sh dev airflow airflow-fernet-dev-secret \
  FERNET_KEY=$(openssl rand -base64 32)     # Airflow 권장

bash ops/rotate/rotate-sealed.sh dev airflow airflow-git-ssh-dev-secret \
  ssh-privatekey=@/secure/path/id_rsa known_hosts=@/secure/path/known_hosts

bash ops/rotate/rotate-sealed.sh dev airflow aws-credentials-dev-secret \
  AWS_ACCESS_KEY_ID=? AWS_SECRET_ACCESS_KEY=?     # (자동화는 rotate-aws-credentials.sh 권장)

bash ops/rotate/rotate-sealed.sh dev airflow fastapi-token-dev-secret \
  FASTAPI_TOKEN=? 

bash ops/rotate/rotate-sealed.sh dev airflow slack-webhook-dev-secret \
  SLACK_WEBHOOK_URL=?

# fastapi
bash ops/rotate/rotate-sealed.sh dev fastapi aws-credentials-dev-secret \
  AWS_ACCESS_KEY_ID=? AWS_SECRET_ACCESS_KEY=?

bash ops/rotate/rotate-sealed.sh dev fastapi fastapi-token-dev-secret \
  FASTAPI_TOKEN=?

bash ops/rotate/rotate-sealed.sh dev fastapi slack-webhook-dev-secret \
  SLACK_WEBHOOK_URL=?

# mlflow
bash ops/rotate/rotate-sealed.sh dev mlflow aws-credentials-dev-secret \
  AWS_ACCESS_KEY_ID=? AWS_SECRET_ACCESS_KEY=?

bash ops/rotate/rotate-sealed.sh dev mlflow mlflow-db-dev-secret \
  DB_USER=? DB_PASSWORD=?

