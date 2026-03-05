# routes/models.py
from __future__ import annotations

import os
from typing import Optional, Any

import requests
import mlflow
from mlflow.tracking import MlflowClient
from fastapi import APIRouter, Request

from core.config import settings
from core.startup import get_ssot_served_version_cached

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
def models(request: Request) -> dict[str, Any]:
    """
    A안(SSOT 수렴형)
    - SSOT = Triton served_version (replicas N개여도 일관된 진실)
    - pod-local(active)는 'override/debug' 참고 정보로만 노출
    - "effective"는 운영자가 보는 최종 상태(=SSOT 기준)
    """
    served = get_ssot_served_version_cached(_triton_served_version, settings.model_name)
    served_meta = _mlflow_meta_for_version(served) if served is not None else None

    # pod-local cache (debug / override)
    cache = getattr(request.app.state, "active", {}) or {}

    # effective: 기본은 ssot로 수렴 (pod-local이 달라도 운영 진실은 ssot)
    effective = {}
    for alias in ["A", "B"]:
        effective[alias] = {
            "mode": "ssot",
            "version": served_meta["version"] if served_meta else served,
            "run_id": (served_meta.get("run_id") if served_meta else None),
        }

    return {
        "pod": _pod(),
        "ssot": {
            "type": "triton",
            "triton_http_url": settings.triton_http_url,
            "model_name": settings.model_name,
            "served_version": served,
            "mlflow_meta": served_meta,
        },
        "effective": effective,
        "cache_pod_local": cache,  # 이름은 유지하되 의미는 debug
    }
