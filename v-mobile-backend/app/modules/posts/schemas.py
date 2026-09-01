from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.common.pagination import PageMeta
from app.modules.users.schemas import FileShortInfo
from app.modules.users.schemas import UserProfileResponse


class PostCreateRequest(BaseModel):
    text: str = Field(min_length=1, max_length=5000)
    attachment_ids: list[UUID] = Field(default_factory=list)


class PostCommentCreateRequest(BaseModel):
    text: str = Field(min_length=1, max_length=1000)


class PostCommentResponse(BaseModel):
    id: UUID
    post_id: UUID
    author_id: UUID
    author: UserProfileResponse | None = None
    text: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class PostAttachmentResponse(BaseModel):
    id: UUID
    file: FileShortInfo

    model_config = ConfigDict(from_attributes=True)


class PostResponse(BaseModel):
    id: UUID
    author_id: UUID
    author: UserProfileResponse | None = None
    text: str
    created_at: datetime
    updated_at: datetime
    attachments: list[PostAttachmentResponse]
    likes_count: int = 0
    comments_count: int = 0
    is_liked: bool = False

    model_config = ConfigDict(from_attributes=True)


class PostListResponse(BaseModel):
    items: list[PostResponse]
    meta: PageMeta
