# routes/reload.py
from __future__ import annotations

import os
import secrets
from typing import Optional, Any

import requests
import mlflow
from fastapi import APIRouter, HTTPException, Header, Request, Query
from mlflow.tracking import MlflowClient
from pydantic import BaseModel

from core.config import settings
from core.startup import get_ssot_served_version_cached
from services.mlflow_meta import get_alias_target_safe, set_active_from_run_id
from utils.slack_alerts import slack_safe

router = APIRouter()


class ReloadBody(BaseModel):
    # Airflow가 보내는 값: {"deploy_version": 57}
    deploy_version: Optional[int] = None


def _pod() -> str:
    return os.environ.get("HOSTNAME", "unknown")


def _try_get_triton_served_version(model_name: str) -> Optional[int]:
    triton = getattr(settings, "triton_http_url", None) or getattr(settings, "triton_url", None)
    if not triton:
        return None

    try:
        r = requests.get(f"{triton.rstrip('/')}/v2/models/{model_name}", timeout=3)
        if r.status_code != 200:
            return None
        j = r.json()
        versions = j.get("versions") or []
        if not versions:
            return None
        return int(versions[0])
    except Exception:
        return None


def _meta_from_mlflow_version(version: int) -> dict[str, Any]:
    if not settings.mlflow_tracking_uri:
        raise HTTPException(status_code=500, detail="서버 설정 오류: mlflow_tracking_uri 미설정")
    if not settings.model_name:
        raise HTTPException(status_code=500, detail="서버 설정 오류: model_name 미설정")

    mlflow.set_tracking_uri(settings.mlflow_tracking_uri)
    c = MlflowClient()

    mv = c.get_model_version(settings.model_name, str(int(version)))
    return {
        "model_name": settings.model_name,
        "alias": None,
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
    deploy_version: int | None = Query(default=None),
    clear_pod_local: bool = Query(default=False),  # ✅ 운영상 pod-local 정리 옵션
):
    # -----------------------------
    # auth
    # -----------------------------
    if not settings.reload_secret_token:
        raise HTTPException(status_code=500, detail="서버 설정 오류: 인증 토큰 미설정")
    if not secrets.compare_digest(x_token, settings.reload_secret_token):
        raise HTTPException(status_code=403, detail="Access denied")

    alias = (alias or "").strip() or "A"

    # -----------------------------
    # mode -1) pod-local debug cache clear (운영자/테스트용)
    # -----------------------------
    if clear_pod_local:
        if hasattr(request.app.state, "active") and isinstance(request.app.state.active, dict):
            request.app.state.active.pop(alias, None)
        slack_safe(f"🧹 [FastAPI] clear pod-local cache: pod={_pod()} alias={alias}")
        return {"status": "success", "pod": _pod(), "variant": alias, "source": "clear_pod_local"}

    # -----------------------------
    # mode 0) deploy_version 지정
    # - A안: FastAPI는 pod-local을 '진실'로 갱신하지 않는다.
    # - 대신 Triton SSOT 불일치면 409로 막고, OK면 "수렴 완료"로 응답한다.
    # -----------------------------
    dv = None
    if body and body.deploy_version is not None:
        dv = int(body.deploy_version)
    elif deploy_version is not None:
        dv = int(deploy_version)

    if dv is not None:
        served = get_ssot_served_version_cached(_try_get_triton_served_version, settings.model_name)
        if served is not None and int(served) != int(dv):
            raise HTTPException(status_code=409, detail=f"Triton served_version({served}) != deploy_version({dv})")

        # meta는 응답/로그/증빙용 (state 저장 X)
        meta = _meta_from_mlflow_version(dv)
        meta["alias"] = alias

        slack_safe(f"🔁 [FastAPI] reload(service, ssot-verified): pod={_pod()} alias={alias} v{meta['version']} run_id={meta['run_id']}")
        return {
            "status": "success",
            "pod": _pod(),
            "variant": alias,
            "version": meta["version"],
            "run_id": meta["run_id"],
            "source": "deploy_version_ssot_verified",
        }

    # -----------------------------
    # mode 1) run_id 지정 (shadow/검증용)  -> pod-local override 허용
    # -----------------------------
    if run_id:
        set_active_from_run_id(request.app, alias, run_id)
        slack_safe(f"🔁 [FastAPI] reload by run_id(pod-local override): pod={_pod()} alias={alias} run_id={run_id}")
        return {"status": "success", "pod": _pod(), "variant": alias, "run_id": run_id, "version": None, "source": "run_id_override"}

    # -----------------------------
    # default reload: SSOT(triton) 조회 -> 응답만 (state 저장 X)
    # - Triton 조회 실패 시에만 레거시(MLflow alias)로 fallback + (debug 목적) pod-local 저장 가능
    # -----------------------------
    served = get_ssot_served_version_cached(_try_get_triton_served_version, settings.model_name)
    if served is not None:
        meta = _meta_from_mlflow_version(int(served))
        meta["alias"] = alias

        slack_safe(f"🔁 [FastAPI] reload default(ssot): pod={_pod()} alias={alias} served_v{meta['version']} run_id={meta['run_id']}")
        return {
            "status": "success",
            "pod": _pod(),
            "variant": alias,
            "version": meta["version"],
            "run_id": meta["run_id"],
            "source": "triton_ssot_default",
        }

    # fallback (정말 마지막)
    meta = get_alias_target_safe(alias)
    if not meta:
        raise HTTPException(status_code=500, detail="MLflow alias meta load failed")

    # fallback에서는 debug 목적상 pod-local에 남겨도 OK (운영 진실은 아님)
    request.app.state.active[alias] = meta

    slack_safe(f"🔁 [FastAPI] reload fallback(alias): pod={_pod()} alias={alias} v{meta['version']} run_id={meta['run_id']}")
    return {"status": "success", "pod": _pod(), "variant": alias, "version": meta["version"], "run_id": meta["run_id"], "source": "mlflow_alias_fallback"}
