from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, computed_field


class FileShortInfo(BaseModel):
    id: UUID
    original_name: str
    content_type: str
    object_name: str = Field(exclude=True)

    @computed_field
    @property
    def url(self) -> str:
        from app.modules.files.storage import MinioStorage

        return MinioStorage().generate_download_url(self.object_name)

    model_config = ConfigDict(from_attributes=True)


class UserProfileResponse(BaseModel):
    id: UUID
    email: str
    phone: str | None = None
    full_name: str
    birth_date: date | None = None
    bio: str | None = None
    presence_status: str
    last_seen: datetime | None = None
    avatar: FileShortInfo | None = None

    model_config = ConfigDict(from_attributes=True)


class UserUpdateRequest(BaseModel):
    full_name: str | None = Field(default=None, min_length=2, max_length=255)
    phone: str | None = Field(default=None, min_length=5, max_length=32)
    birth_date: date | None = None
    bio: str | None = Field(default=None, max_length=1000)
    avatar_file_id: UUID | None = None
