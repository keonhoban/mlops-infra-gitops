from fastapi import FastAPI
from loguru import logger

from core.config import settings
from services.mlflow_meta import get_alias_target_safe

def init_app_state(app: FastAPI):
    """
    app.state.active:
      - 현재 서빙에 사용 중이라고 '기록된' 모델 메타
      - Predict는 Triton만 치고, active는 proof/관측/운영용으로만 씀
    """
    app.state.active = {}
    app.state.loaded_aliases = []

    # startup에서 alias 메타를 '가능하면' 로드
    # (깨져도 서비스는 살아 있어야 함)
    for alias in ["A", "B"]:
        meta = get_alias_target_safe(alias)
        if meta:
            app.state.active[alias] = meta
            app.state.loaded_aliases.append(alias)

    logger.info(f"[startup] loaded_aliases={app.state.loaded_aliases} triton={settings.triton_model_name}")

