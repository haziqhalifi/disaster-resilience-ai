"""AI Risk Mapping endpoints.

Provides:
  - CRUD for risk zones (danger, warning, safe)
  - CRUD for evacuation centres
  - CRUD for evacuation routes
  - Combined map data endpoint (all layers in one call)
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.api.v1.dependencies import get_current_user
from app.db import risk_zones as rz_db
from app.schemas.risk_map import (
    EvacuationCentreCreate,
    EvacuationCentreList,
    EvacuationCentreOut,
    EvacuationRouteCreate,
    EvacuationRouteList,
    EvacuationRouteOut,
    MapDataResponse,
    RiskZoneCreate,
    RiskZoneList,
    RiskZoneOut,
    WaypointOut,
)
from app.schemas.user import UserOut

router = APIRouter()


# ── Helpers ──────────────────────────────────────────────────────────────────

def _zone_to_out(rec: dict) -> RiskZoneOut:
    return RiskZoneOut(**rec)


def _centre_to_out(rec: dict) -> EvacuationCentreOut:
    return EvacuationCentreOut(**rec)


def _route_to_out(rec: dict) -> EvacuationRouteOut:
    wps = rec.get("waypoints") or []
    return EvacuationRouteOut(
        id=rec["id"],
        name=rec["name"],
        start_lat=rec["start_lat"],
        start_lon=rec["start_lon"],
        end_lat=rec["end_lat"],
        end_lon=rec["end_lon"],
        waypoints=[WaypointOut(lat=w["lat"], lon=w["lon"]) for w in wps],
        distance_km=rec["distance_km"],
        estimated_minutes=rec["estimated_minutes"],
        elevation_gain_m=rec["elevation_gain_m"],
        status=rec["status"],
        active=rec["active"],
    )


# ── GET /risk-map — combined map data (all layers) ──────────────────────────

@router.get(
    "",
    response_model=MapDataResponse,
    summary="Get all map layers: risk zones, evacuation centres, and routes",
)
async def get_map_data(
    hazard_type: str | None = Query(None, description="Filter zones by hazard type"),
) -> MapDataResponse:
    """Returns all active map data for rendering the AI Risk Map.

    This is the primary endpoint the mobile app calls to populate the map.
    """
    zones = rz_db.list_risk_zones(active_only=True, hazard_type=hazard_type)
    centres = rz_db.list_evacuation_centres(active_only=True)
    routes = rz_db.list_evacuation_routes(active_only=True)

    return MapDataResponse(
        risk_zones=[_zone_to_out(z) for z in zones],
        evacuation_centres=[_centre_to_out(c) for c in centres],
        evacuation_routes=[_route_to_out(r) for r in routes],
    )


# ── Risk Zones CRUD ──────────────────────────────────────────────────────────

@router.get("/zones", response_model=RiskZoneList, summary="List risk zones")
async def list_zones(
    zone_type: str | None = Query(None),
    hazard_type: str | None = Query(None),
) -> RiskZoneList:
    records = rz_db.list_risk_zones(zone_type=zone_type, hazard_type=hazard_type)
    return RiskZoneList(count=len(records), zones=[_zone_to_out(r) for r in records])


@router.post(
    "/zones",
    response_model=RiskZoneOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new risk zone",
)
async def create_zone(
    body: RiskZoneCreate,
    _current_user: UserOut = Depends(get_current_user),
) -> RiskZoneOut:
    record = rz_db.create_risk_zone(
        name=body.name,
        zone_type=body.zone_type.value,
        hazard_type=body.hazard_type,
        latitude=body.latitude,
        longitude=body.longitude,
        radius_km=body.radius_km,
        risk_score=body.risk_score,
        description=body.description,
    )
    return _zone_to_out(record)


# ── Evacuation Centres CRUD ──────────────────────────────────────────────────

@router.get("/centres", response_model=EvacuationCentreList, summary="List evacuation centres")
async def list_centres() -> EvacuationCentreList:
    records = rz_db.list_evacuation_centres()
    return EvacuationCentreList(count=len(records), centres=[_centre_to_out(r) for r in records])


@router.post(
    "/centres",
    response_model=EvacuationCentreOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new evacuation centre",
)
async def create_centre(
    body: EvacuationCentreCreate,
    _current_user: UserOut = Depends(get_current_user),
) -> EvacuationCentreOut:
    record = rz_db.create_evacuation_centre(
        name=body.name,
        latitude=body.latitude,
        longitude=body.longitude,
        capacity=body.capacity,
        current_occupancy=body.current_occupancy,
        contact_phone=body.contact_phone,
        address=body.address,
    )
    return _centre_to_out(record)


# ── Evacuation Routes CRUD ───────────────────────────────────────────────────

@router.get("/routes", response_model=EvacuationRouteList, summary="List evacuation routes")
async def list_routes() -> EvacuationRouteList:
    records = rz_db.list_evacuation_routes()
    return EvacuationRouteList(count=len(records), routes=[_route_to_out(r) for r in records])


@router.post(
    "/routes",
    response_model=EvacuationRouteOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new evacuation route",
)
async def create_route(
    body: EvacuationRouteCreate,
    _current_user: UserOut = Depends(get_current_user),
) -> EvacuationRouteOut:
    record = rz_db.create_evacuation_route(
        name=body.name,
        start_lat=body.start_lat,
        start_lon=body.start_lon,
        end_lat=body.end_lat,
        end_lon=body.end_lon,
        waypoints=[w.model_dump() for w in body.waypoints],
        distance_km=body.distance_km,
        estimated_minutes=body.estimated_minutes,
        elevation_gain_m=body.elevation_gain_m,
        status=body.status.value,
    )
    return _route_to_out(record)
