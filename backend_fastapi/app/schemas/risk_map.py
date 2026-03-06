"""Pydantic schemas for the AI Risk Mapping system.

Covers:
  - Risk zones (danger, warning, safe)
  - Evacuation centres with occupancy tracking
  - Evacuation routes with waypoints
  - Full map data response combining all layers
"""

from __future__ import annotations

from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field


# ── Enumerations ──────────────────────────────────────────────────────────────

class ZoneType(str, Enum):
    DANGER = "danger"
    WARNING = "warning"
    SAFE = "safe"


class RouteStatus(str, Enum):
    CLEAR = "clear"
    PARTIAL = "partial"
    BLOCKED = "blocked"


# ── Risk Zone schemas ─────────────────────────────────────────────────────────

class RiskZoneCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    zone_type: ZoneType
    hazard_type: str = Field(..., description="flood, landslide, typhoon, earthquake")
    latitude: float = Field(..., ge=-90.0, le=90.0)
    longitude: float = Field(..., ge=-180.0, le=180.0)
    radius_km: float = Field(..., gt=0.0, le=100.0)
    risk_score: float = Field(..., ge=0.0, le=1.0)
    description: str = ""


class RiskZoneOut(BaseModel):
    id: str
    name: str
    zone_type: ZoneType
    hazard_type: str
    latitude: float
    longitude: float
    radius_km: float
    risk_score: float
    description: str
    created_at: datetime
    active: bool = True


class RiskZoneList(BaseModel):
    count: int
    zones: list[RiskZoneOut]


# ── Evacuation Centre schemas ─────────────────────────────────────────────────

class EvacuationCentreCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    latitude: float = Field(..., ge=-90.0, le=90.0)
    longitude: float = Field(..., ge=-180.0, le=180.0)
    capacity: int = Field(..., ge=1)
    current_occupancy: int = Field(default=0, ge=0)
    contact_phone: str | None = None
    address: str = ""


class EvacuationCentreOut(BaseModel):
    id: str
    name: str
    latitude: float
    longitude: float
    capacity: int
    current_occupancy: int
    contact_phone: str | None = None
    address: str
    active: bool = True


class EvacuationCentreList(BaseModel):
    count: int
    centres: list[EvacuationCentreOut]


# ── Evacuation Route schemas ─────────────────────────────────────────────────

class WaypointOut(BaseModel):
    lat: float
    lon: float


class EvacuationRouteCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    start_lat: float = Field(..., ge=-90.0, le=90.0)
    start_lon: float = Field(..., ge=-180.0, le=180.0)
    end_lat: float = Field(..., ge=-90.0, le=90.0)
    end_lon: float = Field(..., ge=-180.0, le=180.0)
    waypoints: list[WaypointOut] = []
    distance_km: float = Field(..., gt=0.0)
    estimated_minutes: int = Field(..., ge=1)
    elevation_gain_m: float = Field(default=0.0, ge=0.0)
    status: RouteStatus = RouteStatus.CLEAR


class EvacuationRouteOut(BaseModel):
    id: str
    name: str
    start_lat: float
    start_lon: float
    end_lat: float
    end_lon: float
    waypoints: list[WaypointOut]
    distance_km: float
    estimated_minutes: int
    elevation_gain_m: float
    status: RouteStatus
    active: bool = True


class EvacuationRouteList(BaseModel):
    count: int
    routes: list[EvacuationRouteOut]


# ── Combined Map Data Response ────────────────────────────────────────────────

class MapDataResponse(BaseModel):
    """All map layers combined in a single response for the mobile app."""
    risk_zones: list[RiskZoneOut]
    evacuation_centres: list[EvacuationCentreOut]
    evacuation_routes: list[EvacuationRouteOut]
