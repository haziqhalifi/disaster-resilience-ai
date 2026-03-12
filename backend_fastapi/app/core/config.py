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

# ── Anthropic / Claude AI ─────────────────────────────────────────────────────
ANTHROPIC_API_KEY: str = os.getenv("ANTHROPIC_API_KEY", "")

# ── Admin Website (simple hardcoded credentials) ─────────────────────────────
# Override these in .env for production
ADMIN_USERNAME: str = os.getenv("ADMIN_USERNAME", "admin")
ADMIN_PASSWORD: str = os.getenv("ADMIN_PASSWORD", "changeme123")
ADMIN_JWT_SECRET: str = os.getenv("ADMIN_JWT_SECRET", "admin-secret-key-change-in-production")
