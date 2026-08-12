import logging
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
import redis.asyncio as aioredis

from app.db.session import get_db
from app.core.redis_client import get_redis
from app.shared.dependencies import get_current_doctor
from app.modules.auth.models import Doctor
from app.modules.auth.schemas import (
    SendOTPRequest,
    VerifyOTPRequest,
    SignupRequest,
    VerifyOTPResponse,
    TokenResponse,
    DoctorOut,
)
from app.modules.auth.service import (
    generate_otp,
    store_otp,
    verify_otp,
    set_phone_verified,
    is_phone_verified,
    clear_phone_verified,
    create_access_token,
)

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/send-otp", status_code=status.HTTP_200_OK)
async def send_otp(
    req: SendOTPRequest,
    redis: aioredis.Redis = Depends(get_redis)
):
    code = generate_otp()
    await store_otp(redis, req.phone, code)
    logger.info(f"========== [DEV SMS MOCK] OTP for {req.phone}: {code} ==========")
    return {"message": "OTP sent successfully", "phone": req.phone}


@router.post("/verify-otp", response_model=VerifyOTPResponse)
async def verify_otp_endpoint(
    req: VerifyOTPRequest,
    db: AsyncSession = Depends(get_db),
    redis: aioredis.Redis = Depends(get_redis)
):
    is_valid = await verify_otp(redis, req.phone, req.otp_code)
    if not is_valid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired OTP code"
        )

    # Set short-lived verification flag for signup flow
    await set_phone_verified(redis, req.phone)

    # Check if doctor exists in DB
    stmt = select(Doctor).where(Doctor.phone == req.phone)
    result = await db.execute(stmt)
    doctor = result.scalar_one_or_none()

    if doctor is None:
        return VerifyOTPResponse(exists=False)

    token = create_access_token(doctor.id)
    return VerifyOTPResponse(
        exists=True,
        access_token=token,
        token_type="bearer",
        doctor=DoctorOut.model_validate(doctor)
    )


@router.post("/signup", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def signup(
    req: SignupRequest,
    db: AsyncSession = Depends(get_db),
    redis: aioredis.Redis = Depends(get_redis)
):
    # Verify phone was OTP-verified
    verified = await is_phone_verified(redis, req.phone)
    if not verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Phone number has not been verified with OTP"
        )

    # Check for existing doctor
    stmt = select(Doctor).where(Doctor.phone == req.phone)
    result = await db.execute(stmt)
    existing_doctor = result.scalar_one_or_none()
    if existing_doctor:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Doctor with this phone number is already registered"
        )

    # Create new Doctor record
    doctor = Doctor(
        full_name=req.full_name,
        phone=req.phone,
        medical_specialty=req.medical_specialty,
        hospital_clinic_address=req.hospital_clinic_address,
        medical_license_number=req.medical_license_number,
    )
    db.add(doctor)
    await db.commit()
    await db.refresh(doctor)

    # Clear verified flag from Redis
    await clear_phone_verified(redis, req.phone)

    token = create_access_token(doctor.id)
    return TokenResponse(
        access_token=token,
        token_type="bearer",
        doctor=DoctorOut.model_validate(doctor)
    )


@router.get("/me", response_model=DoctorOut)
async def get_me(current_doctor: Doctor = Depends(get_current_doctor)):
    return DoctorOut.model_validate(current_doctor)
