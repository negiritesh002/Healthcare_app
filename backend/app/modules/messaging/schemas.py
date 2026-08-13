from datetime import datetime
from typing import Optional
from pydantic import BaseModel


class ConversationCreate(BaseModel):
    target_doctor_id: str


class ConversationOut(BaseModel):
    id: str
    other_doctor_id: str
    other_doctor_name: str
    other_doctor_specialty: str
    last_message_content: Optional[str] = None
    last_message_sent_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class MessageCreate(BaseModel):
    content: str


class MessageOut(BaseModel):
    id: str
    conversation_id: str
    sender_id: str
    sender_name: str
    content: str
    sent_at: datetime
    read_at: Optional[datetime] = None

    class Config:
        from_attributes = True
