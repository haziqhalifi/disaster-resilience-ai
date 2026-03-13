"""Community report endpoints."""

from __future__ import annotations

import logging
import os
import uuid
from datetime import datetime, timezone, timedelta

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status

from app.api.v1.dependencies import get_current_user
from app.db import reports as report_db
from app.db.supabase_client import get_client
from app.schemas.report import (
    BoundingBoxQuery, HelpfulOut, ReportCreate,
    ReportDescriptionUpdate, ReportList, ReportMediaUploadOut, ReportOut,
    ReportRejectRequest, VouchOut,
)
from app.schemas.user import UserOut

logger = logging.getLogger(__name__)

router = APIRouter()

_REPORT_MEDIA_BUCKET = os.getenv("SUPABASE_REPORT_MEDIA_BUCKET", "report-media")
_ALLOWED_MEDIA = {
    "image/jpeg",
    "image/png",
    "image/webp",
    "video/mp4",
    "video/quicktime",
    "video/webm",
}
_MAX_UPLOAD_BYTES = 25 * 1024 * 1024


def _to_out(row: dict, current_user_id: str | None = None) -> ReportOut:
    vouched = report_db.user_has_vouched(row["id"], current_user_id) if current_user_id else False
    helpful = report_db.user_marked_helpful(row["id"], current_user_id) if current_user_id else False
    return ReportOut(
        id=row["id"],
        user_id=row["user_id"],
        report_type=row["report_type"],
        description=row["description"],
        location_name=row["location_name"],
        latitude=row["latitude"],
        longitude=row["longitude"],
        status=row["status"],
        vulnerable_person=row.get("vulnerable_person", False),
        media_urls=row.get("media_urls") or [],
        vouch_count=row.get("vouch_count", 0),
        helpful_count=row.get("helpful_count", 0),
        confidence_score=row.get("confidence_score"),
        distance_km=row.get("distance_km"),
        current_user_vouched=vouched,
        current_user_helpful=helpful,
        created_at=row["created_at"],
        updated_at=row["updated_at"],
    )


@router.post("/media/upload", response_model=ReportMediaUploadOut, status_code=status.HTTP_201_CREATED)
async def upload_report_media(
    file: UploadFile = File(...),
    current_user: UserOut = Depends(get_current_user),
) -> ReportMediaUploadOut:
    if file.content_type not in _ALLOWED_MEDIA:
        raise HTTPException(status_code=415, detail="Unsupported media type")

    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="Empty file")
    if len(data) > _MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="File too large (max 25MB)")

    filename = file.filename or "upload"
    lower_name = filename.lower()
    suffix = f".{lower_name.rsplit('.', 1)[-1]}" if "." in lower_name else (
        ".jpg" if (file.content_type or "").startswith("image/") else ".mp4"
    )
    safe_name = f"{uuid.uuid4().hex}{suffix}"
    storage_path = f"reports/{current_user.id}/{safe_name}"

    sb = get_client()
    try:
        sb.storage.from_(_REPORT_MEDIA_BUCKET).upload(
            storage_path,
            data,
            {
                "content-type": file.content_type,
                "upsert": "false",
            },
        )
    except Exception as exc:
        logger.error("Supabase Storage upload failed for %s: %s", storage_path, exc)
        raise HTTPException(status_code=500, detail="Failed to upload media") from exc

    public_url = sb.storage.from_(_REPORT_MEDIA_BUCKET).get_public_url(storage_path)
    if isinstance(public_url, dict):
        nested_obj = public_url.get("data")
        nested = nested_obj if isinstance(nested_obj, dict) else {}
        media_url = (
            public_url.get("publicURL")
            or public_url.get("publicUrl")
            or nested.get("publicURL")
            or nested.get("publicUrl")
            or ""
        )
    else:
        media_url = str(public_url or "")
    if not media_url:
        raise HTTPException(status_code=500, detail="Failed to generate media URL")

    media_type = "video" if (file.content_type or "").startswith("video/") else "image"
    return ReportMediaUploadOut(url=media_url, media_type=media_type)


