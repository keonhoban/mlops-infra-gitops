from pydantic_settings import BaseSettings
from pydantic import Field

class AppSettings(BaseSettings):
    # -------------------------
    # Traffic routing (SSOT)
    # -------------------------
    # mirror: 응답은 prod, shadow는 비동기 미러링 (권장)
    # split : 응답 자체를 prod/shadow로 분기
    traffic_mode: str = Field(default="mirror")  # mirror / split

    # shadow 비율(0~100)
    traffic_shadow_percent: int = Field(default=10)

    # Triton endpoints
    # - prod는 기존 triton_http_url을 기본으로 사용
    triton_http_url: str = Field(default="http://triton.triton-dev.svc.cluster.local:8000")
    triton_http_url_prod: str | None = Field(default=None)
    triton_http_url_shadow: str | None = Field(default=None)

    # shadow 미러링 요청 timeout (짧게)
    traffic_shadow_timeout_sec: float = Field(default=1.0)

    # Control plane (MLflow)
    mlflow_tracking_uri: str = Field(...)
    model_name: str = Field(default="best_model")
    reload_secret_token: str = Field(...)

    # Serving (Triton)
    triton_model_name: str = Field(default="best_model")
    triton_timeout_sec: int = Field(default=5)

    # ✅ transient error 흡수용 retry (모델 전환 순간 튐 방지)
    triton_retry_attempts: int = Field(default=5)
    triton_retry_backoff_ms: int = Field(default=120)
    triton_retry_max_backoff_ms: int = Field(default=800)

    # SSOT cache TTL (초) — 환경 변수 SSOT_CACHE_TTL_SEC 으로 조정 가능
    ssot_cache_ttl_sec: int = Field(default=2)

    # Feature Store (Optional 레이어 — Feast Feature Server HTTP)
    feast_enabled: bool = Field(default=False)
    feast_url: str = Field(
        default="http://feast-server.feature-store-dev.svc.cluster.local:6566",
    )
    feast_timeout_sec: float = Field(default=1.0)
    feast_feature_service: str = Field(default="iris_features")

    class Config:
        case_sensitive = False

    # -------- helpers --------
    def prod_triton_url(self) -> str:
        return (self.triton_http_url_prod or self.triton_http_url).rstrip("/")

    def shadow_triton_url(self) -> str:
        # shadow가 미설정이면 prod로 fallback (제출용 안전장치)
        return (self.triton_http_url_shadow or self.prod_triton_url()).rstrip("/")

settings = AppSettings()
