from datetime import datetime
from typing import Optional
from pydantic import BaseModel


class AppointmentCreate(BaseModel):
    patient_id: str
    scheduled_at: datetime
    duration_minutes: int = 30
    notes: Optional[str] = None


class AppointmentOut(BaseModel):
    id: str
    doctor_id: str
    patient_id: str
    patient_name: str
    scheduled_at: datetime
    duration_minutes: int
    status: str
    notes: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class AppointmentUpdate(BaseModel):
    status: str  # scheduled, completed, cancelled, no_show
