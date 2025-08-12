# Airflow 3.0.2 with Python 3.12 공식 이미지 기반
FROM apache/airflow:3.0.2-python3.12

# requirements 복사
COPY requirements.txt /tmp/requirements.txt

# airflow 권한으로 pip install
USER airflow

RUN pip install --no-cache-dir -r /tmp/requirements.txt
