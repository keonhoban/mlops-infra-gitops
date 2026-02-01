from pydantic_settings import BaseSettings
from pydantic import Field

class AppSettings(BaseSettings):
    # Traffic routing
    alias_selection_mode: str = Field(default="blue_green")  # ab_test / canary / blue_green
    default_alias: str = Field(default="B")
    canary_percent: int = Field(default=20)

    # Control plane (MLflow)
    mlflow_tracking_uri: str = Field(...)
    model_name: str = Field(default="best_model")
    reload_secret_token: str = Field(...)

    # Serving (Triton)
    triton_http_url: str = Field(default="http://triton.triton-dev.svc.cluster.local:8000")
    triton_model_name: str = Field(default="best_model")
    triton_timeout_sec: int = Field(default=5)

    class Config:
        case_sensitive = False

settings = AppSettings()

