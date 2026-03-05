# core/startup.py
from __future__ import annotations

import time
from typing import Optional

from fastapi import FastAPI
from loguru import logger

from core.config import settings
from services.mlflow_meta import get_alias_target_safe

# SSOT cache (pod-local but short TTL)
_SSOT_CACHE = {"served_version": None, "fetched_at": 0.0}
_SSOT_TTL_SEC = 2  # 너무 길면 운영상 stale, 너무 짧으면 triton/MLflow 부하. 1~3초 추천.


def init_app_state(app: FastAPI):
    """
    app.state.active:
      - pod-local "override/debug" 용도로만 유지
      - 운영 진실은 SSOT(triton served_version)
    """
    app.state.active = {}
    app.state.loaded_aliases = []

    # startup에서 alias 메타를 '가능하면' 로드(legacy/debug)
    # (깨져도 서비스는 살아 있어야 함)
    for alias in ["A", "B"]:
        meta = get_alias_target_safe(alias)
        if meta:
            app.state.active[alias] = meta
            app.state.loaded_aliases.append(alias)

    logger.info(
        f"[startup] loaded_aliases={app.state.loaded_aliases} triton_model={settings.triton_model_name} "
        f"ssot_ttl={_SSOT_TTL_SEC}s"
    )


def get_ssot_served_version_cached(triton_getter, model_name: str) -> Optional[int]:
    """
    /models, /reload에서 SSOT 조회를 매번 때리지 않도록 짧은 TTL 캐시.
    triton_getter: (model_name)->Optional[int]
    """
    now = time.time()
    age = now - float(_SSOT_CACHE.get("fetched_at") or 0.0)

    if _SSOT_CACHE.get("served_version") is not None and age <= _SSOT_TTL_SEC:
        return _SSOT_CACHE["served_version"]

    served = triton_getter(model_name)
    _SSOT_CACHE["served_version"] = served
    _SSOT_CACHE["fetched_at"] = now
    return served
