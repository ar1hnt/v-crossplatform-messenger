from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.common.pagination import PageMeta
from app.modules.users.schemas import FileShortInfo


class MessageCreateRequest(BaseModel):
    text: str | None = Field(default=None, max_length=5000)
    file_id: UUID | None = None
    message_type: str


class MessageResponse(BaseModel):
    id: UUID
    chat_id: UUID
    sender_id: UUID
    message_type: str
    text: str | None
    file: FileShortInfo | None = None
    created_at: datetime
    read_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)


class MessageListResponse(BaseModel):
    items: list[MessageResponse]
    meta: PageMeta


class MessageReadResponse(BaseModel):
    updated: int
