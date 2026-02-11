from __future__ import annotations

from typing import Optional, Any

from fastapi import APIRouter, HTTPException, Header, Request, Query
from pydantic import BaseModel
import secrets
import requests

from core.config import settings
from services.mlflow_meta import get_alias_target_safe, set_active_from_run_id
from utils.slack_alerts import slack_safe

import mlflow
from mlflow.tracking import MlflowClient

router = APIRouter()


class ReloadBody(BaseModel):
    # ✅ Airflow가 보내는 값: {"deploy_version": 26}
    deploy_version: Optional[int] = None


def _try_get_triton_served_version(model_name: str) -> Optional[int]:
    """
    Best-effort:
    - settings에 triton_http_url / triton_url 같은 값이 있으면 조회
    - 없으면 None (검증 스킵)
    """
    triton = getattr(settings, "triton_http_url", None) or getattr(settings, "triton_url", None)
    if not triton:
        return None

    try:
        r = requests.get(f"{triton}/v2/models/{model_name}", timeout=3)
        if r.status_code != 200:
            return None
        j = r.json()
        versions = j.get("versions") or []
        if not versions:
            return None
        # explicit + version_policy specific이면 보통 1개만 옴
        return int(versions[0])
    except Exception:
        return None


def _meta_from_mlflow_version(version: int) -> dict[str, Any]:
    """
    deploy_version(=Triton SSOT)을 기준으로 FastAPI의 active meta를 동기화.
    """
    if not settings.mlflow_tracking_uri:
        raise HTTPException(status_code=500, detail="서버 설정 오류: mlflow_tracking_uri 미설정")
    if not settings.model_name:
        raise HTTPException(status_code=500, detail="서버 설정 오류: model_name 미설정")

    mlflow.set_tracking_uri(settings.mlflow_tracking_uri)
    c = MlflowClient()

    mv = c.get_model_version(settings.model_name, str(int(version)))
    return {
        "model_name": settings.model_name,
        "alias": None,  # alias는 라우팅 키라서 밖에서 채움
        "version": int(mv.version),
        "run_id": str(mv.run_id),
    }


@router.post("/variant/{alias}/reload")
def reload_variant(
    request: Request,
    alias: str,
    body: ReloadBody | None = None,
    x_token: str = Header(...),
    run_id: str | None = Query(default=None),
):
    # auth
    if not settings.reload_secret_token:
        raise HTTPException(status_code=500, detail="서버 설정 오류: 인증 토큰 미설정")
    if not secrets.compare_digest(x_token, settings.reload_secret_token):
        raise HTTPException(status_code=403, detail="Access denied")

    alias = (alias or "").strip() or "A"

    # -----------------------------
    # mode 0) ✅ deploy_version 지정 (Triton SSOT 동기화)
    # -----------------------------
    deploy_version = None
    if body and body.deploy_version is not None:
        deploy_version = int(body.deploy_version)

    if deploy_version is not None:
        # (옵션) Triton 실서빙 버전과 일치 검증 (운영 안전)
        served = _try_get_triton_served_version(settings.model_name)
        if served is not None and int(served) != int(deploy_version):
            raise HTTPException(
                status_code=409,
                detail=f"Triton served_version({served}) != deploy_version({deploy_version})",
            )

        meta = _meta_from_mlflow_version(deploy_version)
        meta["alias"] = alias
        request.app.state.active[alias] = meta

        slack_safe(
            f"🔁 [FastAPI] active meta updated by deploy_version: "
            f"alias={alias}, v{meta['version']}, run_id={meta['run_id']}"
        )
        return {"status": "success", "variant": alias, "version": meta["version"], "run_id": meta["run_id"]}

    # -----------------------------
    # mode 1) run_id 지정 (shadow/검증)
    # -----------------------------
    if run_id:
        set_active_from_run_id(request.app, alias, run_id)
        slack_safe(f"🔁 [FastAPI] active meta updated by run_id: alias={alias}, run_id={run_id}")
        return {"status": "success", "variant": alias, "run_id": run_id, "version": None}

    # -----------------------------
    # mode 2) alias 메타 조회 (기존 유지)
    # -----------------------------
    meta = get_alias_target_safe(alias)
    if not meta:
        raise HTTPException(status_code=500, detail="MLflow alias meta load failed")

    request.app.state.active[alias] = meta
    slack_safe(f"🔁 [FastAPI] active meta updated by alias: alias={alias}, v{meta['version']}, run_id={meta['run_id']}")
    return {"status": "success", "variant": alias, "version": meta["version"], "run_id": meta["run_id"]}

