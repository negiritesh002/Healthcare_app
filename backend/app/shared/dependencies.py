import jwt
from uuid import UUID
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.config import settings
from app.db.session import get_db
from app.modules.auth.models import Doctor

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/verify-otp")


async def get_current_doctor(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db)
) -> Doctor:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate authentication credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET,
            algorithms=["HS256"]
        )
        doctor_id_str: str = payload.get("sub")
        if doctor_id_str is None:
            raise credentials_exception
        doctor_id = UUID(doctor_id_str)
    except (jwt.PyJWTError, ValueError):
        raise credentials_exception

    stmt = select(Doctor).where(Doctor.id == doctor_id)
    result = await db.execute(stmt)
    doctor = result.scalar_one_or_none()

    if doctor is None:
        raise credentials_exception

    return doctor
