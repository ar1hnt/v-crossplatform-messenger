from datetime import UTC, datetime

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.common.exceptions import ConflictException, UnauthorizedException
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from app.modules.users.models import RefreshToken, User
from app.modules.users.phone import normalize_phone
from app.modules.users.repository import RefreshTokenRepository, UserRepository
from app.modules.auth.schemas import LoginRequest, TokenPair, UserRegisterRequest


class AuthService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.users = UserRepository(session)
        self.refresh_tokens = RefreshTokenRepository(session)

    async def register(self, payload: UserRegisterRequest) -> TokenPair:
        existing_user = await self.users.get_by_email(payload.email)
        if existing_user:
            raise ConflictException("Пользователь с таким email уже существует")
        normalized_phone = normalize_phone(payload.phone) if payload.phone else None
        if normalized_phone:
            existing_phone_user = await self.users.get_by_phone(normalized_phone)
            if existing_phone_user:
                raise ConflictException("Пользователь с таким телефоном уже существует")

        try:
            user = User(
                email=payload.email,
                full_name=payload.full_name,
                phone=normalized_phone,
                password_hash=hash_password(payload.password),
            )
            self.session.add(user)
            await self.session.flush()
            tokens = await self._issue_token_pair(user)
            await self.session.commit()
            return tokens
        except IntegrityError as exc:
            await self.session.rollback()
            self._raise_user_uniqueness_conflict(exc)

    async def login(self, payload: LoginRequest) -> TokenPair:
        user = await self.users.get_by_email(payload.email)
        if not user or not verify_password(payload.password, user.password_hash):
            raise UnauthorizedException("Неверный email или пароль")
        tokens = await self._issue_token_pair(user)
        await self.session.commit()
        return tokens

    async def refresh(self, refresh_token: str) -> TokenPair:
        payload = self._decode_refresh_token(refresh_token)
        token_record = await self.refresh_tokens.get_by_jti(payload["jti"])
        if not token_record or token_record.revoked_at is not None:
            raise UnauthorizedException("Refresh token недействителен")
        user = await self.users.get_by_id(token_record.user_id)
        if user is None:
            raise UnauthorizedException()
        token_record.revoked_at = datetime.now(UTC)
        tokens = await self._issue_token_pair(user)
        await self.session.commit()
        return tokens

    async def logout(self, authorization_header: str) -> None:
        token = self._extract_bearer_token(authorization_header)
        payload = self._decode_refresh_token(token)
        token_record = await self.refresh_tokens.get_by_jti(payload["jti"])
        if token_record:
            token_record.revoked_at = datetime.now(UTC)
            await self.session.commit()

    async def get_current_user_from_header(self, authorization_header: str) -> User:
        token = self._extract_bearer_token(authorization_header)
        payload = decode_token(token)
        if payload.get("type") != "access":
            raise UnauthorizedException("Некорректный access token")
        user = await self.users.get_by_id(payload["sub"])
        if user is None:
            raise UnauthorizedException()
        return user

    async def _issue_token_pair(self, user: User) -> TokenPair:
        access_token = create_access_token(str(user.id))
        refresh_token, jti, expires_at = create_refresh_token(str(user.id))
        self.session.add(RefreshToken(user_id=user.id, jti=jti, expires_at=expires_at))
        return TokenPair(access_token=access_token, refresh_token=refresh_token)

    def _decode_refresh_token(self, token: str) -> dict:
        payload = decode_token(token)
        if payload.get("type") != "refresh":
            raise UnauthorizedException("Некорректный refresh token")
        return payload

    def _extract_bearer_token(self, authorization_header: str) -> str:
        if not authorization_header.startswith("Bearer "):
            raise UnauthorizedException("Отсутствует Bearer token")
        return authorization_header.split(" ", maxsplit=1)[1].strip()

    def _raise_user_uniqueness_conflict(self, exc: IntegrityError) -> None:
        error_text = str(exc.orig).lower() if exc.orig is not None else str(exc).lower()
        if "email" in error_text:
            raise ConflictException("Пользователь с таким email уже существует") from exc
        if "phone" in error_text:
            raise ConflictException("Пользователь с таким телефоном уже существует") from exc
        raise ConflictException("Пользователь с такими данными уже существует") from exc
