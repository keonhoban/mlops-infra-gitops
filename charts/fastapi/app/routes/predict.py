from fastapi import APIRouter, Header, HTTPException, Request
from pydantic import BaseModel
from typing import List
import pandas as pd
from loguru import logger

from services.alias_selector import choose_alias
from services.triton_client import infer
from core.config import settings
from utils.slack_alerts import slack_safe

router = APIRouter()

class PredictInput(BaseModel):
    data: List[List[float]]

@router.post("/predict")
async def predict(request: Request, input_data: PredictInput, x_client_id: str = Header(...)):
    alias = choose_alias(x_client_id)

    try:
        df = pd.DataFrame(input_data.data)
        rows = df.astype("float32").values.tolist()

        resp = infer(rows)

        # proof: 어떤 alias로 라우팅했는지 + 현재 active meta(있으면) 같이 반환
        active = request.app.state.active.get(alias)
        return {
            "variant": alias,
            "mode": settings.alias_selection_mode,
            "client_id": x_client_id,
            "triton_model": resp.get("model_name"),
            "triton_model_version": resp.get("model_version"),
            "active_meta": active,
            "outputs": resp.get("outputs"),
        }

    except Exception as e:
        logger.exception("predict failed")
        slack_safe(f"❌ [FastAPI] Triton predict failed (alias={alias}): {e}")
        raise HTTPException(status_code=500, detail=f"예측 실패: {e}")

@router.post("/variant/{alias}/predict")
async def predict_by_alias(request: Request, alias: str, input_data: PredictInput):
    try:
        df = pd.DataFrame(input_data.data)
        rows = df.astype("float32").values.tolist()
        resp = infer(rows)
        return {
            "variant": alias,
            "triton_model": resp.get("model_name"),
            "triton_model_version": resp.get("model_version"),
            "active_meta": request.app.state.active.get(alias),
            "outputs": resp.get("outputs"),
        }
    except Exception as e:
        logger.exception("predict_by_alias failed")
        slack_safe(f"❌ [FastAPI] Triton predict failed (alias={alias}): {e}")
        raise HTTPException(status_code=500, detail=f"예측 실패: {e}")

