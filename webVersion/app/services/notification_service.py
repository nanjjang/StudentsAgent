"""
NotificationService — Manages daily study reminders using APScheduler.
Stores schedules in memory (extend to DB for persistence).
"""

import logging
from datetime import datetime
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger

logger = logging.getLogger(__name__)

_scheduler: AsyncIOScheduler | None = None
_schedules: dict[str, dict] = {}        # session_id -> schedule info
_notification_log: list[dict] = []      # in-memory notification log


def get_scheduler() -> AsyncIOScheduler:
    global _scheduler
    if _scheduler is None:
        _scheduler = AsyncIOScheduler()
    return _scheduler


def start_scheduler():
    scheduler = get_scheduler()
    if not scheduler.running:
        scheduler.start()
        logger.info("APScheduler started")


def stop_scheduler():
    scheduler = get_scheduler()
    if scheduler.running:
        scheduler.shutdown()
        logger.info("APScheduler stopped")


def _send_notification(session_id: str, message: str):
    """Simulated notification send. Replace with push/email/SMS in production."""
    entry = {
        "session_id": session_id,
        "message": message,
        "sent_at": datetime.now().isoformat(),
    }
    _notification_log.append(entry)
    logger.info(f"[NOTIFICATION] session={session_id}: {message}")


def schedule_notifications(
    session_id: str,
    message: str,
    time_str: str,        # "09:00"
    days: list[str],      # ["월", "화", "수", ...]
) -> dict:
    """Register daily notifications for a study session."""
    _day_to_cron = {
        "월": "mon", "화": "tue", "수": "wed",
        "목": "thu", "금": "fri", "토": "sat", "일": "sun",
    }

    scheduler = get_scheduler()
    hour, minute = map(int, time_str.split(":"))
    cron_days = ",".join(_day_to_cron[d] for d in days if d in _day_to_cron)

    job_id = f"notify_{session_id}"
    # Remove existing job if re-scheduling
    if scheduler.get_job(job_id):
        scheduler.remove_job(job_id)

    scheduler.add_job(
        _send_notification,
        CronTrigger(day_of_week=cron_days, hour=hour, minute=minute),
        args=[session_id, message],
        id=job_id,
        replace_existing=True,
    )

    _schedules[session_id] = {
        "session_id": session_id,
        "message": message,
        "time": time_str,
        "days": days,
        "job_id": job_id,
        "active": True,
    }

    logger.info(f"Scheduled notifications for session {session_id} at {time_str} on {days}")
    return _schedules[session_id]


def cancel_notifications(session_id: str) -> bool:
    scheduler = get_scheduler()
    job_id = f"notify_{session_id}"
    if scheduler.get_job(job_id):
        scheduler.remove_job(job_id)
        if session_id in _schedules:
            _schedules[session_id]["active"] = False
        return True
    return False


def get_schedule(session_id: str) -> dict | None:
    return _schedules.get(session_id)


def get_notification_log(session_id: str | None = None) -> list[dict]:
    if session_id:
        return [n for n in _notification_log if n["session_id"] == session_id]
    return list(_notification_log)
