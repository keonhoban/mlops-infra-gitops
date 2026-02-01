import hashlib
from core.config import settings

def choose_alias(client_id: str) -> str:
    hashed = int(hashlib.sha256(client_id.encode()).hexdigest(), 16)
    pct = hashed % 100

    if settings.alias_selection_mode == "ab_test":
        return "A" if pct < 90 else "B"
    if settings.alias_selection_mode == "canary":
        return "B" if pct < settings.canary_percent else "A"
    # blue_green / default
    return settings.default_alias

