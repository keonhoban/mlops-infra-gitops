from fastapi import APIRouter, HTTPException, Header
from pydantic import BaseModel
from typing import List
import pandas as pd
from services.alias_selector import get_alias
from core.config import settings
from utils.slack_alerts import send_slack_alert
from loguru import logger
from fastapi import Request

router = APIRouter()

class PredictInput(BaseModel):
    data: List[List[float]]

@router.post("/predict")
async def ab_predict(request: Request, input_data: PredictInput, x_client_id: str = Header(...)):
    models = getattr(request.app.state, "models", {})
    if not models:
        raise HTTPException(status_code=503, detail="모델 미로딩 상태")

    alias = get_alias(x_client_id)
    if alias not in models:
        raise HTTPException(status_code=503, detail=f"모델 {alias} 미로딩 상태")

    try:
        df = pd.DataFrame(input_data.data)
        prediction = models[alias]["model"].predict(df)
        logger.info(f"🔮 예측 성공: mode={settings.alias_selection_mode}, alias={alias}, client_id={x_client_id}")
        return {
            "variant": alias,
            "mode": settings.alias_selection_mode,
            "client_id": x_client_id,
            "prediction": prediction.tolist()
        }
    except Exception as e:
        logger.exception("❌ 예측 실패")
        send_slack_alert(f"❌ 예측 실패 (alias={alias}): {e}")
        raise HTTPException(status_code=500, detail=f"예측 실패: {e}")

@router.post("/variant/{alias}/predict")
async def predict_by_alias(alias: str, input_data: PredictInput, request: Request):
    models = getattr(request.app.state, "models", {})
    if alias not in models:
        raise HTTPException(status_code=503, detail=f"모델 {alias} 미로딩 상태")

    try:
        df = pd.DataFrame(input_data.data)
        prediction = models[alias]["model"].predict(df)
        logger.info(f"🔮 수동 예측 성공: alias={alias}")
        return {
            "variant": alias,
            "prediction": prediction.tolist()
        }
    except Exception as e:
        logger.exception("❌ 예측 실패")
        send_slack_alert(f"❌ [FastAPI] 예측 실패 (alias={alias}): {e}")
        raise HTTPException(status_code=500, detail=f"예측 실패: {e}")
