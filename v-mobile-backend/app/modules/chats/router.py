from fastapi import APIRouter, Depends, Header, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db_session
from app.modules.auth.service import AuthService
from app.modules.chats.schemas import ChatResponse
from app.modules.chats.service import ChatService
from app.modules.messages.schemas import (
    MessageCreateRequest,
    MessageListResponse,
    MessageReadResponse,
    MessageResponse,
)
from app.modules.messages.service import MessageService

router = APIRouter()


@router.post("/private/{user_id}", response_model=ChatResponse, status_code=status.HTTP_201_CREATED)
async def create_or_get_private_chat(
    user_id: str,
    authorization: str = Header(default=""),
    session: AsyncSession = Depends(get_db_session),
) -> ChatResponse:
    auth_service = AuthService(session)
    current_user = await auth_service.get_current_user_from_header(authorization)
    service = ChatService(session)
    chat = await service.create_or_get_private_chat(current_user, user_id)
    return await service.build_chat_response(chat, current_user)


@router.get("", response_model=list[ChatResponse])
async def get_my_chats(
    authorization: str = Header(default=""),
    session: AsyncSession = Depends(get_db_session),
) -> list[ChatResponse]:
    auth_service = AuthService(session)
    current_user = await auth_service.get_current_user_from_header(authorization)
    service = ChatService(session)
    chats = await service.list_user_chats(current_user)
    return [await service.build_chat_response(chat, current_user) for chat in chats]


@router.get("/{chat_id}/messages", response_model=MessageListResponse)
async def get_chat_messages(
    chat_id: str,
    limit: int = 20,
    offset: int = 0,
    authorization: str = Header(default=""),
    session: AsyncSession = Depends(get_db_session),
) -> MessageListResponse:
    auth_service = AuthService(session)
    current_user = await auth_service.get_current_user_from_header(authorization)
    service = MessageService(session)
    return await service.list_messages(chat_id, current_user, limit, offset)


@router.post("/{chat_id}/messages", response_model=MessageResponse, status_code=status.HTTP_201_CREATED)
async def create_message(
    chat_id: str,
    payload: MessageCreateRequest,
    authorization: str = Header(default=""),
    session: AsyncSession = Depends(get_db_session),
) -> MessageResponse:
    auth_service = AuthService(session)
    current_user = await auth_service.get_current_user_from_header(authorization)
    service = MessageService(session)
    message = await service.create_message(chat_id, current_user, payload)
    return MessageResponse.model_validate(message)


@router.post("/{chat_id}/messages/read", response_model=MessageReadResponse)
async def mark_messages_as_read(
    chat_id: str,
    authorization: str = Header(default=""),
    session: AsyncSession = Depends(get_db_session),
) -> MessageReadResponse:
    auth_service = AuthService(session)
    current_user = await auth_service.get_current_user_from_header(authorization)
    service = MessageService(session)
    return await service.mark_as_read(chat_id, current_user)
