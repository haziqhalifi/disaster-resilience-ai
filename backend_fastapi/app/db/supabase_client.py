"""Supabase client factory.

Three isolated clients are exposed:

  get_client()          — General-purpose LRU-cached service-role client.
                          Used by report DB, user DB, and other modules.

  get_admin_db_client() — Separate LRU-cached service-role client ONLY for
                          admin_users table operations.  Keeps admin auth
                          permanently isolated from any auth state mutations.

  get_storage_client()  — Separate LRU-cached client for Supabase Storage.

  get_auth_client()     — Returns a FRESH (non-cached) client for every call.
                          Used exclusively by the /auth/signup and /auth/signin
                          endpoints that call sign_in_with_password().

WHY SEPARATE CLIENTS?
  supabase-py v2 stores session state inside the client object. Calling
  sb.auth.sign_in_with_password() overwrites the internal Authorization header
  with the user's JWT, stripping the service-role key.  Any DB operation on
  that same client then runs as the user (with RLS restrictions) rather than
  the service role (which bypasses RLS).  By routing sign-in calls through a
  throw-away get_auth_client() we ensure the LRU-cached clients always retain
  the service-role key and can INSERT/UPDATE admin_users without RLS errors.
"""

from __future__ import annotations

import os
from functools import lru_cache
from pathlib import Path

from dotenv import load_dotenv
from supabase import Client, ClientOptions, create_client

_env_path = Path(__file__).resolve().parents[3] / ".env"
load_dotenv(_env_path, override=True)


def _make_service_client() -> Client:
    """Create a brand-new Supabase client using the service-role key."""
    url = os.getenv("SUPABASE_URL", "")
    key = os.getenv("SUPABASE_KEY", "")
    if not url or not key:
        raise ValueError(
            "SUPABASE_URL and SUPABASE_KEY must be set in backend_fastapi/.env"
        )
    options = ClientOptions(auto_refresh_token=False, persist_session=False)
    return create_client(url, key, options=options)


# ── Cached clients (long-lived, never used for sign_in_with_password) ─────────

@lru_cache(maxsize=1)
def get_client() -> Client:
    """General-purpose cached service-role client (reports, users, etc.)."""
    return _make_service_client()


@lru_cache(maxsize=1)
def get_admin_db_client() -> Client:
    """Dedicated cached client for admin_users table operations only.

    Kept permanently separate so that even if get_client() were somehow
    contaminated in a future code change, admin registration and login
    would continue to work correctly.
    """
    return _make_service_client()


@lru_cache(maxsize=1)
def get_storage_client() -> Client:
    """Dedicated cached client for Supabase Storage uploads."""
    return _make_service_client()


# ── Non-cached auth client ─────────────────────────────────────────────────────

def get_auth_client() -> Client:
    """Return a FRESH Supabase client for every call.

    Must be used whenever sign_in_with_password() is called.  Each invocation
    gets its own client object so session mutations never affect the shared
    cached clients above.
    """
    return _make_service_client()
