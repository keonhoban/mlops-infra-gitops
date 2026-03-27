# services/feast_client.py
"""
Feast Feature Server HTTP client (Method C).

feast 라이브러리 의존 없이 REST API로 online feature를 조회한다.
Optional 레이어(Feast + Redis)가 비활성이면 None을 반환하여
caller가 request payload를 fallback으로 사용하도록 한다.
"""
from __future__ import annotations

from typing import Any

import asyncio

import requests
from loguru import logger

from core.config import settings


def _fetch_online_features(
    entity_ids: list[str],
) -> list[list[float]]:
    """동기 HTTP 호출 — asyncio.to_thread 로 감싸서 사용."""
    payload: dict[str, Any] = {
        "feature_service": settings.feast_feature_service,
        "entities": {"entity_id": entity_ids},
    }
    resp = requests.post(
        f"{settings.feast_url.rstrip('/')}/get-online-features",
        json=payload,
        timeout=settings.feast_timeout_sec,
    )
    resp.raise_for_status()
    return _parse_feature_vectors(resp.json(), len(entity_ids))


async def get_online_features(
    entity_ids: list[str],
) -> list[list[float]] | None:
    """
    Feast Feature Server ``/get-online-features`` 호출.

    Returns:
        feature vectors (list[list[float]]) 또는 None (비활성/실패 시).
        None이면 caller가 request payload를 그대로 사용해야 한다.
    """
    if not settings.feast_enabled:
        return None

    try:
        return await asyncio.to_thread(_fetch_online_features, entity_ids)
    except Exception as e:
        logger.warning(f"[feast_client] fallback to payload: {e}")
        return None


def _parse_feature_vectors(data: dict[str, Any], n: int) -> list[list[float]]:
    """
    Feast Feature Server 응답에서 feature matrix를 추출한다.

    응답 형식 (Feast 0.40+):
    {
      "metadata": {"feature_names": ["f1", "f2", ...]},
      "results": [
        {"values": [v1, v2, ...], "statuses": ["PRESENT", ...], "event_timestamps": [...]},
        ...
      ]
    }
    """
    results = data.get("results", [])
    if not results:
        raise ValueError("Feast response has no results")

    n_features = len(results)
    vectors: list[list[float]] = []
    for row_idx in range(n):
        row = []
        for feat_idx in range(n_features):
            val = results[feat_idx]["values"][row_idx]
            row.append(float(val))
        vectors.append(row)
    return vectors
