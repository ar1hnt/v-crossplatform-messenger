from uuid import UUID

import httpx
from sqlalchemy.ext.asyncio import AsyncSession

from app.common.exceptions import BadRequestException
from app.core.config import settings
from app.modules.ai.schemas import (
    AiSuggestionResponse,
    MessageSuggestionRequest,
    PostSuggestionRequest,
)
from app.modules.chats.service import ChatService
from app.modules.messages.repository import MessageRepository
from app.modules.users.models import User
from app.modules.users.repository import UserRepository


class AiService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.messages = MessageRepository(session)
        self.users = UserRepository(session)
        self.chats = ChatService(session)

    async def suggest_message(
        self,
        chat_id: str,
        current_user: User,
        payload: MessageSuggestionRequest,
    ) -> AiSuggestionResponse:
        await self.chats.get_user_chat(chat_id, current_user)
        messages, _ = await self.messages.list_by_chat(chat_id, limit=12, offset=0)
        chronological_messages = list(reversed(messages))
        user_names = await self._load_user_names(
            [message.sender_id for message in chronological_messages]
        )
        context_lines = [
            f"{user_names.get(message.sender_id, 'Пользователь')}: {message.text}"
            for message in chronological_messages
            if message.text
        ]
        if not context_lines:
            raise BadRequestException("В чате пока нет текстового контекста для генерации")

        prompt = "\n".join(
            [
                "Ты помогаешь пользователю мессенджера написать личный ответ.",
                "Сгенерируй один естественный вариант ответа на русском языке.",
                "Не добавляй кавычки, пояснения, варианты, markdown и подписи.",
                "Ответ должен быть готов к отправке, но пользователь сможет его отредактировать.",
                f"Тон: {payload.tone or 'нейтральный, дружелюбный'}.",
                f"Просьба: {payload.instruction or 'нет'}.",
                # "",
                # "Контекст переписки пользователя с собеседником:",
                # *context_lines[-20:], # Ограничиваем контекст последними 20 сообщениями, чтобы не превышать лимиты провайдера
                # "",
                # f"Ответ должен написать: {current_user.full_name}.",
            ]
        )
        return await self._generate_text(prompt=prompt, max_output_tokens=180)

    async def suggest_post(
        self,
        current_user: User,
        payload: PostSuggestionRequest,
    ) -> AiSuggestionResponse:
        topic = payload.topic or payload.draft
        if topic is None or not topic.strip():
            raise BadRequestException("Укажите тему или черновик поста")

        prompt = "\n".join(
            [
                "Ты помогаешь пользователю мессенджера написать пост в профиль.",
                "Сгенерируй один живой пост на русском языке.",
                "Не добавляй кавычки, пояснения, варианты, markdown и подписи.",
                "Пост должен звучать естественно и быть готовым к публикации.",
                f"Автор: {current_user.full_name}.",
                f"Тон: {payload.tone or 'естественный, уверенный'}.",
                f"Тема или черновик: {topic.strip()}",
            ]
        )
        return await self._generate_text(prompt=prompt, max_output_tokens=260)

    async def _load_user_names(self, user_ids: list[UUID]) -> dict[UUID, str]:
        names: dict[UUID, str] = {}
        for user_id in set(user_ids):
            user = await self.users.get_by_id(user_id)
            if user is not None:
                names[user_id] = user.full_name
        return names

    async def _generate_text(self, prompt: str, max_output_tokens: int) -> AiSuggestionResponse:
        if settings.ai_provider == "groq":
            return await self._generate_with_groq(prompt, max_output_tokens)
        if settings.ai_provider == "gemini":
            return await self._generate_with_gemini(prompt, max_output_tokens)
        raise BadRequestException("Поддерживаются AI_PROVIDER=gemini или AI_PROVIDER=groq")

    async def _generate_with_gemini(
        self,
        prompt: str,
        max_output_tokens: int,
    ) -> AiSuggestionResponse:
        if not settings.gemini_api_key:
            raise BadRequestException("GEMINI_API_KEY не настроен на backend")

        url = (
            "https://generativelanguage.googleapis.com/v1beta/models/"
            f"{settings.gemini_model}:generateContent"
        )
        request_payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {
                "temperature": 0.7,
                "topP": 0.9,
                "maxOutputTokens": max_output_tokens,
            },
        }

        try:
            async with httpx.AsyncClient(timeout=settings.ai_timeout_seconds) as client:
                response = await client.post(
                    url,
                    headers={
                        "x-goog-api-key": settings.gemini_api_key,
                        "Content-Type": "application/json",
                    },
                    json=request_payload,
                )
                response.raise_for_status()
        except httpx.HTTPStatusError as exc:
            error_message = self._extract_gemini_error(exc.response)
            raise BadRequestException(
                f"Gemini API вернул ошибку {exc.response.status_code}: {error_message}"
            ) from exc
        except httpx.HTTPError as exc:
            raise BadRequestException("Не удалось обратиться к Gemini API") from exc

        data = response.json()
        text = self._extract_gemini_text(data)
        return AiSuggestionResponse(
            text=text,
            provider="gemini",
            model=settings.gemini_model,
        )

    async def _generate_with_groq(
        self,
        prompt: str,
        max_output_tokens: int,
    ) -> AiSuggestionResponse:
        if not settings.groq_api_key:
            raise BadRequestException("GROQ_API_KEY не настроен на backend")

        request_payload = {
            "model": settings.groq_model,
            "messages": [
                {
                    "role": "system",
                    "content": "Ты пишешь короткие естественные тексты на русском языке.",
                },
                {"role": "user", "content": prompt},
            ],
            "temperature": 0.7,
            "top_p": 0.9,
            "max_tokens": max_output_tokens,
        }

        try:
            async with httpx.AsyncClient(timeout=settings.ai_timeout_seconds) as client:
                response = await client.post(
                    "https://api.groq.com/openai/v1/chat/completions",
                    headers={
                        "Authorization": f"Bearer {settings.groq_api_key}",
                        "Content-Type": "application/json",
                    },
                    json=request_payload,
                )
                response.raise_for_status()
        except httpx.HTTPStatusError as exc:
            error_message = self._extract_openai_compatible_error(exc.response)
            raise BadRequestException(
                f"Groq API вернул ошибку {exc.response.status_code}: {error_message}"
            ) from exc
        except httpx.HTTPError as exc:
            raise BadRequestException("Не удалось обратиться к Groq API") from exc

        data = response.json()
        text = self._extract_openai_compatible_text(data)
        return AiSuggestionResponse(
            text=text,
            provider="groq",
            model=settings.groq_model,
        )

    def _extract_gemini_text(self, data: dict) -> str:
        candidates = data.get("candidates") or []
        if not candidates:
            raise BadRequestException("Gemini не вернул вариант текста")

        parts = candidates[0].get("content", {}).get("parts") or []
        text = "".join(str(part.get("text", "")) for part in parts).strip()
        if not text:
            raise BadRequestException("Gemini вернул пустой текст")
        return text

    def _extract_gemini_error(self, response: httpx.Response) -> str:
        try:
            data = response.json()
        except ValueError:
            return response.text[:300] or "без описания"

        message = data.get("error", {}).get("message")
        if isinstance(message, str) and message.strip():
            return message.strip()
        return "без описания"

    def _extract_openai_compatible_text(self, data: dict) -> str:
        choices = data.get("choices") or []
        if not choices:
            raise BadRequestException("AI-провайдер не вернул вариант текста")

        text = choices[0].get("message", {}).get("content", "")
        if not isinstance(text, str) or not text.strip():
            raise BadRequestException("AI-провайдер вернул пустой текст")
        return text.strip()

    def _extract_openai_compatible_error(self, response: httpx.Response) -> str:
        try:
            data = response.json()
        except ValueError:
            return response.text[:300] or "без описания"

        error = data.get("error")
        if isinstance(error, dict):
            message = error.get("message")
            if isinstance(message, str) and message.strip():
                return message.strip()
        if isinstance(error, str) and error.strip():
            return error.strip()
        return "без описания"
