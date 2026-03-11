"""Twilio SMS service — sends flood alerts and processes replies."""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone

from app.core.config import TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER
from app.db.supabase_client import get_client

logger = logging.getLogger(__name__)

_MOCK_MODE = not (TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN and TWILIO_PHONE_NUMBER)


def _print_sms_preview(alert_type: str, to_number: str, body: str) -> None:
    """Print a clearly formatted SMS preview to stdout for demo/logging purposes."""
    border = "=" * 62
    print(f"\n{border}", flush=True)
    print(f"  LANDA  |  Twilio SMS  |  {alert_type}", flush=True)
    print(f"  To   : {to_number}", flush=True)
    print(f"  From : {TWILIO_PHONE_NUMBER or '(mock)'}", flush=True)
    print(f"  Mode : {'LIVE' if not _MOCK_MODE else 'MOCK'}", flush=True)
    print(f"{'─' * 62}", flush=True)
    for line in body.split("\n"):
        print(f"  {line}", flush=True)
    print(f"{border}\n", flush=True)


def _get_client():
    if _MOCK_MODE:
        return None
    from twilio.rest import Client
    return Client(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)


def send_flood_alert(
    *,
    phone_number: str,
    user_id: str,
    location_name: str,
    distance_km: float,
    shelter_name: str = "",
    shelter_phone: str = "",
    shelter_distance_km: float | None = None,
    event_id: str,
) -> bool:
    """Send a flood alert SMS via Twilio. Returns True on success."""
    if not phone_number:
        return False

    # Check dedup: don't send same event to same user within 1 hour
    if _already_sent(user_id=user_id, event_id=event_id):
        logger.info("Dedup: already sent flood alert to user %s for event %s", user_id, event_id)
        return False

    shelter_info = ""
    if shelter_name:
        shelter_info = f"\nNearest shelter: {shelter_name}"
        if shelter_distance_km:
            shelter_info += f" ({shelter_distance_km:.1f}km)"
        if shelter_phone:
            shelter_info += f" | {shelter_phone}"
        shelter_info += "\n"

    message = (
        f"FLOOD ALERT — LANDA App\n\n"
        f"A flood has been CONFIRMED at {location_name} "
        f"({distance_km:.1f}km from you).\n"
        f"{shelter_info}\n"
        f"Reply:\nSAFE — I evacuated safely\nDANGER — I need rescue\n\n"
        f"Stay away from floodwater. Move to higher ground now."
    )

    _print_sms_preview("FLOOD ALERT", phone_number, message)

    success = False
    error_reason = None

    if _MOCK_MODE:
        logger.info("[MOCK] SMS to %s: %s", phone_number, message[:80])
        success = True
    else:
        try:
            client = _get_client()
            client.messages.create(to=phone_number, from_=TWILIO_PHONE_NUMBER, body=message)
            success = True
            logger.info("SMS sent to %s for event %s", phone_number, event_id)
        except Exception as exc:
            error_reason = str(exc)
            logger.error("SMS failed to %s: %s", phone_number, exc)

    _log_alert(
        user_id=user_id, phone_number=phone_number,
        event_id=event_id, message_body=message,
        status="sent" if success else "failed",
        error_reason=error_reason,
    )
    return success


_TYPE_LABELS: dict[str, str] = {
    "flood":             "Flood",
    "landslide":         "Landslide",
    "blocked_road":      "Blocked Road",
    "medical_emergency": "Medical Emergency",
}


