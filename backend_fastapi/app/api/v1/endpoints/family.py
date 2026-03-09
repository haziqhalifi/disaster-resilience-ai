"""Family linking endpoints for real-time location sharing."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status

from app.api.v1.dependencies import get_current_user
from app.db import family as family_db
from app.schemas.family import (
    FamilyInviteCreate,
    FamilyInviteListOut,
    FamilyInviteOut,
    FamilyInviteRespond,
    FamilyMemberLocationOut,
    FamilyMemberLocationListOut,
)
from app.schemas.user import UserOut

router = APIRouter()


@router.post(
    "/invite",
    response_model=FamilyInviteOut,
    status_code=status.HTTP_201_CREATED,
    summary="Invite a family member by username or email",
)
async def invite_family_member(
    body: FamilyInviteCreate,
    current_user: UserOut = Depends(get_current_user),
) -> FamilyInviteOut:
    try:
        rec = family_db.create_invite(current_user.id, body.identifier)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    return FamilyInviteOut(**rec)


@router.get(
    "/invites",
    response_model=FamilyInviteListOut,
    summary="Get pending family invites for current user",
)
async def list_pending_invites(
    current_user: UserOut = Depends(get_current_user),
) -> FamilyInviteListOut:
    invites = family_db.list_pending_for_user(current_user.id)
    return FamilyInviteListOut(count=len(invites), invites=[FamilyInviteOut(**x) for x in invites])


@router.post(
    "/invites/{invite_id}/respond",
    response_model=FamilyInviteOut,
    summary="Accept or reject a family invite",
)
async def respond_family_invite(
    invite_id: str,
    body: FamilyInviteRespond,
    current_user: UserOut = Depends(get_current_user),
) -> FamilyInviteOut:
    try:
        rec = family_db.respond_invite(current_user.id, invite_id, body.accept)
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    return FamilyInviteOut(**rec)


@router.get(
    "/members/locations",
    response_model=FamilyMemberLocationListOut,
    summary="Get accepted family members with latest known location",
)
async def get_family_member_locations(
    current_user: UserOut = Depends(get_current_user),
) -> FamilyMemberLocationListOut:
    members = family_db.list_family_locations(current_user.id)
    return FamilyMemberLocationListOut(
        count=len(members),
        members=[FamilyMemberLocationOut(**m) for m in members],
    )
