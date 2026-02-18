from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from urllib.request import urlopen
from urllib.error import URLError

from core.config import settings

router = APIRouter()

def _triton_ready(triton_http_url: str) -> bool:
    url = triton_http_url.rstrip("/") + "/v2/health/ready"
    try:
        with urlopen(url, timeout=1.5) as resp:
            return 200 <= resp.status < 300
    except URLError:
        return False
    except Exception:
        return False

@router.get("/ready")
def ready(request: Request):
    """
    Readiness는 '서빙 준비'를 의미해야 합니다.
    - 최소 1개 alias 메타가 로드되어 있어야 함 (startup 단계)
    - Triton /v2/health/ready 가 OK 여야 함

    ✅ NOT READY 시 반드시 503을 반환해야
    K8s readinessProbe가 '준비 안 됨'으로 정확히 판단합니다.
    """
    active = getattr(request.app.state, "active", {}) or {}
    loaded_aliases = list(active.keys())

    if not loaded_aliases:
        return JSONResponse(
            status_code=503,
            content={"status": "not_ready", "reason": "no_alias_loaded"},
        )

    triton = settings.triton_http_url or ""
    if not triton:
        return JSONResponse(
            status_code=503,
            content={"status": "not_ready", "reason": "missing_triton_http_url"},
        )

    if not _triton_ready(triton):
        return JSONResponse(
            status_code=503,
            content={"status": "not_ready", "reason": "triton_not_ready", "triton": triton},
        )

    return {"status": "ready", "loaded_aliases": loaded_aliases, "triton": triton}

