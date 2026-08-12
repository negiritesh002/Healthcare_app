from datetime import datetime
from typing import Optional
from pydantic import BaseModel, EmailStr


class PatientCreate(BaseModel):
    full_name: str
    date_of_birth: str
    gender: str
    phone: Optional[str] = None
    email: Optional[str] = None
    chief_complaint: str
    severity: str = "low"  # low, medium, high, critical


class PatientOut(BaseModel):
    id: str
    doctor_id: str
    full_name: str
    date_of_birth: str
    gender: str
    phone: Optional[str] = None
    email: Optional[str] = None
    chief_complaint: str
    severity: str
    created_at: datetime

    class Config:
        from_attributes = True


class PatientListItem(BaseModel):
    id: str
    full_name: str
    chief_complaint: str
    severity: str
    created_at: datetime

    class Config:
        from_attributes = True
