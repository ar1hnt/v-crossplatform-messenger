from fastapi import UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from app.common.exceptions import ForbiddenException, NotFoundException
from app.core.config import settings
from app.modules.chats.service import ChatService
from app.modules.files.models import StoredFile
from app.modules.files.repository import FileRepository
from app.modules.files.schemas import FileDownloadUrlResponse
from app.modules.files.storage import MinioStorage
from app.modules.users.models import User


class FileService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.files = FileRepository(session)
        self.chats = ChatService(session)
        self.storage = MinioStorage()

    async def upload_file(self, user: User, upload_file: UploadFile, kind: str) -> StoredFile:
        self.storage.ensure_bucket_exists()
        object_name, file_size = await self.storage.upload(upload_file, str(user.id))
        stored_file = StoredFile(
            owner_id=user.id,
            bucket_name=settings.minio_bucket,
            object_name=object_name,
            original_name=upload_file.filename or "file",
            content_type=upload_file.content_type or "application/octet-stream",
            size=file_size,
            kind=kind,
        )
        self.session.add(stored_file)
        await self.session.commit()
        await self.session.refresh(stored_file)
        return stored_file

    async def get_download_url(self, file_id: str, user: User) -> FileDownloadUrlResponse:
        stored_file = await self.files.get_by_id(file_id)
        if stored_file is None:
            raise NotFoundException("Файл не найден")
        if not await self._can_access_file(stored_file, user):
            raise ForbiddenException("Нет доступа к файлу")
        return FileDownloadUrlResponse(url=self.storage.generate_download_url(stored_file.object_name))

    async def get_file_content(self, file_id: str, user: User) -> tuple[StoredFile, bytes, str]:
        stored_file = await self.files.get_by_id(file_id)
        if stored_file is None:
            raise NotFoundException("Файл не найден")
        if not await self._can_access_file(stored_file, user):
            raise ForbiddenException("Нет доступа к файлу")

        content, detected_content_type = self.storage.download(stored_file.object_name)
        content_type = detected_content_type or stored_file.content_type or "application/octet-stream"
        return stored_file, content, content_type

    async def get_file_record(self, file_id: str, user: User) -> StoredFile:
        stored_file = await self.files.get_by_id(file_id)
        if stored_file is None:
            raise NotFoundException("Файл не найден")
        if not await self._can_access_file(stored_file, user):
            raise ForbiddenException("Нет доступа к файлу")
        return stored_file

    async def _can_access_file(self, stored_file: StoredFile, user: User) -> bool:
        if stored_file.owner_id in (None, user.id):
            return True
        if await self.files.is_avatar_file(stored_file.id):
            return True
        if await self.files.is_post_attachment(stored_file.id):
            return True
        message_chat_id = await self.files.get_message_attachment_owner_chat_id(stored_file.id)
        if message_chat_id is None:
            return False
        await self.chats.get_user_chat(str(message_chat_id), user)
        return True
