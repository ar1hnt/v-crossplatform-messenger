from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.modules.messages.schemas import MessageResponse
from app.modules.users.schemas import UserProfileResponse


class ChatParticipantResponse(BaseModel):
    user_id: UUID

    model_config = ConfigDict(from_attributes=True)


class ChatResponse(BaseModel):
    id: UUID
    created_by_id: UUID
    created_at: datetime
    updated_at: datetime
    participants: list[ChatParticipantResponse]
    peer_user: UserProfileResponse | None = None
    last_message: MessageResponse | None = None

    model_config = ConfigDict(from_attributes=True, arbitrary_types_allowed=True)
