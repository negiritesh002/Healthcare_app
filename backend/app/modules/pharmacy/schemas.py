from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field


class MedicineOut(BaseModel):
    id: str
    name: str
    category: str
    unit: str
    stock_qty: int
    low_stock_threshold: int

    class Config:
        from_attributes = True


class PrescriptionItemCreate(BaseModel):
    medicine_id: str
    quantity: int = Field(gt=0)


class PrescriptionItemOut(BaseModel):
    id: str
    medicine_id: str
    medicine_name: str
    quantity: int

    class Config:
        from_attributes = True


class PrescriptionCreate(BaseModel):
    patient_id: str
    items: List[PrescriptionItemCreate] = Field(min_items=1)


class PrescriptionOut(BaseModel):
    id: str
    doctor_id: str
    patient_id: str
    patient_name: str
    status: str
    created_at: datetime
    items: List[PrescriptionItemOut]

    class Config:
        from_attributes = True


class PrescriptionUpdate(BaseModel):
    status: str  # pending_verification, approved, dispensed
