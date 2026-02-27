import hashlib
from dataclasses import dataclass
from core.config import settings

@dataclass(frozen=True)
class TrafficDecision:
    primary: str          # "prod" or "shadow"
    do_shadow_mirror: bool
    reason: str

def _stable_pct_0_99(key: str) -> int:
    hashed = int(hashlib.sha256(key.encode()).hexdigest(), 16)
    return hashed % 100

def decide_traffic(client_id: str) -> TrafficDecision:
    """
    SSOT: prod/shadow 라우팅 결정.
    - sticky_enabled이면 client_id 기반 deterministic
    - 아니면 현재도 client_id가 필수라 사실상 deterministic을 유지하는게 안정적
    """
    pct = _stable_pct_0_99(client_id)
    shadow_p = max(0, min(100, int(settings.traffic_shadow_percent)))

    mode = (settings.traffic_mode or "mirror").strip().lower()

    if mode == "split":
        # 응답 자체를 분기
        if pct < shadow_p:
            return TrafficDecision(primary="shadow", do_shadow_mirror=False, reason=f"split:pct={pct}<shadow_p={shadow_p}")
        return TrafficDecision(primary="prod", do_shadow_mirror=False, reason=f"split:pct={pct}>=shadow_p={shadow_p}")

    # default: mirror
    # 응답은 항상 prod, shadow는 확률적으로 미러링
    do_shadow = pct < shadow_p
    return TrafficDecision(primary="prod", do_shadow_mirror=do_shadow, reason=f"mirror:pct={pct},shadow_p={shadow_p},do_shadow={do_shadow}")

