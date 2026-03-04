"""User-location and device-registration store backed by Supabase (table: ``devices``).

Tracks each user's last-known location, FCM push token,
and phone number for SMS fallback.

Expected table schema — run the SQL migration in ``docs/supabase_migrations.sql``.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import TypedDict

from app.db.supabase_client import get_client


class DeviceRecord(TypedDict):
    user_id: str
    latitude: float | None
    longitude: float | None
    fcm_token: str | None
    phone_number: str | None
    updated_at: datetime | None


# ── Helpers ──────────────────────────────────────────────────────────────────

def _ensure(user_id: str) -> DeviceRecord:
    """Return the existing record or upsert a blank one."""
    sb = get_client()
    res = (
        sb.table("devices")
        .select("*")
        .eq("user_id", user_id)
        .limit(1)
        .execute()
    )
    if res.data:
        return res.data[0]
    # Create a blank row
    row: dict = {
        "user_id": user_id,
        "latitude": None,
        "longitude": None,
        "fcm_token": None,
        "phone_number": None,
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }
    insert_res = sb.table("devices").insert(row).execute()
    return insert_res.data[0]


def update_location(user_id: str, latitude: float, longitude: float) -> DeviceRecord:
    _ensure(user_id)
    sb = get_client()
    res = (
        sb.table("devices")
        .update({
            "latitude": latitude,
            "longitude": longitude,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        })
        .eq("user_id", user_id)
        .execute()
    )
    return res.data[0]


def register_device(
    user_id: str,
    fcm_token: str | None = None,
    phone_number: str | None = None,
) -> DeviceRecord:
    _ensure(user_id)
    sb = get_client()
    updates: dict = {"updated_at": datetime.now(timezone.utc).isoformat()}
    if fcm_token is not None:
        updates["fcm_token"] = fcm_token
    if phone_number is not None:
        updates["phone_number"] = phone_number
    res = (
        sb.table("devices")
        .update(updates)
        .eq("user_id", user_id)
        .execute()
    )
    return res.data[0]


def get_device(user_id: str) -> DeviceRecord | None:
    sb = get_client()
    res = (
        sb.table("devices")
        .select("*")
        .eq("user_id", user_id)
        .limit(1)
        .execute()
    )
    if res.data:
        return res.data[0]
    return None


def get_all_devices_with_location() -> list[DeviceRecord]:
    """Return every device record that has a known location."""
    sb = get_client()
    res = (
        sb.table("devices")
        .select("*")
        .neq("latitude", None)
        .execute()
    )
    return res.data
