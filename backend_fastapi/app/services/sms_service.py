"""Unified SMS service — routes to Mocean, Vonage, or EasySendSMS.

Set SMS_PROVIDER in .env to switch providers:
    SMS_PROVIDER=mocean       # MoceanAPI  (Malaysian, free 10 SMS trial)
    SMS_PROVIDER=vonage       # Vonage     (€2 free trial, 4 test numbers)
    SMS_PROVIDER=easysendsms  # EasySendSMS (15 free SMS trial)
"""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone

from app.core.config import (
    SMS_PROVIDER,
    MOCEAN_API_KEY, MOCEAN_API_SECRET,
    VONAGE_API_KEY, VONAGE_API_SECRET,
    EASYSENDSMS_USERNAME, EASYSENDSMS_PASSWORD,
)
from app.db.supabase_client import get_client

logger = logging.getLogger(__name__)

_TYPE_LABELS: dict[str, str] = {
    "flood":             "Flood",
    "landslide":         "Landslide",
    "blocked_road":      "Blocked Road",
    "medical_emergency": "Medical Emergency",
}


# ── Terminal preview ──────────────────────────────────────────────────────────

def _print_preview(alert_type: str, to_number: str, body: str) -> None:
    border  = "=" * 62
    divider = "-" * 62
    try:
        print(f"\n{border}", flush=True)
        print(f"  LANDA  |  {SMS_PROVIDER.upper()} SMS  |  {alert_type}", flush=True)
        print(f"  To   : {to_number}", flush=True)
        print(f"  Mode : {'LIVE' if _is_configured() else 'MOCK'}", flush=True)
        print(f"{divider}", flush=True)
        for line in body.split("\n"):
            print(f"  {line}", flush=True)
        print(f"{border}\n", flush=True)
    except UnicodeEncodeError:
        logger.info("SMS preview [%s] to %s: %s", alert_type, to_number, body[:120])


def _is_configured() -> bool:
    if SMS_PROVIDER == "mocean":
        return bool(MOCEAN_API_KEY and MOCEAN_API_SECRET)
    if SMS_PROVIDER == "vonage":
        return bool(VONAGE_API_KEY and VONAGE_API_SECRET)
    if SMS_PROVIDER == "easysendsms":
        return bool(EASYSENDSMS_USERNAME and EASYSENDSMS_PASSWORD)
    return False


# ── Provider send functions ───────────────────────────────────────────────────

def _send_mocean(phone_number: str, message: str) -> bool:
    if not (MOCEAN_API_KEY and MOCEAN_API_SECRET):
        logger.warning("[MOCK-MOCEAN] Would send to %s: %s", phone_number, message[:80])
        return True
    try:
        from moceansdk import Client, Basic
        client = Client(Basic(MOCEAN_API_KEY, MOCEAN_API_SECRET))
        res = client.sms.send({
            "mocean-from": "LANDA",
            "mocean-to":   phone_number,
            "mocean-text": message,
        })
        status = str(res.messages[0].status) if res.messages else "unknown"
        if status == "0":
            logger.info("[Mocean] SMS sent to %s", phone_number)
            return True
        logger.error("[Mocean] Send failed, status=%s", status)
        return False
    except Exception as exc:
        logger.error("[Mocean] Send error to %s: %s", phone_number, exc)
        return False


def _send_vonage(phone_number: str, message: str) -> bool:
    if not (VONAGE_API_KEY and VONAGE_API_SECRET):
        logger.warning("[MOCK-VONAGE] Would send to %s: %s", phone_number, message[:80])
        return True
    try:
        import vonage
        from vonage import Auth
        from vonage_sms import SmsMessage

        client = vonage.Vonage(auth=Auth(api_key=VONAGE_API_KEY, api_secret=VONAGE_API_SECRET))
        # Vonage v4 requires E.164 without '+' prefix (e.g. 60123456789)
        to = phone_number.lstrip("+")
        response = client.sms.send(SmsMessage(to=to, from_="LANDA", text=message))
        # response.messages is a list of SmsResponse objects
        msg = response.messages[0]
        if str(msg.status) == "0":
            logger.info("[Vonage] SMS sent to %s (msg-id: %s)", phone_number, msg.message_id)
            return True
        logger.error("[Vonage] Send failed status=%s error=%s", msg.status, getattr(msg, "error_text", ""))
        return False
    except Exception as exc:
        logger.error("[Vonage] Send error to %s: %s", phone_number, exc)
        return False


