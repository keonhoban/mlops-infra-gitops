import os
import requests
from loguru import logger

def slack_safe(text: str):
    url = os.environ.get("SLACK_WEBHOOK_URL")
    if not url:
        return
    try:
        requests.post(url, json={"text": text}, timeout=3)
    except Exception as e:
        logger.warning(f"[slack] 알림 전송 실패: {e}")

