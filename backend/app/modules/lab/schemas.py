from datetime import datetime
from typing import Optional
from pydantic import BaseModel


class LabOrderCreate(BaseModel):
    patient_id: str
    test_type: str
    notes: Optional[str] = None


class LabOrderOut(BaseModel):
    id: str
    doctor_id: str
    patient_id: str
    patient_name: str
    test_type: str
    status: str
    requested_at: datetime
    result_notes: Optional[str] = None
    result_file_url: Optional[str] = None

    class Config:
        from_attributes = True


class LabOrderUpdate(BaseModel):
    status: str  # pending, in_progress, completed
    result_notes: Optional[str] = None
