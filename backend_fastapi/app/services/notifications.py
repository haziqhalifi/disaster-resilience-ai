"""Notification dispatch service.

Provides helpers to fan-out a warning to every user whose last-known
location falls inside the affected radius.

Channels:
  1. Push notification via FCM token   (stub — integrate Firebase Admin SDK)
  2. SMS fallback for offline users     (stub — integrate Twilio / Vonage)
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field

from app.core.geo import is_point_in_radius
from app.db import devices as device_db
from app.db.devices import DeviceRecord
from app.db.warnings import WarningRecord

logger = logging.getLogger(__name__)


# ── Stubs for external integrations ──────────────────────────────────────────

def _send_push(fcm_token: str, title: str, body: str, data: dict) -> bool:
    """Send a push notification via Firebase Cloud Messaging.

    TODO: Replace with real firebase-admin call:
        from firebase_admin import messaging
        message = messaging.Message(notification=..., token=fcm_token, data=data)
        messaging.send(message)
    """
    logger.info("PUSH → token=%s…  title=%s", fcm_token[:12], title)
    return True  # assume success in dev


def _send_sms(phone_number: str, text: str) -> bool:
    """Send an SMS via Twilio / Vonage / local gateway.

    TODO: Replace with real SMS integration:
        from twilio.rest import Client
        client.messages.create(to=phone_number, from_=SENDER, body=text)
    """
    logger.info("SMS  → phone=%s  text=%s", phone_number, text[:60])
    return True  # assume success in dev


# ── Broadcast logic ──────────────────────────────────────────────────────────

@dataclass
class BroadcastResult:
    warning_id: str
    push_sent: int = 0
    sms_sent: int = 0
    total_affected: int = 0
    affected_users: list[str] = field(default_factory=list)


def broadcast_warning(warning: WarningRecord) -> BroadcastResult:
    """Fan-out *warning* to every user within the affected radius.

    Decision tree per user:
      • Has FCM token  → push notification
      • No FCM token, but has phone number → SMS fallback
      • Neither → skipped (logged)
    """
    result = BroadcastResult(warning_id=warning["id"])

    title = f"[{warning['alert_level'].upper()}] {warning['title']}"
    body = (
        f"{warning['hazard_type'].capitalize()} alert — {warning['description'][:200]}"
    )
    data = {
        "warning_id": warning["id"],
        "hazard_type": warning["hazard_type"],
        "alert_level": warning["alert_level"],
    }

    for device in device_db.get_all_devices_with_location():
        assert device["latitude"] is not None and device["longitude"] is not None
        if not is_point_in_radius(
            device["latitude"],
            device["longitude"],
            warning["latitude"],
            warning["longitude"],
            warning["radius_km"],
        ):
            continue

        result.total_affected += 1
        result.affected_users.append(device["user_id"])

        # Prefer push; fall back to SMS
        if device.get("fcm_token"):
            if _send_push(device["fcm_token"], title, body, data):
                result.push_sent += 1
        elif device.get("phone_number"):
            sms_text = f"{title}\n{body}"
            if _send_sms(device["phone_number"], sms_text):
                result.sms_sent += 1
        else:
            logger.warning(
                "User %s in affected zone but has no push/SMS channel.",
                device["user_id"],
            )

    return result


def get_warnings_for_location(
    latitude: float,
    longitude: float,
    active_warnings: list[WarningRecord],
) -> list[WarningRecord]:
    """Return the subset of *active_warnings* that cover the given point."""
    return [
        w
        for w in active_warnings
        if is_point_in_radius(latitude, longitude, w["latitude"], w["longitude"], w["radius_km"])
    ]
