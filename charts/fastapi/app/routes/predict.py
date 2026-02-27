from fastapi import APIRouter, Header, HTTPException, Request, BackgroundTasks
from pydantic import BaseModel
from typing import List
import pandas as pd
from loguru import logger

from services.alias_selector import decide_traffic
from services.triton_client import infer
from core.config import settings
from utils.slack_alerts import slack_safe

router = APIRouter()

class PredictInput(BaseModel):
    data: List[List[float]]

def _shadow_mirror_task(rows: list[list[float]], client_id: str):
    """
    shadow는 사용자 응답에 영향 주지 않는 게 핵심.
    - timeout 짧게
    - 실패는 로그/슬랙만 남기고 swallow
    """
    try:
        infer(
            rows,
            base_url=settings.shadow_triton_url(),
            timeout_sec=settings.traffic_shadow_timeout_sec,
        )
    except Exception as e:
        logger.warning(f"[shadow_mirror] failed client_id={client_id}: {e}")
        slack_safe(f"⚠️ [FastAPI] shadow mirror failed (client_id={client_id}): {e}")

@router.post("/predict")
async def predict(
    request: Request,
    input_data: PredictInput,
    background_tasks: BackgroundTasks,
    x_client_id: str = Header(...),
):
    decision = decide_traffic(x_client_id)

    try:
        df = pd.DataFrame(input_data.data)
        rows = df.astype("float32").values.tolist()

        # primary routing
        if decision.primary == "shadow":
            primary_url = settings.shadow_triton_url()
        else:
            primary_url = settings.prod_triton_url()

        resp = infer(rows, base_url=primary_url)

        # mirror mode: shadow async call
        if decision.do_shadow_mirror:
            background_tasks.add_task(_shadow_mirror_task, rows, x_client_id)

        # proof: 어떤 라우팅 결정이 났는지 + active meta 같이 반환
        # (주의) active meta는 alias(A/B) 기반이므로, prod/shadow 체계에서는 "관측용"으로만 유지
        return {
            "traffic": {
                "mode": settings.traffic_mode,
                "shadow_percent": settings.traffic_shadow_percent,
                "primary": decision.primary,
                "shadow_mirrored": decision.do_shadow_mirror,
                "reason": decision.reason,
                "prod_triton": settings.prod_triton_url(),
                "shadow_triton": settings.shadow_triton_url(),
            },
            "client_id": x_client_id,
            "triton_model": resp.get("model_name"),
            "triton_model_version": resp.get("model_version"),
            "outputs": resp.get("outputs"),
        }

    except Exception as e:
        logger.exception("predict failed")
        slack_safe(f"❌ [FastAPI] Triton predict failed (primary={decision.primary}): {e}")
        raise HTTPException(status_code=500, detail=f"예측 실패: {e}")

@router.post("/variant/{alias}/predict")
async def predict_by_alias(request: Request, alias: str, input_data: PredictInput):
    """
    제출/테스트 편의:
    - /variant/production/predict or /variant/prod/predict  -> prod triton
    - /variant/shadow/predict                              -> shadow triton
    - 그 외는 prod로 fallback (안전)
    """
    try:
        df = pd.DataFrame(input_data.data)
        rows = df.astype("float32").values.tolist()

        a = (alias or "").strip().lower()
        if a in ("shadow", "canary", "b"):
            url = settings.shadow_triton_url()
        else:
            url = settings.prod_triton_url()

        resp = infer(rows, base_url=url)
        return {
            "variant": alias,
            "triton": url,
            "triton_model": resp.get("model_name"),
            "triton_model_version": resp.get("model_version"),
            "outputs": resp.get("outputs"),
        }
    except Exception as e:
        logger.exception("predict_by_alias failed")
        slack_safe(f"❌ [FastAPI] Triton predict failed (alias={alias}): {e}")
        raise HTTPException(status_code=500, detail=f"예측 실패: {e}")
