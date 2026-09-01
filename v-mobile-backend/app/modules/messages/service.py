from datetime import UTC, datetime

from sqlalchemy.ext.asyncio import AsyncSession

from app.common.exceptions import BadRequestException
from app.common.pagination import PageMeta
from app.modules.chats.service import ChatService
from app.modules.messages.models import Message, MessageType
from app.modules.messages.repository import MessageRepository
from app.modules.messages.schemas import (
    MessageCreateRequest,
    MessageListResponse,
    MessageReadResponse,
    MessageResponse,
)
from app.modules.push.service import PushNotificationService
from app.modules.users.models import User
from app.websockets.connection_manager import connection_manager


class MessageService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.messages = MessageRepository(session)
        self.chats = ChatService(session)
        self.push_notifications = PushNotificationService(session)

    async def list_messages(
        self,
        chat_id: str,
        current_user: User,
        limit: int,
        offset: int,
    ) -> MessageListResponse:
        await self.chats.get_user_chat(chat_id, current_user)
        items, total = await self.messages.list_by_chat(chat_id, limit, offset)
        return MessageListResponse(
            items=[MessageResponse.model_validate(item) for item in items],
            meta=PageMeta(limit=limit, offset=offset, total=total),
        )

    async def create_message(self, chat_id: str, current_user: User, payload: MessageCreateRequest) -> Message:
        chat = await self.chats.get_user_chat(chat_id, current_user)
        self._validate_message_payload(payload)
        chat.updated_at = datetime.now(UTC)
        for participant in chat.participants:
            connection_manager.subscribe_chat(str(participant.user_id), str(chat.id))

        message = Message(
            chat_id=chat_id,
            sender_id=current_user.id,
            text=payload.text,
            file_id=payload.file_id,
            message_type=payload.message_type,
        )
        self.session.add(message)
        await self.session.commit()
        hydrated_message = await self.messages.get_by_id(str(message.id))
        if hydrated_message is None:
            await self.session.refresh(message)
            hydrated_message = message

        await connection_manager.broadcast_to_chat(
            chat_id,
            {
                "event": "message.created",
                "data": MessageResponse.model_validate(hydrated_message).model_dump(mode="json"),
            },
        )
        recipient_ids = [
            str(participant.user_id)
            for participant in chat.participants
            if str(participant.user_id) != str(current_user.id)
        ]
        await self.push_notifications.notify_new_message(
            recipient_ids,
            title=current_user.full_name,
            body=payload.text or "Новое вложение",
            data={"chat_id": chat_id, "message_id": str(message.id)},
        )
        return hydrated_message

    async def mark_as_read(self, chat_id: str, current_user: User) -> MessageReadResponse:
        await self.chats.get_user_chat(chat_id, current_user)
        updated = await self.messages.mark_chat_as_read(chat_id, str(current_user.id))
        await self.session.commit()
        await connection_manager.broadcast_to_chat(
            chat_id,
            {
                "event": "message.read",
                "data": {"chat_id": chat_id, "reader_id": str(current_user.id), "updated": updated},
            },
        )
        return MessageReadResponse(updated=updated)

    def _validate_message_payload(self, payload: MessageCreateRequest) -> None:
        if payload.message_type not in {item.value for item in MessageType}:
            raise BadRequestException("Неподдерживаемый тип сообщения")
        if payload.message_type == MessageType.TEXT and not payload.text:
            raise BadRequestException("Для текстового сообщения нужен текст")
        if payload.message_type in {MessageType.FILE, MessageType.VOICE} and payload.file_id is None:
            raise BadRequestException("Для сообщения с файлом нужен file_id")
        if payload.message_type == MessageType.TEXT_FILE and (not payload.text or payload.file_id is None):
            raise BadRequestException("Для text_file нужны текст и file_id")
