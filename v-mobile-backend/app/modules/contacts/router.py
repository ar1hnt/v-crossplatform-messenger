from fastapi import APIRouter, Depends, Header, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db_session
from app.modules.auth.service import AuthService
from app.modules.contacts.schemas import ContactMatchResponse, ContactSyncRequest
from app.modules.contacts.service import ContactSyncService

router = APIRouter()


@router.post("/sync", response_model=list[ContactMatchResponse], status_code=status.HTTP_201_CREATED)
async def sync_contacts(
    payload: ContactSyncRequest,
    authorization: str = Header(default=""),
    session: AsyncSession = Depends(get_db_session),
) -> list[ContactMatchResponse]:
    auth_service = AuthService(session)
    current_user = await auth_service.get_current_user_from_header(authorization)
    service = ContactSyncService(session)
    return await service.sync_contacts(current_user, payload)


@router.get("/matches", response_model=list[ContactMatchResponse])
async def get_contact_matches(
    authorization: str = Header(default=""),
    session: AsyncSession = Depends(get_db_session),
) -> list[ContactMatchResponse]:
    auth_service = AuthService(session)
    current_user = await auth_service.get_current_user_from_header(authorization)
    service = ContactSyncService(session)
    return await service.list_matches(current_user)
