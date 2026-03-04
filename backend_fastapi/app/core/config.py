"""Application configuration loaded from environment variables."""

import os
from pathlib import Path

from dotenv import load_dotenv

# Load .env from the backend_fastapi directory
_env_path = Path(__file__).resolve().parents[2] / ".env"
load_dotenv(_env_path)

# ── Supabase ─────────────────────────────────────────────────────────────────
# Set these in your shell or in a .env file before running the server.
#   SUPABASE_URL=https://<project-ref>.supabase.co
#   SUPABASE_KEY=<service_role key for backend operations>

SUPABASE_URL: str = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY: str = os.getenv("SUPABASE_KEY", "")
