from fastapi import APIRouter, Request

router = APIRouter()

@router.get("/health")
def health_check(request: Request):
    models = getattr(request.app.state, "models", {})
    if not models:
        return {"status": "unhealthy", "loaded": []}

    missing = [v for v in ["A", "B"] if v not in models]
    if missing:
        return {"status": "degraded", "loaded": list(models.keys()), "missing": missing}

    return {"status": "ok", "loaded": list(models.keys())}
