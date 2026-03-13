"""Pydantic schemas for user authentication endpoints."""

from pydantic import BaseModel, EmailStr, Field


# ── Sign-Up ──────────────────────────────────────────────────────────────────

class UserSignUp(BaseModel):
    """Request body for POST /auth/signup."""

    username: str = Field(..., min_length=3, max_length=50, description="Unique username.")
    email: EmailStr = Field(..., description="Valid email address.")
    password: str = Field(..., min_length=6, description="Password (min 6 characters).")


# ── Sign-In ───────────────────────────────────────────────────────────────────

class UserSignIn(BaseModel):
    """Request body for POST /auth/signin."""

    email: EmailStr = Field(..., description="Registered email address.")
    password: str = Field(..., description="Account password.")


# ── Responses ────────────────────────────────────────────────────────────────

class UserOut(BaseModel):
    """Public user data returned in responses (never exposes hashed password)."""

    id: str
    username: str
    email: EmailStr


class Token(BaseModel):
    """JWT token response returned after successful sign-in or sign-up."""

    access_token: str
    refresh_token: str | None = None
    token_type: str = "bearer"
    user: UserOut
