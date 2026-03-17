# core/startup.py
from __future__ import annotations

import time
from typing import Optional

from fastapi import FastAPI
from loguru import logger

from core.config import settings

# SSOT cache (pod-local but short TTL)
_SSOT_CACHE = {"served_version": None, "fetched_at": 0.0}
_SSOT_TTL_SEC = 2


def init_app_state(app: FastAPI):
    """
    SSOT-only 구조:
    - pod-local alias cache를 유지하지 않는다.
    - 운영 진실은 Triton served_version
    """
    logger.info(
        f"[startup] ssot_only=true triton_model={settings.triton_model_name} "
        f"ssot_ttl={_SSOT_TTL_SEC}s"
    )


def get_ssot_served_version_cached(triton_getter, model_name: str) -> Optional[int]:
    now = time.time()
    age = now - float(_SSOT_CACHE.get('fetched_at') or 0.0)

    if _SSOT_CACHE.get("served_version") is not None and age <= _SSOT_TTL_SEC:
        return _SSOT_CACHE["served_version"]

    served = triton_getter(model_name)
    _SSOT_CACHE["served_version"] = served
    _SSOT_CACHE["fetched_at"] = now
    return served
