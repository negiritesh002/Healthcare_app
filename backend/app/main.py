import logging
from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
import redis.asyncio as aioredis

from app.db.session import get_db
from app.core.redis_client import get_redis
from app.modules.auth.router import router as auth_router
from app.modules.dashboard.router import router as dashboard_router
from app.modules.patients.router import router as patients_router
from app.modules.appointments.router import router as appointments_router
from app.modules.lab.router import router as lab_router
from app.modules.pharmacy.router import router as pharmacy_router

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Healthcare App API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router, prefix="/auth", tags=["Auth"])
app.include_router(dashboard_router, prefix="/dashboard", tags=["Dashboard"])
app.include_router(patients_router, prefix="/patients", tags=["Patients"])
app.include_router(appointments_router, prefix="/appointments", tags=["Appointments"])
app.include_router(lab_router, prefix="/lab", tags=["Lab"])
app.include_router(pharmacy_router, prefix="/pharmacy", tags=["Pharmacy"])



@app.get("/health")
async def health_check(
    db: AsyncSession = Depends(get_db),
    redis: aioredis.Redis = Depends(get_redis),
):
    db_status = False
    redis_status = False
    db_error = None
    redis_error = None

    # Ping Postgres DB
    try:
        result = await db.execute(text("SELECT 1"))
        if result.scalar() == 1:
            db_status = True
    except Exception as e:
        logger.error(f"PostgreSQL health check failed: {e}", exc_info=True)
        db_status = False
        db_error = str(e)

    # Ping Redis Cache
    try:
        if await redis.ping():
            redis_status = True
    except Exception as e:
        logger.error(f"Redis health check failed: {e}", exc_info=True)
        redis_status = False
        redis_error = str(e)

    response = {
        "status": "ok",
        "db": db_status,
        "redis": redis_status,
    }
    if db_error:
        response["db_error"] = db_error
    if redis_error:
        response["redis_error"] = redis_error

    return response

