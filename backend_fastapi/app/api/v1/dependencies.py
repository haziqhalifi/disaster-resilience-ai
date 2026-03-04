"""FastAPI dependency: extract and validate the JWT from the Authorization header."""

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.db.supabase_client import get_client
from app.db import users as user_db
from app.schemas.user import UserOut

_bearer = HTTPBearer()


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
) -> UserOut:
    """Validate a Supabase bearer token and return the corresponding user profile.

    Raises HTTP 401 if the token is missing, malformed, or expired.
    """
    sb = get_client()

    try:
        auth_res = sb.auth.get_user(credentials.credentials)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token.",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc

    auth_user = auth_res.user
    if auth_user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    record = user_db.get_user_by_id(str(auth_user.id))
    if record is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return UserOut(id=record["id"], username=record["username"], email=record["email"])
