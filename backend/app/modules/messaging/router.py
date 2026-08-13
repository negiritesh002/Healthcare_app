import json
import asyncio
import logging
from datetime import datetime
from uuid import UUID
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status, WebSocket, WebSocketDisconnect, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_, and_
from sqlalchemy.orm import joinedload
import redis.asyncio as aioredis

from app.db.session import get_db
from app.core.redis_client import get_redis
from app.shared.dependencies import get_current_doctor
from app.modules.auth.models import Doctor
from app.modules.auth.service import decode_token
from app.modules.messaging.models import Conversation, Message
from app.modules.messaging.schemas import (
    ConversationCreate,
    ConversationOut,
    MessageOut,
    MessageCreate,
)

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/conversations", response_model=list[ConversationOut])
async def list_conversations(
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
):
    """
    List all conversations for current doctor with other participant's details and last message.
    """
    stmt = (
        select(Conversation)
        .options(
            joinedload(Conversation.doctor_a),
            joinedload(Conversation.doctor_b),
            joinedload(Conversation.messages),
        )
        .where(
            or_(
                Conversation.doctor_a_id == current_doctor.id,
                Conversation.doctor_b_id == current_doctor.id,
            )
        )
    )
    res = await db.execute(stmt)
    conversations = res.scalars().unique().all()

    out = []
    for c in conversations:
        other_doctor = c.doctor_b if c.doctor_a_id == current_doctor.id else c.doctor_a
        last_msg = c.messages[-1] if c.messages else None

        out.append(
            ConversationOut(
                id=str(c.id),
                other_doctor_id=str(other_doctor.id),
                other_doctor_name=other_doctor.full_name,
                other_doctor_specialty=other_doctor.medical_specialty,
                last_message_content=last_msg.content if last_msg else None,
                last_message_sent_at=last_msg.sent_at if last_msg else c.created_at,
            )
        )

    out.sort(key=lambda x: x.last_message_sent_at or datetime.min, reverse=True)
    return out


@router.post("/conversations", response_model=ConversationOut, status_code=status.HTTP_201_CREATED)
async def create_or_get_conversation(
    req: ConversationCreate,
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
):
    """
    Create a new conversation with target_doctor_id, or return existing one.
    """
    try:
        target_uuid = UUID(req.target_doctor_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Doctor not found"
        )

    if target_uuid == current_doctor.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot start a conversation with yourself"
        )

    stmt_d = select(Doctor).where(Doctor.id == target_uuid)
    res_d = await db.execute(stmt_d)
    target_doctor = res_d.scalar_one_or_none()
    if target_doctor is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Doctor not found"
        )

    # Check existing conversation
    stmt_c = (
        select(Conversation)
        .options(
            joinedload(Conversation.doctor_a),
            joinedload(Conversation.doctor_b),
            joinedload(Conversation.messages),
        )
        .where(
            or_(
                and_(Conversation.doctor_a_id == current_doctor.id, Conversation.doctor_b_id == target_uuid),
                and_(Conversation.doctor_a_id == target_uuid, Conversation.doctor_b_id == current_doctor.id),
            )
        )
    )
    res_c = await db.execute(stmt_c)
    existing = res_c.unique().scalar_one_or_none()

    if existing:
        other_doc = existing.doctor_b if existing.doctor_a_id == current_doctor.id else existing.doctor_a
        last_msg = existing.messages[-1] if existing.messages else None
        return ConversationOut(
            id=str(existing.id),
            other_doctor_id=str(other_doc.id),
            other_doctor_name=other_doc.full_name,
            other_doctor_specialty=other_doc.medical_specialty,
            last_message_content=last_msg.content if last_msg else None,
            last_message_sent_at=last_msg.sent_at if last_msg else existing.created_at,
        )

    new_conv = Conversation(
        doctor_a_id=current_doctor.id,
        doctor_b_id=target_uuid,
    )
    db.add(new_conv)
    await db.commit()
    await db.refresh(new_conv)

    return ConversationOut(
        id=str(new_conv.id),
        other_doctor_id=str(target_doctor.id),
        other_doctor_name=target_doctor.full_name,
        other_doctor_specialty=target_doctor.medical_specialty,
        last_message_content=None,
        last_message_sent_at=new_conv.created_at,
    )


