"""Pydantic schemas for family groups and safety check-in."""

from __future__ import annotations

from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field, field_validator


class FamilySafetyStatus(str, Enum):
    unknown    = "unknown"
    safe       = "safe"
    needs_help = "needs_help"   # stored as needs_help in DB; displayed as DANGER in UI


# ── Family Groups ─────────────────────────────────────────────────────────────

class FamilyMemberIn(BaseModel):
    name:         str = Field(..., min_length=1, max_length=200)
    phone_number: str = Field(default="", max_length=20)
    relationship: str = Field(default="", max_length=50)


class FamilyGroupCreate(BaseModel):
    name:    str                  = Field(default="My Family", max_length=100)
    members: list[FamilyMemberIn] = Field(default_factory=list)

    @field_validator('members')
    @classmethod
    def at_least_one_member(cls, v: list) -> list:
        if len(v) < 1:
            raise ValueError('At least one member is required to create a family group.')
        return v


class FamilyGroupRename(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)


class FamilyMemberOut(BaseModel):
    id:            str
    group_id:      str
    name:          str
    phone_number:  str
    relationship:  str
    safety_status: str
    last_updated:  datetime


class FamilyGroupOut(BaseModel):
    id:             str
    leader_user_id: str
    name:           str
    members:        list[FamilyMemberOut]
    created_at:     datetime


# ── Status Update ─────────────────────────────────────────────────────────────

class FamilyCheckin(BaseModel):
    member_id: str
    status:    FamilySafetyStatus
    source:    str = Field(default="app", max_length=20)  # "app" | "sms"


class FamilyCheckinOut(BaseModel):
    member_id:     str
    safety_status: str
    last_updated:  datetime
    leader_notified: bool = False


# ── Member Update ─────────────────────────────────────────────────────────────

class FamilyMemberUpdate(BaseModel):
    name:         str | None = Field(default=None, min_length=1, max_length=200)
    phone_number: str | None = Field(default=None, max_length=20)
    relationship: str | None = Field(default=None, max_length=50)

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
