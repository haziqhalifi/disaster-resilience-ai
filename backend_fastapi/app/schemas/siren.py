"""Pydantic schemas for IoT siren device management."""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


# ── Request models ──────────────────────────────────────────────────────────

class SirenRegister(BaseModel):
    name: str = Field(..., min_length=1, max_length=200, description="Human-readable siren name / location label")
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    radius_km: float = Field(5.0, gt=0, le=100, description="Coverage radius in km")
    endpoint_url: Optional[str] = Field(None, description="HTTP endpoint to trigger the physical siren")
    api_key: Optional[str] = Field(None, description="Auth key for the siren endpoint")


class SirenTrigger(BaseModel):
    warning_id: Optional[str] = Field(None, description="Warning that caused the trigger (optional for manual)")


class SirenStatusUpdate(BaseModel):
    status: str = Field(..., pattern=r"^(idle|active|offline|maintenance)$")


# ── Response models ─────────────────────────────────────────────────────────

class SirenOut(BaseModel):
    id: str
    name: str
    latitude: float
    longitude: float
    radius_km: float
    endpoint_url: Optional[str] = None
    api_key: Optional[str] = None
    status: str
    registered_by: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class SirenActivationOut(BaseModel):
    id: str
    siren_id: str
    warning_id: Optional[str] = None
    trigger_type: str
    triggered_by: Optional[str] = None
    triggered_at: Optional[datetime] = None
    stopped_at: Optional[datetime] = None
    status: str
    error_reason: Optional[str] = None


class SirenTriggerResult(BaseModel):
    siren_id: str
    siren_name: str
    activation_id: str
    status: str
    hardware_reached: bool
