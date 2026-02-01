import os
import requests

def slack_safe(text: str):
    url = os.environ.get("SLACK_WEBHOOK_URL")
    if not url:
        return
    try:
        requests.post(url, json={"text": text}, timeout=3)
    except Exception:
        pass

