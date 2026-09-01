from datetime import UTC, datetime

from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.users.models import PresenceStatus, User


class PresenceService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def mark_online(self, user: User) -> None:
        await self.session.execute(
            update(User)
            .where(User.id == user.id)
            .values(presence_status=PresenceStatus.ONLINE, last_seen=user.last_seen)
        )
        await self.session.commit()

    async def mark_offline(self, user: User) -> None:
        await self.session.execute(
            update(User)
            .where(User.id == user.id)
            .values(presence_status=PresenceStatus.OFFLINE, last_seen=datetime.now(UTC))
        )
        await self.session.commit()
