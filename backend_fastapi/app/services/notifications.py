"""Notification dispatch service.

Channels:
  1. Push notification via FCM token   (stub — integrate Firebase Admin SDK)
  2. SMS via Twilio for flood alerts
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field

from app.core.geo import is_point_in_radius
from app.db import devices as device_db
from app.db.warnings import WarningRecord

logger = logging.getLogger(__name__)


def _send_push(fcm_token: str, title: str, body: str, data: dict) -> bool:
    """Send a push notification via Firebase Cloud Messaging.

    TODO: Replace with real firebase-admin call:
        from firebase_admin import messaging
        message = messaging.Message(notification=..., token=fcm_token, data=data)
        messaging.send(message)
    """
    logger.info("PUSH → token=%s…  title=%s", fcm_token[:12], title)
    return True


@dataclass
class BroadcastResult:
    warning_id: str
    push_sent: int = 0
    sms_sent: int = 0
    sirens_triggered: int = 0
    total_affected: int = 0
    affected_users: list[str] = field(default_factory=list)


def broadcast_warning(warning: WarningRecord) -> BroadcastResult:
    """Fan-out warning to every user within the affected radius."""
    result = BroadcastResult(warning_id=warning["id"])

    title = f"[{warning['alert_level'].upper()}] {warning['title']}"
    body  = f"{warning['hazard_type'].capitalize()} alert — {warning['description'][:200]}"
    data  = {
        "warning_id": warning["id"],
        "hazard_type": warning["hazard_type"],
        "alert_level": warning["alert_level"],
    }

    for device in device_db.get_all_devices_with_location():
        if device["latitude"] is None or device["longitude"] is None:
            continue
        if not is_point_in_radius(
            device["latitude"], device["longitude"],
            warning["latitude"], warning["longitude"], warning["radius_km"],
        ):
            continue

        result.total_affected += 1
        result.affected_users.append(device["user_id"])

        if device.get("fcm_token"):
            if _send_push(device["fcm_token"], title, body, data):
                result.push_sent += 1
        elif device.get("phone_number"):
            from app.services.twilio_service import send_government_alert
            sent = send_government_alert(
                phone_number=device["phone_number"],
                user_id=device["user_id"],
                area=warning.get("title", ""),
                severity=warning.get("alert_level", ""),
                event_id=warning["id"],
            )
            if sent:
                result.sms_sent += 1
        else:
            logger.warning("User %s in zone but has no push/SMS channel.", device["user_id"])

    # Trigger IoT sirens for high-severity warnings
    if warning.get("alert_level") in ("warning", "evacuate"):
        try:
            from app.db import sirens as siren_db
            from app.core.geo import haversine
            nearby_sirens = siren_db.get_sirens_near(
                warning["latitude"], warning["longitude"],
                max_km=warning.get("radius_km", 25.0),
            )
            for siren in nearby_sirens:
                if siren["status"] in ("offline", "maintenance"):
                    continue
                siren_db.log_activation(
                    siren_id=siren["id"],
                    warning_id=warning["id"],
                    trigger_type="auto",
                    triggered_by="broadcast_warning",
                    status="triggered",
                )
                siren_db.update_siren_status(siren["id"], "active")
                result.sirens_triggered += 1
                logger.info(
                    "Siren %s (%s) auto-triggered for warning %s",
                    siren["id"], siren["name"], warning["id"],
                )
        except Exception as exc:
            logger.error("Siren auto-trigger failed: %s", exc)

    return result


def get_warnings_for_location(
    latitude: float,
    longitude: float,
    active_warnings: list[WarningRecord],
) -> list[WarningRecord]:
    return [
        w for w in active_warnings
        if is_point_in_radius(latitude, longitude, w["latitude"], w["longitude"], w["radius_km"])
    ]


async def broadcast_flood_report(report: dict) -> dict:
    """Fan-out a validated flood report to nearby users via FCM and Twilio SMS."""
    from app.core.geo import haversine
    from app.db.preparedness import get_nearest_evacuation_centre
    from app.services.twilio_service import send_flood_alert

    report_lat  = report["latitude"]
    report_lon  = report["longitude"]
    if report_lat is None or report_lon is None:
        logger.warning("Skipping broadcast for report %s — no coordinates", report["id"])
        return {"total_affected": 0, "push_sent": 0, "sms_sent": 0}
    radius_km   = 10.0
    event_id    = report["id"]

    nearest = get_nearest_evacuation_centre(report_lat, report_lon)

    title = "FLOOD ALERT"
    body  = f"Flood reported at {report.get('location_name', 'nearby area')}."
    data  = {
        "report_id":   report["id"],
        "report_type": report.get("report_type", ""),
        "latitude":    str(report_lat),
        "longitude":   str(report_lon),
    }

    push_sent = sms_sent = total = 0

    for device in device_db.get_all_devices_with_location():
        if device["latitude"] is None or device["longitude"] is None:
            continue
        dist = haversine(device["latitude"], device["longitude"], report_lat, report_lon)
        if dist > radius_km:
            continue

        total += 1
        dist_msg = f"{body} ({dist:.1f} km from you)"

        if device.get("fcm_token"):
            if _send_push(device["fcm_token"], title, dist_msg, data):
                push_sent += 1
        elif device.get("phone_number"):
            shelter_name = nearest["name"] if nearest else ""
            shelter_phone = nearest["contact_phone"] if nearest else ""
            shelter_dist = nearest["distance_km"] if nearest else None
            sent = send_flood_alert(
                phone_number=device["phone_number"],
                user_id=device["user_id"],
                location_name=report.get("location_name", "nearby area"),
                distance_km=dist,
                shelter_name=shelter_name,
                shelter_phone=shelter_phone,
                shelter_distance_km=shelter_dist,
                event_id=event_id,
            )
            if sent:
                sms_sent += 1
        else:
            logger.warning("User %s near flood but has no notification channel", device["user_id"])

    logger.info("Flood report %s broadcast: %d affected, %d push, %d SMS", report["id"], total, push_sent, sms_sent)
    return {"total_affected": total, "push_sent": push_sent, "sms_sent": sms_sent}
