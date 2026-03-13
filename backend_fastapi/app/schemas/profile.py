"""Pydantic schemas for User Profile and Emergency Info."""

from __future__ import annotations
from pydantic import BaseModel, Field
from typing import Optional

class UserProfileUpdate(BaseModel):
    full_name: Optional[str] = Field(None, max_length=100)
    phone_number: Optional[str] = Field(None, max_length=20)
    blood_type: Optional[str] = Field(None, pattern=r"^(A|B|AB|O)[+-]$")
    profile_photo_url: Optional[str] = Field(None, max_length=500)
    allergies: Optional[str] = ""
    medical_conditions: Optional[str] = ""
    emergency_contact_name: Optional[str] = Field(None, max_length=100)
    emergency_contact_relationship: Optional[str] = Field(None, max_length=50)
    emergency_contact_phone: Optional[str] = Field(None, max_length=20)


class ProfilePhotoUploadOut(BaseModel):
    url: str

class UserProfileOut(BaseModel):
    user_id: str
    full_name: Optional[str] = None
    phone_number: Optional[str] = None
    blood_type: Optional[str] = None
    profile_photo_url: Optional[str] = None
    allergies: str = ""
    medical_conditions: str = ""
    emergency_contact_name: Optional[str] = None
    emergency_contact_relationship: Optional[str] = None
    emergency_contact_phone: Optional[str] = None
