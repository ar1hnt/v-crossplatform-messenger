from fastapi import APIRouter, Depends, Header, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db_session
from app.modules.auth.service import AuthService
from app.modules.push.schemas import DeviceTokenResponse, DeviceTokenUpsertRequest
from app.modules.push.service import PushDeviceService

router = APIRouter()


@router.post("/devices", response_model=DeviceTokenResponse, status_code=status.HTTP_201_CREATED)
async def register_device(
    payload: DeviceTokenUpsertRequest,
    authorization: str = Header(default=""),
    session: AsyncSession = Depends(get_db_session),
) -> DeviceTokenResponse:
    auth_service = AuthService(session)
    current_user = await auth_service.get_current_user_from_header(authorization)
    service = PushDeviceService(session)
    device = await service.register_device(current_user, payload)
    return DeviceTokenResponse.model_validate(device)


@router.delete("/devices", status_code=status.HTTP_204_NO_CONTENT)
async def unregister_device(
    push_token: str = Query(min_length=10, max_length=512),
    authorization: str = Header(default=""),
    session: AsyncSession = Depends(get_db_session),
) -> None:
    auth_service = AuthService(session)
    current_user = await auth_service.get_current_user_from_header(authorization)
    service = PushDeviceService(session)
    await service.unregister_device(current_user, push_token)
