from datetime import datetime
from typing import Optional
from pydantic import BaseModel


class AmbulanceOut(BaseModel):
    id: str
    unit_code: str
    status: str
    current_location: Optional[str] = None

    class Config:
        from_attributes = True


class DispatchRequestCreate(BaseModel):
    patient_id: str
    pickup_location: str


class DispatchRequestOut(BaseModel):
    id: str
    ambulance_id: Optional[str] = None
    unit_code: Optional[str] = None
    patient_id: str
    patient_name: str
    doctor_id: str
    pickup_location: str
    status: str
    requested_at: datetime

    class Config:
        from_attributes = True


class DispatchRequestUpdate(BaseModel):
    status: str  # pending, dispatched, completed
