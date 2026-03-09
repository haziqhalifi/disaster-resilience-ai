"""Pydantic schemas for family linking and shared live locations."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field


class FamilyInviteCreate(BaseModel):
    """Request body to invite a family member by username or email."""

    identifier: str = Field(
        ...,
        min_length=3,
        max_length=120,
        description="Target username or email to invite.",
    )


class FamilyInviteRespond(BaseModel):
    """Request body to accept or reject a family invite."""

    accept: bool = Field(..., description="True to accept, false to reject.")


class FamilyInviteOut(BaseModel):
    """Family invite item returned by the API."""

    id: str
    requester_id: str
    requester_username: str
    requester_email: str
    addressee_id: str
    addressee_username: str
    addressee_email: str
    status: str
    created_at: datetime | None = None
    responded_at: datetime | None = None


class FamilyMemberLocationOut(BaseModel):
    """Accepted family member with latest known location."""

    user_id: str
    username: str
    email: str
    latitude: float | None = None
    longitude: float | None = None
    updated_at: datetime | None = None


class FamilyInviteListOut(BaseModel):
    count: int
    invites: list[FamilyInviteOut]


class FamilyMemberLocationListOut(BaseModel):
    count: int
    members: list[FamilyMemberLocationOut]
