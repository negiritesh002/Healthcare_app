import logging
from uuid import UUID
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_, and_
from pydantic import BaseModel

from app.db.session import get_db
from app.shared.dependencies import get_current_doctor
from app.modules.auth.models import Doctor
from app.modules.messaging.models import Conversation

logger = logging.getLogger(__name__)

router = APIRouter()


class DoctorPublicOut(BaseModel):
    id: str
    full_name: str
    medical_specialty: str
    hospital_clinic_address: str
    medical_license_number: str
    phone: Optional[str] = None  # Hidden on public profile unless active conversation exists

    class Config:
        from_attributes = True


@router.get("", response_model=list[DoctorPublicOut])
async def list_team_doctors(
    specialty: Optional[str] = Query(None),
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
):
    """
    List all doctors in the practice EXCEPT the requesting doctor.
    Supports filtering by specialty.
    """
    stmt = select(Doctor).where(Doctor.id != current_doctor.id)

    if specialty and specialty.strip() and specialty.lower() != "all":
        stmt = stmt.where(Doctor.medical_specialty.ilike(f"%{specialty.strip()}%"))

    stmt = stmt.order_by(Doctor.full_name.asc())
    res = await db.execute(stmt)
    doctors = res.scalars().all()

    return [
        DoctorPublicOut(
            id=str(d.id),
            full_name=d.full_name,
            medical_specialty=d.medical_specialty,
            hospital_clinic_address=d.hospital_clinic_address,
            medical_license_number=d.medical_license_number,
            phone=None,  # Do not leak phone number in public list
        )
        for d in doctors
    ]


@router.get("/{id}", response_model=DoctorPublicOut)
async def get_doctor_profile_detail(
    id: str,
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
):
    """
    Get public profile view of another doctor.
    Hides phone number unless an active conversation exists between current_doctor and target doctor.
    """
    try:
        doc_uuid = UUID(id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Doctor not found"
        )

    stmt_d = select(Doctor).where(Doctor.id == doc_uuid)
    res_d = await db.execute(stmt_d)
    target_doctor = res_d.scalar_one_or_none()

    if target_doctor is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Doctor not found"
        )

    # Check if active conversation exists between current_doctor and target_doctor
    stmt_c = select(Conversation).where(
        or_(
            and_(Conversation.doctor_a_id == current_doctor.id, Conversation.doctor_b_id == doc_uuid),
            and_(Conversation.doctor_a_id == doc_uuid, Conversation.doctor_b_id == current_doctor.id),
        )
    )
    res_c = await db.execute(stmt_c)
    has_conversation = res_c.scalar_one_or_none() is not None

    return DoctorPublicOut(
        id=str(target_doctor.id),
        full_name=target_doctor.full_name,
        medical_specialty=target_doctor.medical_specialty,
        hospital_clinic_address=target_doctor.hospital_clinic_address,
        medical_license_number=target_doctor.medical_license_number,
        phone=target_doctor.phone if has_conversation else None,
    )
