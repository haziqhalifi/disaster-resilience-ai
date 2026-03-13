"""Admin endpoints — report moderation and statistics."""

from __future__ import annotations

import hashlib
import logging
from datetime import datetime, timezone, timedelta

import jwt
from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from app.core.config import ADMIN_JWT_SECRET
from app.db import admin as admin_db
from app.db import reports as report_db
from app.db import warnings as warning_db

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
    if admin_db.get_admin_by_username(username):
        raise HTTPException(status_code=409, detail="Username already taken")
    admin_db.create_admin_user(username=username, password_hash=_hash(password))
    token = _make_token(username)
    return {"access_token": token, "token_type": "bearer", "expires_in": _EXPIRY_HOURS * 3600}


@router.get("/me")
async def admin_me(sub: str = Depends(_verify_token)) -> dict:
    return {"username": sub, "role": "admin"}


# ── Report management ─────────────────────────────────────────────────────────

# In-memory cache: report_id → full Claude analysis result
# Persists while the server is running; lost on restart (acceptable — admin can re-run)
_ai_cache: dict[str, dict] = {}


def _enrich_ai_fields(row: dict) -> dict:
    """Attach ai_status + ai_analysis for the admin UI.

    Rules:
    - If a Claude analysis is cached for this report → show score badge (ai_status='done')
    - If report is still 'pending' → always show AI Check button (ai_status=None)
      so the admin can trigger a real content analysis
    - Otherwise (validated/rejected/resolved with confidence_score) → show ML score badge
    """
    report_id = row.get("id", "")

    # Claude result takes priority
    if report_id in _ai_cache:
        row["ai_status"] = "done"
        row["ai_analysis"] = _ai_cache[report_id]
        return row

    # Pending reports always show the AI Check button — never show ML auto-score
    if row.get("status") == "pending":
        row["ai_status"] = None
        row["ai_analysis"] = None
        return row

    # Non-pending: convert ML confidence_score to a badge if available
    score_raw = row.get("confidence_score")
    if score_raw is None:
        row.setdefault("ai_status", None)
        row.setdefault("ai_analysis", None)
        return row
    score = round(score_raw * 100)
    rec = ("Credible" if score >= 70 else "Moderate" if score >= 40 else "Low Credibility")
    row["ai_status"] = "done"
    row["ai_analysis"] = {"score": score, "recommendation": rec, "reasoning": "", "sources": []}
    return row


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
    rows = report_db.get_all_reports(
        status_filter=status_filter,
        report_type=report_type,
        search=search,
        limit=limit,
        offset=offset,
    )
    rows = [_enrich_ai_fields(r) for r in rows]
    return {"reports": rows, "total": len(rows)}


@router.get("/reports/{report_id}")
async def get_report(report_id: str, sub: str = Depends(_verify_token)) -> dict:
    row = report_db.get_report(report_id)
    if not row:
        raise HTTPException(status_code=404, detail="Report not found")
    return row


@router.post("/reports/{report_id}/approve")
async def approve_report(report_id: str, sub: str = Depends(_verify_token)) -> dict:
    row = report_db.get_report(report_id)
    if not row:
        raise HTTPException(status_code=404, detail="Report not found")
    updated = report_db.validate_report(report_id, validated_by="admin")
    return {"message": "Report approved", "report": updated}


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


# ── SMS alert dispatch ─────────────────────────────────────────────────────────

@router.get("/reports/{report_id}/sms-replies")
async def sms_reply_stats(report_id: str, sub: str = Depends(_verify_token)) -> dict:
    """Return per-report SMS reply stats: safe / danger / no-reply counts and per-row detail."""
    from app.db.supabase_client import get_client
    sb = get_client()
    rows = (
        sb.table("sms_alerts")
        .select("*")
        .eq("event_id", report_id)
        .order("sent_at", desc=True)
        .execute().data or []
    )

    def _mask(phone: str) -> str:
        p = phone or ""
        if len(p) < 6:
            return "****"
        return p[:3] + "****" + p[-3:]

    safe_count     = sum(1 for r in rows if r.get("reply_status") == "safe")
    danger_count   = sum(1 for r in rows if r.get("reply_status") == "needs_help")
    no_reply_count = sum(1 for r in rows if not r.get("reply_status"))

    return {
        "report_id":      report_id,
        "total_sent":     len(rows),
        "safe_count":     safe_count,
        "danger_count":   danger_count,
        "no_reply_count": no_reply_count,
        "replies": [
            {
                "id":                   r["id"],
                "phone_masked":         _mask(r.get("phone_number", "")),
                "reply_status":         r.get("reply_status") or "no_reply",
                "alert_type":           r.get("alert_type", ""),
                "sent_at":              r.get("sent_at"),
                "reply_at":             r.get("reply_at"),
                "rescue_acknowledged":  r.get("rescue_acknowledged", False),
            }
            for r in rows
        ],
    }


