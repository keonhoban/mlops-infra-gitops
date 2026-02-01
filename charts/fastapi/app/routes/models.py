from fastapi import APIRouter, Request
router = APIRouter()

@router.get("/models")
def models(request: Request):
    return {"active": getattr(request.app.state, "active", {})}

