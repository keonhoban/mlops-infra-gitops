from fastapi import APIRouter
from fastapi.responses import JSONResponse
from urllib.request import urlopen
from urllib.error import URLError

from core.config import settings

router = APIRouter()

_DEFAULT_TIMEOUT_SEC = 1.2


def _http_ok(url: str, timeout: float = _DEFAULT_TIMEOUT_SEC) -> bool:
    try:
        with urlopen(url, timeout=timeout) as resp:
            return 200 <= resp.status < 300
    except URLError:
        return False
    except Exception:
        return False


def _triton_server_ready(triton_http_url: str) -> bool:
    url = triton_http_url.rstrip("/") + "/v2/health/ready"
    return _http_ok(url)


def _triton_model_ready(triton_http_url: str, model_name: str) -> bool:
    base = triton_http_url.rstrip("/")
    model = (model_name or "").strip()
    if not model:
        return False
    url = f"{base}/v2/models/{model}/ready"
    return _http_ok(url)


@router.get("/ready")
def ready():
    """
    SSOT-only readiness:
    - Triton server ready
    - Triton model ready
    """
    triton = settings.prod_triton_url()
    if not triton:
        return JSONResponse(
            status_code=503,
            content={"status": "not_ready", "reason": "missing_triton_http_url_prod"},
        )

    if not _triton_server_ready(triton):
        return JSONResponse(
            status_code=503,
            content={"status": "not_ready", "reason": "triton_server_not_ready", "triton": triton},
        )

    model_name = settings.triton_model_name or settings.model_name
    if not _triton_model_ready(triton, model_name):
        return JSONResponse(
            status_code=503,
            content={
                "status": "not_ready",
                "reason": "triton_model_not_ready",
                "triton": triton,
                "model": model_name,
            },
        )

    return {
        "status": "ready",
        "triton": triton,
        "model": model_name,
        "mode": "ssot_only",
    }
