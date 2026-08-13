import logging
from uuid import UUID
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import joinedload

from app.db.session import get_db
from app.shared.dependencies import get_current_doctor
from app.modules.auth.models import Doctor
from app.modules.patients.models import Patient
from app.modules.nurses.models import Nurse, NurseAssignment
from app.modules.nurses.schemas import NurseOut, NurseAssignmentCreate, NurseAssignmentOut

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("", response_model=list[NurseOut])
async def list_nurses(
    db: AsyncSession = Depends(get_db),
):
    """
    List practice-wide nurse staff directory (shared across all doctors).
    """
    stmt = select(Nurse).order_by(Nurse.full_name.asc())
    res = await db.execute(stmt)
    nurses = res.scalars().all()

    return [
        NurseOut(
            id=str(n.id),
            full_name=n.full_name,
            ward_department=n.ward_department,
            duty_status=n.duty_status,
            phone=n.phone,
        )
        for n in nurses
    ]


@router.post("/{id}/assign", response_model=NurseAssignmentOut, status_code=status.HTTP_201_CREATED)
async def assign_nurse(
    id: str,
    req: NurseAssignmentCreate,
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
):
    """
    Assign a nurse to a patient.
    Validates patient_id ownership (returns 404 if not owned by current_doctor).
    Updates nurse duty_status to 'busy'.
    """
    try:
        nurse_uuid = UUID(id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Nurse not found"
        )

    # 1. Fetch Nurse
    stmt_n = select(Nurse).where(Nurse.id == nurse_uuid)
    res_n = await db.execute(stmt_n)
    nurse = res_n.scalar_one_or_none()
    if nurse is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Nurse not found"
        )

    # 2. Validate Patient ownership (Doctor isolation check)
    try:
        patient_uuid = UUID(req.patient_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Patient not found"
        )

    stmt_p = select(Patient).where(
        Patient.id == patient_uuid,
        Patient.doctor_id == current_doctor.id,
    )
    res_p = await db.execute(stmt_p)
    patient = res_p.scalar_one_or_none()

    if patient is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Patient not found"
        )

    # 3. Create Assignment & update nurse duty_status to busy
    assignment = NurseAssignment(
        nurse_id=nurse.id,
        patient_id=patient.id,
        doctor_id=current_doctor.id,
        notes=req.notes,
    )
    nurse.duty_status = "busy"

    db.add(assignment)
    await db.commit()
    await db.refresh(assignment)

    return NurseAssignmentOut(
        id=str(assignment.id),
        nurse_id=str(nurse.id),
        nurse_name=nurse.full_name,
        patient_id=str(patient.id),
        patient_name=patient.full_name,
        doctor_id=str(current_doctor.id),
        assigned_at=assignment.assigned_at,
        notes=assignment.notes,
    )


@router.get("/assignments", response_model=list[NurseAssignmentOut])
async def list_assignments(
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
):
    """
    List nurse assignments assigned by current doctor.
    """
    stmt = (
        select(NurseAssignment)
        .options(
            joinedload(NurseAssignment.nurse),
            joinedload(NurseAssignment.patient),
        )
        .where(NurseAssignment.doctor_id == current_doctor.id)
        .order_by(NurseAssignment.assigned_at.desc())
    )
    res = await db.execute(stmt)
    assignments = res.scalars().unique().all()

    return [
        NurseAssignmentOut(
            id=str(a.id),
            nurse_id=str(a.nurse_id),
            nurse_name=a.nurse.full_name if a.nurse else "Unknown Nurse",
            patient_id=str(a.patient_id),
            patient_name=a.patient.full_name if a.patient else "Unknown Patient",
            doctor_id=str(a.doctor_id),
            assigned_at=a.assigned_at,
            notes=a.notes,
        )
        for a in assignments
    ]