@router.post("/submit", response_model=ReportOut, status_code=status.HTTP_201_CREATED)
async def submit_report(
    body: ReportCreate,
    current_user: UserOut = Depends(get_current_user),
) -> ReportOut:
    row = report_db.create_report(
        user_id=current_user.id,
        report_type=body.report_type.value,
        description=body.description,
        location_name=body.location_name,
        latitude=body.latitude,
        longitude=body.longitude,
        vulnerable_person=body.vulnerable_person,
        media_urls=body.media_urls,
    )

    # ── AI credibility scoring ────────────────────────────────────────────
    try:
        from ai_models.services.inference import score_report
        ai_result = score_report(
            vouch_count=0,
            description_length=len(body.description),
            has_precise_coords=True,
            report_age_hours=0.0,
            reporter_total_reports=report_db.count_user_reports(current_user.id),
            proximity_to_risk_zone_km=_nearest_risk_zone_distance(
                body.latitude, body.longitude,
            ),
        )
        report_db.update_confidence_score(
            row["id"], ai_result["confidence_score"],
        )
        row["confidence_score"] = ai_result["confidence_score"]
        logger.info(
            "Report %s AI confidence=%.2f credible=%s",
            row["id"], ai_result["confidence_score"], ai_result["is_credible"],
        )
    except Exception as exc:
        logger.warning("AI scoring failed for report %s: %s", row["id"], exc)

    return _to_out(row, current_user.id)


def _nearest_risk_zone_distance(lat: float, lon: float) -> float:
    """Best-effort distance to nearest risk zone. Returns 50 km if unknown."""
    try:
        from app.db.risk_zones import get_all_risk_zones
        from app.core.geo import haversine
        zones = get_all_risk_zones()
        if not zones:
            return 50.0
        return min(
            haversine(lat, lon, z["latitude"], z["longitude"]) for z in zones
        )
    except Exception:
        return 50.0


@router.get("/my", response_model=ReportList)
async def get_my_reports(
    limit:  int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0,  ge=0),
    current_user: UserOut = Depends(get_current_user),
) -> ReportList:
    rows = report_db.get_my_reports(
        user_id=current_user.id,
        limit=limit,
        offset=offset,
    )
    return ReportList(reports=[_to_out(r, current_user.id) for r in rows], total=len(rows))


@router.get("/nearby/list", response_model=ReportList)
async def get_nearby_reports(
    latitude:      float = Query(..., ge=-90,  le=90),
    longitude:     float = Query(..., ge=-180, le=180),
    radius_km:     float = Query(default=10.0, gt=0, le=100),
    report_type:   str   = Query(default=None),
    status_filter: str   = Query(default=None, description="Comma-separated statuses, e.g. 'validated' or 'validated,verified'"),
    limit:         int   = Query(default=50, ge=1, le=200),
    offset:        int   = Query(default=0,  ge=0),
    current_user: UserOut = Depends(get_current_user),
) -> ReportList:
    status_list = [s.strip() for s in status_filter.split(",")] if status_filter else None
    rows = report_db.get_nearby_reports(
        latitude=latitude, longitude=longitude,
        radius_km=radius_km, report_type=report_type,
        status_filter=status_list,
        limit=limit, offset=offset,
    )
    return ReportList(reports=[_to_out(r, current_user.id) for r in rows], total=len(rows))


@router.get("/bbox/list", response_model=ReportList)
async def get_bbox_reports(
    min_lat: float = Query(..., ge=-90,  le=90),
    max_lat: float = Query(..., ge=-90,  le=90),
    min_lon: float = Query(..., ge=-180, le=180),
    max_lon: float = Query(..., ge=-180, le=180),
    limit:   int   = Query(default=100, ge=1, le=500),
    current_user: UserOut = Depends(get_current_user),
) -> ReportList:
    if max_lat <= min_lat:
        raise HTTPException(status_code=422, detail="max_lat must be greater than min_lat")
    rows = report_db.get_reports_in_bbox(min_lat, max_lat, min_lon, max_lon, limit)
    return ReportList(reports=[_to_out(r, current_user.id) for r in rows], total=len(rows))


