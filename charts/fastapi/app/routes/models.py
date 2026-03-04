from __future__ import annotations

import os
from typing import Optional

import requests
import mlflow
from mlflow.tracking import MlflowClient
from fastapi import APIRouter, Request

from core.config import settings

router = APIRouter()


def _pod() -> str:
    return os.environ.get("HOSTNAME", "unknown")


def _triton_served_version(model_name: str) -> Optional[int]:
    triton = settings.triton_http_url.rstrip("/")
    try:
        r = requests.get(f"{triton}/v2/models/{model_name}", timeout=3)
        if r.status_code != 200:
            return None
        j = r.json()
        versions = j.get("versions") or []
        if not versions:
            return None
        return int(versions[0])
    except Exception:
        return None


def _mlflow_meta_for_version(version: int) -> dict | None:
    try:
        mlflow.set_tracking_uri(settings.mlflow_tracking_uri)
        c = MlflowClient()
        mv = c.get_model_version(settings.model_name, str(int(version)))
        return {"version": int(mv.version), "run_id": str(mv.run_id)}
    except Exception:
        return None


@router.get("/models")
def models(request: Request):
    """
    SSOT = Triton served_version
    - replicas가 2개 이상이어도 일관된 진실을 보여주기 위해,
      /models는 메모리 캐시(app.state.active)가 아니라 Triton을 우선한다.
    """
    served = _triton_served_version(settings.model_name)
    served_meta = _mlflow_meta_for_version(served) if served is not None else None

    # pod-local cache (debug)
    cache = getattr(request.app.state, "active", {}) or {}

    return {
        "pod": _pod(),
        "ssot": {
            "type": "triton",
            "triton_http_url": settings.triton_http_url,
            "model_name": settings.model_name,
            "served_version": served,
            "mlflow_meta": served_meta,
        },
        "cache_pod_local": cache,
    }
