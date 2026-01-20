from fastapi import APIRouter, HTTPException, Header, Request
from pydantic import BaseModel
from typing import List
import pandas as pd
import requests

from services.alias_selector import get_alias
from core.config import settings
from utils.slack_alerts import send_slack_alert
from loguru import logger

router = APIRouter()

class PredictInput(BaseModel):
    data: List[List[float]]

def triton_infer(rows: List[List[float]]):
    url = f"{settings.triton_http_url}/v2/models/{settings.triton_model_name}/infer"
    payload = {
        "inputs": [
            {
                "name": "input",
                "shape": [len(rows), len(rows[0]) if rows else 0],
                "datatype": "FP32",
                "data": rows,
            }
        ]
    }
    r = requests.post(url, json=payload, timeout=settings.triton_timeout_sec)
    if r.status_code != 200:
        raise RuntimeError(f"Triton infer failed: {r.status_code} {r.text}")
    return r.json()

@router.post("/predict")
async def ab_predict(request: Request, input_data: PredictInput, x_client_id: str = Header(...)):
    # alias 선택 로직은 그대로 유지
    alias = get_alias(x_client_id)

    try:
        # 입력을 float로 강제 변환
        df = pd.DataFrame(input_data.data)
        rows = df.astype("float32").values.tolist()

        resp = triton_infer(rows)
        logger.info(f"🔮 Triton 예측 성공: alias={alias}, client_id={x_client_id}, model={settings.triton_model_name}")

        # Proof를 위해 model_version을 응답에 포함
        return {
            "variant": alias,
            "mode": settings.alias_selection_mode,
            "client_id": x_client_id,
            "model": resp.get("model_name"),
            "model_version": resp.get("model_version"),
            "outputs": resp.get("outputs"),
        }

    except Exception as e:
        logger.exception("❌ Triton 예측 실패")
        send_slack_alert(f"❌ Triton 예측 실패 (alias={alias}): {e}")
        raise HTTPException(status_code=500, detail=f"예측 실패: {e}")

@router.post("/variant/{alias}/predict")
async def predict_by_alias(alias: str, input_data: PredictInput, request: Request):
    try:
        df = pd.DataFrame(input_data.data)
        rows = df.astype("float32").values.tolist()

        resp = triton_infer(rows)
        logger.info(f"🔮 Triton 수동 예측 성공: alias={alias}")

        return {
            "variant": alias,
            "model": resp.get("model_name"),
            "model_version": resp.get("model_version"),
            "outputs": resp.get("outputs"),
        }

    except Exception as e:
        logger.exception("❌ Triton 예측 실패")
        send_slack_alert(f"❌ [FastAPI] Triton 예측 실패 (alias={alias}): {e}")
        raise HTTPException(status_code=500, detail=f"예측 실패: {e}")
