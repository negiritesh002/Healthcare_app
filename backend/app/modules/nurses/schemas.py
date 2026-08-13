from datetime import datetime
from typing import Optional
from pydantic import BaseModel


class NurseOut(BaseModel):
    id: str
    full_name: str
    ward_department: str
    duty_status: str
    phone: Optional[str] = None

    class Config:
        from_attributes = True


class NurseAssignmentCreate(BaseModel):
    patient_id: str
    notes: Optional[str] = None


class NurseAssignmentOut(BaseModel):
    id: str
    nurse_id: str
    nurse_name: str
    patient_id: str
    patient_name: str
    doctor_id: str
    assigned_at: datetime
    notes: Optional[str] = None

    class Config:
        from_attributes = True
