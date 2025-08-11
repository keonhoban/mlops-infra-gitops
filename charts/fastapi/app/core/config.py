# core/config.py
from pydantic_settings import BaseSettings

class AppSettings(BaseSettings):
    alias_selection_mode: str
    default_alias: str
    canary_percent: int
    mlflow_tracking_uri: str
    model_name: str
    reload_secret_token: str

    class Config:
        case_sensitive = False

settings = AppSettings()
