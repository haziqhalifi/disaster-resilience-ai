"""SMS webhook endpoint — processes safety status replies from any provider.

Supports inbound webhook formats for:
  - MoceanAPI   : mocean-from, mocean-text
  - Vonage      : msisdn, text
  - EasySendSMS : From, message
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse

from app.db import family as family_db

logger = logging.getLogger(__name__)
router = APIRouter()

_SAFE_KEYWORDS   = {"safe", "selamat", "ok", "okay"}
_DANGER_KEYWORDS = {"danger", "help", "bahaya", "tolong", "sos"}


def _parse_status(body: str) -> str | None:
    """Return 'safe', 'needs_help', or None if unrecognised."""
    word = body.strip().lower()
    if word in _SAFE_KEYWORDS:
        return "safe"
    if word in _DANGER_KEYWORDS:
        return "needs_help"
    return None


@router.post("/webhook")
async def sms_webhook(request: Request) -> JSONResponse:
    """
    Unified inbound SMS webhook.

    Auto-detects provider by inspecting which field names are present:
      Mocean      → mocean-from / mocean-text
      Vonage      → msisdn / text
      EasySendSMS → From / message
    """
    data = dict(await request.form())

    # Auto-detect sender phone and message body across provider formats
    sender = (
        data.get("mocean-from")   # Mocean
        or data.get("msisdn")     # Vonage
        or data.get("From", "")   # EasySendSMS / Twilio (legacy)
    )
    body = (
        data.get("mocean-text")   # Mocean
        or data.get("text")       # Vonage
        or data.get("message")    # EasySendSMS
        or data.get("Body", "")   # Twilio (legacy)
    )

    if not sender:
        logger.warning("SMS webhook: could not determine sender from fields: %s", list(data.keys()))
        return JSONResponse({"status": "error", "detail": "sender not found"}, status_code=400)

    logger.info("SMS reply from %s: %s", sender, str(body)[:60])

    # Find family member by phone number
    member = family_db.find_member_by_phone(sender)
    if not member:
        logger.warning("Unregistered phone replied: %s", sender)
        return JSONResponse({
            "status": "unregistered",
            "message": "Your number is not registered. Download the Resilience AI app to register.",
        })

    new_status = _parse_status(str(body))
    if new_status is None:
        return JSONResponse({
            "status": "unrecognised",
            "message": "Reply not recognised. Please reply SAFE or DANGER.",
        })

    # Update family member status in DB
    family_db.update_member_status(member["id"], safety_status=new_status)
    logger.info("Updated %s (%s) status to %s via SMS", member["name"], sender, new_status)

    # Record reply on the outgoing SMS alert row so admin rescue panel can see it
    try:
        from app.services.sms_service import record_sms_reply
        record_sms_reply(sender, new_status)
    except Exception as exc:
        logger.warning("record_sms_reply failed: %s", exc)

    # Notify family group leader via FCM (best effort)
    try:
        group = family_db.get_family_group(member["group_id"])
        if group:
            from app.services.notifications import _send_push
            from app.db.devices import get_device
            leader_device = get_device(group["leader_user_id"])
            if leader_device and leader_device.get("fcm_token"):
                label = "SAFE" if new_status == "safe" else "DANGER"
                _send_push(
                    leader_device["fcm_token"],
                    "Family Safety Update",
                    f"{member['name']} replied {label} via SMS",
                    {"type": "family_sms_reply"},
                )
    except Exception as exc:
        logger.warning("FCM notify failed: %s", exc)

    label = "SAFE" if new_status == "safe" else "DANGER - help requested"
    return JSONResponse({
        "status": "ok",
        "message": f"Status updated to {label}. Your family has been notified. Stay safe.",
    })
