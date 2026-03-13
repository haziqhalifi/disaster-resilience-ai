"""Community reports database layer."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone, timedelta
from typing import TypedDict

from app.core.geo import haversine
from app.db.supabase_client import get_client


class ReportRecord(TypedDict):
    id:               str
    user_id:          str
    report_type:      str
    description:      str
    location_name:    str
    latitude:         float
    longitude:        float
    status:           str
    vulnerable_person: bool
    media_urls:       list[str]
    vouch_count:      int
    helpful_count:    int
    confidence_score: float | None
    resolved_by:      str | None
    resolution_reason: str | None
    resolved_at:      str | None
    description_updated_at: str | None
    created_at:       str
    updated_at:       str


# ── Create ────────────────────────────────────────────────────────────────────

def create_report(
    *,
    user_id: str,
    report_type: str,
    description: str,
    location_name: str,
    latitude: float,
    longitude: float,
    vulnerable_person: bool = False,
    media_urls: list[str] | None = None,
) -> ReportRecord:
    sb = get_client()
    now = datetime.now(timezone.utc).isoformat()
    row = {
        "id":              str(uuid.uuid4()),
        "user_id":         user_id,
        "report_type":     report_type,
        "description":     description,
        "location_name":   location_name,
        "latitude":        latitude,
        "longitude":       longitude,
        "status":          "pending",
        "vulnerable_person": vulnerable_person,
        "media_urls":      media_urls or [],
        "vouch_count":     0,
        "helpful_count":   0,
        "created_at":      now,
        "updated_at":      now,
    }
    res = sb.table("reports").insert(row).execute()
    return res.data[0]


# ── Read ──────────────────────────────────────────────────────────────────────

def get_report(report_id: str) -> ReportRecord | None:
    sb = get_client()
    res = sb.table("reports").select("*").eq("id", report_id).limit(1).execute()
    return res.data[0] if res.data else None


def get_nearby_reports(
    latitude: float,
    longitude: float,
    radius_km: float,
    report_type: str | None = None,
    status_filter: list[str] | None = None,
    limit: int = 50,
    offset: int = 0,
) -> list[dict]:
    """Return reports within radius_km, sorted by distance."""
    sb = get_client()
    query = sb.table("reports").select("*")

    if status_filter:
        query = query.in_("status", status_filter)
    else:
        query = query.in_("status", ["pending", "validated"])

    if report_type:
        query = query.eq("report_type", report_type)

    rows = query.execute().data or []

    nearby = []
    for row in rows:
        dist = haversine(latitude, longitude, row["latitude"], row["longitude"])
        if dist <= radius_km:
            nearby.append({**row, "distance_km": round(dist, 3)})

    nearby.sort(key=lambda r: r["distance_km"])
    return nearby[offset: offset + limit]


def get_my_reports(
    user_id: str,
    limit: int = 20,
    offset: int = 0,
) -> list[dict]:
    """Return all reports submitted by the given user, newest first."""
    sb = get_client()
    res = (
        sb.table("reports")
        .select("*")
        .eq("user_id", user_id)
        .order("created_at", desc=True)
        .range(offset, offset + limit - 1)
        .execute()
    )
    return res.data or []


def get_all_my_reports(user_id: str) -> list[dict]:
    """Return all reports submitted by the given user, newest first."""
    sb = get_client()
    res = (
        sb.table("reports")
        .select("*")
        .eq("user_id", user_id)
        .order("created_at", desc=True)
        .execute()
    )
    return res.data or []


def get_reports_in_bbox(
    min_lat: float, max_lat: float,
    min_lon: float, max_lon: float,
    limit: int = 100,
) -> list[ReportRecord]:
    sb = get_client()
    res = (
        sb.table("reports")
        .select("*")
        .gte("latitude",  min_lat).lte("latitude",  max_lat)
        .gte("longitude", min_lon).lte("longitude", max_lon)
        .in_("status", ["pending", "validated"])
        .limit(limit)
        .execute()
    )
    return res.data or []


def get_all_reports(
    status_filter: list[str] | None = None,
    report_type: str | None = None,
    search: str | None = None,
    limit: int = 50,
    offset: int = 0,
) -> list[ReportRecord]:
    """Admin: return reports with optional filters."""
    sb = get_client()
    query = sb.table("reports").select("*")
    if status_filter:
        query = query.in_("status", status_filter)
    if report_type:
        query = query.eq("report_type", report_type)
    query = query.order("created_at", desc=True)
    res = query.execute()
    rows = res.data or []
    if search:
        s = search.lower()
        rows = [r for r in rows if s in (r.get("description") or "").lower()
                or s in (r.get("location_name") or "").lower()]
    return rows[offset: offset + limit]


def get_report_stats() -> dict:
    sb = get_client()
    rows = sb.table("reports").select("status, report_type").execute().data or []
    total = len(rows)
    by_status: dict[str, int] = {}
    by_type: dict[str, int] = {}
    for r in rows:
        by_status[r["status"]] = by_status.get(r["status"], 0) + 1
        by_type[r["report_type"]] = by_type.get(r["report_type"], 0) + 1
    return {
        "total": total,
        "pending":   by_status.get("pending", 0),
        "validated": by_status.get("validated", 0),
        "rejected":  by_status.get("rejected", 0),
        "resolved":  by_status.get("resolved", 0),
        "expired":   by_status.get("expired", 0),
        "by_type":   by_type,
    }


# ── Update ────────────────────────────────────────────────────────────────────

def validate_report(report_id: str, *, validated_by: str) -> ReportRecord | None:
    sb = get_client()
    now = datetime.now(timezone.utc).isoformat()
    update_data = {"status": "validated", "updated_at": now}
    # Only set resolved_by if it looks like a UUID (user ID), not an admin username
    try:
        import uuid
        uuid.UUID(validated_by)
        update_data["resolved_by"] = validated_by
    except (ValueError, AttributeError):
        pass  # Admin username — skip FK-constrained field
    res = (
        sb.table("reports")
        .update(update_data)
        .eq("id", report_id)
        .execute()
    )
    return res.data[0] if res.data else None


def update_report_description(report_id: str, description: str) -> ReportRecord | None:
    sb = get_client()
    now = datetime.now(timezone.utc).isoformat()
    res = (
        sb.table("reports")
        .update({"description": description, "description_updated_at": now, "updated_at": now})
        .eq("id", report_id)
        .execute()
    )
    return res.data[0] if res.data else None



def resolve_report(report_id: str, *, resolved_by: str, reason: str = "") -> ReportRecord | None:
    sb = get_client()
    now = datetime.now(timezone.utc).isoformat()
    update_data = {
        "status": "resolved",
        "resolution_reason": reason,
        "resolved_at": now,
        "updated_at": now,
    }
    # Only set resolved_by if it looks like a UUID (user ID), not an admin username
    try:
        import uuid
        uuid.UUID(resolved_by)
        update_data["resolved_by"] = resolved_by
    except (ValueError, AttributeError):
        pass  # Admin username — skip FK-constrained field
    res = (
        sb.table("reports")
        .update(update_data)
        .eq("id", report_id)
        .execute()
    )
    return res.data[0] if res.data else None


def reject_report(report_id: str, *, resolved_by: str, reason: str) -> ReportRecord | None:
    sb = get_client()
    now = datetime.now(timezone.utc).isoformat()
    update_data = {
        "status": "rejected",
        "resolution_reason": reason,
        "resolved_at": now,
        "updated_at": now,
    }
    # Only set resolved_by if it's a UUID (user ID)
    try:
        import uuid
        uuid.UUID(resolved_by)
        update_data["resolved_by"] = resolved_by
    except (ValueError, AttributeError):
        pass  # Admin username — skip FK-constrained field
    res = (
        sb.table("reports")
        .update(update_data)
        .eq("id", report_id)
        .execute()
    )
    return res.data[0] if res.data else None


def delete_report(report_id: str) -> bool:
    sb = get_client()
    sb.table("reports").delete().eq("id", report_id).execute()
    return True


def expire_old_reports() -> int:
    """Auto-expire reports older than 7 days that are still pending/validated."""
    sb = get_client()
    cutoff = (datetime.now(timezone.utc) - timedelta(days=7)).isoformat()
    res = (
        sb.table("reports")
        .update({"status": "expired", "updated_at": datetime.now(timezone.utc).isoformat()})
        .in_("status", ["pending", "validated"])
        .lt("created_at", cutoff)
        .execute()
    )
    return len(res.data) if res.data else 0


# ── Vouches (community members vouch for reports they witness) ─────────────────

def add_vouch(report_id: str, user_id: str) -> int:
    """Returns updated vouch_count. Raises on duplicate."""
    sb = get_client()
    sb.table("report_vouches").insert({
        "id": str(uuid.uuid4()),
        "report_id": report_id,
        "user_id": user_id,
    }).execute()
    report = get_report(report_id)
    new_count = (report["vouch_count"] or 0) + 1
    sb.table("reports").update({"vouch_count": new_count, "updated_at": datetime.now(timezone.utc).isoformat()}).eq("id", report_id).execute()
    return new_count


def remove_vouch(report_id: str, user_id: str) -> int:
    sb = get_client()
    sb.table("report_vouches").delete().eq("report_id", report_id).eq("user_id", user_id).execute()
    report = get_report(report_id)
    new_count = max(0, (report["vouch_count"] or 0) - 1)
    sb.table("reports").update({"vouch_count": new_count, "updated_at": datetime.now(timezone.utc).isoformat()}).eq("id", report_id).execute()
    return new_count


def user_has_vouched(report_id: str, user_id: str) -> bool:
    sb = get_client()
    res = sb.table("report_vouches").select("id").eq("report_id", report_id).eq("user_id", user_id).limit(1).execute()
    return bool(res.data)


# ── Helpful ───────────────────────────────────────────────────────────────────

def add_helpful(report_id: str, user_id: str) -> int:
    sb = get_client()
    sb.table("report_helpful").insert({
        "id": str(uuid.uuid4()),
        "report_id": report_id,
        "user_id": user_id,
    }).execute()
    report = get_report(report_id)
    new_count = (report["helpful_count"] or 0) + 1
    sb.table("reports").update({"helpful_count": new_count, "updated_at": datetime.now(timezone.utc).isoformat()}).eq("id", report_id).execute()
    return new_count


def remove_helpful(report_id: str, user_id: str) -> int:
    sb = get_client()
    sb.table("report_helpful").delete().eq("report_id", report_id).eq("user_id", user_id).execute()
    report = get_report(report_id)
    new_count = max(0, (report["helpful_count"] or 0) - 1)
    sb.table("reports").update({"helpful_count": new_count, "updated_at": datetime.now(timezone.utc).isoformat()}).eq("id", report_id).execute()
    return new_count


def user_marked_helpful(report_id: str, user_id: str) -> bool:
    sb = get_client()
    res = sb.table("report_helpful").select("id").eq("report_id", report_id).eq("user_id", user_id).limit(1).execute()
    return bool(res.data)


# ── Flood reports for SMS alert trigger ──────────────────────────────────────

def get_validated_flood_reports_since(minutes: int = 2) -> list[ReportRecord]:
    """Return flood reports validated in the last N minutes (for SMS scheduler)."""
    sb = get_client()
    cutoff = (datetime.now(timezone.utc) - timedelta(minutes=minutes)).isoformat()
    res = (
        sb.table("reports")
        .select("*")
        .eq("status", "validated")
        .eq("report_type", "flood")
        .gte("updated_at", cutoff)
        .execute()
    )
    return res.data or []


def get_validated_reports_since(minutes: int = 2) -> list[ReportRecord]:
    """Return ALL validated reports (any type) from the last N minutes (for SMS scheduler)."""
    sb = get_client()
    cutoff = (datetime.now(timezone.utc) - timedelta(minutes=minutes)).isoformat()
    res = (
        sb.table("reports")
        .select("*")
        .eq("status", "validated")
        .gte("updated_at", cutoff)
        .execute()
    )
    return res.data or []


# ── AI scoring helpers ──────────────────────────────────────────────────────

def count_user_reports(user_id: str) -> int:
    """Return total number of reports submitted by a user."""
    sb = get_client()
    res = sb.table("reports").select("id", count="exact").eq("user_id", user_id).execute()
    return res.count if res.count is not None else 0


def update_confidence_score(report_id: str, score: float) -> None:
    """Persist the AI-computed credibility score on the report."""
    sb = get_client()
    sb.table("reports").update({
        "confidence_score": round(score, 4),
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }).eq("id", report_id).execute()


def get_pending_reports_for_ai_review(
    min_age_minutes: int = 5,
    max_age_hours: int = 24,
) -> list[ReportRecord]:
    """Return pending reports old enough for AI re-scoring."""
    sb = get_client()
    now = datetime.now(timezone.utc)
    min_cutoff = (now - timedelta(minutes=min_age_minutes)).isoformat()
    max_cutoff = (now - timedelta(hours=max_age_hours)).isoformat()
    res = (
        sb.table("reports")
        .select("*")
        .eq("status", "pending")
        .lte("created_at", min_cutoff)
        .gte("created_at", max_cutoff)
        .execute()
    )
    return res.data or []
