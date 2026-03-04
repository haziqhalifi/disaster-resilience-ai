"""Authentication endpoints: sign-up, sign-in, and /me (current user)."""

from fastapi import APIRouter, Depends, HTTPException, status

from app.api.v1.dependencies import get_current_user
from app.core.security import create_access_token, hash_password, verify_password
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
    """Create a new user account and return a JWT access token.

    - **username**: must be unique (3–50 characters)
    - **email**: must be a valid, unique email address
    - **password**: minimum 6 characters (stored as a bcrypt hash)
    """
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

    # Persist the new user
    record = user_db.create_user(
        username=body.username,
        email=body.email,
        hashed_password=hash_password(body.password),
    )

    user_out = UserOut(id=record["id"], username=record["username"], email=record["email"])
    token = create_access_token(data={"sub": record["email"]})

    return Token(access_token=token, token_type="bearer", user=user_out)


# ── POST /auth/signin ─────────────────────────────────────────────────────────

@router.post(
    "/signin",
    response_model=Token,
    status_code=status.HTTP_200_OK,
    summary="Sign in and receive a JWT access token",
)
async def signin(body: UserSignIn) -> Token:
    """Authenticate an existing user and return a JWT access token.

    - **email**: the registered email address
    - **password**: the account password
    """
    record = user_db.get_user_by_email(body.email)
    if record is None or not verify_password(body.password, record["hashed_password"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user_out = UserOut(id=record["id"], username=record["username"], email=record["email"])
    token = create_access_token(data={"sub": record["email"]})

    return Token(access_token=token, token_type="bearer", user=user_out)


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
