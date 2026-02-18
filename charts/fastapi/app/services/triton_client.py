import random
import time
import requests

from core.config import settings

# Triton 모델 스위치/로드 순간에 발생할 수 있는 transient error 후보
_TRANSIENT_HTTP = {409, 425, 429, 500, 502, 503, 504}


def _sleep_backoff(attempt_idx: int):
    """
    attempt_idx: 0부터 시작
    backoff: base * 2^n + jitter
    """
    base = max(10, int(getattr(settings, "triton_retry_backoff_ms", 120)))
    cap = max(base, int(getattr(settings, "triton_retry_max_backoff_ms", 800)))

    backoff = min(cap, base * (2 ** attempt_idx))
    jitter = random.randint(0, max(10, base // 2))  # 약간의 jitter
    time.sleep((backoff + jitter) / 1000.0)


def infer(rows: list[list[float]]):
    """
    Triton infer 호출.
    - 모델 전환 순간의 503/timeout/connection reset 등을 짧은 retry로 흡수한다.
    """
    url = f"{settings.triton_http_url.rstrip('/')}/v2/models/{settings.triton_model_name}/infer"
    payload = {
        "inputs": [{
            "name": "input",
            "shape": [len(rows), len(rows[0]) if rows else 0],
            "datatype": "FP32",
            "data": rows,
        }]
    }

    attempts = max(1, int(getattr(settings, "triton_retry_attempts", 5)))
    last_err: Exception | None = None
    last_status: int | None = None
    last_text: str | None = None

    for i in range(attempts):
        try:
            r = requests.post(url, json=payload, timeout=settings.triton_timeout_sec)

            if r.status_code == 200:
                return r.json()

            last_status = r.status_code
            last_text = r.text

            # transient로 판단되면 retry
            if r.status_code in _TRANSIENT_HTTP and i < attempts - 1:
                _sleep_backoff(i)
                continue

            raise RuntimeError(f"Triton infer failed: {r.status_code} {r.text}")

        except requests.exceptions.RequestException as e:
            # timeout / connection reset / DNS 등: transient로 보고 retry
            last_err = e
            if i < attempts - 1:
                _sleep_backoff(i)
                continue
            raise

    # 여기 도달하면 거의 없음(안전망)
    if last_err:
        raise last_err
    raise RuntimeError(f"Triton infer failed: {last_status} {last_text}")

