from fastapi import APIRouter, Depends, Header
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db_session
from app.modules.ai.schemas import (
    AiSuggestionResponse,
    MessageSuggestionRequest,
    PostSuggestionRequest,
)
from app.modules.ai.service import AiService
from app.modules.auth.service import AuthService

router = APIRouter()


@router.post("/chats/{chat_id}/suggest-message", response_model=AiSuggestionResponse)
async def suggest_message(
    chat_id: str,
    payload: MessageSuggestionRequest,
    authorization: str = Header(default=""),
    session: AsyncSession = Depends(get_db_session),
) -> AiSuggestionResponse:
    current_user = await AuthService(session).get_current_user_from_header(authorization)
    return await AiService(session).suggest_message(chat_id, current_user, payload)


@router.post("/posts/suggest", response_model=AiSuggestionResponse)
async def suggest_post(
    payload: PostSuggestionRequest,
    authorization: str = Header(default=""),
    session: AsyncSession = Depends(get_db_session),
) -> AiSuggestionResponse:
    current_user = await AuthService(session).get_current_user_from_header(authorization)
    return await AiService(session).suggest_post(current_user, payload)
