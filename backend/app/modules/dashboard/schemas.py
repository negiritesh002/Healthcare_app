from datetime import datetime
from pydantic import BaseModel


class RecentPatientSummary(BaseModel):
    id: str
    full_name: str
    reason: str
    appointment_time: datetime

    class Config:
        from_attributes = True


class DashboardStats(BaseModel):
    appointments_today: int
    pending_reports: int
    recent_patients: list[RecentPatientSummary]
