import mlflow.pyfunc
from utils.slack_alerts import slack_safe
from loguru import logger
from core.config import settings
from services.mlflow_meta import get_mlflow_client

def load_model_by_alias(alias: str):
    try:
        client = get_mlflow_client()
        model_uri = f"models:/{settings.model_name}@{alias}"
        model = mlflow.pyfunc.load_model(model_uri)
        version_info = client.get_model_version_by_alias(settings.model_name, alias)

        logger.info(f"✅ 모델 로딩 성공: alias={alias}, version={version_info.version}")
        return {
            "model": model,
            "info": {
                "model_name": settings.model_name,
                "alias": alias,
                "version": version_info.version,
                "run_id": version_info.run_id,
                "model_uri": model_uri,
            }
        }
    except Exception as e:
        logger.error(f"❌ 모델 로딩 실패: {e}")
        slack_safe(f"❌ 모델 로딩 실패: alias={alias}, {e}")
        return None
