"""Warning store backed by Supabase (table: ``warnings``).

Expected table schema — run the SQL migration in ``docs/supabase_migrations.sql``.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import TypedDict

from app.db.supabase_client import get_client


class WarningRecord(TypedDict):
    id: str
    title: str
    description: str
    hazard_type: str          # HazardType enum value
    alert_level: str          # AlertLevel enum value
    latitude: float
    longitude: float
    radius_km: float
    source: str
    created_at: datetime
    active: bool


# ── CRUD helpers ──────────────────────────────────────────────────────────────

def create_warning(
    *,
    title: str,
    description: str,
    hazard_type: str,
    alert_level: str,
    latitude: float,
    longitude: float,
    radius_km: float,
    source: str,
) -> WarningRecord:
    """Insert a new warning row and return the record."""
    sb = get_client()
    row = {
        "id": str(uuid.uuid4()),
        "title": title,
        "description": description,
        "hazard_type": hazard_type,
        "alert_level": alert_level,
        "latitude": latitude,
        "longitude": longitude,
        "radius_km": radius_km,
        "source": source,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "active": True,
    }
    res = sb.table("warnings").insert(row).execute()
    return res.data[0]


def get_warning(warning_id: str) -> WarningRecord | None:
    sb = get_client()
    res = (
        sb.table("warnings")
        .select("*")
        .eq("id", warning_id)
        .limit(1)
        .execute()
    )
    if res.data:
        return res.data[0]
    return None


def list_warnings(
    *,
    active_only: bool = True,
    hazard_type: str | None = None,
    alert_level: str | None = None,
) -> list[WarningRecord]:
    """Return warnings optionally filtered by active status, hazard, or level."""
    sb = get_client()
    query = sb.table("warnings").select("*")
    if active_only:
        query = query.eq("active", True)
    if hazard_type:
        query = query.eq("hazard_type", hazard_type)
    if alert_level:
        query = query.eq("alert_level", alert_level)
    query = query.order("created_at", desc=True)
    res = query.execute()
    return res.data


def deactivate_warning(warning_id: str) -> WarningRecord | None:
    """Mark a warning as inactive (resolved / expired)."""
    sb = get_client()
    res = (
        sb.table("warnings")
        .update({"active": False})
        .eq("id", warning_id)
        .execute()
    )
    if res.data:
        return res.data[0]
    return None


def get_all_active_warnings() -> list[WarningRecord]:
    """Return every active warning (used when resolving user-local alerts)."""
    sb = get_client()
    res = (
        sb.table("warnings")
        .select("*")
        .eq("active", True)
        .execute()
    )
    return res.data
