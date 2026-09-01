from sqlalchemy.ext.asyncio import AsyncSession

from app.common.exceptions import BadRequestException, ForbiddenException, NotFoundException
from app.modules.chats.models import ChatParticipant, PrivateChat
from app.modules.chats.repository import ChatRepository
from app.modules.chats.schemas import ChatResponse
from app.modules.messages.schemas import MessageResponse
from app.modules.users.models import PresenceStatus
from app.modules.users.models import User
from app.modules.users.repository import UserRepository
from app.modules.users.schemas import UserProfileResponse
from app.websockets.connection_manager import connection_manager


class ChatService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.chats = ChatRepository(session)
        self.users = UserRepository(session)

    async def create_or_get_private_chat(self, current_user: User, other_user_id: str) -> PrivateChat:
        if str(current_user.id) == other_user_id:
            raise BadRequestException("Нельзя создать чат с самим собой")

        other_user = await self.users.get_by_id(other_user_id)
        if other_user is None:
            raise NotFoundException("Пользователь не найден")

        existing_chat = await self.chats.get_private_chat_between_users(current_user.id, other_user.id)
        if existing_chat:
            self._subscribe_participants(existing_chat)
            await self._sync_participants_presence(existing_chat)
            return existing_chat

        chat = PrivateChat(created_by_id=current_user.id)
        self.session.add(chat)
        await self.session.flush()
        self.session.add_all(
            [
                ChatParticipant(chat_id=chat.id, user_id=current_user.id),
                ChatParticipant(chat_id=chat.id, user_id=other_user.id),
            ]
        )
        await self.session.commit()
        created_chat = await self.get_user_chat(chat.id, current_user)
        self._subscribe_participants(created_chat)
        await self._sync_participants_presence(created_chat)
        return created_chat

    async def list_user_chats(self, current_user: User) -> list[PrivateChat]:
        return await self.chats.list_for_user(current_user.id)

    async def get_user_chat(self, chat_id: str, current_user: User) -> PrivateChat:
        chat = await self.chats.get_by_id(chat_id)
        if chat is None:
            raise NotFoundException("Чат не найден")
        participant_ids = {str(item.user_id) for item in chat.participants}
        if str(current_user.id) not in participant_ids:
            raise ForbiddenException("Нет доступа к чату")
        connection_manager.subscribe_chat(str(current_user.id), str(chat.id))
        await self._sync_participants_presence(chat)
        return chat

    async def build_chat_response(self, chat: PrivateChat, current_user: User) -> ChatResponse:
        peer_user = None
        for participant in chat.participants:
            if str(participant.user_id) != str(current_user.id):
                user = await self.users.get_by_id(participant.user_id)
                peer_user = UserProfileResponse.model_validate(user) if user else None
                break
        last_message = await self.chats.get_last_message(chat.id)
        return ChatResponse(
            id=chat.id,
            created_by_id=chat.created_by_id,
            created_at=chat.created_at,
            updated_at=chat.updated_at,
            participants=chat.participants,
            peer_user=peer_user,
            last_message=MessageResponse.model_validate(last_message) if last_message else None,
        )

    def _subscribe_participants(self, chat: PrivateChat) -> None:
        for participant in chat.participants:
            connection_manager.subscribe_chat(str(participant.user_id), str(chat.id))

    async def _sync_participants_presence(self, chat: PrivateChat) -> None:
        participant_ids = [str(participant.user_id) for participant in chat.participants]

        for target_user_id in participant_ids:
            for peer_user_id in participant_ids:
                if peer_user_id == target_user_id:
                    continue

                peer_user = await self.users.get_by_id(peer_user_id)
                if peer_user is None:
                    continue

                status = (
                    PresenceStatus.ONLINE.value
                    if connection_manager.has_active_connection(peer_user_id)
                    else str(peer_user.presence_status)
                )
                await connection_manager.send_personal_event(
                    target_user_id,
                    {
                        "event": "presence.updated",
                        "data": {"user_id": peer_user_id, "status": status},
                    },
                )
