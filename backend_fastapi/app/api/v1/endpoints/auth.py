"""Authentication endpoints: sign-up, sign-in, and /me (current user)."""

from fastapi import APIRouter, Depends, HTTPException, status

from app.api.v1.dependencies import get_current_user
from app.db.supabase_client import get_client
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
        sign_in = sb.auth.sign_in_with_password(
            {"email": str(body.email).lower(), "password": body.password}
        )
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
    return Token(access_token=session.access_token, token_type="bearer", user=user_out)


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
    try:
        sign_in = sb.auth.sign_in_with_password(
            {"email": str(body.email).lower(), "password": body.password}
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password.",
            headers={"WWW-Authenticate": "Bearer"},
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
    return Token(access_token=session.access_token, token_type="bearer", user=user_out)


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
