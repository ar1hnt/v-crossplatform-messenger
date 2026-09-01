from uuid import UUID

from sqlalchemy import Select, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.modules.chats.models import ChatParticipant, PrivateChat
from app.modules.messages.models import Message


class ChatRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_by_id(self, chat_id: UUID | str) -> PrivateChat | None:
        query: Select[tuple[PrivateChat]] = (
            select(PrivateChat)
            .options(selectinload(PrivateChat.participants))
            .where(PrivateChat.id == chat_id)
        )
        return await self.session.scalar(query)

    async def get_private_chat_between_users(
        self,
        first_user_id: UUID,
        second_user_id: UUID,
    ) -> PrivateChat | None:
        participant_subquery = (
            select(ChatParticipant.chat_id)
            .where(ChatParticipant.user_id.in_([first_user_id, second_user_id]))
            .group_by(ChatParticipant.chat_id)
            .having(func.count(ChatParticipant.user_id) == 2)
            .subquery()
        )

        total_participants_subquery = (
            select(ChatParticipant.chat_id)
            .group_by(ChatParticipant.chat_id)
            .having(func.count(ChatParticipant.user_id) == 2)
            .subquery()
        )

        query = (
            select(PrivateChat)
            .options(selectinload(PrivateChat.participants))
            .where(PrivateChat.id.in_(select(participant_subquery.c.chat_id)))
            .where(PrivateChat.id.in_(select(total_participants_subquery.c.chat_id)))
        )
        return await self.session.scalar(query)

    async def list_for_user(self, user_id: UUID) -> list[PrivateChat]:
        query = (
            select(PrivateChat)
            .join(ChatParticipant, ChatParticipant.chat_id == PrivateChat.id)
            .options(selectinload(PrivateChat.participants))
            .where(ChatParticipant.user_id == user_id)
            .order_by(PrivateChat.updated_at.desc())
        )
        return list((await self.session.scalars(query)).unique().all())

    async def list_participant_ids(self, chat_id: UUID | str) -> list[str]:
        query = select(ChatParticipant.user_id).where(ChatParticipant.chat_id == chat_id)
        return [str(item) for item in (await self.session.scalars(query)).all()]

    async def get_last_message(self, chat_id: UUID | str) -> Message | None:
        query = (
            select(Message)
            .where(Message.chat_id == chat_id)
            .order_by(Message.created_at.desc())
            .limit(1)
        )
        return await self.session.scalar(query)
