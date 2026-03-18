# core/startup.py
from __future__ import annotations

import time

from fastapi import FastAPI
from loguru import logger

from core.config import settings

# SSOT cache (pod-local but short TTL)
_SSOT_CACHE = {"served_version": None, "fetched_at": 0.0}


def init_app_state(app: FastAPI):
    """
    SSOT-only 구조:
    - pod-local alias cache를 유지하지 않는다.
    - 운영 진실은 Triton served_version
    """
    logger.info(
        f"[startup] ssot_only=true triton_model={settings.triton_model_name} "
        f"ssot_ttl={settings.ssot_cache_ttl_sec}s"
    )


def get_ssot_served_version_cached(triton_getter, model_name: str) -> int | None:
    now = time.time()
    age = now - float(_SSOT_CACHE.get('fetched_at') or 0.0)

    if _SSOT_CACHE.get("served_version") is not None and age <= settings.ssot_cache_ttl_sec:
        return _SSOT_CACHE["served_version"]

    served = triton_getter(model_name)
    _SSOT_CACHE["served_version"] = served
    _SSOT_CACHE["fetched_at"] = now
    return served
