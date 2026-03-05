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
from services.mlflow_meta import get_alias_target_safe, set_active_from_run_id
from utils.slack_alerts import slack_safe

router = APIRouter()


class ReloadBody(BaseModel):
    # Airflow가 보내는 값: {"deploy_version": 57}
    deploy_version: Optional[int] = None


def _pod() -> str:
    return os.environ.get("HOSTNAME", "unknown")


def _try_get_triton_served_version(model_name: str) -> Optional[int]:
    """
    Triton /v2/models/{model} 응답의 versions[0]을 served_version으로 간주.
    (현재 구성에서 Triton은 version_policy로 single version만 노출되도록 운용 중)
    """
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
    """
    MLflow Registry에서 특정 model version의 run_id 등을 조회해 meta 생성.
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
        "alias": None,  # caller sets
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
    deploy_version: int | None = Query(default=None),  # query 지원
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
    # mode 0) deploy_version 지정 (Triton SSOT 검증 + 해당 버전으로 cache 동기화)
    # - precedence: body > query
    # -----------------------------
    dv = None
    if body and body.deploy_version is not None:
        dv = int(body.deploy_version)
    elif deploy_version is not None:
        dv = int(deploy_version)

    if dv is not None:
        served = _try_get_triton_served_version(settings.model_name)
        if served is not None and int(served) != int(dv):
            raise HTTPException(
                status_code=409,
                detail=f"Triton served_version({served}) != deploy_version({dv})",
            )

        meta = _meta_from_mlflow_version(dv)
        meta["alias"] = alias

        # NOTE: replicas>1이면 app.state는 pod-local
        request.app.state.active[alias] = meta

        slack_safe(
            f"🔁 [FastAPI] reload by deploy_version: pod={_pod()} alias={alias} v{meta['version']} run_id={meta['run_id']}"
        )
        return {
            "status": "success",
            "pod": _pod(),
            "variant": alias,
            "version": meta["version"],
            "run_id": meta["run_id"],
            "source": "deploy_version",
        }

    # -----------------------------
    # mode 1) run_id 지정 (shadow/검증용)
    # -----------------------------
    if run_id:
        set_active_from_run_id(request.app, alias, run_id)
        slack_safe(f"🔁 [FastAPI] reload by run_id: pod={_pod()} alias={alias} run_id={run_id}")
        return {
            "status": "success",
            "pod": _pod(),
            "variant": alias,
            "run_id": run_id,
            "version": None,
            "source": "run_id",
        }

    # -----------------------------
    # default reload는 SSOT(Triton) 기준 동기화
    # - 파라미터가 없으면 "항상 Triton served_version"으로 cache를 맞춘다.
    # - Triton 조회 실패 시에만 레거시(MLflow alias)로 fallback
    # -----------------------------
    served = _try_get_triton_served_version(settings.model_name)
    if served is not None:
        meta = _meta_from_mlflow_version(int(served))
        meta["alias"] = alias

        request.app.state.active[alias] = meta

        slack_safe(
            f"🔁 [FastAPI] reload default(ssot=triton): pod={_pod()} alias={alias} served_v{meta['version']} run_id={meta['run_id']}"
        )
        return {
            "status": "success",
            "pod": _pod(),
            "variant": alias,
            "version": meta["version"],
            "run_id": meta["run_id"],
            "source": "triton_ssot_default",
        }

    # fallback: 레거시 유지(정말 마지막 수단)
    meta = get_alias_target_safe(alias)
    if not meta:
        raise HTTPException(status_code=500, detail="MLflow alias meta load failed")

    request.app.state.active[alias] = meta
    slack_safe(f"🔁 [FastAPI] reload fallback(alias): pod={_pod()} alias={alias} v{meta['version']} run_id={meta['run_id']}")

    return {
        "status": "success",
        "pod": _pod(),
        "variant": alias,
        "version": meta["version"],
        "run_id": meta["run_id"],
        "source": "mlflow_alias_fallback",
    }
