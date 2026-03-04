"""Pydantic schemas for the Hyper-Local Early Warning system.

Covers:
  - Hazard types (flood, landslide, typhoon, earthquake)
  - Tiered alert levels: advisory → observe → warning → evacuate
  - Warning CRUD models
  - User location / device registration
  - SMS fallback payloads
"""

from __future__ import annotations

from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field


# ── Enumerations ──────────────────────────────────────────────────────────────

class HazardType(str, Enum):
    """Multi-hazard coverage types."""
    FLOOD = "flood"
    LANDSLIDE = "landslide"
    TYPHOON = "typhoon"
    EARTHQUAKE = "earthquake"


class AlertLevel(str, Enum):
    """Tiered alert levels, in increasing severity order."""
    ADVISORY = "advisory"
    OBSERVE = "observe"
    WARNING = "warning"
    EVACUATE = "evacuate"


# ── Location helpers ──────────────────────────────────────────────────────────

class GeoPoint(BaseModel):
    """A geographic coordinate pair."""
    latitude: float = Field(..., ge=-90.0, le=90.0, description="Latitude in decimal degrees.")
    longitude: float = Field(..., ge=-180.0, le=180.0, description="Longitude in decimal degrees.")


# ── Warning schemas ──────────────────────────────────────────────────────────

class WarningCreate(BaseModel):
    """Request body for creating a new warning (admin / system use)."""
    title: str = Field(..., min_length=1, max_length=200, description="Short headline.")
    description: str = Field(..., min_length=1, description="Detailed description of the threat.")
    hazard_type: HazardType
    alert_level: AlertLevel
    location: GeoPoint = Field(..., description="Epicentre / affected-area centre.")
    radius_km: float = Field(
        ..., gt=0.0, le=500.0,
        description="Radius (km) around `location` that defines the affected zone.",
    )
    source: str = Field(
        default="system",
        description="Originating authority or data source (e.g. 'MET Malaysia', 'USGS').",
    )


class WarningOut(BaseModel):
    """Public representation of a stored warning."""
    id: str
    title: str
    description: str
    hazard_type: HazardType
    alert_level: AlertLevel
    location: GeoPoint
    radius_km: float
    source: str
    created_at: datetime
    active: bool = True


class WarningList(BaseModel):
    """Paginated list wrapper."""
    count: int
    warnings: list[WarningOut]


# ── User location / device registration ─────────────────────────────────────

class UserLocationUpdate(BaseModel):
    """Payload sent by the mobile app when the user's location changes."""
    latitude: float = Field(..., ge=-90.0, le=90.0)
    longitude: float = Field(..., ge=-180.0, le=180.0)


class DeviceRegister(BaseModel):
    """Register a device for push notifications and optional SMS fallback."""
    fcm_token: str | None = Field(
        default=None,
        description="Firebase Cloud Messaging token for push notifications.",
    )
    phone_number: str | None = Field(
        default=None,
        description="Phone number (E.164) for SMS fallback when offline.",
        examples=["+60123456789"],
    )


class DeviceOut(BaseModel):
    """Stored device / location record."""
    user_id: str
    latitude: float | None = None
    longitude: float | None = None
    fcm_token: str | None = None
    phone_number: str | None = None
    updated_at: datetime | None = None


# ── Notification payloads ────────────────────────────────────────────────────

class NotificationPayload(BaseModel):
    """Payload dispatched to affected users (push or SMS)."""
    warning_id: str
    title: str
    body: str
    hazard_type: HazardType
    alert_level: AlertLevel
    channel: str = Field(
        ..., description="Delivery channel used: 'push' or 'sms'.",
    )


class NotifyResult(BaseModel):
    """Summary returned after broadcasting a warning."""
    warning_id: str
    push_sent: int = 0
    sms_sent: int = 0
    total_affected: int = 0
