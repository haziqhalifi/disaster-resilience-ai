"""Family relationship store backed by Supabase table ``family_links``."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, TypedDict, cast
from uuid import uuid4

from app.db.supabase_client import get_client
from app.db import users as user_db


class FamilyInviteRecord(TypedDict):
    id: str
    requester_id: str
    requester_username: str
    requester_email: str
    addressee_id: str
    addressee_username: str
    addressee_email: str
    status: str
    created_at: datetime | None
    responded_at: datetime | None


class FamilyMemberLocationRecord(TypedDict):
    user_id: str
    username: str
    email: str
    latitude: float | None
    longitude: float | None
    updated_at: datetime | None


def _normalize_identifier(identifier: str) -> str:
    return identifier.strip().lower()


def _lookup_user_by_identifier(identifier: str) -> user_db.UserRecord | None:
    normalized = _normalize_identifier(identifier)
    if "@" in normalized:
        return user_db.get_user_by_email(normalized)
    return user_db.get_user_by_username(normalized)


def _links_for_user(user_id: str) -> list[dict[str, Any]]:
    sb = get_client()
    res = (
        sb.table("family_links")
        .select("*")
        .or_(f"requester_id.eq.{user_id},addressee_id.eq.{user_id}")
        .execute()
    )
    return cast(list[dict[str, Any]], res.data or [])


def create_invite(requester_id: str, identifier: str) -> FamilyInviteRecord:
    target_user = _lookup_user_by_identifier(identifier)
    if target_user is None:
        raise ValueError("User not found for this username/email.")

    addressee_id = target_user["id"]
    if addressee_id == requester_id:
        raise ValueError("You cannot add yourself as a family member.")

    links = _links_for_user(requester_id)
    for link in links:
        same_pair = {
            link["requester_id"],
            link["addressee_id"],
        } == {requester_id, addressee_id}
        if same_pair and link["status"] in {"pending", "accepted"}:
            raise ValueError("Family link already exists or is pending.")

    row: dict[str, Any] = {
        "id": str(uuid4()),
        "requester_id": requester_id,
        "addressee_id": addressee_id,
        "status": "pending",
        "created_at": datetime.now(timezone.utc).isoformat(),
        "responded_at": None,
    }
    sb = get_client()
    insert_res = sb.table("family_links").insert(row).execute()
    inserted_rows = cast(list[dict[str, Any]], insert_res.data or [])
    return _hydrate_invite(inserted_rows[0])


def list_pending_for_user(user_id: str) -> list[FamilyInviteRecord]:
    sb = get_client()
    res = (
        sb.table("family_links")
        .select("*")
        .eq("addressee_id", user_id)
        .eq("status", "pending")
        .order("created_at", desc=True)
        .execute()
    )
    rows = cast(list[dict[str, Any]], res.data or [])
    return [_hydrate_invite(row) for row in rows]


def respond_invite(user_id: str, invite_id: str, accept: bool) -> FamilyInviteRecord:
    sb = get_client()
    existing = (
        sb.table("family_links")
        .select("*")
        .eq("id", invite_id)
        .limit(1)
        .execute()
    )
    if not existing.data:
        raise ValueError("Invite not found.")

    existing_rows = cast(list[dict[str, Any]], existing.data or [])
    row = existing_rows[0]
    if row["addressee_id"] != user_id:
        raise PermissionError("You are not allowed to respond to this invite.")
    if row["status"] != "pending":
        raise ValueError("Invite was already processed.")

    updated = (
        sb.table("family_links")
        .update(
            {
                "status": "accepted" if accept else "rejected",
                "responded_at": datetime.now(timezone.utc).isoformat(),
            }
        )
        .eq("id", invite_id)
        .execute()
    )
    updated_rows = cast(list[dict[str, Any]], updated.data or [])
    return _hydrate_invite(updated_rows[0])


def list_family_locations(user_id: str) -> list[FamilyMemberLocationRecord]:
    links = [row for row in _links_for_user(user_id) if row["status"] == "accepted"]
    member_ids: list[str] = []
    for link in links:
        member_ids.append(
            link["addressee_id"] if link["requester_id"] == user_id else link["requester_id"]
        )

    if not member_ids:
        return []

    sb = get_client()
    users_res = (
        sb.table("users")
        .select("id, username, email")
        .in_("id", member_ids)
        .execute()
    )
    devices_res = (
        sb.table("devices")
        .select("user_id, latitude, longitude, updated_at")
        .in_("user_id", member_ids)
        .execute()
    )

    user_rows = cast(list[dict[str, Any]], users_res.data or [])
    device_rows = cast(list[dict[str, Any]], devices_res.data or [])

    user_map: dict[str, dict[str, Any]] = {str(u["id"]): u for u in user_rows}
    device_map: dict[str, dict[str, Any]] = {
        str(d["user_id"]): d for d in device_rows
    }

    out: list[FamilyMemberLocationRecord] = []
    for member_id in member_ids:
        user = user_map.get(member_id)
        if user is None:
            continue
        device = device_map.get(member_id, {})
        out.append(
            {
                "user_id": member_id,
                "username": user["username"],
                "email": user["email"],
                "latitude": device.get("latitude"),
                "longitude": device.get("longitude"),
                "updated_at": device.get("updated_at"),
            }
        )

    out.sort(key=lambda rec: rec["username"])
    return out


def _hydrate_invite(link_row: dict[str, Any]) -> FamilyInviteRecord:
    requester = user_db.get_user_by_id(link_row["requester_id"])
    addressee = user_db.get_user_by_id(link_row["addressee_id"])

    if requester is None or addressee is None:
        raise ValueError("Invite references unknown user.")

    return {
        "id": link_row["id"],
        "requester_id": requester["id"],
        "requester_username": requester["username"],
        "requester_email": requester["email"],
        "addressee_id": addressee["id"],
        "addressee_username": addressee["username"],
        "addressee_email": addressee["email"],
        "status": link_row["status"],
        "created_at": link_row.get("created_at"),
        "responded_at": link_row.get("responded_at"),
    }
