"""Application configuration loaded from environment variables."""

import os
from pathlib import Path

from dotenv import load_dotenv

# Load .env from the backend_fastapi directory
_env_path = Path(__file__).resolve().parents[2] / ".env"
load_dotenv(_env_path)

# ── Supabase ──────────────────────────────────────────────────────────────────
SUPABASE_URL: str = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY: str = os.getenv("SUPABASE_KEY", "")

# ── Twilio SMS (legacy — kept for fallback) ───────────────────────────────────
TWILIO_ACCOUNT_SID: str = os.getenv("TWILIO_ACCOUNT_SID", "")
TWILIO_AUTH_TOKEN: str = os.getenv("TWILIO_AUTH_TOKEN", "")
# Support both TWILIO_PHONE_NUMBER and TWILIO_FROM_NUMBER (legacy)
TWILIO_PHONE_NUMBER: str = os.getenv("TWILIO_PHONE_NUMBER") or os.getenv("TWILIO_FROM_NUMBER", "")

# ── SMS Provider Switch ───────────────────────────────────────────────────────
# Set SMS_PROVIDER to: mocean | vonage | easysendsms
SMS_PROVIDER:         str = os.getenv("SMS_PROVIDER", "mocean")

# MoceanAPI
MOCEAN_API_KEY:       str = os.getenv("MOCEAN_API_KEY", "")
MOCEAN_API_SECRET:    str = os.getenv("MOCEAN_API_SECRET", "")

# Vonage
VONAGE_API_KEY:       str = os.getenv("VONAGE_API_KEY", "")
VONAGE_API_SECRET:    str = os.getenv("VONAGE_API_SECRET", "")

# EasySendSMS
EASYSENDSMS_USERNAME: str = os.getenv("EASYSENDSMS_USERNAME", "")
EASYSENDSMS_PASSWORD: str = os.getenv("EASYSENDSMS_PASSWORD", "")
EASYSENDSMS_API_KEY:  str = os.getenv("EASYSENDSMS_API_KEY", "")

# ── Demo / Testing override ───────────────────────────────────────────────────
# When set, ALL outgoing SMS is redirected to this single number regardless of
# who is actually in the affected area. Use for local demo testing only.
# Format: E.164 without '+', e.g. 60175815030 for Malaysian number 0175815030
DEMO_PHONE: str = os.getenv("DEMO_PHONE", "")

# When True, each broadcast sends at most ONE SMS (to the first eligible recipient
# or DEMO_PHONE). Set SMS_DEMO_MODE=false in .env to broadcast to all users.
SMS_DEMO_MODE: bool = os.getenv("SMS_DEMO_MODE", "true").lower() not in ("false", "0", "no")

# ── Anthropic / Claude AI ─────────────────────────────────────────────────────
ANTHROPIC_API_KEY: str = os.getenv("ANTHROPIC_API_KEY", "")


# ── Admin Website (simple hardcoded credentials) ─────────────────────────────
# Override these in .env for production
ADMIN_USERNAME: str = os.getenv("ADMIN_USERNAME", "admin")
ADMIN_PASSWORD: str = os.getenv("ADMIN_PASSWORD", "changeme123")
ADMIN_JWT_SECRET: str = os.getenv("ADMIN_JWT_SECRET", "admin-secret-key-change-in-production")

# ── NADMA MyDIMS Official Disaster Feed ─────────────────────────────────────
NADMA_DISASTERS_API_URL: str = os.getenv(
	"NADMA_DISASTERS_API_URL",
	"https://mydims.nadma.gov.my/api/disasters",
)
NADMA_DISASTERS_API_TOKEN: str = os.getenv(
	"NADMA_DISASTERS_API_TOKEN",
	"6571756|yN5L6StiHQOlyouD5FjmMFBOeywAxjPE79x0m7n843ac4e63",
)

# ── OpenAI Assistant Chatbot ────────────────────────────────────────────────
OPENAI_API_KEY: str = os.getenv("OPENAI_API_KEY", "")
OPENAI_ASSISTANT_ID: str = os.getenv(
	"OPENAI_ASSISTANT_ID",
	"asst_z53ZlGOoHh76CDfqcBA0t4gC",
)
