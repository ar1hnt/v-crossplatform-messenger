from fastapi import APIRouter, Depends, Header, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db_session
from app.modules.auth.service import AuthService
from app.modules.users.schemas import UserProfileResponse, UserUpdateRequest
from app.modules.users.service import UserService

router = APIRouter()


@router.get("/me", response_model=UserProfileResponse)
async def get_me(
    authorization: str = Header(default=""),
    session: AsyncSession = Depends(get_db_session),
) -> UserProfileResponse:
    auth_service = AuthService(session)
    user = await auth_service.get_current_user_from_header(authorization)
    return UserProfileResponse.model_validate(user)


@router.patch("/me", response_model=UserProfileResponse)
async def update_me(
    payload: UserUpdateRequest,
    authorization: str = Header(default=""),
    session: AsyncSession = Depends(get_db_session),
) -> UserProfileResponse:
    auth_service = AuthService(session)
    user = await auth_service.get_current_user_from_header(authorization)
    service = UserService(session)
    updated_user = await service.update_me(user, payload)
    return UserProfileResponse.model_validate(updated_user)


@router.get("/search", response_model=list[UserProfileResponse])
async def search_users(
    q: str = Query(min_length=1, max_length=255),
    session: AsyncSession = Depends(get_db_session),
) -> list[UserProfileResponse]:
    service = UserService(session)
    users = await service.search(q)
    return [UserProfileResponse.model_validate(user) for user in users]


@router.get("/{user_id}", response_model=UserProfileResponse)
async def get_user(
    user_id: str,
    session: AsyncSession = Depends(get_db_session),
) -> UserProfileResponse:
    service = UserService(session)
    user = await service.get_by_id(user_id)
    return UserProfileResponse.model_validate(user)
