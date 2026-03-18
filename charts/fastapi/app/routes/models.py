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
    현재 서빙 상태를 반환합니다.

    ## 설계: SSOT-only (Single Source of Truth)

    이 엔드포인트는 alias(A/B)별 독립 상태를 관리하지 않습니다.
    운영 진실(SSOT)은 Triton이 실제로 서빙 중인 버전(`served_version`)이며,
    A/B alias는 모두 동일한 SSOT 값을 반영합니다.

    ### effective[A] == effective[B] 인 이유

    과거 구조에서는 FastAPI가 pod-local dict에 alias별 버전을 캐시했습니다.
    이 방식은 다중 Pod 환경에서 alias 상태가 Pod마다 달라지는 불일치 문제를 유발했습니다.

    현재 구조는 이를 제거하고 Triton served_version만을 신뢰합니다:
    - A와 B 중 어느 alias로 요청해도 같은 모델이 응답합니다.
    - 버전 전환은 Airflow DAG → Triton load API → FastAPI reload 순서로 이루어집니다.
    - alias는 reload 요청의 식별자로만 사용되며, 독립 버전 분기는 지원하지 않습니다.

    prod/shadow 분기는 `alias`가 아닌 `traffic_mode`(mirror/split)로 제어합니다.
    """
    served = get_ssot_served_version_cached(get_served_version, settings.model_name)
    shadow_served = get_served_version(settings.model_name, triton_url=settings.shadow_triton_url())
    served_meta = _mlflow_meta_for_version(served) if served is not None else None

    effective = {}
    for alias in ["A", "B"]:
        effective[alias] = {
            # SSOT-only: A/B 모두 Triton served_version 기준으로 동일한 값을 반환.
            # alias별 독립 버전 관리는 하지 않음 (다중 Pod 불일치 방지).
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
