import logging
from datetime import datetime, date as date_type, time as time_type, timezone
from uuid import UUID
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import joinedload
import redis.asyncio as aioredis

from app.db.session import get_db
from app.core.redis_client import get_redis
from app.shared.dependencies import get_current_doctor
from app.modules.auth.models import Doctor
from app.modules.patients.models import Patient
from app.modules.appointments.models import Appointment
from app.modules.appointments.schemas import AppointmentCreate, AppointmentOut, AppointmentUpdate

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("", response_model=AppointmentOut, status_code=status.HTTP_201_CREATED)
async def create_appointment(
    req: AppointmentCreate,
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
    redis: aioredis.Redis = Depends(get_redis),
):
    """
    Create an appointment.
    Validates that patient_id belongs to the requesting doctor (returns 404 if unowned).
    Invalidates dashboard_stats:{doctor_id} Redis cache key.
    """
    try:
        patient_uuid = UUID(req.patient_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Patient not found"
        )

    # Doctor isolation check on patient_id
    stmt_p = select(Patient).where(
        Patient.id == patient_uuid,
        Patient.doctor_id == current_doctor.id
    )
    res_p = await db.execute(stmt_p)
    patient = res_p.scalar_one_or_none()

    if patient is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Patient not found"
        )

    appointment = Appointment(
        doctor_id=current_doctor.id,
        patient_id=patient.id,
        scheduled_at=req.scheduled_at,
        appointment_time=req.scheduled_at,
        duration_minutes=req.duration_minutes,
        notes=req.notes,
        status="scheduled",
    )
    db.add(appointment)
    await db.commit()
    await db.refresh(appointment)

    # Invalidate dashboard cache
    cache_key = f"dashboard_stats:{current_doctor.id}"
    await redis.delete(cache_key)
    logger.info(f"========== [REDIS CACHE INVALIDATED] {cache_key} ==========")

    return AppointmentOut(
        id=str(appointment.id),
        doctor_id=str(appointment.doctor_id),
        patient_id=str(appointment.patient_id),
        patient_name=patient.full_name,
        scheduled_at=appointment.scheduled_at,
        duration_minutes=appointment.duration_minutes,
        status=appointment.status,
        notes=appointment.notes,
        created_at=appointment.created_at,
    )


@router.get("", response_model=list[AppointmentOut])
async def list_appointments(
    date_str: Optional[str] = Query(None, alias="date"),
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
):
    """
    List appointments for current doctor, optionally filtered by date (YYYY-MM-DD).
    Sorted by scheduled_at ascending.
    """
    stmt = (
        select(Appointment)
        .options(joinedload(Appointment.patient))
        .where(Appointment.doctor_id == current_doctor.id)
    )

    if date_str:
        try:
            target_date = date_type.fromisoformat(date_str)
            start_dt = datetime.combine(target_date, time_type.min, tzinfo=timezone.utc)
            end_dt = datetime.combine(target_date, time_type.max, tzinfo=timezone.utc)
            stmt = stmt.where(
                Appointment.scheduled_at >= start_dt,
                Appointment.scheduled_at <= end_dt,
            )
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid date format, expected YYYY-MM-DD"
            )

    stmt = stmt.order_by(Appointment.scheduled_at.asc())
    res = await db.execute(stmt)
    appointments = res.scalars().unique().all()

    return [
        AppointmentOut(
            id=str(a.id),
            doctor_id=str(a.doctor_id),
            patient_id=str(a.patient_id),
            patient_name=a.patient.full_name if a.patient else "Unknown Patient",
            scheduled_at=a.scheduled_at,
            duration_minutes=a.duration_minutes,
            status=a.status,
            notes=a.notes,
            created_at=a.created_at,
        )
        for a in appointments
    ]


@router.get("/{id}", response_model=AppointmentOut)
async def get_appointment_by_id(
    id: str,
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
):
    """
    Get single appointment detail.
    Returns 404 if not found or unowned.
    """
    try:
        apt_uuid = UUID(id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Appointment not found"
        )

    stmt = (
        select(Appointment)
        .options(joinedload(Appointment.patient))
        .where(
            Appointment.id == apt_uuid,
            Appointment.doctor_id == current_doctor.id,
        )
    )
    res = await db.execute(stmt)
    appointment = res.scalar_one_or_none()

    if appointment is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Appointment not found"
        )

    return AppointmentOut(
        id=str(appointment.id),
        doctor_id=str(appointment.doctor_id),
        patient_id=str(appointment.patient_id),
        patient_name=appointment.patient.full_name if appointment.patient else "Unknown Patient",
        scheduled_at=appointment.scheduled_at,
        duration_minutes=appointment.duration_minutes,
        status=appointment.status,
        notes=appointment.notes,
        created_at=appointment.created_at,
    )


@router.patch("/{id}", response_model=AppointmentOut)
async def update_appointment_status(
    id: str,
    req: AppointmentUpdate,
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
    redis: aioredis.Redis = Depends(get_redis),
):
    """
    Update appointment status (scheduled, completed, cancelled, no_show).
    Invalidates dashboard_stats:{doctor_id} Redis cache key.
    """
    try:
        apt_uuid = UUID(id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Appointment not found"
        )

    stmt = (
        select(Appointment)
        .options(joinedload(Appointment.patient))
        .where(
            Appointment.id == apt_uuid,
            Appointment.doctor_id == current_doctor.id,
        )
    )
    res = await db.execute(stmt)
    appointment = res.scalar_one_or_none()

    if appointment is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Appointment not found"
        )

    valid_statuses = {"scheduled", "completed", "cancelled", "no_show"}
    if req.status.lower() not in valid_statuses:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid status. Must be one of {valid_statuses}"
        )

    appointment.status = req.status.lower()
    await db.commit()
    await db.refresh(appointment)

    # Invalidate dashboard cache key on status change
    cache_key = f"dashboard_stats:{current_doctor.id}"
    await redis.delete(cache_key)
    logger.info(f"========== [REDIS CACHE INVALIDATED] {cache_key} ==========")

    return AppointmentOut(
        id=str(appointment.id),
        doctor_id=str(appointment.doctor_id),
        patient_id=str(appointment.patient_id),
        patient_name=appointment.patient.full_name if appointment.patient else "Unknown Patient",
        scheduled_at=appointment.scheduled_at,
        duration_minutes=appointment.duration_minutes,
        status=appointment.status,
        notes=appointment.notes,
        created_at=appointment.created_at,
    )