def send_emergency_alert(
    *,
    phone_number: str,
    user_id: str,
    report_type: str,
    location_name: str,
    distance_km: float,
    event_id: str,
) -> bool:
    """Send a generic emergency alert SMS for any disaster report type."""
    if not phone_number:
        return False

    if _already_sent(user_id=user_id, event_id=event_id):
        logger.info("Dedup: already sent emergency alert to user %s for event %s", user_id, event_id)
        return False

    type_label = _TYPE_LABELS.get(report_type, report_type.replace("_", " ").title())

    message = (
        f"EMERGENCY ALERT — LANDA App\n\n"
        f"{type_label} reported at {location_name} "
        f"({distance_km:.1f}km from you).\n\n"
        f"Stay safe. Follow local authority instructions.\n\n"
        f"Reply:\nSAFE — I am safe\nDANGER — I need rescue"
    )

    _print_sms_preview(f"EMERGENCY — {type_label}", phone_number, message)

    success = False
    error_reason = None

    if _MOCK_MODE:
        logger.info("[MOCK] Emergency SMS (%s) to %s: %s", type_label, phone_number, message[:100])
        success = True
    else:
        try:
            client = _get_client()
            client.messages.create(to=phone_number, from_=TWILIO_PHONE_NUMBER, body=message)
            success = True
            logger.info("Emergency SMS (%s) sent to %s for event %s", type_label, phone_number, event_id)
        except Exception as exc:
            error_reason = str(exc)
            logger.error("Emergency SMS failed to %s: %s", phone_number, exc)

    _log_alert(
        user_id=user_id, phone_number=phone_number,
        event_id=event_id, message_body=message,
        alert_type=report_type,
        status="sent" if success else "failed",
        error_reason=error_reason,
    )
    return success


def send_government_alert(
    *,
    phone_number: str,
    user_id: str,
    area: str,
    severity: str,
    event_id: str,
) -> bool:
    """Send a government flood warning SMS."""
    if not phone_number:
        return False
    if _already_sent(user_id=user_id, event_id=event_id):
        return False

    message = (
        f"GOVERNMENT FLOOD WARNING\n\n"
        f"Area: {area}\n"
        f"Severity: {severity}\n\n"
        f"Reply SAFE or DANGER to update your status.\n"
        f"Source: MetMalaysia"
    )

    success = False
    error_reason = None

    if _MOCK_MODE:
        logger.info("[MOCK] Gov SMS to %s: %s", phone_number, message[:80])
        success = True
    else:
        try:
            client = _get_client()
            client.messages.create(to=phone_number, from_=TWILIO_PHONE_NUMBER, body=message)
            success = True
        except Exception as exc:
            error_reason = str(exc)
            logger.error("Gov SMS failed to %s: %s", phone_number, exc)

    _log_alert(
        user_id=user_id, phone_number=phone_number, event_id=event_id,
        message_body=message, alert_type="government_warning",
        status="sent" if success else "failed", error_reason=error_reason,
    )
    return success


def record_sms_reply(phone_number: str, reply_status: str) -> None:
    """Update the most recent sms_alert for this phone with the user's reply status."""
    try:
        sb = get_client()
        res = (
            sb.table("sms_alerts")
            .select("id")
            .eq("phone_number", phone_number)
            .is_("reply_status", "null")
            .order("sent_at", desc=True)
            .limit(1)
            .execute()
        )
        if res.data:
            sb.table("sms_alerts").update({
                "reply_status": reply_status,
                "reply_at": datetime.now(timezone.utc).isoformat(),
            }).eq("id", res.data[0]["id"]).execute()
    except Exception as exc:
        logger.warning("Failed to record SMS reply: %s", exc)


def _already_sent(*, user_id: str, event_id: str) -> bool:
    """Check if we already sent an alert for this event to this user in the past hour."""
    from datetime import timedelta
    sb = get_client()
    cutoff = (datetime.now(timezone.utc) - timedelta(hours=1)).isoformat()
    res = (
        sb.table("sms_alerts")
        .select("id")
        .eq("user_id", user_id)
        .eq("event_id", event_id)
        .gte("sent_at", cutoff)
        .limit(1)
        .execute()
    )
    return bool(res.data)


def _log_alert(
    *, user_id: str, phone_number: str, event_id: str,
    message_body: str, status: str, error_reason: str | None = None,
    alert_type: str = "flood",
) -> None:
    try:
        sb = get_client()
        sb.table("sms_alerts").insert({
            "id": str(uuid.uuid4()),
            "user_id": user_id,
            "phone_number": phone_number,
            "alert_type": alert_type,
            "event_id": event_id,
            "message_body": message_body,
            "status": status,
            "error_reason": error_reason,
            "sent_at": datetime.now(timezone.utc).isoformat(),
        }).execute()
    except Exception as exc:
        logger.warning("Failed to log SMS alert: %s", exc)
