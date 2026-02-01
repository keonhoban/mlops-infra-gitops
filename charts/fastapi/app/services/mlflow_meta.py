from loguru import logger
import mlflow
from mlflow.tracking import MlflowClient

from core.config import settings
from utils.slack_alerts import slack_safe

def _client():
    mlflow.set_tracking_uri(settings.mlflow_tracking_uri)
    return MlflowClient()

def get_alias_target_safe(alias: str) -> dict | None:
    """
    alias가 가리키는 version/run_id 조회만 한다.
    아티팩트 download는 하지 않는다. (다운로드 실패=서비스 장애로 번지기 때문)
    """
    try:
        c = _client()
        v = c.get_model_version_by_alias(settings.model_name, alias)
        return {
            "model_name": settings.model_name,
            "alias": alias,
            "version": int(v.version),
            "run_id": v.run_id,
        }
    except Exception as e:
        logger.warning(f"[mlflow] alias meta load failed alias={alias}: {e}")
        slack_safe(f"⚠️ [FastAPI] MLflow alias meta load failed: alias={alias}, {e}")
        return None

def set_active_from_run_id(app, alias: str, run_id: str):
    # run_id는 검증/추적용으로만 저장
    app.state.active[alias] = {
        "model_name": settings.model_name,
        "alias": alias,
        "version": None,
        "run_id": run_id,
    }

