from sqlalchemy import Select, delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.contacts.models import ContactSync


class ContactSyncRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def list_by_owner(self, owner_id: str) -> list[ContactSync]:
        query: Select[tuple[ContactSync]] = (
            select(ContactSync)
            .where(ContactSync.owner_id == owner_id)
            .order_by(ContactSync.contact_name.asc())
        )
        return list((await self.session.scalars(query)).all())

    async def delete_for_owner(self, owner_id: str) -> None:
        await self.session.execute(delete(ContactSync).where(ContactSync.owner_id == owner_id))