@router.get("/{report_id}", response_model=ReportOut)
async def get_report(
    report_id: str,
    current_user: UserOut = Depends(get_current_user),
) -> ReportOut:
    row = report_db.get_report(report_id)
    if not row:
        raise HTTPException(status_code=404, detail="Report not found")
    return _to_out(row, current_user.id)


@router.patch("/{report_id}/description", response_model=ReportOut)
async def update_description(
    report_id: str,
    body: ReportDescriptionUpdate,
    current_user: UserOut = Depends(get_current_user),
) -> ReportOut:
    row = report_db.get_report(report_id)
    if not row:
        raise HTTPException(status_code=404, detail="Report not found")
    if row["user_id"] != current_user.id:
        raise HTTPException(status_code=403, detail="Not your report")
    created = datetime.fromisoformat(row["created_at"].replace("Z", "+00:00"))
    if datetime.now(timezone.utc) - created > timedelta(hours=24):
        raise HTTPException(status_code=403, detail="Can only edit description within 24 hours")
    updated = report_db.update_report_description(report_id, body.description)
    return _to_out(updated, current_user.id)


@router.patch("/{report_id}/resolve", response_model=ReportOut)
async def resolve_report(
    report_id: str,
    current_user: UserOut = Depends(get_current_user),
) -> ReportOut:
    row = report_db.get_report(report_id)
    if not row:
        raise HTTPException(status_code=404, detail="Report not found")
    updated = report_db.resolve_report(report_id, resolved_by=current_user.id)
    return _to_out(updated, current_user.id)


@router.patch("/{report_id}/reject", response_model=ReportOut)
async def reject_report(
    report_id: str,
    body: ReportRejectRequest,
    current_user: UserOut = Depends(get_current_user),
) -> ReportOut:
    row = report_db.get_report(report_id)
    if not row:
        raise HTTPException(status_code=404, detail="Report not found")
    updated = report_db.reject_report(report_id, resolved_by=current_user.id, reason=body.reason)
    return _to_out(updated, current_user.id)


@router.post("/{report_id}/vouch", response_model=VouchOut)
async def vouch_report(
    report_id: str,
    current_user: UserOut = Depends(get_current_user),
) -> VouchOut:
    row = report_db.get_report(report_id)
    if not row:
        raise HTTPException(status_code=404, detail="Report not found")
    if report_db.user_has_vouched(report_id, current_user.id):
        raise HTTPException(status_code=409, detail="Already vouched")
    count = report_db.add_vouch(report_id, current_user.id)
    return VouchOut(report_id=report_id, vouch_count=count, user_vouched=True)


@router.delete("/{report_id}/vouch", response_model=VouchOut)
async def unvouch_report(
    report_id: str,
    current_user: UserOut = Depends(get_current_user),
) -> VouchOut:
    row = report_db.get_report(report_id)
    if not row:
        raise HTTPException(status_code=404, detail="Report not found")
    count = report_db.remove_vouch(report_id, current_user.id)
    return VouchOut(report_id=report_id, vouch_count=count, user_vouched=False)


@router.post("/{report_id}/helpful", response_model=HelpfulOut)
async def mark_helpful(
    report_id: str,
    current_user: UserOut = Depends(get_current_user),
) -> HelpfulOut:
    row = report_db.get_report(report_id)
    if not row:
        raise HTTPException(status_code=404, detail="Report not found")
    if report_db.user_marked_helpful(report_id, current_user.id):
        raise HTTPException(status_code=409, detail="Already marked as helpful")
    count = report_db.add_helpful(report_id, current_user.id)
    return HelpfulOut(report_id=report_id, helpful_count=count, user_marked=True)


@router.delete("/{report_id}/helpful", response_model=HelpfulOut)
async def unmark_helpful(
    report_id: str,
    current_user: UserOut = Depends(get_current_user),
) -> HelpfulOut:
    row = report_db.get_report(report_id)
    if not row:
        raise HTTPException(status_code=404, detail="Report not found")
    count = report_db.remove_helpful(report_id, current_user.id)
    return HelpfulOut(report_id=report_id, helpful_count=count, user_marked=False)