@router.post("/reports/{report_id}/send-sms")
async def send_sms_alert(report_id: str, sub: str = Depends(_verify_token)) -> dict:
    """Broadcast a flood SMS to all users within 10km of the validated report."""
    row = report_db.get_report(report_id)
    if not row:
        raise HTTPException(status_code=404, detail="Report not found")
    if row.get("status") != "validated":
        raise HTTPException(status_code=400, detail="Report must be validated before sending an SMS alert")
    from app.services.notifications import broadcast_flood_report
    result = await broadcast_flood_report(row)
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


# ── SMS preview ────────────────────────────────────────────────────────────────

@router.get("/reports/{report_id}/sms-preview")
async def sms_preview(report_id: str, sub: str = Depends(_verify_token)) -> dict:
    """Return how many SMS-capable users are within 10 km of the report."""
    row = report_db.get_report(report_id)
    if not row:
        raise HTTPException(status_code=404, detail="Report not found")
    lat, lon = row.get("latitude"), row.get("longitude")
    if lat is None or lon is None:
        return {"phone_users": 0, "location_name": row.get("location_name", "unknown")}
    from app.core.geo import haversine
    from app.db.devices import get_all_devices_with_location
    phone_count = sum(
        1 for d in get_all_devices_with_location()
        if d.get("phone_number")
        and d.get("latitude") is not None
        and haversine(d["latitude"], d["longitude"], lat, lon) <= 10.0
    )
    return {"phone_users": phone_count, "location_name": row.get("location_name", "unknown")}


# ── AI analysis (on-demand, Claude-powered) ────────────────────────────────────

@router.post("/reports/{report_id}/ai-analyze")
async def ai_analyze_report(report_id: str, sub: str = Depends(_verify_token)) -> dict:
    """Run multi-agent Claude analysis (news + weather + gov alerts) to assess report credibility."""
    row = report_db.get_report(report_id)
    if not row:
        raise HTTPException(status_code=404, detail="Report not found")

    from app.core.config import ANTHROPIC_API_KEY
    if not ANTHROPIC_API_KEY:
        raise HTTPException(status_code=503, detail="AI analysis unavailable — ANTHROPIC_API_KEY not configured")

    try:
        import asyncio
        from app.services.ai_analysis import analyze_report
        loop = asyncio.get_event_loop()
        analysis = await loop.run_in_executor(None, analyze_report, dict(row))

        # Clamp score
        analysis["score"] = max(0, min(100, int(analysis.get("score", 50))))

        # Cache and persist score
        _ai_cache[report_id] = analysis
        report_db.update_confidence_score(report_id, analysis["score"] / 100)

        logger.info("Admin %s: AI analysis for report %s → score=%s sources=%s",
                    sub, report_id, analysis["score"], analysis.get("sources"))
        return {"analysis": analysis}

    except Exception as exc:
        logger.error("AI analysis failed for report %s: %s", report_id, exc)
        raise HTTPException(status_code=500, detail=f"AI analysis failed: {exc}")


# ── Warnings management ────────────────────────────────────────────────────────

@router.get("/warnings")
async def list_active_warnings(sub: str = Depends(_verify_token)) -> list[dict]:
    """Return all active DB warnings (excludes MetMalaysia gov alerts)."""
    rows = warning_db.list_warnings(active_only=True)
    return [dict(r) for r in rows]


@router.patch("/warnings/{warning_id}/deactivate")
async def deactivate_warning(warning_id: str, sub: str = Depends(_verify_token)) -> dict:
    """Deactivate (dismiss) a warning so it no longer appears in the app."""
    record = warning_db.deactivate_warning(warning_id)
    if record is None:
        raise HTTPException(status_code=404, detail="Warning not found")
    logger.info("Admin %s deactivated warning %s", sub, warning_id)
    return {"message": "Warning deactivated", "id": warning_id}
