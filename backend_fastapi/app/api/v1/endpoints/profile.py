"""User Profile endpoints."""

from __future__ import annotations
import logging
import os
import uuid

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from app.api.v1.dependencies import get_current_user
from app.db.supabase_client import get_client
from app.schemas.profile import ProfilePhotoUploadOut, UserProfileOut, UserProfileUpdate
from app.schemas.user import UserOut
from app.db import profiles as prof_db

router = APIRouter()
logger = logging.getLogger(__name__)

_PROFILE_PHOTO_BUCKET = os.getenv("SUPABASE_PROFILE_PHOTO_BUCKET", "report-media")
_ALLOWED_IMAGE_TYPES = {
    "image/jpeg",
    "image/png",
    "image/webp",
}
_MAX_UPLOAD_BYTES = 5 * 1024 * 1024

@router.get("/me", response_model=UserProfileOut)
async def get_my_profile(current_user: UserOut = Depends(get_current_user)):
    profile = prof_db.get_profile(current_user.id)
    if not profile:
        # Return empty profile if not initialized
        return UserProfileOut(user_id=current_user.id)
    return UserProfileOut(**profile)

@router.put("/me", response_model=UserProfileOut)
async def update_my_profile(
    body: UserProfileUpdate,
    current_user: UserOut = Depends(get_current_user)
):
    update_data = body.model_dump(exclude_unset=True)
    profile = prof_db.update_or_create_profile(current_user.id, update_data)
    return UserProfileOut(**profile)


@router.post("/me/photo/upload", response_model=ProfilePhotoUploadOut, status_code=status.HTTP_201_CREATED)
async def upload_my_profile_photo(
    file: UploadFile = File(...),
    current_user: UserOut = Depends(get_current_user),
) -> ProfilePhotoUploadOut:
    if file.content_type not in _ALLOWED_IMAGE_TYPES:
        raise HTTPException(status_code=415, detail="Unsupported image type")

    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="Empty file")
    if len(data) > _MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="File too large (max 5MB)")

    filename = file.filename or "profile-photo"
    lower_name = filename.lower()
    suffix = f".{lower_name.rsplit('.', 1)[-1]}" if "." in lower_name else ".jpg"
    safe_name = f"{uuid.uuid4().hex}{suffix}"
    storage_path = f"profiles/{current_user.id}/{safe_name}"

    sb = get_client()
    try:
        sb.storage.from_(_PROFILE_PHOTO_BUCKET).upload(
            storage_path,
            data,
            {
                "content-type": file.content_type,
                "upsert": "false",
            },
        )
    except Exception as exc:
        logger.error("Supabase Storage upload failed for %s: %s", storage_path, exc)
        raise HTTPException(status_code=500, detail="Failed to upload profile photo") from exc

    public_url = sb.storage.from_(_PROFILE_PHOTO_BUCKET).get_public_url(storage_path)
    if isinstance(public_url, dict):
        nested_obj = public_url.get("data")
        nested = nested_obj if isinstance(nested_obj, dict) else {}
        image_url = (
            public_url.get("publicURL")
            or public_url.get("publicUrl")
            or nested.get("publicURL")
            or nested.get("publicUrl")
            or ""
        )
    else:
        image_url = str(public_url or "")
    if not image_url:
        raise HTTPException(status_code=500, detail="Failed to generate profile photo URL")

    prof_db.update_or_create_profile(current_user.id, {"profile_photo_url": image_url})
    return ProfilePhotoUploadOut(url=image_url)
