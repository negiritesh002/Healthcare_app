import logging
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
import redis.asyncio as aioredis

from app.db.session import get_db
from app.core.redis_client import get_redis
from app.shared.dependencies import get_current_doctor
from app.modules.auth.models import Doctor
from app.modules.patients.models import Patient
from app.modules.patients.schemas import PatientCreate, PatientOut, PatientListItem

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("", response_model=PatientOut, status_code=status.HTTP_201_CREATED)
async def create_patient(
    req: PatientCreate,
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
    redis: aioredis.Redis = Depends(get_redis),
):
    """
    Create a new patient record for the logged-in doctor.
    Invalidates the doctor's dashboard_stats cache key in Redis.
    """
    patient = Patient(
        doctor_id=current_doctor.id,
        full_name=req.full_name,
        date_of_birth=req.date_of_birth,
        gender=req.gender,
        phone=req.phone,
        email=req.email,
        chief_complaint=req.chief_complaint,
        severity=req.severity,
    )
    db.add(patient)
    await db.commit()
    await db.refresh(patient)

    # Invalidate dashboard cache key for this doctor
    cache_key = f"dashboard_stats:{current_doctor.id}"
    await redis.delete(cache_key)
    logger.info(f"========== [REDIS CACHE INVALIDATED] {cache_key} ==========")

    return PatientOut(
        id=str(patient.id),
        doctor_id=str(patient.doctor_id),
        full_name=patient.full_name,
        date_of_birth=patient.date_of_birth,
        gender=patient.gender,
        phone=patient.phone,
        email=patient.email,
        chief_complaint=patient.chief_complaint,
        severity=patient.severity,
        created_at=patient.created_at,
    )


@router.get("", response_model=list[PatientListItem])
async def list_patients(
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
):
    """
    List paginated patients belonging ONLY to the requesting doctor.
    """
    stmt = (
        select(Patient)
        .where(Patient.doctor_id == current_doctor.id)
        .order_by(Patient.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    res = await db.execute(stmt)
    patients = res.scalars().all()

    return [
        PatientListItem(
            id=str(p.id),
            full_name=p.full_name,
            chief_complaint=p.chief_complaint,
            severity=p.severity,
            created_at=p.created_at,
        )
        for p in patients
    ]


@router.get("/{id}", response_model=PatientOut)
async def get_patient_by_id(
    id: str,
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
):
    """
    Get single patient detail.
    Strictly isolated: returns HTTP 404 if not found OR not owned by requesting doctor.
    """
    try:
        patient_uuid = UUID(id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Patient not found"
        )

    stmt = select(Patient).where(
        Patient.id == patient_uuid,
        Patient.doctor_id == current_doctor.id,
    )
    res = await db.execute(stmt)
    patient = res.scalar_one_or_none()

    if patient is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Patient not found"
        )

    return PatientOut(
        id=str(patient.id),
        doctor_id=str(patient.doctor_id),
        full_name=patient.full_name,
        date_of_birth=patient.date_of_birth,
        gender=patient.gender,
        phone=patient.phone,
        email=patient.email,
        chief_complaint=patient.chief_complaint,
        severity=patient.severity,
        created_at=patient.created_at,
    )
