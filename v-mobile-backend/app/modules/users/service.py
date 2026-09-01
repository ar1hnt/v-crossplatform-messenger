from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.common.exceptions import (
    BadRequestException,
    ConflictException,
    NotFoundException,
)
from app.modules.files.repository import FileRepository
from app.modules.users.phone import normalize_phone
from app.modules.users.models import User
from app.modules.users.repository import UserRepository
from app.modules.users.schemas import UserUpdateRequest


class UserService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.users = UserRepository(session)
        self.files = FileRepository(session)

    async def get_by_id(self, user_id: str) -> User:
        user = await self.users.get_by_id(user_id)
        if user is None:
            raise NotFoundException("Пользователь не найден")
        return user

    async def search(self, query: str) -> list[User]:
        return await self.users.search(query)

    async def update_me(self, user: User, payload: UserUpdateRequest) -> User:
        update_data = payload.model_dump(exclude_unset=True)
        if "phone" in update_data and update_data["phone"] is not None:
            normalized_phone = normalize_phone(update_data["phone"])
            existing_user = await self.users.get_by_phone(normalized_phone)
            if existing_user and existing_user.id != user.id:
                raise ConflictException("Телефон уже используется другим пользователем")
            update_data["phone"] = normalized_phone
        if (
            "avatar_file_id" in update_data
            and update_data["avatar_file_id"] is not None
        ):
            avatar = await self.files.get_by_id(update_data["avatar_file_id"])
            if avatar is None or avatar.owner_id != user.id:
                raise BadRequestException("Файл аватарки не найден")
            if avatar.kind != "avatar":
                raise BadRequestException("Файл должен быть загружен как avatar")
            if not avatar.content_type.startswith("image/"):
                raise BadRequestException("Для аватарки нужно изображение")
        for field, value in update_data.items():
            setattr(user, field, value)
        try:
            await self.session.commit()
        except IntegrityError as exc:
            await self.session.rollback()
            raise ConflictException("Телефон уже используется другим пользователем") from exc
        updated_user = await self.users.get_by_id(user.id)
        if updated_user is None:
            raise NotFoundException("Пользователь не найден")
        return updated_user
