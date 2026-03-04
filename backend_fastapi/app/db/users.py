"""User profile store backed by Supabase table ``users``.

Authentication is handled by Supabase Auth. This module stores only public
profile metadata (id/username/email) keyed by the Supabase Auth user id.
"""

from __future__ import annotations

import uuid
from typing import TypedDict

from app.db.supabase_client import get_client


class UserRecord(TypedDict):
    id: str
    username: str
    email: str


# ── CRUD helpers ──────────────────────────────────────────────────────────────

def get_user_by_email(email: str) -> UserRecord | None:
    sb = get_client()
    res = (
        sb.table("users")
        .select("id, username, email")
        .eq("email", email.lower())
        .limit(1)
        .execute()
    )
    if res.data:
        return res.data[0]
    return None


def get_user_by_username(username: str) -> UserRecord | None:
    sb = get_client()
    res = (
        sb.table("users")
        .select("id, username, email")
        .eq("username", username.lower())
        .limit(1)
        .execute()
    )
    if res.data:
        return res.data[0]
    return None


def get_user_by_id(user_id: str) -> UserRecord | None:
    sb = get_client()
    res = (
        sb.table("users")
        .select("id, username, email")
        .eq("id", user_id)
        .limit(1)
        .execute()
    )
    if res.data:
        return res.data[0]
    return None


def create_user_profile(user_id: str, username: str, email: str) -> UserRecord:
    """Insert a new profile row and return it."""
    sb = get_client()
    row = {
        "id": str(uuid.UUID(user_id)),
        "username": username.lower(),
        "email": email.lower(),
    }
    try:
        res = sb.table("users").insert(row).execute()
    except Exception as exc:
        msg = str(exc).lower()
        if "hashed_password" in msg:
            legacy_row = {
                **row,
                "hashed_password": "managed-by-supabase-auth",
            }
            res = sb.table("users").insert(legacy_row).execute()
        else:
            raise
    return res.data[0]
