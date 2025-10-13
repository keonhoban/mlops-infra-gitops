import hashlib
from core.config import settings

def get_alias(client_id: str) -> str:
    hashed = int(hashlib.sha256(client_id.encode()).hexdigest(), 16)

    if settings.alias_selection_mode == "ab_test":
        return "A" if hashed % 100 < 90 else "B"
    elif settings.alias_selection_mode == "canary":
        return "B" if hashed % 100 < settings.canary_percent else "A"
    elif settings.alias_selection_mode == "blue_green":
        return settings.default_alias
    else:
        return settings.default_alias
