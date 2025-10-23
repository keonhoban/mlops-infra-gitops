FROM python:3.12

WORKDIR /app

COPY app /app
COPY image/requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

# logs 디렉토리 생성 (NFS와 연결될 위치)
RUN mkdir -p /app/logs

# fastapiuser 생성 (UID: 2001, GID: 2001 고정)
RUN addgroup --gid 2001 fastapigroup && \
    adduser --uid 2001 --gid 2001 --disabled-password --gecos "" fastapiuser

# logs 폴더 권한 부여
RUN chown -R fastapiuser:fastapigroup /app/logs

# non-root 유저로 실행
USER fastapiuser

# FastAPI 실행
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
