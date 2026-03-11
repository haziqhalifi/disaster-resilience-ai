"""Community report endpoints."""

from __future__ import annotations

import uuid as uuid_module
from datetime import datetime, timezone, timedelta

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status

from app.api.v1.dependencies import get_current_user
from app.db import reports as report_db
from app.schemas.report import (
    BoundingBoxQuery, HelpfulOut, ReportCreate,
    ReportDescriptionUpdate, ReportList, ReportOut,
    ReportRejectRequest, VouchOut,
)
from app.schemas.user import UserOut

router = APIRouter()


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
        vouch_count=row.get("vouch_count", 0),
        helpful_count=row.get("helpful_count", 0),
        distance_km=row.get("distance_km"),
        current_user_vouched=vouched,
        current_user_helpful=helpful,
        media_url=row.get("media_url"),
        ai_analysis=row.get("ai_analysis"),
        ai_status=row.get("ai_status"),
        created_at=row["created_at"],
        updated_at=row["updated_at"],
    )


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
    )
    return _to_out(row, current_user.id)


@router.get("/nearby/list", response_model=ReportList)
async def get_nearby_reports(
    latitude:      float = Query(..., ge=-90,  le=90),
    longitude:     float = Query(..., ge=-180, le=180),
    radius_km:     float = Query(default=10.0, gt=0, le=100),
    report_type:   str   = Query(default=None),
    status_filter: str   = Query(default=None),
    sort_by:       str   = Query(default=None),
    limit:         int   = Query(default=50, ge=1, le=200),
    offset:        int   = Query(default=0,  ge=0),
    current_user: UserOut = Depends(get_current_user),
) -> ReportList:
    status_list = [status_filter] if status_filter else None
    rows = report_db.get_nearby_reports(
        latitude=latitude, longitude=longitude,
        radius_km=radius_km, report_type=report_type,
        status_filter=status_list,
        limit=limit, offset=offset,
    )
    if sort_by == "vouch_count":
        rows = sorted(rows, key=lambda r: r.get("vouch_count", 0), reverse=True)
    return ReportList(reports=[_to_out(r, current_user.id) for r in rows], total=len(rows))


@router.post("/{report_id}/upload-media")
async def upload_report_media(
    report_id: str,
    file: UploadFile = File(...),
    current_user: UserOut = Depends(get_current_user),
) -> dict:
    """Upload a photo for a community report. Stores in Supabase Storage."""
    row = report_db.get_report(report_id)
    if not row:
        raise HTTPException(status_code=404, detail="Report not found")
    if row["user_id"] != current_user.id:
        raise HTTPException(status_code=403, detail="Not your report")

    allowed_types = {"image/jpeg", "image/png", "image/webp", "image/gif"}
    content_type = file.content_type or "image/jpeg"
    if content_type not in allowed_types:
        raise HTTPException(status_code=422, detail="Only JPEG, PNG, WebP, or GIF images allowed")

    from app.db.supabase_client import get_storage_client
    sb = get_storage_client()
    ext = (file.filename or "photo.jpg").rsplit(".", 1)[-1].lower()
    path = f"{report_id}/{uuid_module.uuid4()}.{ext}"
    content = await file.read()

    try:
        sb.storage.from_("report-media").upload(
            path, content, {"content-type": content_type, "upsert": "true"}
        )
        public_url = sb.storage.from_("report-media").get_public_url(path)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Storage upload failed: {exc}")

    report_db.update_report_media(report_id, public_url)
    return {"media_url": public_url, "report_id": report_id}


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
