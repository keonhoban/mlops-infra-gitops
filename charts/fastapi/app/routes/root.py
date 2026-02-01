from fastapi import APIRouter
router = APIRouter()

@router.get("/")
def root():
    return {
        "message": "FastAPI Triton Gateway",
        "endpoints": ["/predict", "/variant/{alias}/predict", "/variant/{alias}/reload", "/models", "/health", "/metrics"],
    }

