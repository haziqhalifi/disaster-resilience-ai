"""Application configuration loaded from environment variables.

For development, values fall back to insecure defaults.
In production, set DISASTER_SECRET_KEY to a cryptographically random string:
    python -c "import secrets; print(secrets.token_hex(32))"
"""

import os

# Secret key used to sign JWT tokens.
# CHANGE THIS in production — keep it in an environment variable.
SECRET_KEY: str = os.getenv(
    "DISASTER_SECRET_KEY",
    "change-me-in-production-use-a-long-random-secret-key",
)

# JWT algorithm
ALGORITHM: str = "HS256"

# Token expiry in minutes (default: 7 days)
ACCESS_TOKEN_EXPIRE_MINUTES: int = int(
    os.getenv("DISASTER_TOKEN_EXPIRE_MINUTES", "10080")
)
