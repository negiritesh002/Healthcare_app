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
from app.modules.pharmacy.models import Medicine, Prescription, PrescriptionItem
from app.modules.pharmacy.schemas import (
    MedicineOut,
    PrescriptionCreate,
    PrescriptionOut,
    PrescriptionItemOut,
    PrescriptionUpdate,
)

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/medicines", response_model=list[MedicineOut])
async def list_medicines(
    db: AsyncSession = Depends(get_db),
):
    """
    List practice-wide medicine inventory (shared across doctors).
    """
    stmt = select(Medicine).order_by(Medicine.name.asc())
    res = await db.execute(stmt)
    medicines = res.scalars().all()

    return [
        MedicineOut(
            id=str(m.id),
            name=m.name,
            category=m.category,
            unit=m.unit,
            stock_qty=m.stock_qty,
            low_stock_threshold=m.low_stock_threshold,
        )
        for m in medicines
    ]


@router.post("/prescriptions", response_model=PrescriptionOut, status_code=status.HTTP_201_CREATED)
async def create_prescription(
    req: PrescriptionCreate,
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
):
    """
    Create a new prescription with items for a patient.
    Validates patient_id ownership (returns 404 if not owned by current_doctor).
    Validates each medicine_id exists.
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

    # Validate each medicine_id exists
    items_to_create = []
    for item_req in req.items:
        try:
            med_uuid = UUID(item_req.medicine_id)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid medicine ID: {item_req.medicine_id}"
            )
        stmt_m = select(Medicine).where(Medicine.id == med_uuid)
        res_m = await db.execute(stmt_m)
        med = res_m.scalar_one_or_none()
        if med is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Medicine not found for ID: {item_req.medicine_id}"
            )
        items_to_create.append((med_uuid, item_req.quantity, med.name))

    prescription = Prescription(
        doctor_id=current_doctor.id,
        patient_id=patient.id,
        status="pending_verification",
    )
    db.add(prescription)
    await db.flush()  # Flush to generate prescription.id

    out_items = []
    for med_uuid, qty, med_name in items_to_create:
        p_item = PrescriptionItem(
            prescription_id=prescription.id,
            medicine_id=med_uuid,
            quantity=qty,
        )
        db.add(p_item)
        await db.flush()
        out_items.append(
            PrescriptionItemOut(
                id=str(p_item.id),
                medicine_id=str(med_uuid),
                medicine_name=med_name,
                quantity=qty,
            )
        )

    await db.commit()
    await db.refresh(prescription)

    return PrescriptionOut(
        id=str(prescription.id),
        doctor_id=str(prescription.doctor_id),
        patient_id=str(prescription.patient_id),
        patient_name=patient.full_name,
        status=prescription.status,
        created_at=prescription.created_at,
        items=out_items,
    )


@router.get("/prescriptions", response_model=list[PrescriptionOut])
async def list_prescriptions(
    status_filter: Optional[str] = Query(None, alias="status"),
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
):
    """
    List prescriptions for current doctor, optionally filtered by status (pending_verification, approved, dispensed).
    """
    stmt = (
        select(Prescription)
        .options(
            joinedload(Prescription.patient),
            joinedload(Prescription.items).joinedload(PrescriptionItem.medicine),
        )
        .where(Prescription.doctor_id == current_doctor.id)
    )

    if status_filter:
        stmt = stmt.where(Prescription.status == status_filter.lower())

    stmt = stmt.order_by(Prescription.created_at.desc())
    res = await db.execute(stmt)
    prescriptions = res.scalars().unique().all()

    return [
        PrescriptionOut(
            id=str(p.id),
            doctor_id=str(p.doctor_id),
            patient_id=str(p.patient_id),
            patient_name=p.patient.full_name if p.patient else "Unknown Patient",
            status=p.status,
            created_at=p.created_at,
            items=[
                PrescriptionItemOut(
                    id=str(item.id),
                    medicine_id=str(item.medicine_id),
                    medicine_name=item.medicine.name if item.medicine else "Unknown Medicine",
                    quantity=item.quantity,
                )
                for item in p.items
            ],
        )
        for p in prescriptions
    ]


@router.get("/prescriptions/{id}", response_model=PrescriptionOut)
async def get_prescription_by_id(
    id: str,
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
):
    """
    Get single prescription detail. Returns 404 if not found or unowned.
    """
    try:
        p_uuid = UUID(id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Prescription not found"
        )

    stmt = (
        select(Prescription)
        .options(
            joinedload(Prescription.patient),
            joinedload(Prescription.items).joinedload(PrescriptionItem.medicine),
        )
        .where(
            Prescription.id == p_uuid,
            Prescription.doctor_id == current_doctor.id,
        )
    )
    res = await db.execute(stmt)
    prescription = res.unique().scalar_one_or_none()

    if prescription is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Prescription not found"
        )

    return PrescriptionOut(
        id=str(prescription.id),
        doctor_id=str(prescription.doctor_id),
        patient_id=str(prescription.patient_id),
        patient_name=prescription.patient.full_name if prescription.patient else "Unknown Patient",
        status=prescription.status,
        created_at=prescription.created_at,
        items=[
            PrescriptionItemOut(
                id=str(item.id),
                medicine_id=str(item.medicine_id),
                medicine_name=item.medicine.name if item.medicine else "Unknown Medicine",
                quantity=item.quantity,
            )
            for item in prescription.items
        ],
    )


@router.patch("/prescriptions/{id}", response_model=PrescriptionOut)
async def update_prescription_status(
    id: str,
    req: PrescriptionUpdate,
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
):
    """
    Update status of a prescription (pending_verification -> approved -> dispensed).
    When changing to 'dispensed', validates stock availability and decrements medicine stock atomically.
    """
    try:
        p_uuid = UUID(id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Prescription not found"
        )

    stmt = (
        select(Prescription)
        .options(
            joinedload(Prescription.patient),
            joinedload(Prescription.items).joinedload(PrescriptionItem.medicine),
        )
        .where(
            Prescription.id == p_uuid,
            Prescription.doctor_id == current_doctor.id,
        )
    )
    res = await db.execute(stmt)
    prescription = res.unique().scalar_one_or_none()

    if prescription is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Prescription not found"
        )

    target_status = req.status.lower()
    valid_statuses = {"pending_verification", "approved", "dispensed"}
    if target_status not in valid_statuses:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid status. Must be one of {valid_statuses}"
        )

    # Stock validation and decrement transaction logic when dispensing
    if target_status == "dispensed" and prescription.status != "dispensed":
        # 1. Stock availability validation
        for item in prescription.items:
            stmt_m = select(Medicine).where(Medicine.id == item.medicine_id).with_for_update()
            res_m = await db.execute(stmt_m)
            med = res_m.scalar_one_or_none()

            if med is None:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Medicine not found for ID {item.medicine_id}"
                )

            if item.quantity > med.stock_qty:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Insufficient stock for {med.name}. Available: {med.stock_qty}, requested: {item.quantity}"
                )

        # 2. Decrement stock
        for item in prescription.items:
            stmt_m = select(Medicine).where(Medicine.id == item.medicine_id).with_for_update()
            res_m = await db.execute(stmt_m)
            med = res_m.scalar_one()
            med.stock_qty -= item.quantity

    prescription.status = target_status
    await db.commit()
    await db.refresh(prescription)

    return PrescriptionOut(
        id=str(prescription.id),
        doctor_id=str(prescription.doctor_id),
        patient_id=str(prescription.patient_id),
        patient_name=prescription.patient.full_name if prescription.patient else "Unknown Patient",
        status=prescription.status,
        created_at=prescription.created_at,
        items=[
            PrescriptionItemOut(
                id=str(item.id),
                medicine_id=str(item.medicine_id),
                medicine_name=item.medicine.name if item.medicine else "Unknown Medicine",
                quantity=item.quantity,
            )
            for item in prescription.items
        ],
    )
