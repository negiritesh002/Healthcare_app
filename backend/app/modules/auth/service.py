import secrets
import jwt
from datetime import datetime, timedelta, timezone
import redis.asyncio as aioredis

from app.core.config import settings


def generate_otp() -> str:
    """Generate a secure random 6-digit OTP code."""
    return f"{secrets.randbelow(900000) + 100000}"


async def store_otp(redis: aioredis.Redis, phone: str, code: str, ttl_seconds: int = 300) -> None:
    """Store 6-digit OTP code in Redis with a 5-minute TTL (otp:{phone})."""
    key = f"otp:{phone}"
    await redis.setex(key, ttl_seconds, code)


async def verify_otp(redis: aioredis.Redis, phone: str, code: str) -> bool:
    """Verify OTP code against Redis and delete key on success (single-use)."""
    key = f"otp:{phone}"
    stored_code = await redis.get(key)
    if stored_code and stored_code == code:
        await redis.delete(key)
        return True
    return False


async def set_phone_verified(redis: aioredis.Redis, phone: str, ttl_seconds: int = 900) -> None:
    """Set a short-lived Redis flag indicating phone number has been OTP-verified."""
    key = f"phone_verified:{phone}"
    await redis.setex(key, ttl_seconds, "1")


async def is_phone_verified(redis: aioredis.Redis, phone: str) -> bool:
    """Check if phone number has been verified via OTP."""
    key = f"phone_verified:{phone}"
    value = await redis.get(key)
    return value is not None


async def clear_phone_verified(redis: aioredis.Redis, phone: str) -> None:
    """Delete verified phone flag from Redis."""
    key = f"phone_verified:{phone}"
    await redis.delete(key)


def create_access_token(doctor_id: str) -> str:
    """Create a signed JWT access token containing doctor_id in the 'sub' claim."""
    now = datetime.now(timezone.utc)
    expires = now + timedelta(minutes=settings.JWT_EXPIRE_MINUTES)
    payload = {
        "sub": str(doctor_id),
        "iat": now,
        "exp": expires,
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm="HS256")


def decode_token(token: str):
    """Decode and verify a signed JWT token."""
    try:
        return jwt.decode(token, settings.JWT_SECRET, algorithms=["HS256"])
    except Exception:
        return None
