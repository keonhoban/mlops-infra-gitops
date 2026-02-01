import requests
from core.config import settings

def infer(rows: list[list[float]]):
    url = f"{settings.triton_http_url}/v2/models/{settings.triton_model_name}/infer"
    payload = {
        "inputs": [{
            "name": "input",
            "shape": [len(rows), len(rows[0]) if rows else 0],
            "datatype": "FP32",
            "data": rows,
        }]
    }

    r = requests.post(url, json=payload, timeout=settings.triton_timeout_sec)
    if r.status_code != 200:
        raise RuntimeError(f"Triton infer failed: {r.status_code} {r.text}")
    return r.json()

