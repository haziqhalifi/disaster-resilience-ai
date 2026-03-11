"""Supabase client singleton using the service-role key.

The service-role key bypasses Row Level Security and is safe to use
server-side.  We cache one client per process lifetime; the JWT embedded
in a legacy service-role key does not expire for many years.

Usage:
    from app.db.supabase_client import get_client
    sb = get_client()
    sb.table("users").select("*").execute()
"""

from __future__ import annotations

import os
from functools import lru_cache
from pathlib import Path

from dotenv import load_dotenv
from supabase import Client, ClientOptions, create_client

# Always re-read the .env so that a hot-reload (uvicorn --reload) picks up
# any key changes without requiring a full process restart.
# backend_fastapi/app/db/supabase_client.py -> parents[2] == backend_fastapi
_env_path = Path(__file__).resolve().parents[2] / ".env"
load_dotenv(_env_path, override=True)


@lru_cache(maxsize=1)
def get_client() -> Client:
    """Return a cached Supabase client using the service-role key.

    Raises ``ValueError`` at startup if the env vars are missing —
    fail-fast so the developer knows configuration is incomplete.
    """
    url = os.getenv("SUPABASE_URL", "")
    key = os.getenv("SUPABASE_KEY", "")

    if not url or not key:
        raise ValueError(
            "SUPABASE_URL and SUPABASE_KEY environment variables must be set. "
            "See backend_fastapi/.env for details."
        )

    # Disable local session persistence — this is a server-side service client,
    # not a browser client. Persisting sessions can cause stale-JWT errors in
    # background scheduler jobs.
    options = ClientOptions(
        auto_refresh_token=False,
        persist_session=False,
    )
    return create_client(url, key, options=options)
