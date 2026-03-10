"""Family group and safety status endpoints."""
"""Family linking endpoints for real-time location sharing."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status

from app.api.v1.dependencies import get_current_user
from app.db import family as family_db
from app.schemas.family import (
    FamilyCheckin, FamilyCheckinOut,
    FamilyGroupCreate, FamilyGroupOut, FamilyGroupRename,
    FamilyMemberOut, FamilyMemberUpdate,
    FamilyInviteCreate,
    FamilyInviteListOut,
    FamilyInviteOut,
    FamilyInviteRespond,
    FamilyMemberLocationOut,
    FamilyMemberLocationListOut,
)
from app.schemas.user import UserOut

router = APIRouter()


def _member_out(row: dict) -> FamilyMemberOut:
    return FamilyMemberOut(
        id=row["id"],
        group_id=row["group_id"],
        name=row["name"],
        phone_number=row.get("phone_number", ""),
        relationship=row.get("relationship", ""),
        safety_status=row["safety_status"],
        last_updated=row["last_updated"],
    )


def _group_out(group: dict) -> FamilyGroupOut:
    members = family_db.get_family_members(group["id"])
    return FamilyGroupOut(
        id=group["id"],
        leader_user_id=group["leader_user_id"],
        name=group["name"],
        members=[_member_out(m) for m in members],
        created_at=group["created_at"],
    )


# ── Groups ────────────────────────────────────────────────────────────────────

@router.post("/groups", response_model=FamilyGroupOut, status_code=status.HTTP_201_CREATED)
async def create_group(
    body: FamilyGroupCreate,
    current_user: UserOut = Depends(get_current_user),
) -> FamilyGroupOut:
    """Create a family group. Requires at least one member."""
    # Validation is handled by FamilyGroupCreate.at_least_one_member validator
    group = family_db.create_family_group(leader_user_id=current_user.id, name=body.name)
    for m in body.members:
        family_db.add_family_member(
            group_id=group["id"], name=m.name,
            phone_number=m.phone_number, relationship=m.relationship,
        )
    return _group_out(group)


@router.get("/groups", response_model=list[FamilyGroupOut])
async def my_groups(current_user: UserOut = Depends(get_current_user)) -> list[FamilyGroupOut]:
    groups = family_db.get_groups_by_leader(current_user.id)
    return [_group_out(g) for g in groups]


@router.get("/groups/{group_id}", response_model=FamilyGroupOut)
async def get_group(group_id: str, current_user: UserOut = Depends(get_current_user)) -> FamilyGroupOut:
    group = family_db.get_family_group(group_id)
    if not group:
        raise HTTPException(status_code=404, detail="Family group not found")
    return _group_out(group)


@router.patch("/groups/{group_id}/rename", response_model=FamilyGroupOut)
async def rename_group(
    group_id: str,
    body: FamilyGroupRename,
    current_user: UserOut = Depends(get_current_user),
) -> FamilyGroupOut:
    """Rename a family group. Only the group leader can rename."""
    group = family_db.get_family_group(group_id)
    if not group:
        raise HTTPException(status_code=404, detail="Family group not found")
    if group["leader_user_id"] != current_user.id:
        raise HTTPException(status_code=403, detail="Only the group leader can rename this group")
    updated = family_db.rename_family_group(group_id, name=body.name)
    if not updated:
        raise HTTPException(status_code=500, detail="Failed to rename group")
    return _group_out(updated)


@router.delete("/groups/{group_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_group(
    group_id: str,
    current_user: UserOut = Depends(get_current_user),
) -> None:
    """Delete a family group and all its members. Only the group leader can delete."""
    group = family_db.get_family_group(group_id)
    if not group:
        raise HTTPException(status_code=404, detail="Family group not found")
    if group["leader_user_id"] != current_user.id:
        raise HTTPException(status_code=403, detail="Only the group leader can delete this group")
    family_db.delete_family_group(group_id)


# ── Members ───────────────────────────────────────────────────────────────────

@router.post("/members", response_model=FamilyMemberOut, status_code=status.HTTP_201_CREATED)
async def add_member(
    group_id: str,
    body: FamilyMemberUpdate,
    current_user: UserOut = Depends(get_current_user),
) -> FamilyMemberOut:
    group = family_db.get_family_group(group_id)
    if not group or group["leader_user_id"] != current_user.id:
        raise HTTPException(status_code=403, detail="Not your family group")
    row = family_db.add_family_member(
        group_id=group_id,
        name=body.name or "",
        phone_number=body.phone_number or "",
        relationship=body.relationship or "",
    )
    return _member_out(row)


@router.patch("/members/{member_id}", response_model=FamilyMemberOut)
async def update_member(
    member_id: str,
    body: FamilyMemberUpdate,
    current_user: UserOut = Depends(get_current_user),
) -> FamilyMemberOut:
    member = family_db.get_family_member(member_id)
    if not member:
        raise HTTPException(status_code=404, detail="Family member not found")
    updated = family_db.update_member_info(
        member_id,
        name=body.name,
        phone_number=body.phone_number,
        relationship=body.relationship,
    )
    return _member_out(updated)


@router.delete("/members/{member_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_member(member_id: str, current_user: UserOut = Depends(get_current_user)) -> None:
    family_db.delete_family_member(member_id)


# ── Check-in ──────────────────────────────────────────────────────────────────

@router.post("/checkin", response_model=FamilyCheckinOut)
async def family_checkin(
    body: FamilyCheckin,
    current_user: UserOut = Depends(get_current_user),
) -> FamilyCheckinOut:
    member = family_db.get_family_member(body.member_id)
    if not member:
        raise HTTPException(status_code=404, detail="Family member not found")

    updated = family_db.update_member_status(body.member_id, safety_status=body.status.value)

    leader_notified = False
    try:
        group = family_db.get_family_group(member["group_id"])
        if group:
            from app.services.notifications import _send_push
            from app.db.devices import get_device
            leader_device = get_device(group["leader_user_id"])
            if leader_device and leader_device.get("fcm_token"):
                status_label = body.status.value.replace("needs_help", "DANGER").upper()
                msg = f"{member['name']} status: {status_label}"
                _send_push(leader_device["fcm_token"], "Family Safety Update", msg, {"type": "family_checkin"})
                leader_notified = True
    except Exception:
        pass

    return FamilyCheckinOut(
        member_id=body.member_id,
        safety_status=updated["safety_status"],
        last_updated=updated["last_updated"],
        leader_notified=leader_notified,
    )


@router.get("/status", response_model=list[FamilyMemberOut])
async def get_family_status(current_user: UserOut = Depends(get_current_user)) -> list[FamilyMemberOut]:
    groups = family_db.get_groups_by_leader(current_user.id)
    all_members: list[FamilyMemberOut] = []
    for group in groups:
        members = family_db.get_family_members(group["id"])
        all_members.extend([_member_out(m) for m in members])
    return all_members
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
