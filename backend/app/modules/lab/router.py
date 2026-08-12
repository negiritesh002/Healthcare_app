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
from app.modules.lab.models import LabOrder
from app.modules.lab.schemas import LabOrderCreate, LabOrderOut, LabOrderUpdate

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/orders", response_model=LabOrderOut, status_code=status.HTTP_201_CREATED)
async def create_lab_order(
    req: LabOrderCreate,
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
):
    """
    Create a new lab order for a patient.
    Validates patient_id ownership (returns 404 if patient not owned by current_doctor).
    """
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

    order = LabOrder(
        doctor_id=current_doctor.id,
        patient_id=patient.id,
        test_type=req.test_type,
        status="pending",
        result_notes=req.notes,
    )
    db.add(order)
    await db.commit()
    await db.refresh(order)

    return LabOrderOut(
        id=str(order.id),
        doctor_id=str(order.doctor_id),
        patient_id=str(order.patient_id),
        patient_name=patient.full_name,
        test_type=order.test_type,
        status=order.status,
        requested_at=order.requested_at,
        result_notes=order.result_notes,
        result_file_url=order.result_file_url,
    )


@router.get("/orders", response_model=list[LabOrderOut])
async def list_lab_orders(
    status_filter: Optional[str] = Query(None, alias="status"),
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
):
    """
    List lab orders for current doctor, optionably filtered by status (pending, in_progress, completed).
    """
    stmt = (
        select(LabOrder)
        .options(joinedload(LabOrder.patient))
        .where(LabOrder.doctor_id == current_doctor.id)
    )

    if status_filter:
        stmt = stmt.where(LabOrder.status == status_filter.lower())

    stmt = stmt.order_by(LabOrder.requested_at.desc())
    res = await db.execute(stmt)
    orders = res.scalars().unique().all()

    return [
        LabOrderOut(
            id=str(o.id),
            doctor_id=str(o.doctor_id),
            patient_id=str(o.patient_id),
            patient_name=o.patient.full_name if o.patient else "Unknown Patient",
            test_type=o.test_type,
            status=o.status,
            requested_at=o.requested_at,
            result_notes=o.result_notes,
            result_file_url=o.result_file_url,
        )
        for o in orders
    ]


@router.get("/orders/{id}", response_model=LabOrderOut)
async def get_lab_order_by_id(
    id: str,
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
):
    """
    Get single lab order details. Returns 404 if not found or not owned by requesting doctor.
    """
    try:
        order_uuid = UUID(id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Lab order not found"
        )

    stmt = (
        select(LabOrder)
        .options(joinedload(LabOrder.patient))
        .where(
            LabOrder.id == order_uuid,
            LabOrder.doctor_id == current_doctor.id,
        )
    )
    res = await db.execute(stmt)
    order = res.scalar_one_or_none()

    if order is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Lab order not found"
        )

    return LabOrderOut(
        id=str(order.id),
        doctor_id=str(order.doctor_id),
        patient_id=str(order.patient_id),
        patient_name=order.patient.full_name if order.patient else "Unknown Patient",
        test_type=order.test_type,
        status=order.status,
        requested_at=order.requested_at,
        result_notes=order.result_notes,
        result_file_url=order.result_file_url,
    )


@router.patch("/orders/{id}", response_model=LabOrderOut)
async def update_lab_order_status(
    id: str,
    req: LabOrderUpdate,
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
):
    """
    Update status (pending -> in_progress -> completed) and optional result notes of a lab order.
    """
    try:
        order_uuid = UUID(id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Lab order not found"
        )

    stmt = (
        select(LabOrder)
        .options(joinedload(LabOrder.patient))
        .where(
            LabOrder.id == order_uuid,
            LabOrder.doctor_id == current_doctor.id,
        )
    )
    res = await db.execute(stmt)
    order = res.scalar_one_or_none()

    if order is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Lab order not found"
        )

    valid_statuses = {"pending", "in_progress", "completed"}
    if req.status.lower() not in valid_statuses:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid status. Must be one of {valid_statuses}"
        )

    order.status = req.status.lower()
    if req.result_notes is not None:
        order.result_notes = req.result_notes

    await db.commit()
    await db.refresh(order)

    return LabOrderOut(
        id=str(order.id),
        doctor_id=str(order.doctor_id),
        patient_id=str(order.patient_id),
        patient_name=order.patient.full_name if order.patient else "Unknown Patient",
        test_type=order.test_type,
        status=order.status,
        requested_at=order.requested_at,
        result_notes=order.result_notes,
        result_file_url=order.result_file_url,
    )
