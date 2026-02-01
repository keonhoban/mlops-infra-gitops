from fastapi import APIRouter, Request
router = APIRouter()

@router.get("/health")
def health(request: Request):
    active = getattr(request.app.state, "active", {})
    loaded = list(active.keys())
    if not loaded:
        return {"status": "ok", "active": {}, "note": "no active meta yet"}  # 서비스는 살아있음
    return {"status": "ok", "loaded_aliases": loaded}

