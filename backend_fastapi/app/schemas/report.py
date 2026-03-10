"""Pydantic schemas for community reports."""

from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Any

from pydantic import BaseModel, Field, field_validator


class ReportType(str, Enum):
    flood             = "flood"
    landslide         = "landslide"
    blocked_road      = "blocked_road"
    medical_emergency = "medical_emergency"


class ReportStatus(str, Enum):
    pending   = "pending"
    validated = "validated"
    rejected  = "rejected"
    resolved  = "resolved"
    expired   = "expired"


# ── Requests ──────────────────────────────────────────────────────────────────

class ReportCreate(BaseModel):
    report_type:      ReportType
    description:      str  = Field(default="", max_length=1000)
    location_name:    str  = Field(..., min_length=1, max_length=200)
    latitude:         float = Field(..., ge=-90,  le=90)
    longitude:        float = Field(..., ge=-180, le=180)
    vulnerable_person: bool = False


class ReportDescriptionUpdate(BaseModel):
    description: str = Field(..., min_length=1, max_length=1000)


class ReportRejectRequest(BaseModel):
    reason: str = Field(..., min_length=1, max_length=500)


# ── Responses ─────────────────────────────────────────────────────────────────

class ReportOut(BaseModel):
    id:                 str
    user_id:            str
    report_type:        str
    description:        str
    location_name:      str
    latitude:           float
    longitude:          float
    status:             str
    vulnerable_person:  bool
    vouch_count:        int
    helpful_count:      int
    confidence_score:   float | None = None
    distance_km:        float | None = None
    current_user_vouched: bool       = False
    current_user_helpful: bool       = False
    created_at:         datetime
    updated_at:         datetime


class ReportList(BaseModel):
    reports: list[ReportOut]
    total:   int


class VouchOut(BaseModel):
    report_id:    str
    vouch_count:  int
    user_vouched: bool


class HelpfulOut(BaseModel):
    report_id:    str
    helpful_count: int
    user_marked:  bool


class NearbyQuery(BaseModel):
    latitude:    float = Field(..., ge=-90,  le=90)
    longitude:   float = Field(..., ge=-180, le=180)
    radius_km:   float = Field(default=10.0, gt=0, le=100)
    report_type: ReportType | None = None
    limit:       int   = Field(default=50, ge=1, le=200)
    offset:      int   = Field(default=0,  ge=0)


class BoundingBoxQuery(BaseModel):
    min_lat:  float = Field(..., ge=-90,  le=90)
    max_lat:  float = Field(..., ge=-90,  le=90)
    min_lon:  float = Field(..., ge=-180, le=180)
    max_lon:  float = Field(..., ge=-180, le=180)
    limit:    int   = Field(default=100, ge=1, le=500)

    @field_validator("max_lat")
    @classmethod
    def max_lat_gt_min(cls, v: float, info: Any) -> float:
        if "min_lat" in info.data and v <= info.data["min_lat"]:
            raise ValueError("max_lat must be greater than min_lat")
        return v
