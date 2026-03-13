"""AI Risk Mapping endpoints.

Provides:
  - CRUD for risk zones (danger, warning, safe)
  - CRUD for evacuation centres
  - CRUD for evacuation routes
  - Combined map data endpoint (all layers in one call)
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.db import dun_boundaries as dunboundary_db
from app.api.v1.dependencies import get_current_user
from app.db import district_boundaries as dboundary_db
from app.db import risk_zones as rz_db
from app.services import nadma
from app.schemas.risk_map import (
    AdminAreaOut,
    EvacuationCentreCreate,
    EvacuationCentreList,
    EvacuationCentreOut,
    EvacuationRouteCreate,
    EvacuationRouteList,
    EvacuationRouteOut,
    MapDataResponse,
    OfficialDisasterOut,
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


def _point_in_polygon(lat: float, lon: float, polygon: list[dict]) -> bool:
    # Ray-casting algorithm for point-in-polygon checks.
    inside = False
    j = len(polygon) - 1
    for i in range(len(polygon)):
        yi = polygon[i]["lat"]
        xi = polygon[i]["lon"]
        yj = polygon[j]["lat"]
        xj = polygon[j]["lon"]

        intersects = ((yi > lat) != (yj > lat)) and (
            lon < (xj - xi) * (lat - yi) / ((yj - yi) or 1e-12) + xi
        )
        if intersects:
            inside = not inside
        j = i
    return inside


def _extract_boundary_from_geometry(geometry: dict) -> list[dict]:
    gtype = geometry.get("type")
    coords = geometry.get("coordinates")
    if not coords:
        return []

    rings: list[list[list[float]]] = []
    if gtype == "Polygon":
        # Polygon coordinates => [ [ [lon, lat], ... ] , ... ]
        if coords and isinstance(coords[0], list):
            rings.append(coords[0])
    elif gtype == "MultiPolygon":
        # MultiPolygon coordinates => [ polygon1, polygon2, ... ]
        for polygon in coords:
            if polygon and isinstance(polygon, list) and polygon[0]:
                rings.append(polygon[0])

    if not rings:
        return []

    # Use the largest outer ring to represent the district boundary.
    ring = max(rings, key=len)
    boundary = []
    for pair in ring:
        if not isinstance(pair, list) or len(pair) < 2:
            continue
        lon, lat = pair[0], pair[1]
        boundary.append({"lat": float(lat), "lon": float(lon)})
    return boundary


def _load_admin_boundaries() -> list[dict]:
    # Prefer finer-grained DUN boundaries when available.
    dun_rows = dunboundary_db.list_dun_boundaries(active_only=True)
    boundaries = []
    for row in dun_rows:
        boundary = _extract_boundary_from_geometry(row.get("geometry") or {})
        if len(boundary) < 3:
            continue
        boundaries.append(
            {
                "id": row["id"],
                "name": row["name"],
                "boundary": boundary,
            }
        )
    if boundaries:
        return boundaries

    # Fallback to district boundaries for states that do not have DUN data yet.
    rows = dboundary_db.list_district_boundaries(active_only=True)
    boundaries = []
    for row in rows:
        boundary = _extract_boundary_from_geometry(row.get("geometry") or {})
        if len(boundary) < 3:
            continue
        boundaries.append(
            {
                "id": row["id"],
                "name": row["name"],
                "boundary": boundary,
            }
        )
    return boundaries


def _aggregate_admin_areas(
    zones: list[dict],
    hazard_type: str,
    boundaries: list[dict],
) -> list[AdminAreaOut]:
    hazard_zones = [z for z in zones if z.get("hazard_type") == hazard_type]
    areas: list[AdminAreaOut] = []

    for area in boundaries:
        boundary = area["boundary"]
        area_zones = [
            z
            for z in hazard_zones
            if _point_in_polygon(z["latitude"], z["longitude"], boundary)
        ]
        if not area_zones:
            continue

        avg_risk = sum(z["risk_score"] for z in area_zones) / len(area_zones)
        areas.append(
            AdminAreaOut(
                id=f"{area['id']}-{hazard_type}",
                name=area["name"],
                hazard_type=hazard_type,
                risk_score=round(avg_risk, 4),
                zone_count=len(area_zones),
                boundary=[WaypointOut(lat=p["lat"], lon=p["lon"]) for p in boundary],
            )
        )

    return areas


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
    official_disasters = await nadma.get_active_disasters(hazard_type=hazard_type)
    boundaries = _load_admin_boundaries()
    area_hazards = [hazard_type] if hazard_type else ["flood", "landslide"]
    admin_areas: list[AdminAreaOut] = []
    for h in area_hazards:
        admin_areas.extend(_aggregate_admin_areas(zones, h, boundaries))

    return MapDataResponse(
        risk_zones=[_zone_to_out(z) for z in zones],
        evacuation_centres=[_centre_to_out(c) for c in centres],
        evacuation_routes=[_route_to_out(r) for r in routes],
        admin_areas=admin_areas,
        official_disasters=[OfficialDisasterOut(**d) for d in official_disasters],
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
