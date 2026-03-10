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
from app.services import met_malaysia
from app.core.geo import haversine

router = APIRouter()

# ── Malaysia state / sea-area centroids for MetMalaysia text matching ─────────
# Used to resolve a rough lat/lon when MetMalaysia stores no coordinates.
_STATE_CENTROIDS: dict[str, tuple[float, float]] = {
    "perlis":           (6.44,  100.19),
    "kedah":            (6.12,  100.37),
    "penang":           (5.42,  100.33),
    "perak":            (4.59,  101.09),
    "selangor":         (3.07,  101.52),
    "kuala lumpur":     (3.14,  101.69),
    "putrajaya":        (2.93,  101.69),
    "negeri sembilan":  (2.72,  102.25),
    "melaka":           (2.21,  102.25),
    "johor":            (1.86,  103.43),
    "pahang":           (3.81,  103.33),
    "terengganu":       (5.31,  103.14),
    "kelantan":         (5.88,  102.24),
    "sabah":            (5.98,  116.07),
    "sarawak":          (1.55,  110.36),
    "labuan":           (5.28,  115.24),
    # Coastal / sea areas
    "south china sea":  (8.00,  112.00),
    "strait of malacca":(3.00,  100.50),
    "sulu sea":         (7.00,  120.00),
    "andaman":          (12.00,  93.00),
    "east coast":       (4.50,  103.40),
    "west coast":       (3.50,  100.80),
    "sabah waters":     (5.50,  117.00),
    "sarawak waters":   (3.00,  111.00),
}


def _resolve_gov_coords(row: dict) -> tuple[float, float] | None:
    """Return (lat, lon) for a government alert by:
       1. Real DB coordinates (if any),
       2. Scanning heading + text for a Malaysia state/sea-area keyword.
       Returns None if no location can be determined.
    """
    if row.get("latitude") and row.get("longitude"):
        return float(row["latitude"]), float(row["longitude"])
    raw = row.get("raw_data") or {}
    text = (
        (raw.get("heading_en") or "") + " " +
        (raw.get("text_en") or "") + " " +
        (row.get("area") or "")
    ).lower()
    for keyword, coords in _STATE_CENTROIDS.items():
        if keyword in text:
            return coords
    return None


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


_SEVERITY_TO_ALERT = {"high": "warning", "medium": "observe", "low": "advisory", "info": "advisory"}


def _gov_alert_to_out(row: dict) -> WarningOut:
    """Convert a government_alerts row (MetMalaysia) into a WarningOut."""
    from datetime import datetime, timezone
    raw = row.get("raw_data") or {}
    heading = raw.get("heading_en") or row.get("area") or "MetMalaysia Warning"
    text    = raw.get("text_en") or ""
    valid_to = raw.get("valid_to") or ""
    description = text or heading
    if valid_to:
        description += f" (valid until {valid_to})"

    # Map severity to alert_level
    severity   = row.get("severity") or "info"
    alert_str  = _SEVERITY_TO_ALERT.get(severity, "advisory")

    # Guess hazard type from heading
    h_lower = heading.lower()
    if "flood" in h_lower or "rain" in h_lower:
        hazard = HazardType.FLOOD
    elif "wind" in h_lower or "sea" in h_lower or "wave" in h_lower:
        hazard = HazardType.TYPHOON
    elif "landslide" in h_lower:
        hazard = HazardType.LANDSLIDE
    else:
        hazard = HazardType.FORECAST

    # MetMalaysia warnings are nationwide — use Malaysia centroid if no coords
    lat = row.get("latitude") or 4.2105
    lon = row.get("longitude") or 108.9758

    fetched_at = row.get("fetched_at") or datetime.now(timezone.utc).isoformat()
    try:
        created_at_dt = datetime.fromisoformat(fetched_at.replace("Z", "+00:00"))
    except Exception:
        created_at_dt = datetime.now(timezone.utc)

    return WarningOut(
        id=row["id"],
        title=heading,
        description=description,
        hazard_type=hazard,
        alert_level=AlertLevel(alert_str),
        location=GeoPoint(latitude=lat, longitude=lon),
        radius_km=500.0,  # nationwide/regional — large radius
        source="MetMalaysia",
        created_at=created_at_dt,
        active=row.get("active", True),
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
    warnings = [_record_to_out(r) for r in records]

    # Merge MetMalaysia government alerts
    try:
        gov_rows = met_malaysia.get_active_warnings()
        warnings += [_gov_alert_to_out(r) for r in gov_rows]
    except Exception:
        pass  # Never let MetMalaysia failure break the endpoint

    return WarningList(count=len(warnings), warnings=warnings)


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
    all_warnings = [
        _record_to_out(r).model_copy(update={
            "distance_km": round(haversine(latitude, longitude, r["latitude"], r["longitude"]), 1)
        })
        for r in matched
    ]

    # Include MetMalaysia government alerts only within 50 km.
    # Location is resolved by parsing the warning text for state/sea-area keywords.
    # Warnings with no recognisable location are skipped (irrelevant to user).
    _GOV_RADIUS_KM = 50.0
    try:
        gov_rows = met_malaysia.get_active_warnings()
        for r in gov_rows:
            coords = _resolve_gov_coords(r)
            if coords is None:
                continue  # No location resolved — skip this warning
            gov_lat, gov_lon = coords
            dist = haversine(latitude, longitude, gov_lat, gov_lon)
            if dist <= _GOV_RADIUS_KM:
                out = _gov_alert_to_out(r).model_copy(update={"distance_km": round(dist, 1)})
                all_warnings.append(out)
    except Exception:
        pass

    return WarningList(count=len(all_warnings), warnings=all_warnings)


# ── GET /warnings/gov-alerts — raw MetMalaysia alerts ────────────────────────

@router.get(
    "/gov-alerts",
    summary="Raw MetMalaysia government alerts (last 24 h)",
)
async def gov_alerts() -> dict:
    """Return the latest MetMalaysia government weather warnings in their raw format."""
    try:
        rows = met_malaysia.get_active_warnings()
        return {"count": len(rows), "alerts": rows}
    except Exception as exc:
        return {"count": 0, "alerts": [], "error": str(exc)}
    return WarningList(
        count=len(matched),
        warnings=[_record_to_out(r) for r in matched],
    )


# ── GET /warnings/since — new warnings after a timestamp ─────────────────────

@router.get(
    "/since/",
    response_model=WarningList,
    summary="Get warnings created after a given timestamp",
)
async def warnings_since(
    since: str = Query(..., description="ISO-8601 timestamp. Returns warnings created after this time."),
    latitude: float | None = Query(None, ge=-90.0, le=90.0, description="Optional lat to filter by proximity."),
    longitude: float | None = Query(None, ge=-180.0, le=180.0, description="Optional lon to filter by proximity."),
) -> WarningList:
    """Return active warnings created after *since*.

    If latitude and longitude are provided, only returns warnings whose
    affected zone covers that coordinate (hyper-local filtering).
    """
    records = warning_db.get_warnings_since(since)
    if latitude is not None and longitude is not None:
        records = [
            r for r in records
            if get_warnings_for_location(latitude, longitude, [r])
        ]
    return WarningList(
        count=len(records),
        warnings=[_record_to_out(r) for r in records],
    )
