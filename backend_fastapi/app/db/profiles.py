"""User profile CRUD operations."""

from __future__ import annotations
from typing import TypedDict, Optional
from app.db.supabase_client import get_client

class UserProfileRecord(TypedDict):
    user_id: str
    full_name: Optional[str]
    phone_number: Optional[str]
    blood_type: Optional[str]
    allergies: str
    medical_conditions: str
    emergency_contact_name: Optional[str]
    emergency_contact_relationship: Optional[str]
    emergency_contact_phone: Optional[str]

def get_profile(user_id: str) -> UserProfileRecord | None:
    sb = get_client()
    res = sb.table("user_profiles").select("*").eq("user_id", user_id).limit(1).execute()
    return res.data[0] if res.data else None

def update_or_create_profile(user_id: str, data: dict) -> UserProfileRecord:
    sb = get_client()
    # Check if exists
    existing = get_profile(user_id)
    if existing:
        res = sb.table("user_profiles").update(data).eq("user_id", user_id).execute()
    else:
        row = {"user_id": user_id, **data}
        res = sb.table("user_profiles").insert(row).execute()
    return res.data[0]
