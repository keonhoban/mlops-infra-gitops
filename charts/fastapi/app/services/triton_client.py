import random
import time
import requests

from core.config import settings

_TRANSIENT_HTTP = {409, 425, 429, 500, 502, 503, 504}

def _sleep_backoff(attempt_idx: int):
    base = max(10, int(getattr(settings, "triton_retry_backoff_ms", 120)))
    cap = max(base, int(getattr(settings, "triton_retry_max_backoff_ms", 800)))

    backoff = min(cap, base * (2 ** attempt_idx))
    jitter = random.randint(0, max(10, base // 2))
    time.sleep((backoff + jitter) / 1000.0)

def infer(rows: list[list[float]], base_url: str | None = None, timeout_sec: float | None = None):
    """
    Triton infer 호출.
    ✅ Traffic Control을 위해 base_url override 지원 (prod/shadow 분기)
    """
    triton = (base_url or settings.triton_http_url).rstrip("/")
    url = f"{triton}/v2/models/{settings.triton_model_name}/infer"

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

    req_timeout = timeout_sec if timeout_sec is not None else settings.triton_timeout_sec

    for i in range(attempts):
        try:
            r = requests.post(url, json=payload, timeout=req_timeout)

            if r.status_code == 200:
                return r.json()

            last_status = r.status_code
            last_text = r.text

            if r.status_code in _TRANSIENT_HTTP and i < attempts - 1:
                _sleep_backoff(i)
                continue

            raise RuntimeError(f"Triton infer failed: {r.status_code} {r.text}")

        except requests.exceptions.RequestException as e:
            last_err = e
            if i < attempts - 1:
                _sleep_backoff(i)
                continue
            raise

    if last_err:
        raise last_err
    raise RuntimeError(f"Triton infer failed: {last_status} {last_text}")
