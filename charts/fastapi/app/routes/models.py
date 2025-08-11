from fastapi import APIRouter, HTTPException, Request

router = APIRouter()

@router.get("/models")
def get_all_model_info(request: Request):
    models = getattr(request.app.state, "models", {})
    if not models:
        raise HTTPException(status_code=503, detail="등록된 모델 없음")

    return {alias: content["info"] for alias, content in models.items()}
