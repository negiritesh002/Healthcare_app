import logging
from uuid import UUID
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import joinedload

from app.db.session import get_db
from app.shared.dependencies import get_current_doctor
from app.modules.auth.models import Doctor
from app.modules.patients.models import Patient
from app.modules.ambulance.models import Ambulance, DispatchRequest
from app.modules.ambulance.schemas import (
    AmbulanceOut,
    DispatchRequestCreate,
    DispatchRequestOut,
    DispatchRequestUpdate,
)

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/units", response_model=list[AmbulanceOut])
async def list_ambulance_units(
    db: AsyncSession = Depends(get_db),
):
    """
    List practice-wide ambulance fleet (shared across doctors).
    """
    stmt = select(Ambulance).order_by(Ambulance.unit_code.asc())
    res = await db.execute(stmt)
    units = res.scalars().all()

    return [
        AmbulanceOut(
            id=str(u.id),
            unit_code=u.unit_code,
            status=u.status,
            current_location=u.current_location,
        )
        for u in units
    ]


@router.post("/dispatch", response_model=DispatchRequestOut, status_code=status.HTTP_201_CREATED)
async def dispatch_ambulance(
    req: DispatchRequestCreate,
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
):
    """
    Create a new ambulance dispatch request.
    Validates patient_id ownership (returns 404 if not owned by current_doctor).
    Auto-assigns first available unit using row locking (with_for_update(skip_locked=True)).
    If no unit is available, creates a pending request with ambulance_id=None.
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
        Patient.doctor_id == current_doctor.id,
    )
    res_p = await db.execute(stmt_p)
    patient = res_p.scalar_one_or_none()

    if patient is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Patient not found"
        )

    # Concurrency-safe row locking auto-assignment query
    stmt_u = (
        select(Ambulance)
        .where(Ambulance.status == "available")
        .with_for_update(skip_locked=True)
        .limit(1)
    )
    res_u = await db.execute(stmt_u)
    available_unit = res_u.scalar_one_or_none()

    if available_unit is not None:
        assigned_ambulance_id = available_unit.id
        unit_code = available_unit.unit_code
        available_unit.status = "en_route"
        dispatch_status = "dispatched"
    else:
        assigned_ambulance_id = None
        unit_code = None
        dispatch_status = "pending"

    dispatch = DispatchRequest(
        doctor_id=current_doctor.id,
        patient_id=patient.id,
        ambulance_id=assigned_ambulance_id,
        pickup_location=req.pickup_location,
        status=dispatch_status,
    )
    db.add(dispatch)
    await db.commit()
    await db.refresh(dispatch)

    return DispatchRequestOut(
        id=str(dispatch.id),
        ambulance_id=str(dispatch.ambulance_id) if dispatch.ambulance_id else None,
        unit_code=unit_code,
        patient_id=str(patient.id),
        patient_name=patient.full_name,
        doctor_id=str(current_doctor.id),
        pickup_location=dispatch.pickup_location,
        status=dispatch.status,
        requested_at=dispatch.requested_at,
    )


@router.get("/dispatches", response_model=list[DispatchRequestOut])
async def list_dispatch_requests(
    status_filter: Optional[str] = Query(None, alias="status"),
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
):
    """
    List ambulance dispatch requests for current doctor.
    """
    stmt = (
        select(DispatchRequest)
        .options(
            joinedload(DispatchRequest.patient),
            joinedload(DispatchRequest.ambulance),
        )
        .where(DispatchRequest.doctor_id == current_doctor.id)
    )

    if status_filter:
        stmt = stmt.where(DispatchRequest.status == status_filter.lower())

    stmt = stmt.order_by(DispatchRequest.requested_at.desc())
    res = await db.execute(stmt)
    dispatches = res.scalars().unique().all()

    return [
        DispatchRequestOut(
            id=str(d.id),
            ambulance_id=str(d.ambulance_id) if d.ambulance_id else None,
            unit_code=d.ambulance.unit_code if d.ambulance else None,
            patient_id=str(d.patient_id),
            patient_name=d.patient.full_name if d.patient else "Unknown Patient",
            doctor_id=str(d.doctor_id),
            pickup_location=d.pickup_location,
            status=d.status,
            requested_at=d.requested_at,
        )
        for d in dispatches
    ]


@router.get("/dispatch/{id}", response_model=DispatchRequestOut)
async def get_dispatch_by_id(
    id: str,
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
):
    """
    Get single dispatch request detail. Returns 404 if unowned or not found.
    """
    try:
        d_uuid = UUID(id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Dispatch request not found"
        )

    stmt = (
        select(DispatchRequest)
        .options(
            joinedload(DispatchRequest.patient),
            joinedload(DispatchRequest.ambulance),
        )
        .where(
            DispatchRequest.id == d_uuid,
            DispatchRequest.doctor_id == current_doctor.id,
        )
    )
    res = await db.execute(stmt)
    dispatch = res.unique().scalar_one_or_none()

    if dispatch is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Dispatch request not found"
        )

    return DispatchRequestOut(
        id=str(dispatch.id),
        ambulance_id=str(dispatch.ambulance_id) if dispatch.ambulance_id else None,
        unit_code=dispatch.ambulance.unit_code if dispatch.ambulance else None,
        patient_id=str(dispatch.patient_id),
        patient_name=dispatch.patient.full_name if dispatch.patient else "Unknown Patient",
        doctor_id=str(dispatch.doctor_id),
        pickup_location=dispatch.pickup_location,
        status=dispatch.status,
        requested_at=dispatch.requested_at,
    )


@router.patch("/dispatch/{id}", response_model=DispatchRequestOut)
async def update_dispatch_status(
    id: str,
    req: DispatchRequestUpdate,
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
):
    """
    Update dispatch request status (pending -> dispatched -> completed).
    When status transitions to 'completed', releases assigned ambulance unit back to 'available'.
    """
    try:
        d_uuid = UUID(id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Dispatch request not found"
        )

    stmt = (
        select(DispatchRequest)
        .options(
            joinedload(DispatchRequest.patient),
            joinedload(DispatchRequest.ambulance),
        )
        .where(
            DispatchRequest.id == d_uuid,
            DispatchRequest.doctor_id == current_doctor.id,
        )
    )
    res = await db.execute(stmt)
    dispatch = res.unique().scalar_one_or_none()

    if dispatch is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Dispatch request not found"
        )

    target_status = req.status.lower()
    valid_statuses = {"pending", "dispatched", "completed"}
    if target_status not in valid_statuses:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid status. Must be one of {valid_statuses}"
        )

    # Release ambulance back to available when completed
    if target_status == "completed" and dispatch.status != "completed":
        if dispatch.ambulance_id is not None:
            stmt_a = select(Ambulance).where(Ambulance.id == dispatch.ambulance_id).with_for_update()
            res_a = await db.execute(stmt_a)
            unit = res_a.scalar_one_or_none()
            if unit:
                unit.status = "available"

    dispatch.status = target_status
    await db.commit()
    await db.refresh(dispatch)

    return DispatchRequestOut(
        id=str(dispatch.id),
        ambulance_id=str(dispatch.ambulance_id) if dispatch.ambulance_id else None,
        unit_code=dispatch.ambulance.unit_code if dispatch.ambulance else None,
        patient_id=str(dispatch.patient_id),
        patient_name=dispatch.patient.full_name if dispatch.patient else "Unknown Patient",
        doctor_id=str(dispatch.doctor_id),
        pickup_location=dispatch.pickup_location,
        status=dispatch.status,
        requested_at=dispatch.requested_at,
    )
