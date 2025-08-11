from fastapi import APIRouter, Request

router = APIRouter()

@router.get("/")
def root(request: Request):
    models = getattr(request.app.state, "models", {})
    variants = list(models.keys())
    endpoints = []

    for alias in variants:
        endpoints.extend([
            f"/variant/{alias}/predict",
            f"/variant/{alias}/reload"
        ])

    endpoints.append("/predict")
    endpoints.append("/models")
    endpoints.append("/health")

    return {
        "message": "FastAPI 동작 중",
        "loaded_variants": variants,
        "available_endpoints": endpoints
    }
