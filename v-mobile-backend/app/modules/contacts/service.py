from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.contacts.models import ContactSync
from app.modules.contacts.repository import ContactSyncRepository
from app.modules.contacts.schemas import ContactMatchResponse, ContactSyncRequest
from app.modules.users.models import User
from app.modules.users.repository import UserRepository
from app.modules.users.schemas import UserProfileResponse


class ContactSyncService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.contacts = ContactSyncRepository(session)
        self.users = UserRepository(session)

    async def sync_contacts(self, current_user: User, payload: ContactSyncRequest) -> list[ContactMatchResponse]:
        await self.contacts.delete_for_owner(str(current_user.id))

        items: list[ContactMatchResponse] = []
        for contact in payload.contacts:
            normalized_phone = self._normalize_phone(contact.phone_number)
            if len(normalized_phone.replace("+", "")) < 5:
                continue
            contact_name = contact.contact_name.strip() or "Без имени"
            matched_user = await self.users.get_by_phone(normalized_phone)
            entity = ContactSync(
                owner_id=current_user.id,
                contact_name=contact_name,
                phone_number=normalized_phone,
                matched_user_id=matched_user.id if matched_user else None,
            )
            self.session.add(entity)
            await self.session.flush()
            items.append(
                ContactMatchResponse(
                    id=entity.id,
                    contact_name=entity.contact_name,
                    phone_number=entity.phone_number,
                    matched_user_id=entity.matched_user_id,
                    matched_user=UserProfileResponse.model_validate(matched_user) if matched_user else None,
                )
            )

        await self.session.commit()
        return items

    async def list_matches(self, current_user: User) -> list[ContactMatchResponse]:
        contacts = await self.contacts.list_by_owner(str(current_user.id))
        items: list[ContactMatchResponse] = []
        for contact in contacts:
            matched_user = (
                await self.users.get_by_id(contact.matched_user_id)
                if contact.matched_user_id is not None
                else None
            )
            items.append(
                ContactMatchResponse(
                    id=contact.id,
                    contact_name=contact.contact_name,
                    phone_number=contact.phone_number,
                    matched_user_id=contact.matched_user_id,
                    matched_user=UserProfileResponse.model_validate(matched_user) if matched_user else None,
                )
            )
        return items

    def _normalize_phone(self, phone_number: str) -> str:
        raw = "".join(char for char in phone_number if char.isdigit() or char == "+")
        if raw.startswith("8") and len(raw) == 11:
            return f"+7{raw[1:]}"
        if raw.startswith("7") and len(raw) == 11:
            return f"+{raw}"
        if raw.startswith("+"):
            return raw
        return raw
