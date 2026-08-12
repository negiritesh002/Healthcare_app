import logging
from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
import redis.asyncio as aioredis

from app.db.session import get_db
from app.core.redis_client import get_redis
from app.shared.dependencies import get_current_doctor
from app.modules.auth.models import Doctor
from app.modules.patients.models import Patient
from app.modules.appointments.models import Appointment, MedicalReport
from app.modules.dashboard.schemas import DashboardStats, RecentPatientSummary

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/stats", response_model=DashboardStats)
async def get_dashboard_stats(
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
    redis: aioredis.Redis = Depends(get_redis),
):
    """
    Get dashboard statistics for the logged-in doctor.
    Demonstrates Cache-Aside pattern using Redis (TTL: 30 seconds).
    Key: dashboard_stats:{doctor_id}
    """
    cache_key = f"dashboard_stats:{current_doctor.id}"

    # 1. Try reading from Redis cache
    cached_data = await redis.get(cache_key)
    if cached_data:
        logger.info(f"========== [REDIS CACHE HIT] {cache_key} ==========")
        return DashboardStats.model_validate_json(cached_data)

    logger.info(f"========== [REDIS CACHE MISS] Querying DB for {cache_key} ==========")

    # 2. Database query for appointments today
    now_utc = datetime.now(timezone.utc)
    today_start = now_utc.replace(hour=0, minute=0, second=0, microsecond=0)
    today_end = today_start + timedelta(days=1)

    stmt_appts = (
        select(func.count())
        .select_from(Appointment)
        .where(
            Appointment.doctor_id == current_doctor.id,
            Appointment.scheduled_at >= today_start,
            Appointment.scheduled_at < today_end,
            Appointment.status != "cancelled",
        )
    )
    appts_res = await db.execute(stmt_appts)
    appointments_today = appts_res.scalar() or 0

    # 3. Database query for pending reports
    stmt_reports = (
        select(func.count())
        .select_from(MedicalReport)
        .where(
            MedicalReport.doctor_id == current_doctor.id,
            MedicalReport.status == "pending",
        )
    )
    reports_res = await db.execute(stmt_reports)
    pending_reports = reports_res.scalar() or 0

    # 4. Database query for recent patients
    stmt_recent = (
        select(Patient)
        .where(Patient.doctor_id == current_doctor.id)
        .order_by(Patient.created_at.desc())
        .limit(5)
    )
    recent_res = await db.execute(stmt_recent)
    recent_patients = [
        RecentPatientSummary(
            id=str(p.id),
            full_name=p.full_name,
            reason=p.chief_complaint,
            appointment_time=p.created_at,
        )
        for p in recent_res.scalars().all()
    ]

    stats = DashboardStats(
        appointments_today=appointments_today,
        pending_reports=pending_reports,
        recent_patients=recent_patients,
    )

    # 5. Store in Redis cache for 30 seconds
    await redis.setex(cache_key, 30, stats.model_dump_json())

    return stats
