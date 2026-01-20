# core/config.py
from pydantic_settings import BaseSettings
from pydantic import Field

class AppSettings(BaseSettings):
    alias_selection_mode: str
    default_alias: str
    canary_percent: int

    # 기존(유지): 아직 남겨둬도 OK (startup에서 쓰고 있을 수 있음)
    mlflow_tracking_uri: str | None = None
    model_name: str | None = None

    # 기존
    reload_secret_token: str

    # Triton (추가)
    triton_http_url: str = Field(default="http://triton.triton-dev.svc.cluster.local:8000")
    triton_model_name: str = Field(default="best_model")
    triton_timeout_sec: int = Field(default=5)

    class Config:
        case_sensitive = False

settings = AppSettings()
