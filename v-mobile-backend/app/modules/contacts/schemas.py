from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.modules.users.schemas import UserProfileResponse


class ContactSyncItemRequest(BaseModel):
    contact_name: str = Field(default="", max_length=255)
    phone_number: str = Field(default="", max_length=64)


class ContactSyncRequest(BaseModel):
    contacts: list[ContactSyncItemRequest] = Field(default_factory=list)


class ContactMatchResponse(BaseModel):
    id: UUID
    contact_name: str
    phone_number: str
    matched_user_id: UUID | None = None
    matched_user: UserProfileResponse | None = None

    model_config = ConfigDict(from_attributes=True)
