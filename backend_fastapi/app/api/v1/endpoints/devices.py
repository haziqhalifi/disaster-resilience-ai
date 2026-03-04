"""User location & device registration endpoints.

Allows the mobile app to:
  1. Update the user's last-known GPS coordinates
  2. Register an FCM push token and/or phone number for SMS fallback
  3. Retrieve the stored device/location record
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status

from app.api.v1.dependencies import get_current_user
from app.db import devices as device_db
from app.schemas.user import UserOut
from app.schemas.warning import DeviceOut, DeviceRegister, UserLocationUpdate

router = APIRouter()


# ── PUT /me/location — update GPS coordinates ───────────────────────────────

@router.put(
    "/me/location",
    response_model=DeviceOut,
    summary="Update current user's location",
)
async def update_location(
    body: UserLocationUpdate,
    current_user: UserOut = Depends(get_current_user),
) -> DeviceOut:
    """Store or update the latitude/longitude for the signed-in user.

    The mobile app should call this whenever a significant location
    change is detected so the warning system can target users accurately.
    """
    rec = device_db.update_location(current_user.id, body.latitude, body.longitude)
    return DeviceOut(**rec)


# ── PUT /me/device — register FCM token / phone for SMS fallback ────────────

@router.put(
    "/me/device",
    response_model=DeviceOut,
    summary="Register push notification token and/or SMS phone number",
)
async def register_device(
    body: DeviceRegister,
    current_user: UserOut = Depends(get_current_user),
) -> DeviceOut:
    """Register or update the push-notification token and optional SMS number.

    - **fcm_token**: Firebase Cloud Messaging token for push notifications
    - **phone_number**: E.164 phone number for SMS fallback when offline
    """
    if body.fcm_token is None and body.phone_number is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Provide at least one of 'fcm_token' or 'phone_number'.",
        )
    rec = device_db.register_device(
        current_user.id,
        fcm_token=body.fcm_token,
        phone_number=body.phone_number,
    )
    return DeviceOut(**rec)


# ── GET /me/device — retrieve stored device info ────────────────────────────

@router.get(
    "/me/device",
    response_model=DeviceOut,
    summary="Get current user's device / location record",
)
async def get_device(
    current_user: UserOut = Depends(get_current_user),
) -> DeviceOut:
    rec = device_db.get_device(current_user.id)
    if rec is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No device/location record found. Update your location or register a device first.",
        )
    return DeviceOut(**rec)
