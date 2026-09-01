from fastapi import APIRouter, Depends, Header, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db_session
from app.modules.auth.schemas import LoginRequest, RefreshRequest, TokenPair, UserRegisterRequest
from app.modules.auth.service import AuthService
from app.modules.users.schemas import UserProfileResponse

router = APIRouter()


@router.post("/register", response_model=TokenPair, status_code=status.HTTP_201_CREATED)
async def register(
    payload: UserRegisterRequest,
    session: AsyncSession = Depends(get_db_session),
) -> TokenPair:
    service = AuthService(session)
    return await service.register(payload)


@router.post("/login", response_model=TokenPair)
async def login(
    payload: LoginRequest,
    session: AsyncSession = Depends(get_db_session),
) -> TokenPair:
    service = AuthService(session)
    return await service.login(payload)


@router.post("/refresh", response_model=TokenPair)
async def refresh(
    payload: RefreshRequest,
    session: AsyncSession = Depends(get_db_session),
) -> TokenPair:
    service = AuthService(session)
    return await service.refresh(payload.refresh_token)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(
    authorization: str = Header(default=""),
    session: AsyncSession = Depends(get_db_session),
) -> None:
    service = AuthService(session)
    await service.logout(authorization)


@router.get("/me", response_model=UserProfileResponse)
async def current_profile(
    authorization: str = Header(default=""),
    session: AsyncSession = Depends(get_db_session),
) -> UserProfileResponse:
    service = AuthService(session)
    user = await service.get_current_user_from_header(authorization)
    return UserProfileResponse.model_validate(user)
