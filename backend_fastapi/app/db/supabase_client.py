"""Supabase client singleton.

Usage:
    from app.db.supabase_client import get_client
    sb = get_client()
    sb.table("users").select("*").execute()
"""

from __future__ import annotations

from functools import lru_cache

from supabase import Client, create_client

from app.core.config import SUPABASE_KEY, SUPABASE_URL


@lru_cache(maxsize=1)
def get_client() -> Client:
    """Return a cached Supabase client instance.

    Raises ``ValueError`` at startup if the env vars are missing —
    fail-fast so the developer knows configuration is incomplete.
    """
    if not SUPABASE_URL or not SUPABASE_KEY:
        raise ValueError(
            "SUPABASE_URL and SUPABASE_KEY environment variables must be set. "
            "See app/core/config.py for details."
        )
    return create_client(SUPABASE_URL, SUPABASE_KEY)
