from uuid import UUID

from sqlalchemy import Select, and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.users.models import DeviceToken, RefreshToken, User


class UserRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_by_id(self, user_id: UUID | str) -> User | None:
        query: Select[tuple[User]] = select(User).where(User.id == user_id)
        return await self.session.scalar(query)

    async def get_by_email(self, email: str) -> User | None:
        query: Select[tuple[User]] = select(User).where(func.lower(User.email) == email.lower())
        return await self.session.scalar(query)

    async def get_by_phone(self, phone: str) -> User | None:
        query: Select[tuple[User]] = select(User).where(User.phone == phone)
        return await self.session.scalar(query)

    async def search(self, query_string: str, limit: int = 20) -> list[User]:
        normalized_query = " ".join(query_string.lower().split())
        tokens = [token for token in normalized_query.split(" ") if token]
        if not tokens:
            return []

        token_conditions = [User.full_name.ilike(f"%{token}%") for token in tokens]
        query = (
            select(User)
            .where(
                or_(
                    User.full_name.ilike(f"%{normalized_query}%"),
                    and_(*token_conditions),
                    User.email.ilike(f"%{normalized_query}%"),
                )
            )
            .order_by(User.full_name.asc())
            .limit(limit)
        )
        result = await self.session.scalars(query)
        return list(result.all())


class RefreshTokenRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_by_jti(self, jti: str) -> RefreshToken | None:
        query: Select[tuple[RefreshToken]] = select(RefreshToken).where(RefreshToken.jti == jti)
        return await self.session.scalar(query)


class DeviceTokenRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_by_push_token(self, push_token: str) -> DeviceToken | None:
        query: Select[tuple[DeviceToken]] = select(DeviceToken).where(DeviceToken.push_token == push_token)
        return await self.session.scalar(query)

    async def list_by_user_id(self, user_id: UUID | str) -> list[DeviceToken]:
        query = select(DeviceToken).where(DeviceToken.user_id == user_id).order_by(DeviceToken.created_at.desc())
        return list((await self.session.scalars(query)).all())
