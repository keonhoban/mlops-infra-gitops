from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from urllib.request import urlopen
from urllib.error import URLError

from core.config import settings

router = APIRouter()

# readinessProbe timeoutSeconds=1이라면 0.8~0.9 권장
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
def ready(request: Request):
    """
    Readiness는 '서빙 준비'를 의미해야 합니다.

    조건:
    - 최소 1개 alias 메타가 로드되어 있어야 함 (startup 단계)
    - Triton server ready OK
    - Triton model ready OK (✅ explicit-mode 핵심: 모델이 load되어 있어야 함)

    NOT READY 시 반드시 503을 반환해야
    K8s readinessProbe가 '준비 안 됨'으로 정확히 판단합니다.
    """
    active = getattr(request.app.state, "active", {}) or {}
    loaded_aliases = list(active.keys())

    if not loaded_aliases:
        return JSONResponse(
            status_code=503,
            content={"status": "not_ready", "reason": "no_alias_loaded"},
        )

    # ✅ readiness는 prod 기준으로만 체크 (shadow 장애가 prod 트래픽을 막지 않게)
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
        "loaded_aliases": loaded_aliases,
        "triton": triton,
        "model": model_name,
    }
