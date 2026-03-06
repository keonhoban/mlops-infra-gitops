from fastapi import APIRouter, Request

router = APIRouter()

@router.get("/health")
def health(request: Request):
    # liveness 용도: 프로세스/라우팅 생존만 확인
    return {"status": "ok"}

