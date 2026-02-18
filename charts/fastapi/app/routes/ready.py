from fastapi import APIRouter, Request
from urllib.request import urlopen
from urllib.error import URLError
import os

router = APIRouter()

def _triton_ready(triton_http_url: str) -> bool:
    # triton_http_url 예: http://triton.triton-dev.svc.cluster.local:8000
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
    """
    active = getattr(request.app.state, "active", {}) or {}
    loaded_aliases = list(active.keys())

    if not loaded_aliases:
        return {"status": "not_ready", "reason": "no_alias_loaded"}

    triton = os.environ.get("TRITON_HTTP_URL", "")
    if not triton:
        return {"status": "not_ready", "reason": "missing_TRITON_HTTP_URL"}

    if not _triton_ready(triton):
        return {"status": "not_ready", "reason": "triton_not_ready", "triton": triton}

    return {"status": "ready", "loaded_aliases": loaded_aliases, "triton": triton}

