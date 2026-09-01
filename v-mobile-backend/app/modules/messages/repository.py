from datetime import UTC, datetime

from sqlalchemy import update
from sqlalchemy import Select, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.modules.messages.models import Message


class MessageRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def list_by_chat(self, chat_id: str, limit: int, offset: int) -> tuple[list[Message], int]:
        query: Select[tuple[Message]] = (
            select(Message)
            .options(joinedload(Message.file))
            .where(Message.chat_id == chat_id)
            .order_by(Message.created_at.desc())
            .limit(limit)
            .offset(offset)
        )
        count_query = select(func.count()).select_from(Message).where(Message.chat_id == chat_id)
        items = list((await self.session.scalars(query)).all())
        total = await self.session.scalar(count_query) or 0
        return items, total

    async def get_by_id(self, message_id: str) -> Message | None:
        query: Select[tuple[Message]] = (
            select(Message).options(joinedload(Message.file)).where(Message.id == message_id)
        )
        return await self.session.scalar(query)

    async def mark_chat_as_read(self, chat_id: str, user_id: str) -> int:
        result = await self.session.execute(
            update(Message)
            .where(Message.chat_id == chat_id, Message.sender_id != user_id, Message.read_at.is_(None))
            .values(read_at=datetime.now(UTC))
        )
        return int(result.rowcount or 0)
