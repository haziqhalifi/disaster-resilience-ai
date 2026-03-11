"""IoT siren management & triggering endpoints.

Allows admins to:
  1. Register new siren devices
  2. List / view siren status
  3. Trigger or stop a siren
  4. Update siren status (maintenance, offline, etc.)
  5. View activation history
"""

from __future__ import annotations

import asyncio
import logging

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.api.v1.dependencies import get_current_user
from app.db import sirens as siren_db
from app.schemas.siren import (
    SirenActivationOut,
    SirenOut,
    SirenRegister,
    SirenStatusUpdate,
    SirenTrigger,
    SirenTriggerResult,
)
from app.schemas.user import UserOut

logger = logging.getLogger(__name__)

router = APIRouter()


# ── POST / — register a new siren device ────────────────────────────────────

@router.post(
    "/",
    response_model=SirenOut,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new IoT siren device",
)
async def register_siren(
    body: SirenRegister,
    current_user: UserOut = Depends(get_current_user),
) -> SirenOut:
    rec = await asyncio.to_thread(
        siren_db.register_siren,
        name=body.name,
        latitude=body.latitude,
        longitude=body.longitude,
        radius_km=body.radius_km,
        endpoint_url=body.endpoint_url,
        api_key=body.api_key,
        registered_by=current_user.id,
    )
    return SirenOut(**rec)


# ── GET / — list all sirens ─────────────────────────────────────────────────

@router.get(
    "/",
    response_model=list[SirenOut],
    summary="List all registered siren devices",
)
async def list_sirens(
    status_filter: str | None = Query(None, alias="status", description="Filter by status"),
) -> list[SirenOut]:
    recs = await asyncio.to_thread(siren_db.list_sirens, status_filter=status_filter)
    return [SirenOut(**r) for r in recs]


# ── GET /{siren_id} — get a single siren ────────────────────────────────────

@router.get(
    "/{siren_id}",
    response_model=SirenOut,
    summary="Get siren device details",
)
async def get_siren(siren_id: str) -> SirenOut:
    rec = await asyncio.to_thread(siren_db.get_siren, siren_id)
    if not rec:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Siren not found")
    return SirenOut(**rec)


# ── POST /{siren_id}/trigger — activate a siren ─────────────────────────────

@router.post(
    "/{siren_id}/trigger",
    response_model=SirenTriggerResult,
    summary="Trigger (activate) a siren",
)
async def trigger_siren(
    siren_id: str,
    body: SirenTrigger | None = None,
    current_user: UserOut = Depends(get_current_user),
) -> SirenTriggerResult:
    siren = await asyncio.to_thread(siren_db.get_siren, siren_id)
    if not siren:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Siren not found")
    if siren["status"] in ("offline", "maintenance"):
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            f"Siren is {siren['status']} and cannot be triggered",
        )

    warning_id = body.warning_id if body else None
    hardware_reached = await _call_siren_hardware(siren, action="trigger")

    activation = await asyncio.to_thread(
        siren_db.log_activation,
        siren_id=siren_id,
        warning_id=warning_id,
        trigger_type="manual",
        triggered_by=current_user.id,
        status="triggered" if hardware_reached else "failed",
        error_reason=None if hardware_reached else "Hardware unreachable",
    )
    await asyncio.to_thread(siren_db.update_siren_status, siren_id, "active")

    return SirenTriggerResult(
        siren_id=siren_id,
        siren_name=siren["name"],
        activation_id=activation["id"],
        status=activation["status"],
        hardware_reached=hardware_reached,
    )


# ── POST /{siren_id}/stop — deactivate a siren ─────────────────────────────

@router.post(
    "/{siren_id}/stop",
    response_model=SirenOut,
    summary="Stop (deactivate) a siren",
)
async def stop_siren(
    siren_id: str,
    current_user: UserOut = Depends(get_current_user),
) -> SirenOut:
    siren = await asyncio.to_thread(siren_db.get_siren, siren_id)
    if not siren:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Siren not found")

    # Stop all active activations
    active = await asyncio.to_thread(siren_db.get_active_activations, siren_id)
    for act in active:
        await asyncio.to_thread(siren_db.stop_activation, act["id"])

    await _call_siren_hardware(siren, action="stop")
    rec = await asyncio.to_thread(siren_db.update_siren_status, siren_id, "idle")
    return SirenOut(**rec)


# ── PATCH /{siren_id}/status — update siren metadata status ─────────────────

@router.patch(
    "/{siren_id}/status",
    response_model=SirenOut,
    summary="Update siren status (idle/offline/maintenance)",
)
async def update_siren_status(
    siren_id: str,
    body: SirenStatusUpdate,
    current_user: UserOut = Depends(get_current_user),
) -> SirenOut:
    rec = await asyncio.to_thread(siren_db.update_siren_status, siren_id, body.status)
    if not rec:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Siren not found")
    return SirenOut(**rec)


# ── GET /{siren_id}/log — activation history ────────────────────────────────

@router.get(
    "/{siren_id}/log",
    response_model=list[SirenActivationOut],
    summary="Get siren activation history",
)
async def get_siren_log(
    siren_id: str,
    limit: int = Query(20, ge=1, le=100),
) -> list[SirenActivationOut]:
    recs = await asyncio.to_thread(siren_db.get_activation_log, siren_id, limit)
    return [SirenActivationOut(**r) for r in recs]


# ── Hardware integration ─────────────────────────────────────────────────────

async def _call_siren_hardware(siren: dict, *, action: str) -> bool:
    """Send an HTTP request to the physical siren's IoT endpoint.

    Returns True if the hardware acknowledged the command.
    If no endpoint is configured the call is a no-op (simulated success).
    """
    url = siren.get("endpoint_url")
    if not url:
        logger.info("Siren %s has no endpoint — simulating %s", siren["id"], action)
        return True

    headers: dict[str, str] = {"Content-Type": "application/json"}
    api_key = siren.get("api_key")
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"

    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.post(
                url,
                json={"action": action, "siren_id": siren["id"]},
                headers=headers,
            )
            resp.raise_for_status()
            logger.info("Siren %s hardware %s OK (HTTP %d)", siren["id"], action, resp.status_code)
            return True
    except Exception as exc:
        logger.error("Siren %s hardware %s failed: %s", siren["id"], action, exc)
        return False


async def trigger_sirens_for_warning(warning: dict) -> list[SirenTriggerResult]:
    """Trigger all sirens near a warning's epicentre.

    Called by the notification broadcast system and the scheduler.
    """
    nearby = await asyncio.to_thread(
        siren_db.get_sirens_near,
        warning["latitude"],
        warning["longitude"],
        max_km=warning.get("radius_km", 25.0),
    )
    results: list[SirenTriggerResult] = []
    for siren in nearby:
        if siren["status"] in ("offline", "maintenance"):
            continue
        hardware_ok = await _call_siren_hardware(siren, action="trigger")
        activation = await asyncio.to_thread(
            siren_db.log_activation,
            siren_id=siren["id"],
            warning_id=warning.get("id"),
            trigger_type="auto",
            triggered_by="system",
            status="triggered" if hardware_ok else "failed",
            error_reason=None if hardware_ok else "Hardware unreachable",
        )
        await asyncio.to_thread(
            siren_db.update_siren_status,
            siren["id"],
            "active" if hardware_ok else siren["status"],
        )
        results.append(SirenTriggerResult(
            siren_id=siren["id"],
            siren_name=siren["name"],
            activation_id=activation["id"],
            status=activation["status"],
            hardware_reached=hardware_ok,
        ))
    return results
