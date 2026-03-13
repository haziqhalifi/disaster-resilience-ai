"""Authentication endpoints: sign-up, sign-in, and /me (current user)."""

from fastapi import APIRouter, Depends, HTTPException, status
from supabase_auth.errors import AuthApiError

from app.api.v1.dependencies import get_current_user
from app.db.supabase_client import get_auth_client, get_client
from app.db import users as user_db
from app.schemas.user import Token, UserOut, UserSignIn, UserSignUp

router = APIRouter()


# ── POST /auth/signup ─────────────────────────────────────────────────────────

@router.post(
    "/signup",
    response_model=Token,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new user account",
)
async def signup(body: UserSignUp) -> Token:
    """Create a new user account and return a Supabase access token.

    - **username**: must be unique (3–50 characters)
    - **email**: must be a valid, unique email address
    - **password**: minimum 6 characters (managed by Supabase Auth)
    """
    sb = get_client()
    auth_sb = get_auth_client()

    # Uniqueness checks
    if user_db.get_user_by_email(body.email):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this email already exists.",
        )
    if user_db.get_user_by_username(body.username):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This username is already taken.",
        )

    # Create auth account in Supabase Auth
    try:
        auth_res = sb.auth.admin.create_user(
            {
                "email": str(body.email).lower(),
                "password": body.password,
                "email_confirm": True,
                "user_metadata": {"username": body.username.lower()},
            }
        )
    except Exception as exc:
        msg = str(exc).lower()
        if "already" in msg and "registered" in msg:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="An account with this email already exists.",
            ) from exc
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Unable to create account in Supabase Auth.",
        ) from exc

    auth_user = auth_res.user
    if auth_user is None:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Supabase did not return a created user.",
        )

    # Persist profile row linked to auth user id
    try:
        record = user_db.create_user_profile(
            user_id=str(auth_user.id),
            username=body.username,
            email=str(body.email),
        )
    except Exception as exc:
        try:
            sb.auth.admin.delete_user(str(auth_user.id))
        except Exception:
            pass
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Auth account created but profile creation failed.",
        ) from exc

    # Issue access token by signing in with the just-created credentials
    try:
        sign_in = auth_sb.auth.sign_in_with_password(
            {"email": str(body.email).lower(), "password": body.password}
        )
    except AuthApiError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Account created but automatic sign-in failed: {str(exc)}",
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Account created but automatic sign-in failed.",
        ) from exc

    session = sign_in.session
    if session is None:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Supabase did not return a valid auth session.",
        )

    user_out = UserOut(id=record["id"], username=record["username"], email=record["email"])
    return Token(
        access_token=session.access_token,
        refresh_token=session.refresh_token,
        token_type="bearer",
        user=user_out,
    )


# ── POST /auth/signin ─────────────────────────────────────────────────────────

@router.post(
    "/signin",
    response_model=Token,
    status_code=status.HTTP_200_OK,
    summary="Sign in and receive a JWT access token",
)
async def signin(body: UserSignIn) -> Token:
    """Authenticate an existing user and return a Supabase access token.

    - **email**: the registered email address
    - **password**: the account password
    """
    sb = get_client()
    auth_sb = get_auth_client()
    try:
        sign_in = auth_sb.auth.sign_in_with_password(
            {"email": str(body.email).lower(), "password": body.password}
        )
    except AuthApiError as exc:
        msg = str(exc).lower()
        if (
            "invalid login credentials" in msg
            or "email not confirmed" in msg
            or "invalid email or password" in msg
        ):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect email or password.",
                headers={"WWW-Authenticate": "Bearer"},
            ) from exc
        if "invalid api key" in msg or "jwt" in msg or "permission" in msg:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Authentication service error: Supabase auth key/config is invalid.",
            ) from exc
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Authentication service error: {str(exc)}",
        ) from exc
    except Exception as exc:
        msg = str(exc).lower()
        # Wrong credentials should be surfaced as 401.
        if (
            "invalid login credentials" in msg
            or "email not confirmed" in msg
            or "invalid email or password" in msg
        ):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect email or password.",
                headers={"WWW-Authenticate": "Bearer"},
            ) from exc
        # Configuration/upstream auth errors should not be masked as credential failures.
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Authentication service error. Check Supabase URL/API key configuration.",
        ) from exc

    auth_user = sign_in.user
    session = sign_in.session
    if auth_user is None or session is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    record = user_db.get_user_by_id(str(auth_user.id))
    if record is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not found. Please contact support.",
        )

    user_out = UserOut(id=record["id"], username=record["username"], email=record["email"])
    return Token(
        access_token=session.access_token,
        refresh_token=session.refresh_token,
        token_type="bearer",
        user=user_out,
    )


# ── POST /auth/refresh ────────────────────────────────────────────────────────

@router.post(
    "/refresh",
    response_model=Token,
    status_code=status.HTTP_200_OK,
    summary="Refresh an expired access token using a refresh token",
)
async def refresh_token(body: dict) -> Token:
    """Exchange a valid refresh token for a new access token."""
    refresh = body.get("refresh_token", "")
    if not refresh:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="refresh_token is required.",
        )
    auth_sb = get_auth_client()
    try:
        res = auth_sb.auth.refresh_session(refresh)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token is invalid or expired. Please sign in again.",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc

    session = res.session
    auth_user = res.user
    if session is None or auth_user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not refresh session.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    record = user_db.get_user_by_id(str(auth_user.id))
    if record is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found.")

    user_out = UserOut(id=record["id"], username=record["username"], email=record["email"])
    return Token(
        access_token=session.access_token,
        refresh_token=session.refresh_token,
        token_type="bearer",
        user=user_out,
    )


# ── GET /auth/me ──────────────────────────────────────────────────────────────

@router.get(
    "/me",
    response_model=UserOut,
    status_code=status.HTTP_200_OK,
    summary="Get the currently authenticated user",
)
async def me(current_user: UserOut = Depends(get_current_user)) -> UserOut:
    """Return the profile of the user identified by the supplied Bearer token."""
    return current_user
