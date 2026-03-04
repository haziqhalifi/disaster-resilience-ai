"""In-memory user store.

NOTE: Data is lost on server restart.
      Replace with a real database (e.g. SQLAlchemy + PostgreSQL/SQLite)
      for any production deployment.
"""

import uuid
from typing import TypedDict


class UserRecord(TypedDict):
    id: str
    username: str
    email: str
    hashed_password: str


# Keyed by email (lower-cased) for O(1) look-ups during sign-in.
_users_by_email: dict[str, UserRecord] = {}

# Secondary index keyed by username for uniqueness checks.
_users_by_username: dict[str, UserRecord] = {}


# ── CRUD helpers ──────────────────────────────────────────────────────────────

def get_user_by_email(email: str) -> UserRecord | None:
    return _users_by_email.get(email.lower())


def get_user_by_username(username: str) -> UserRecord | None:
    return _users_by_username.get(username.lower())


def create_user(username: str, email: str, hashed_password: str) -> UserRecord:
    """Insert a new user record and return it."""
    record: UserRecord = {
        "id": str(uuid.uuid4()),
        "username": username,
        "email": email.lower(),
        "hashed_password": hashed_password,
    }
    _users_by_email[record["email"]] = record
    _users_by_username[username.lower()] = record
    return record
