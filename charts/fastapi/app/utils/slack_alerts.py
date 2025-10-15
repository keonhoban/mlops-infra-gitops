# charts/fastapi/app/utils/slack_alerts.py

import requests
import os

def send_slack_alert(text: str): # Slack 메시지 전송
    slack_url = os.environ.get("SLACK_WEBHOOK_URL")
    if not slack_url:
        raise ValueError("SLACK_WEBHOOK_URL is not set")

    message = {"text": text}

    try:
        response = requests.post(slack_url, json=message)
        response.raise_for_status()
    except Exception as e:
        print(f"[Slack Alert Error] 전송 실패: {e}")
