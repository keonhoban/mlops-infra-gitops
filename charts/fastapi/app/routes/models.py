# routes/models.py
from __future__ import annotations

import os
from typing import Any

from fastapi import APIRouter

from core.config import settings
from core.startup import get_ssot_served_version_cached
from services.triton_client import get_served_version
from services.mlflow_meta import get_mlflow_client

router = APIRouter()


def _pod() -> str:
    return os.environ.get("HOSTNAME", "unknown")


def _mlflow_meta_for_version(version: int) -> dict | None:
    try:
        c = get_mlflow_client()
        mv = c.get_model_version(settings.model_name, str(int(version)))
        return {"version": int(mv.version), "run_id": str(mv.run_id)}
    except Exception:
        return None


@router.get("/models")
def models() -> dict[str, Any]:
    """
    SSOT-only:
    - SSOT = Triton served_version
    - effective = 운영자가 보는 최종 상태 (SSOT 기준)
    """
    served = get_ssot_served_version_cached(get_served_version, settings.model_name)
    shadow_served = get_served_version(settings.model_name, triton_url=settings.shadow_triton_url())
    served_meta = _mlflow_meta_for_version(served) if served is not None else None

    effective = {}
    for alias in ["A", "B"]:
        effective[alias] = {
            "mode": "ssot",
            "version": served_meta.get("version") if served_meta else served,
            "run_id": (served_meta.get("run_id") if served_meta else None),
        }

    return {
        "pod": _pod(),
        "ssot": {
            "type": "triton",
            "prod_triton_url": settings.prod_triton_url(),
            "shadow_triton_url": settings.shadow_triton_url(),
            "model_name": settings.model_name,
            "prod_served_version": served,
            "shadow_served_version": shadow_served,
            "mlflow_meta": served_meta,
        },
        "effective": effective,
    }
