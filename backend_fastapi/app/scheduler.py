"""APScheduler background jobs.

Jobs:
  fetch_metmalaysia       every 5 minutes  — fetch gov flood warnings
  monitor_flood_reports   every 2 minutes  — send SMS for newly validated flood reports
  ai_validate_reports     every 3 minutes  — AI re-scores pending reports
  check_siren_auto_stop   every 1 minute   — auto-stop sirens whose warning expired
  expire_old_reports      daily at midnight

NOTE: The sync Supabase client calls are wrapped in asyncio.to_thread()
so they run in a thread pool and do NOT block the async event loop.
"""

from __future__ import annotations

import asyncio
import logging

from apscheduler.schedulers.asyncio import AsyncIOScheduler

logger = logging.getLogger(__name__)

scheduler = AsyncIOScheduler()


async def _job_fetch_metmalaysia() -> None:
    try:
        from app.services import met_malaysia
        n = await met_malaysia.fetch_and_store_warnings()
        logger.info("[scheduler] MetMalaysia: %d warnings stored", n)
    except Exception as exc:
        logger.error("[scheduler] MetMalaysia failed: %s", exc)


async def _job_monitor_flood_reports() -> None:
    """Send Twilio SMS flood alerts for reports validated in the last 2 minutes."""
    try:
        from app.services.notifications import broadcast_flood_report
        from app.db import reports as report_db

        recent = await asyncio.to_thread(
            report_db.get_validated_flood_reports_since, minutes=2
        )
        for report in recent:
            try:
                await broadcast_flood_report(report)
            except Exception as exc:
                logger.error(
                    "[scheduler] broadcast failed for report %s: %s",
                    report["id"], exc,
                )
    except Exception as exc:
        logger.error("[scheduler] monitor_flood_reports failed: %s", exc)


async def _job_expire_old_reports() -> None:
    try:
        from app.db import reports as report_db
        n = await asyncio.to_thread(report_db.expire_old_reports)
        logger.info("[scheduler] Expired %d old reports", n)
    except Exception as exc:
        logger.error("[scheduler] expire_old_reports failed: %s", exc)


async def _job_ai_validate_reports() -> None:
    """AI re-scores pending reports and auto-validates high-confidence ones."""
    try:
        from app.db import reports as report_db
        from app.db.risk_zones import get_all_risk_zones
        from app.core.geo import haversine
        from ai_models.services.inference import score_report
        from datetime import datetime, timezone

        pending = await asyncio.to_thread(report_db.get_pending_reports_for_ai_review)
        if not pending:
            return

        risk_zones = await asyncio.to_thread(get_all_risk_zones)
        validated = rejected = rescored = 0

        for report in pending:
            try:
                prox = 50.0
                r_lat, r_lon = report.get("latitude"), report.get("longitude")
                if r_lat and r_lon and risk_zones:
                    prox = min(
                        haversine(r_lat, r_lon, z["latitude"], z["longitude"])
                        for z in risk_zones
                    )

                user_count = await asyncio.to_thread(
                    report_db.count_user_reports, report["user_id"],
                )

                created = datetime.fromisoformat(
                    report["created_at"].replace("Z", "+00:00")
                )
                age_h = (datetime.now(timezone.utc) - created).total_seconds() / 3600

                ai = score_report(
                    vouch_count=report.get("vouch_count", 0),
                    description_length=len(report.get("description", "")),
                    has_precise_coords=bool(r_lat and r_lon),
                    report_age_hours=age_h,
                    reporter_total_reports=user_count,
                    proximity_to_risk_zone_km=prox,
                )

                score = ai["confidence_score"]
                await asyncio.to_thread(
                    report_db.update_confidence_score, report["id"], score,
                )
                rescored += 1

                if score >= 0.75 and report.get("vouch_count", 0) >= 1:
                    await asyncio.to_thread(
                        report_db.validate_report,
                        report["id"],
                        validated_by="ai-auto-validator",
                    )
                    validated += 1
                elif score < 0.3 and age_h > 6:
                    await asyncio.to_thread(
                        report_db.reject_report,
                        report["id"],
                        resolved_by="ai-auto-validator",
                        reason=f"Low AI confidence ({score:.2f}) and stale ({age_h:.0f}h old)",
                    )
                    rejected += 1
            except Exception as exc:
                logger.error("[scheduler] AI scoring failed for report %s: %s", report["id"], exc)

        logger.info(
            "[scheduler] AI review: %d rescored, %d auto-validated, %d auto-rejected",
            rescored, validated, rejected,
        )
    except Exception as exc:
        logger.error("[scheduler] ai_validate_reports failed: %s", exc)


async def _job_check_siren_auto_stop() -> None:
    """Auto-stop sirens whose triggering warning is no longer active."""
    try:
        from app.db import sirens as siren_db
        from app.db import warnings as warning_db

        active_sirens = await asyncio.to_thread(siren_db.list_sirens, status_filter="active")
        stopped = 0

        for siren in active_sirens:
            activations = await asyncio.to_thread(
                siren_db.get_active_activations, siren["id"],
            )
            should_stop = True
            for act in activations:
                if act.get("warning_id"):
                    w = await asyncio.to_thread(warning_db.get_warning, act["warning_id"])
                    if w and w.get("active", False):
                        should_stop = False
                        break
                else:
                    # Manual triggers stay active until manually stopped
                    should_stop = False
                    break

            if should_stop and activations:
                for act in activations:
                    await asyncio.to_thread(siren_db.stop_activation, act["id"])
                await asyncio.to_thread(siren_db.update_siren_status, siren["id"], "idle")
                stopped += 1
                logger.info("[scheduler] Auto-stopped siren %s (%s)", siren["id"], siren["name"])

        if stopped:
            logger.info("[scheduler] Siren auto-stop: %d sirens returned to idle", stopped)
    except Exception as exc:
        logger.error("[scheduler] check_siren_auto_stop failed: %s", exc)


def start_scheduler() -> None:
    scheduler.add_job(_job_fetch_metmalaysia,     "interval", minutes=5,  id="metmalaysia")
    scheduler.add_job(_job_monitor_flood_reports, "interval", minutes=2,  id="flood_monitor")
    scheduler.add_job(_job_ai_validate_reports,   "interval", minutes=3,  id="ai_validate")
    scheduler.add_job(_job_check_siren_auto_stop, "interval", minutes=1,  id="siren_auto_stop")
    scheduler.add_job(_job_expire_old_reports,    "cron",     hour=0, minute=0, id="expire")
    scheduler.start()
    logger.info("[scheduler] Started — 5 jobs registered")


def stop_scheduler() -> None:
    if scheduler.running:
        scheduler.shutdown(wait=False)
        logger.info("[scheduler] Stopped")
