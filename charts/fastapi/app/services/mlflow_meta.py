import concurrent.futures

from loguru import logger
import mlflow
from mlflow.tracking import MlflowClient

from core.config import settings
from utils.slack_alerts import slack_safe

_MLFLOW_TIMEOUT_SEC = 10

def get_mlflow_client() -> MlflowClient:
    mlflow.set_tracking_uri(settings.mlflow_tracking_uri)
    return MlflowClient()

def get_alias_target_safe(alias: str) -> dict | None:
    """
    alias가 가리키는 version/run_id 조회만 한다.
    아티팩트 download는 하지 않는다. (다운로드 실패=서비스 장애로 번지기 때문)
    """
    try:
        c = get_mlflow_client()

        def _call():
            return c.get_model_version_by_alias(settings.model_name, alias)

        # with 문 사용 금지: __exit__의 shutdown(wait=True)가 timeout 후에도 블로킹됨
        executor = concurrent.futures.ThreadPoolExecutor(max_workers=1)
        future = executor.submit(_call)
        try:
            v = future.result(timeout=_MLFLOW_TIMEOUT_SEC)
        except concurrent.futures.TimeoutError:
            future.cancel()
            executor.shutdown(wait=False, cancel_futures=True)
            logger.warning(f"[mlflow] alias meta load timed out alias={alias}")
            slack_safe(f"⚠️ [FastAPI] MLflow alias meta timed out: alias={alias}")
            return None
        except Exception as e:
            future.cancel()
            executor.shutdown(wait=False, cancel_futures=True)
            raise
        executor.shutdown(wait=False)

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