@router.get("/conversations/{id}/messages", response_model=list[MessageOut])
async def list_conversation_messages(
    id: str,
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
):
    """
    Get message history for a conversation. Returns 404 if doctor is not a participant.
    """
    try:
        conv_uuid = UUID(id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found"
        )

    stmt_c = select(Conversation).where(
        Conversation.id == conv_uuid,
        or_(
            Conversation.doctor_a_id == current_doctor.id,
            Conversation.doctor_b_id == current_doctor.id,
        ),
    )
    res_c = await db.execute(stmt_c)
    conv = res_c.scalar_one_or_none()

    if conv is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found"
        )

    stmt_m = (
        select(Message)
        .options(joinedload(Message.sender))
        .where(Message.conversation_id == conv_uuid)
        .order_by(Message.sent_at.asc())
    )
    res_m = await db.execute(stmt_m)
    messages = res_m.scalars().all()

    return [
        MessageOut(
            id=str(m.id),
            conversation_id=str(m.conversation_id),
            sender_id=str(m.sender_id),
            sender_name=m.sender.full_name if m.sender else "Doctor",
            content=m.content,
            sent_at=m.sent_at,
            read_at=m.read_at,
        )
        for m in messages
    ]


@router.websocket("/ws/{conversation_id}")
async def websocket_chat_endpoint(
    websocket: WebSocket,
    conversation_id: str,
    token: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db),
    redis: aioredis.Redis = Depends(get_redis),
):
    """
    Real-time WebSocket chat endpoint for conversations.
    Authenticates via JWT token query parameter.
    Rejects connection with close code 4003 (Forbidden) if doctor is not a participant in conversation.
    Uses Redis PubSub bridge (channel: conversation:{id}) for real-time delivery across instances.
    """
    if not token:
        await websocket.close(code=4003, reason="Token required")
        return

    payload = decode_token(token)
    if not payload or "sub" not in payload:
        await websocket.close(code=4003, reason="Invalid token")
        return

    try:
        doctor_uuid = UUID(payload["sub"])
        conv_uuid = UUID(conversation_id)
    except ValueError:
        await websocket.close(code=4003, reason="Invalid UUID")
        return

    # Verify doctor exists & is participant
    stmt_d = select(Doctor).where(Doctor.id == doctor_uuid)
    res_d = await db.execute(stmt_d)
    connecting_doctor = res_d.scalar_one_or_none()

    if not connecting_doctor:
        await websocket.close(code=4003, reason="Doctor not found")
        return

    stmt_c = select(Conversation).where(
        Conversation.id == conv_uuid,
        or_(
            Conversation.doctor_a_id == doctor_uuid,
            Conversation.doctor_b_id == doctor_uuid,
        ),
    )
    res_c = await db.execute(stmt_c)
    conv = res_c.scalar_one_or_none()

    if not conv:
        logger.warning(f"WebSocket auth failed: Doctor {doctor_uuid} attempted unauthorized access to conversation {conv_uuid}")
        await websocket.close(code=4003, reason="Unauthorized participant")
        return

    await websocket.accept()
    pubsub = redis.pubsub()
    channel_name = f"conversation:{conversation_id}"
    await pubsub.subscribe(channel_name)

    async def redis_listener():
        try:
            async for message in pubsub.listen():
                if message["type"] == "message":
                    data = message["data"]
                    if isinstance(data, bytes):
                        data = data.decode("utf-8")
                    await websocket.send_text(data)
        except asyncio.CancelledError:
            pass
        except Exception as e:
            logger.error(f"Redis listener error: {e}")

    listener_task = asyncio.create_task(redis_listener())

    try:
        while True:
            data_str = await websocket.receive_text()
            try:
                data = json.loads(data_str)
                content = data.get("content", "").strip()
            except Exception:
                content = data_str.strip()

            if not content:
                continue

            # Persist message to PostgreSQL
            msg = Message(
                conversation_id=conv_uuid,
                sender_id=doctor_uuid,
                content=content,
            )
            db.add(msg)
            await db.commit()
            await db.refresh(msg)

            payload_out = {
                "id": str(msg.id),
                "conversation_id": str(msg.conversation_id),
                "sender_id": str(msg.sender_id),
                "sender_name": connecting_doctor.full_name,
                "content": msg.content,
                "sent_at": msg.sent_at.isoformat(),
                "read_at": None,
            }
            # Publish message to Redis channel
            await redis.publish(channel_name, json.dumps(payload_out))
    except WebSocketDisconnect:
        logger.info(f"WebSocket disconnected for doctor {connecting_doctor.full_name} on conversation {conversation_id}")
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
    finally:
        listener_task.cancel()
        await pubsub.unsubscribe(channel_name)
