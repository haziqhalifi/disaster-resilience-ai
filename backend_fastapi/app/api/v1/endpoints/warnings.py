"""Hyper-Local Early Warning endpoints.

Provides CRUD for warnings and a broadcast mechanism that
notifies every user whose last-known location falls inside
the affected radius (push first, SMS fallback).
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.api.v1.dependencies import get_current_user
from app.db import warnings as warning_db
from app.schemas.user import UserOut
from app.schemas.warning import (
    AlertLevel,
    GeoPoint,
    HazardType,
    NotifyResult,
    WarningCreate,
    WarningList,
    WarningOut,
)
from app.services.notifications import broadcast_warning, get_warnings_for_location

router = APIRouter()


# ── Helpers ──────────────────────────────────────────────────────────────────

def _record_to_out(rec: warning_db.WarningRecord) -> WarningOut:
    return WarningOut(
        id=rec["id"],
        title=rec["title"],
        description=rec["description"],
        hazard_type=HazardType(rec["hazard_type"]),
        alert_level=AlertLevel(rec["alert_level"]),
        location=GeoPoint(latitude=rec["latitude"], longitude=rec["longitude"]),
        radius_km=rec["radius_km"],
        source=rec["source"],
        created_at=rec["created_at"],
        active=rec["active"],
    )


# ── POST /warnings — create + broadcast ─────────────────────────────────────

@router.post(
    "",
    response_model=NotifyResult,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new warning and broadcast to affected users",
)
async def create_warning(
    body: WarningCreate,
    _current_user: UserOut = Depends(get_current_user),
) -> NotifyResult:
    """Persist a new hyper-local warning and immediately fan it out.

    Users whose last-known location is within `radius_km` of `location`
    receive either a push notification (FCM) or an SMS fallback.
    """
    record = warning_db.create_warning(
        title=body.title,
        description=body.description,
        hazard_type=body.hazard_type.value,
        alert_level=body.alert_level.value,
        latitude=body.location.latitude,
        longitude=body.location.longitude,
        radius_km=body.radius_km,
        source=body.source,
    )

    result = broadcast_warning(record)
    return NotifyResult(
        warning_id=result.warning_id,
        push_sent=result.push_sent,
        sms_sent=result.sms_sent,
        total_affected=result.total_affected,
    )


# ── GET /warnings — list with optional filters ──────────────────────────────

@router.get(
    "",
    response_model=WarningList,
    summary="List warnings (active by default, supports filters)",
)
async def list_warnings(
    active_only: bool = Query(True, description="Only return active warnings."),
    hazard_type: HazardType | None = Query(None, description="Filter by hazard type."),
    alert_level: AlertLevel | None = Query(None, description="Filter by alert level."),
) -> WarningList:
    """Return warnings, optionally filtered by hazard type, alert level, or status."""
    records = warning_db.list_warnings(
        active_only=active_only,
        hazard_type=hazard_type.value if hazard_type else None,
        alert_level=alert_level.value if alert_level else None,
    )
    return WarningList(
        count=len(records),
        warnings=[_record_to_out(r) for r in records],
    )


# ── GET /warnings/{warning_id} — single warning ─────────────────────────────

@router.get(
    "/{warning_id}",
    response_model=WarningOut,
    summary="Get a single warning by ID",
)
async def get_warning(warning_id: str) -> WarningOut:
    record = warning_db.get_warning(warning_id)
    if record is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Warning not found.")
    return _record_to_out(record)


# ── PATCH /warnings/{warning_id}/deactivate — resolve / expire ───────────────

@router.patch(
    "/{warning_id}/deactivate",
    response_model=WarningOut,
    summary="Deactivate (resolve) a warning",
)
async def deactivate_warning(
    warning_id: str,
    _current_user: UserOut = Depends(get_current_user),
) -> WarningOut:
    record = warning_db.deactivate_warning(warning_id)
    if record is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Warning not found.")
    return _record_to_out(record)


# ── GET /warnings/nearby — warnings affecting a specific location ────────────

@router.get(
    "/nearby/",
    response_model=WarningList,
    summary="Get active warnings affecting a specific coordinate",
)
async def nearby_warnings(
    latitude: float = Query(..., ge=-90.0, le=90.0),
    longitude: float = Query(..., ge=-180.0, le=180.0),
) -> WarningList:
    """Return every currently active warning whose affected zone covers
    the supplied coordinate.  Useful for the mobile app to check on
    launch what warnings are relevant to the user's current position.
    """
    active = warning_db.get_all_active_warnings()
    matched = get_warnings_for_location(latitude, longitude, active)
    return WarningList(
        count=len(matched),
        warnings=[_record_to_out(r) for r in matched],
    )
