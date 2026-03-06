"""User Profile endpoints."""

from __future__ import annotations
from fastapi import APIRouter, Depends, HTTPException, status
from app.api.v1.dependencies import get_current_user
from app.schemas.profile import UserProfileOut, UserProfileUpdate
from app.schemas.user import UserOut
from app.db import profiles as prof_db

router = APIRouter()

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
