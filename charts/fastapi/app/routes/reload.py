# routes/reload.py
from __future__ import annotations

import os
import secrets
from typing import Any

from fastapi import APIRouter, HTTPException, Header, Query
from pydantic import BaseModel

from core.config import settings
from core.startup import get_ssot_served_version_cached
from services.triton_client import get_served_version
from services.mlflow_meta import get_mlflow_client
from utils.slack_alerts import slack_safe

router = APIRouter()


class ReloadBody(BaseModel):
    deploy_version: int | None = None


def _pod() -> str:
    return os.environ.get("HOSTNAME", "unknown")


def _meta_from_mlflow_version(version: int) -> dict[str, Any]:
    # mlflow_tracking_uri: Field(...) required → 앱 시작 시 미설정이면 crash
    # model_name: Field(default=...) → 항상 값 존재
    # 두 필드 모두 Pydantic AppSettings에서 보장되므로 런타임 재확인 불필요
    c = get_mlflow_client()

    mv = c.get_model_version(settings.model_name, str(int(version)))
    return {
        "model_name": settings.model_name,
        "alias": None,
        "version": int(mv.version),
        "run_id": str(mv.run_id),
    }


@router.post("/variant/{alias}/reload")
def reload_variant(
    alias: str,
    body: ReloadBody | None = None,
    x_token: str = Header(...),
    deploy_version: int | None = Query(default=None),
):
    if not settings.reload_secret_token:
        raise HTTPException(status_code=500, detail="서버 설정 오류: 인증 토큰 미설정")
    if not secrets.compare_digest(x_token, settings.reload_secret_token):
        raise HTTPException(status_code=403, detail="Access denied")

    alias = (alias or "").strip() or "A"

    dv = None
    if body and body.deploy_version is not None:
        dv = int(body.deploy_version)
    elif deploy_version is not None:
        dv = int(deploy_version)

    if dv is not None:
        served = get_ssot_served_version_cached(get_served_version, settings.model_name)
        if served is not None and int(served) != int(dv):
            raise HTTPException(status_code=409, detail=f"Triton served_version({served}) != deploy_version({dv})")

        meta = _meta_from_mlflow_version(dv)
        meta["alias"] = alias

        slack_safe(
            f"🔁 [FastAPI] reload(service, ssot-verified): "
            f"pod={_pod()} alias={alias} v{meta['version']} run_id={meta['run_id']}"
        )
        return {
            "status": "success",
            "pod": _pod(),
            "variant": alias,
            "version": meta["version"],
            "run_id": meta["run_id"],
            "source": "deploy_version_ssot_verified",
        }

    served = get_ssot_served_version_cached(get_served_version, settings.model_name)
    if served is None:
        raise HTTPException(status_code=503, detail="Triton served_version 조회 실패")

    meta = _meta_from_mlflow_version(int(served))
    meta["alias"] = alias

    slack_safe(
        f"🔁 [FastAPI] reload default(ssot): "
        f"pod={_pod()} alias={alias} served_v{meta['version']} run_id={meta['run_id']}"
    )
    return {
        "status": "success",
        "pod": _pod(),
        "variant": alias,
        "version": meta["version"],
        "run_id": meta["run_id"],
        "source": "triton_ssot_default",
    }
