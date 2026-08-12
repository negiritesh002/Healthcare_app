from uuid import UUID
from datetime import datetime
from pydantic import BaseModel, Field


class SendOTPRequest(BaseModel):
    phone: str = Field(..., description="Phone number with country code, e.g. +1234567890")


class VerifyOTPRequest(BaseModel):
    phone: str = Field(..., description="Phone number with country code")
    otp_code: str = Field(..., min_length=6, max_length=6, description="6-digit OTP code")


class SignupRequest(BaseModel):
    full_name: str = Field(..., min_length=2, max_length=255)
    phone: str = Field(..., description="Verified phone number")
    medical_specialty: str = Field(..., min_length=2, max_length=255)
    hospital_clinic_address: str = Field(..., min_length=5, max_length=500)
    medical_license_number: str = Field(..., min_length=3, max_length=100)


class DoctorOut(BaseModel):
    id: UUID
    full_name: str
    phone: str
    medical_specialty: str
    hospital_clinic_address: str
    medical_license_number: str
    created_at: datetime

    class Config:
        from_attributes = True


class VerifyOTPResponse(BaseModel):
    exists: bool
    access_token: str | None = None
    token_type: str | None = None
    doctor: DoctorOut | None = None


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    doctor: DoctorOut
