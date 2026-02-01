from fastapi import APIRouter, HTTPException, Header, Request, Query
import secrets

from core.config import settings
from services.mlflow_meta import get_alias_target_safe, set_active_from_run_id
from utils.slack_alerts import slack_safe

router = APIRouter()

@router.post("/variant/{alias}/reload")
def reload_variant(
    request: Request,
    alias: str,
    x_token: str = Header(...),
    run_id: str | None = Query(default=None),
):
    # auth
    if not settings.reload_secret_token:
        raise HTTPException(status_code=500, detail="서버 설정 오류: 인증 토큰 미설정")
    if not secrets.compare_digest(x_token, settings.reload_secret_token):
        raise HTTPException(status_code=403, detail="Access denied")

    # mode 1) run_id 지정 (shadow/검증에서 안전)
    if run_id:
        set_active_from_run_id(request.app, alias, run_id)
        slack_safe(f"🔁 [FastAPI] active meta updated by run_id: alias={alias}, run_id={run_id}")
        return {"status": "success", "variant": alias, "run_id": run_id, "version": None}

    # mode 2) alias 메타 조회 (promotion/운영용)
    meta = get_alias_target_safe(alias)
    if not meta:
        # 기존 active 유지 (서비스 보호)
        raise HTTPException(status_code=500, detail="MLflow alias meta load failed")

    request.app.state.active[alias] = meta
    slack_safe(f"🔁 [FastAPI] active meta updated by alias: alias={alias}, v{meta['version']}, run_id={meta['run_id']}")
    return {"status": "success", "variant": alias, "version": meta["version"], "run_id": meta["run_id"]}

