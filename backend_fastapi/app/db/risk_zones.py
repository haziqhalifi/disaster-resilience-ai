"""Risk zones database store backed by Supabase (table: ``risk_zones``).

Stores AI-computed risk zones for the mapping feature:
  - Danger zones (likely to flood or landslide)
  - Warning zones (elevated risk)
  - Safe zones (designated evacuation centres)
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import TypedDict

from app.db.supabase_client import get_client


class RiskZoneRecord(TypedDict):
    id: str
    name: str
    zone_type: str          # "danger", "warning", "safe"
    hazard_type: str        # "flood", "landslide", "typhoon", "earthquake"
    latitude: float
    longitude: float
    radius_km: float
    risk_score: float       # 0.0 – 1.0
    description: str
    created_at: datetime
    active: bool


class EvacuationCentreRecord(TypedDict):
    id: str
    name: str
    latitude: float
    longitude: float
    capacity: int
    current_occupancy: int
    contact_phone: str | None
    address: str
    active: bool


class EvacuationRouteRecord(TypedDict):
    id: str
    name: str
    start_lat: float
    start_lon: float
    end_lat: float
    end_lon: float
    waypoints: list[dict]   # [{lat, lon}, ...]
    distance_km: float
    estimated_minutes: int
    elevation_gain_m: float
    status: str             # "clear", "partial", "blocked"
    active: bool


# ── Risk Zones CRUD ──────────────────────────────────────────────────────────

def create_risk_zone(
    *,
    name: str,
    zone_type: str,
    hazard_type: str,
    latitude: float,
    longitude: float,
    radius_km: float,
    risk_score: float,
    description: str,
) -> RiskZoneRecord:
    sb = get_client()
    row = {
        "id": str(uuid.uuid4()),
        "name": name,
        "zone_type": zone_type,
        "hazard_type": hazard_type,
        "latitude": latitude,
        "longitude": longitude,
        "radius_km": radius_km,
        "risk_score": risk_score,
        "description": description,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "active": True,
    }
    res = sb.table("risk_zones").insert(row).execute()
    return res.data[0]


def list_risk_zones(
    *,
    active_only: bool = True,
    zone_type: str | None = None,
    hazard_type: str | None = None,
) -> list[RiskZoneRecord]:
    sb = get_client()
    query = sb.table("risk_zones").select("*")
    if active_only:
        query = query.eq("active", True)
    if zone_type:
        query = query.eq("zone_type", zone_type)
    if hazard_type:
        query = query.eq("hazard_type", hazard_type)
    query = query.order("risk_score", desc=True)
    res = query.execute()
    return res.data


def get_risk_zone(zone_id: str) -> RiskZoneRecord | None:
    sb = get_client()
    res = sb.table("risk_zones").select("*").eq("id", zone_id).limit(1).execute()
    return res.data[0] if res.data else None


# ── Evacuation Centres CRUD ──────────────────────────────────────────────────

def create_evacuation_centre(
    *,
    name: str,
    latitude: float,
    longitude: float,
    capacity: int,
    current_occupancy: int = 0,
    contact_phone: str | None = None,
    address: str = "",
) -> EvacuationCentreRecord:
    sb = get_client()
    row = {
        "id": str(uuid.uuid4()),
        "name": name,
        "latitude": latitude,
        "longitude": longitude,
        "capacity": capacity,
        "current_occupancy": current_occupancy,
        "contact_phone": contact_phone,
        "address": address,
        "active": True,
    }
    res = sb.table("evacuation_centres").insert(row).execute()
    return res.data[0]


def list_evacuation_centres(*, active_only: bool = True) -> list[EvacuationCentreRecord]:
    sb = get_client()
    query = sb.table("evacuation_centres").select("*")
    if active_only:
        query = query.eq("active", True)
    res = query.execute()
    return res.data


# ── Evacuation Routes CRUD ───────────────────────────────────────────────────

def create_evacuation_route(
    *,
    name: str,
    start_lat: float,
    start_lon: float,
    end_lat: float,
    end_lon: float,
    waypoints: list[dict],
    distance_km: float,
    estimated_minutes: int,
    elevation_gain_m: float,
    status: str = "clear",
) -> EvacuationRouteRecord:
    sb = get_client()
    row = {
        "id": str(uuid.uuid4()),
        "name": name,
        "start_lat": start_lat,
        "start_lon": start_lon,
        "end_lat": end_lat,
        "end_lon": end_lon,
        "waypoints": waypoints,
        "distance_km": distance_km,
        "estimated_minutes": estimated_minutes,
        "elevation_gain_m": elevation_gain_m,
        "status": status,
        "active": True,
    }
    res = sb.table("evacuation_routes").insert(row).execute()
    return res.data[0]


def list_evacuation_routes(*, active_only: bool = True) -> list[EvacuationRouteRecord]:
    sb = get_client()
    query = sb.table("evacuation_routes").select("*")
    if active_only:
        query = query.eq("active", True)
    res = query.execute()
    return res.data
