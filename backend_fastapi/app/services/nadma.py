"""NADMA MyDIMS API client for active official disaster incidents."""

from __future__ import annotations

import asyncio
import logging
import time

import httpx

from app.core import config

logger = logging.getLogger(__name__)

_TIMEOUT = 20
_CACHE_TTL_SECONDS = 300
_cache_lock = asyncio.Lock()
_cache_rows: list[dict] = []
_cache_expires_at = 0.0


def _coerce_float(*values: object) -> float | None:
    for value in values:
        if value in (None, ""):
            continue
        try:
            return float(value)
        except (TypeError, ValueError):
            continue
    return None


def _coerce_int(value: object) -> int:
    try:
        return int(value or 0)
    except (TypeError, ValueError):
        return 0


def _map_hazard_type(category_name: str) -> str:
    name = (category_name or "").strip().lower()
    if "banjir" in name or "flood" in name:
        return "flood"
    if "tanah runtuh" in name or "landslide" in name:
        return "landslide"
    if "ribut" in name or "storm" in name:
        return "storm"
    if "kebakaran" in name or "fire" in name:
        return "fire"
    return "official"


def _normalize_disaster(item: dict) -> dict | None:
    category = item.get("kategori") or {}
    case = item.get("case") or {}
    district = item.get("district") or {}
    state = item.get("state") or {}

    latitude = _coerce_float(item.get("latitude"), district.get("latitude"))
    longitude = _coerce_float(item.get("longitude"), district.get("longitude"))
    if latitude is None or longitude is None:
        return None

    category_name = category.get("name") or "Official Disaster"
    district_name = district.get("name") or ""
    state_name = state.get("name") or ""
    location_bits = [part for part in [district_name, state_name] if part]
    title = category_name if not location_bits else f"{category_name} - {', '.join(location_bits)}"
    status = item.get("status") or "Unknown"

    return {
        "id": f"nadma_{item.get('id')}",
        "source_id": int(item.get("id") or 0),
        "title": title,
        "category_name": category_name,
        "hazard_type": _map_hazard_type(category_name),
        "status": status,
        "latitude": latitude,
        "longitude": longitude,
        "state_name": state_name,
        "district_name": district_name,
        "started_at": item.get("datetime_start"),
        "ended_at": item.get("datetime_end"),
        "special_case": (item.get("bencana_khas") or "").lower() == "ya",
        "affected_families": _coerce_int(case.get("jumlah_keluarga")),
        "affected_people": _coerce_int(case.get("jumlah_mangsa")),
        "evacuation_centres": _coerce_int(case.get("jumlah_pps")),
        "raw_data": item,
        "active": status.lower() == "aktif",
    }


async def _fetch_remote_disasters() -> list[dict]:
    token = config.NADMA_DISASTERS_API_TOKEN.strip()
    if not token:
        logger.warning("NADMA disasters token missing; returning no official disasters")
        return []

    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/json",
        "Content-Type": "application/json",
    }
    async with httpx.AsyncClient(timeout=_TIMEOUT, follow_redirects=True) as client:
        response = await client.post(
            config.NADMA_DISASTERS_API_URL,
            headers=headers,
            json={},
        )
        response.raise_for_status()
        payload = response.json()

    items = payload if isinstance(payload, list) else payload.get("data", [])
    rows: list[dict] = []
    for item in items:
        normalized = _normalize_disaster(item)
        if normalized and normalized["active"]:
            rows.append(normalized)
    return rows


async def get_active_disasters(hazard_type: str | None = None) -> list[dict]:
    global _cache_rows, _cache_expires_at

    now = time.monotonic()
    rows = _cache_rows if now < _cache_expires_at else None

    if rows is None:
        async with _cache_lock:
            now = time.monotonic()
            if now < _cache_expires_at:
                rows = _cache_rows
            else:
                try:
                    rows = await _fetch_remote_disasters()
                    _cache_rows = rows
                    _cache_expires_at = time.monotonic() + _CACHE_TTL_SECONDS
                except Exception as exc:
                    logger.warning("NADMA disasters fetch failed: %s", exc)
                    rows = _cache_rows

    if hazard_type:
        return [row for row in rows if row.get("hazard_type") == hazard_type]
    return list(rows)