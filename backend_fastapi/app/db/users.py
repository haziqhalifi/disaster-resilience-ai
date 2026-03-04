"""User store backed by Supabase (table: ``users``).

Expected table schema — run the SQL migration in ``docs/supabase_migrations.sql``.
"""

from __future__ import annotations

import uuid
from typing import TypedDict

from app.db.supabase_client import get_client


class UserRecord(TypedDict):
    id: str
    username: str
    email: str
    hashed_password: str


# ── CRUD helpers ──────────────────────────────────────────────────────────────

def get_user_by_email(email: str) -> UserRecord | None:
    sb = get_client()
    res = (
        sb.table("users")
        .select("id, username, email, hashed_password")
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
        .select("id, username, email, hashed_password")
        .eq("username", username.lower())
        .limit(1)
        .execute()
    )
    if res.data:
        return res.data[0]
    return None


def create_user(username: str, email: str, hashed_password: str) -> UserRecord:
    """Insert a new user row and return it."""
    sb = get_client()
    row = {
        "id": str(uuid.uuid4()),
        "username": username,
        "email": email.lower(),
        "hashed_password": hashed_password,
    }
    res = sb.table("users").insert(row).execute()
    return res.data[0]
