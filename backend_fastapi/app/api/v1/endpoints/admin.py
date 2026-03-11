"""Admin endpoints — report moderation and statistics."""

from __future__ import annotations

import asyncio
import hashlib
import logging
from datetime import datetime, timezone, timedelta

import jwt
from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from app.core.config import ADMIN_JWT_SECRET
from app.db import admin as admin_db
from app.db import reports as report_db

logger = logging.getLogger(__name__)
router = APIRouter()
_bearer = HTTPBearer()

_ALGO = "HS256"
_EXPIRY_HOURS = 24


# ── Auth helpers ──────────────────────────────────────────────────────────────

def _hash(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()


def _make_token(username: str) -> str:
    exp = datetime.now(timezone.utc) + timedelta(hours=_EXPIRY_HOURS)
    return jwt.encode({"sub": username, "exp": exp}, ADMIN_JWT_SECRET, algorithm=_ALGO)


def _verify_token(credentials: HTTPAuthorizationCredentials = Depends(_bearer)) -> str:
    try:
        payload = jwt.decode(credentials.credentials, ADMIN_JWT_SECRET, algorithms=[_ALGO])
        return payload["sub"]
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid token")


# ── Login / Register ──────────────────────────────────────────────────────────

@router.post("/login")
async def admin_login(body: dict) -> dict:
    username = body.get("username", "").strip()
    password = body.get("password", "")
    if not username or not password:
        raise HTTPException(status_code=422, detail="Username and password required")
    row = admin_db.get_admin_by_username(username)
    if not row or row["password_hash"] != _hash(password):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    token = _make_token(username)
    return {"access_token": token, "token_type": "bearer", "expires_in": _EXPIRY_HOURS * 3600}


@router.post("/register", status_code=status.HTTP_201_CREATED)
async def admin_register(body: dict) -> dict:
    username = body.get("username", "").strip()
    password = body.get("password", "")
    if not username or len(password) < 6:
        raise HTTPException(status_code=422, detail="Username required and password must be ≥6 characters")
    try:
        existing = admin_db.get_admin_by_username(username)
    except Exception as exc:
        logger.error("DB error checking admin username: %s", exc)
        raise HTTPException(status_code=503, detail="Database unavailable — check Supabase connection")
    if existing:
        raise HTTPException(status_code=409, detail="Username already taken")
    try:
        admin_db.create_admin_user(username=username, password_hash=_hash(password))
    except Exception as exc:
        logger.error("DB error creating admin user: %s", exc)
        raise HTTPException(status_code=503, detail=f"Failed to create user: {exc}")
    token = _make_token(username)
    return {"access_token": token, "token_type": "bearer", "expires_in": _EXPIRY_HOURS * 3600}


@router.get("/me")
async def admin_me(sub: str = Depends(_verify_token)) -> dict:
    return {"username": sub, "role": "admin"}


# ── Report management ─────────────────────────────────────────────────────────

@router.get("/reports")
async def list_reports(
    report_status: str  = Query(default=None),
    report_type:   str  = Query(default=None),
    search:        str  = Query(default=None),
    limit:         int  = Query(default=50, ge=1, le=200),
    offset:        int  = Query(default=0,  ge=0),
    sub: str = Depends(_verify_token),
) -> dict:
    status_filter = [report_status] if report_status else None
    rows, total = report_db.get_all_reports(
        status_filter=status_filter,
        report_type=report_type,
        search=search,
        limit=limit,
        offset=offset,
    )
    return {"reports": rows, "total": total}


@router.get("/reports/{report_id}")
async def get_report(report_id: str, sub: str = Depends(_verify_token)) -> dict:
    row = report_db.get_report(report_id)
    if not row:
        raise HTTPException(status_code=404, detail="Report not found")
    return row


@router.get("/reports/{report_id}/sms-preview")
async def sms_preview(report_id: str, sub: str = Depends(_verify_token)) -> dict:
    """Return count of users who would receive an SMS if this report were approved."""
    from app.core.geo import haversine
    from app.db import devices as device_db

    row = report_db.get_report(report_id)
    if not row:
        raise HTTPException(status_code=404, detail="Report not found")

    lat = row.get("latitude")
    lon = row.get("longitude")
    radius_km = 10.0
    affected = phone_users = 0

    if lat is not None and lon is not None:
        for dev in device_db.get_all_devices_with_location():
            if dev["latitude"] is None or dev["longitude"] is None:
                continue
            if haversine(dev["latitude"], dev["longitude"], lat, lon) <= radius_km:
                affected += 1
                if dev.get("phone_number"):
                    phone_users += 1

    return {
        "report_id":      report_id,
        "location_name":  row.get("location_name", ""),
        "report_type":    row.get("report_type", ""),
        "radius_km":      radius_km,
        "affected_count": affected,
        "phone_users":    phone_users,
    }


@router.post("/reports/{report_id}/approve")
async def approve_report(report_id: str, sub: str = Depends(_verify_token)) -> dict:
    row = report_db.get_report(report_id)
    if not row:
        raise HTTPException(status_code=404, detail="Report not found")
    updated = report_db.validate_report(report_id, validated_by="admin")

    broadcast_result: dict = {"total_affected": 0, "push_sent": 0, "sms_sent": 0, "family_leader_sms": 0}
    try:
        if row.get("report_type") == "flood":
            from app.services.notifications import broadcast_flood_report, notify_family_leaders_of_flood
            broadcast_result = await broadcast_flood_report(updated)
            broadcast_result["family_leader_sms"] = await notify_family_leaders_of_flood(updated)
        else:
            from app.services.notifications import broadcast_report_alert
            result = await broadcast_report_alert(updated)
            broadcast_result.update(result)
        logger.info("Auto-SMS broadcast for report %s (%s): %s", report_id, row.get("report_type"), broadcast_result)
    except Exception as exc:
        logger.error("Auto-SMS failed for report %s: %s", report_id, exc)

    return {"message": "Report approved", "report": updated, "broadcast": broadcast_result}


@router.post("/reports/{report_id}/reject")
async def reject_report(report_id: str, body: dict, sub: str = Depends(_verify_token)) -> dict:
    reason = body.get("reason", "")
    if not reason:
        raise HTTPException(status_code=422, detail="Rejection reason required")
    row = report_db.get_report(report_id)
    if not row:
        raise HTTPException(status_code=404, detail="Report not found")
    updated = report_db.reject_report(report_id, resolved_by="admin", reason=reason)
    return {"message": "Report rejected", "report": updated}


@router.post("/reports/{report_id}/resolve")
async def resolve_report(report_id: str, sub: str = Depends(_verify_token)) -> dict:
    row = report_db.get_report(report_id)
    if not row:
        raise HTTPException(status_code=404, detail="Report not found")
    updated = report_db.resolve_report(report_id, resolved_by="admin")
    return {"message": "Report resolved", "report": updated}


@router.delete("/reports/{report_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_report(report_id: str, sub: str = Depends(_verify_token)) -> None:
    row = report_db.get_report(report_id)
    if not row:
        raise HTTPException(status_code=404, detail="Report not found")
    report_db.delete_report(report_id)


@router.get("/stats")
async def get_stats(sub: str = Depends(_verify_token)) -> dict:
    return report_db.get_report_stats()


# ── AI Analysis ───────────────────────────────────────────────────────────────

@router.post("/reports/{report_id}/ai-analyze")
async def ai_analyze_report(report_id: str, sub: str = Depends(_verify_token)) -> dict:
    """Run Claude multi-agent analysis to assess report legitimacy."""
    row = report_db.get_report(report_id)
    if not row:
        raise HTTPException(status_code=404, detail="Report not found")

    # Mark as analyzing
    from app.db.supabase_client import get_client
    sb = get_client()
    sb.table("reports").update({"ai_status": "analyzing"}).eq("id", report_id).execute()

    try:
        from app.services.ai_analysis import analyze_report
        loop = asyncio.get_event_loop()
        result = await loop.run_in_executor(None, analyze_report, dict(row))

        sb.table("reports").update({
            "ai_analysis": result,
            "ai_status": "done",
        }).eq("id", report_id).execute()

        logger.info("AI analysis for report %s: score=%s rec=%s", report_id, result.get("score"), result.get("recommendation"))
        return {"report_id": report_id, "analysis": result}
    except Exception as exc:
        sb.table("reports").update({"ai_status": "failed"}).eq("id", report_id).execute()
        logger.error("AI analysis failed for report %s: %s", report_id, exc)
        raise HTTPException(status_code=500, detail=f"AI analysis failed: {exc}")


# ── SMS alert dispatch ─────────────────────────────────────────────────────────

@router.post("/reports/{report_id}/send-sms")
async def send_sms_alert(report_id: str, sub: str = Depends(_verify_token)) -> dict:
    """Broadcast a flood SMS to all users within 10km of the validated report."""
    row = report_db.get_report(report_id)
    if not row:
        raise HTTPException(status_code=404, detail="Report not found")
    if row.get("status") != "validated":
        raise HTTPException(status_code=400, detail="Report must be validated before sending an SMS alert")
    if row.get("report_type") == "flood":
        from app.services.notifications import broadcast_flood_report
        result = await broadcast_flood_report(row)
    else:
        from app.services.notifications import broadcast_report_alert
        result = await broadcast_report_alert(row)
    logger.info("Admin %s triggered SMS broadcast for report %s: %s", sub, report_id, result)
    return result


# ── Rescue requests ────────────────────────────────────────────────────────────

@router.get("/rescue-requests")
async def get_rescue_requests(sub: str = Depends(_verify_token)) -> list[dict]:
    """Return unacknowledged DANGER replies with the sender's last-known location."""
    from app.db.supabase_client import get_client
    from app.db.devices import get_device
    sb = get_client()
    rows = (
        sb.table("sms_alerts")
        .select("*")
        .eq("reply_status", "danger")
        .eq("rescue_acknowledged", False)
        .order("reply_at", desc=True)
        .execute().data or []
    )
    result = []
    for row in rows:
        device = get_device(row["user_id"]) if row.get("user_id") else None
        result.append({
            **row,
            "device_latitude":  device["latitude"]  if device else None,
            "device_longitude": device["longitude"] if device else None,
        })
    return result


@router.post("/rescue-requests/{alert_id}/acknowledge")
async def acknowledge_rescue(alert_id: str, sub: str = Depends(_verify_token)) -> dict:
    """Mark a rescue request as handled by the rescue team."""
    from app.db.supabase_client import get_client
    sb = get_client()
    sb.table("sms_alerts").update({"rescue_acknowledged": True}).eq("id", alert_id).execute()
    logger.info("Admin %s acknowledged rescue request %s", sub, alert_id)
    return {"message": "Rescue request acknowledged"}
