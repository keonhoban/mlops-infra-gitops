FROM ghcr.io/mlflow/mlflow:v2.13.0

# 시스템 도구 설치
RUN apt-get update && apt-get install -y \
    curl \
    telnet \
    postgresql-client \
    awscli \
    procps \
 && rm -rf /var/lib/apt/lists/*

# Python 패키지 설치
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
