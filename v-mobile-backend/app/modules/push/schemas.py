from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class DeviceTokenUpsertRequest(BaseModel):
    device_id: str = Field(min_length=1, max_length=255)
    push_token: str = Field(min_length=10, max_length=512)
    platform: str = Field(min_length=2, max_length=32)


class DeviceTokenResponse(BaseModel):
    id: UUID
    device_id: str
    push_token: str
    platform: str

    model_config = ConfigDict(from_attributes=True)