def _send_easysendsms(phone_number: str, message: str) -> bool:
    if not (EASYSENDSMS_USERNAME and EASYSENDSMS_PASSWORD):
        logger.warning("[MOCK-EASYSENDSMS] Would send to %s: %s", phone_number, message[:80])
        return True
    try:
        import httpx
        # EasySendSMS expects number without '+' prefix
        to = phone_number.lstrip("+")
        resp = httpx.post(
            "https://www.easysendsms.app/bulksms",
            data={
                "username":   EASYSENDSMS_USERNAME,
                "password":   EASYSENDSMS_PASSWORD,
                "msisdn":     to,
                "message":    message,
                "sender":     "LANDA",
                "type":       "0",
                "dlr":        "1",
            },
            timeout=10.0,
        )
        body = resp.text.strip()
        if resp.status_code == 200 and "OK" in body.upper():
            logger.info("[EasySendSMS] SMS sent to %s", phone_number)
            return True
        logger.error("[EasySendSMS] Send failed: %s", body)
        return False
    except Exception as exc:
        logger.error("[EasySendSMS] Send error to %s: %s", phone_number, exc)
        return False


# ── Router ────────────────────────────────────────────────────────────────────

def _route(phone_number: str, message: str) -> bool:
    if SMS_PROVIDER == "mocean":
        return _send_mocean(phone_number, message)
    if SMS_PROVIDER == "vonage":
        return _send_vonage(phone_number, message)
    if SMS_PROVIDER == "easysendsms":
        return _send_easysendsms(phone_number, message)
    logger.warning("SMS_PROVIDER '%s' not recognised — message not sent", SMS_PROVIDER)
    return False


# ── Dedup check ───────────────────────────────────────────────────────────────

def _already_sent(*, user_id: str, event_id: str) -> bool:
    from datetime import timedelta
    sb     = get_client()
    cutoff = (datetime.now(timezone.utc) - timedelta(hours=1)).isoformat()
    res = (
        sb.table("sms_alerts")
        .select("id")
        .eq("user_id",  user_id)
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
            "id":           str(uuid.uuid4()),
            "user_id":      user_id,
            "phone_number": phone_number,
            "alert_type":   alert_type,
            "event_id":     event_id,
            "message_body": message_body,
            "status":       status,
            "error_reason": error_reason,
            "sent_at":      datetime.now(timezone.utc).isoformat(),
        }).execute()
    except Exception as exc:
        logger.warning("Failed to log SMS alert: %s", exc)


# ── Public API ────────────────────────────────────────────────────────────────

def send_flood_alert(
    *,
    phone_number: str,
    user_id: str,
    location_name: str,
    distance_km: float,
    event_id: str,
    shelter_name: str = "",
    shelter_phone: str = "",
    shelter_distance_km: float | None = None,
) -> bool:
    if not phone_number:
        return False
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

    message = (
        f"FLOOD ALERT - LANDA App\n\n"
        f"Flood confirmed at {location_name} ({distance_km:.1f}km from you)."
        f"{shelter_info}\n\n"
        f"Reply SAFE or DANGER to update your status.\n"
        f"Stay away from floodwater. Move to higher ground now."
    )

    _print_preview("FLOOD ALERT", phone_number, message)
    success = _route(phone_number, message)
    _log_alert(
        user_id=user_id, phone_number=phone_number,
        event_id=event_id, message_body=message,
        alert_type="flood",
        status="sent" if success else "failed",
    )
    return success


def send_emergency_alert(
    *,
    phone_number: str,
    user_id: str,
    report_type: str,
    location_name: str,
    distance_km: float,
    event_id: str,
) -> bool:
    if not phone_number:
        return False
    if _already_sent(user_id=user_id, event_id=event_id):
        logger.info("Dedup: already sent emergency alert to user %s for event %s", user_id, event_id)
        return False

    type_label = _TYPE_LABELS.get(report_type, report_type.replace("_", " ").title())
    message = (
        f"EMERGENCY ALERT - LANDA App\n\n"
        f"{type_label} reported at {location_name} ({distance_km:.1f}km from you).\n\n"
        f"Stay safe. Follow local authority instructions.\n\n"
        f"Reply SAFE or DANGER to update your status."
    )

    _print_preview(f"EMERGENCY - {type_label}", phone_number, message)
    success = _route(phone_number, message)
    _log_alert(
        user_id=user_id, phone_number=phone_number,
        event_id=event_id, message_body=message,
        alert_type=report_type,
        status="sent" if success else "failed",
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

    _print_preview("GOV WARNING", phone_number, message)
    success = _route(phone_number, message)
    _log_alert(
        user_id=user_id, phone_number=phone_number,
        event_id=event_id, message_body=message,
        alert_type="government_warning",
        status="sent" if success else "failed",
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
                "reply_at":     datetime.now(timezone.utc).isoformat(),
            }).eq("id", res.data[0]["id"]).execute()
    except Exception as exc:
        logger.warning("Failed to record SMS reply: %s", exc)
