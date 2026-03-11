"""IoT siren device store backed by Supabase (tables: ``siren_devices``, ``siren_activations``).

Provides CRUD for community siren hardware and an activation audit trail.
"""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from typing import TypedDict

from app.db.supabase_client import get_client

logger = logging.getLogger(__name__)


class SirenRecord(TypedDict):
    id: str
    name: str
    latitude: float
    longitude: float
    radius_km: float
    endpoint_url: str | None
    api_key: str | None
    status: str
    registered_by: str | None
    created_at: str
    updated_at: str


class SirenActivationRecord(TypedDict):
    id: str
    siren_id: str
    warning_id: str | None
    trigger_type: str
    triggered_by: str | None
    triggered_at: str
    stopped_at: str | None
    status: str
    error_reason: str | None


# ── Siren device CRUD ───────────────────────────────────────────────────────

def register_siren(
    *,
    name: str,
    latitude: float,
    longitude: float,
    radius_km: float = 5.0,
    endpoint_url: str | None = None,
    api_key: str | None = None,
    registered_by: str | None = None,
) -> SirenRecord:
    sb = get_client()
    row = {
        "id": str(uuid.uuid4()),
        "name": name,
        "latitude": latitude,
        "longitude": longitude,
        "radius_km": radius_km,
        "endpoint_url": endpoint_url,
        "api_key": api_key,
        "status": "idle",
        "registered_by": registered_by,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }
    res = sb.table("siren_devices").insert(row).execute()
    return res.data[0]


def list_sirens(*, status_filter: str | None = None) -> list[SirenRecord]:
    sb = get_client()
    q = sb.table("siren_devices").select("*").order("created_at", desc=True)
    if status_filter:
        q = q.eq("status", status_filter)
    return q.execute().data


def get_siren(siren_id: str) -> SirenRecord | None:
    sb = get_client()
    res = sb.table("siren_devices").select("*").eq("id", siren_id).limit(1).execute()
    return res.data[0] if res.data else None


def update_siren_status(siren_id: str, status: str) -> SirenRecord | None:
    sb = get_client()
    res = (
        sb.table("siren_devices")
        .update({"status": status, "updated_at": datetime.now(timezone.utc).isoformat()})
        .eq("id", siren_id)
        .execute()
    )
    return res.data[0] if res.data else None


def get_sirens_near(lat: float, lon: float, max_km: float = 50.0) -> list[SirenRecord]:
    """Return all idle/active sirens whose registered location is within *max_km*."""
    from app.core.geo import haversine

    all_sirens = list_sirens()
    return [
        s for s in all_sirens
        if s["status"] in ("idle", "active")
        and haversine(lat, lon, s["latitude"], s["longitude"]) <= max_km
    ]


# ── Activation log ──────────────────────────────────────────────────────────

def log_activation(
    *,
    siren_id: str,
    warning_id: str | None = None,
    trigger_type: str = "manual",
    triggered_by: str | None = None,
    status: str = "triggered",
    error_reason: str | None = None,
) -> SirenActivationRecord:
    sb = get_client()
    row = {
        "id": str(uuid.uuid4()),
        "siren_id": siren_id,
        "warning_id": warning_id,
        "trigger_type": trigger_type,
        "triggered_by": triggered_by,
        "triggered_at": datetime.now(timezone.utc).isoformat(),
        "status": status,
        "error_reason": error_reason,
    }
    res = sb.table("siren_activations").insert(row).execute()
    return res.data[0]


def stop_activation(activation_id: str) -> SirenActivationRecord | None:
    sb = get_client()
    res = (
        sb.table("siren_activations")
        .update({
            "stopped_at": datetime.now(timezone.utc).isoformat(),
            "status": "stopped",
        })
        .eq("id", activation_id)
        .execute()
    )
    return res.data[0] if res.data else None


def get_active_activations(siren_id: str) -> list[SirenActivationRecord]:
    sb = get_client()
    return (
        sb.table("siren_activations")
        .select("*")
        .eq("siren_id", siren_id)
        .eq("status", "triggered")
        .order("triggered_at", desc=True)
        .execute()
        .data
    )


def get_activation_log(siren_id: str, limit: int = 20) -> list[SirenActivationRecord]:
    sb = get_client()
    return (
        sb.table("siren_activations")
        .select("*")
        .eq("siren_id", siren_id)
        .order("triggered_at", desc=True)
        .limit(limit)
        .execute()
        .data
    )
