from uuid import UUID

from sqlalchemy import Select, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.files.models import StoredFile
from app.modules.messages.models import Message
from app.modules.posts.models import PostAttachment
from app.modules.users.models import User


class FileRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_by_id(self, file_id: UUID | str) -> StoredFile | None:
        query: Select[tuple[StoredFile]] = select(StoredFile).where(StoredFile.id == file_id)
        return await self.session.scalar(query)

    async def is_avatar_file(self, file_id: UUID | str) -> bool:
        query = select(User.id).where(User.avatar_file_id == file_id).limit(1)
        return await self.session.scalar(query) is not None

    async def is_post_attachment(self, file_id: UUID | str) -> bool:
        query = select(PostAttachment.id).where(PostAttachment.file_id == file_id).limit(1)
        return await self.session.scalar(query) is not None

    async def get_message_attachment_owner_chat_id(self, file_id: UUID | str) -> UUID | None:
        query = select(Message.chat_id).where(Message.file_id == file_id).limit(1)
        return await self.session.scalar(query)
