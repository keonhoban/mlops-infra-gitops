# core/startup.py
from __future__ import annotations

import os
import time

from fastapi import FastAPI
from loguru import logger

from core.config import settings

# SSOT cache (pod-local but short TTL)
_SSOT_CACHE = {"served_version": None, "fetched_at": 0.0}


_MLFLOW_TIMEOUT_DEFAULT = "10"


def _ensure_mlflow_timeout():
    """MLflow SDK 내부 HTTP 타임아웃 보장. 환경 변수 MLFLOW_HTTP_REQUEST_TIMEOUT 미설정 시 기본값 주입."""
    if not os.environ.get("MLFLOW_HTTP_REQUEST_TIMEOUT"):
        os.environ["MLFLOW_HTTP_REQUEST_TIMEOUT"] = _MLFLOW_TIMEOUT_DEFAULT
        logger.info(f"[startup] MLFLOW_HTTP_REQUEST_TIMEOUT={_MLFLOW_TIMEOUT_DEFAULT}s (default)")


def init_app_state(app: FastAPI):
    """
    SSOT-only 구조:
    - pod-local alias cache를 유지하지 않는다.
    - 운영 진실은 Triton served_version
    """
    _ensure_mlflow_timeout()
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
