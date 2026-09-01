import asyncio
import logging

import httpx
from google.auth.transport.requests import Request
from google.oauth2 import service_account
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.modules.push.schemas import DeviceTokenUpsertRequest
from app.modules.users.models import DeviceToken, User
from app.modules.users.repository import DeviceTokenRepository

logger = logging.getLogger(__name__)
FCM_SCOPES = ("https://www.googleapis.com/auth/firebase.messaging",)


class PushDeviceService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.devices = DeviceTokenRepository(session)

    async def register_device(
        self,
        current_user: User,
        payload: DeviceTokenUpsertRequest,
    ) -> DeviceToken:
        device = await self.devices.get_by_push_token(payload.push_token)
        if device is None:
            device = DeviceToken(
                user_id=current_user.id,
                device_id=payload.device_id,
                push_token=payload.push_token,
                platform=payload.platform,
            )
            self.session.add(device)
        else:
            device.user_id = current_user.id
            device.device_id = payload.device_id
            device.platform = payload.platform
        await self.session.commit()
        await self.session.refresh(device)
        return device

    async def unregister_device(self, current_user: User, push_token: str) -> None:
        await self.session.execute(
            delete(DeviceToken).where(
                DeviceToken.user_id == current_user.id,
                DeviceToken.push_token == push_token,
            )
        )
        await self.session.commit()

    async def get_user_push_tokens(self, user_id: str) -> list[str]:
        return [item.push_token for item in await self.devices.list_by_user_id(user_id)]


class PushNotificationService:
    def __init__(self, session: AsyncSession) -> None:
        self.devices = PushDeviceService(session)

    async def notify_new_message(
        self,
        recipient_user_ids: list[str],
        title: str,
        body: str,
        data: dict[str, str],
    ) -> None:
        tokens: list[str] = []
        for user_id in recipient_user_ids:
            tokens.extend(await self.devices.get_user_push_tokens(user_id))

        if not tokens:
            return

        auth = await self._get_fcm_auth()
        if auth is None:
            return
        access_token, project_id = auth

        url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        }

        try:
            async with httpx.AsyncClient(timeout=settings.fcm_timeout_seconds) as client:
                for token in tokens:
                    response = await client.post(
                        url,
                        json=self._build_fcm_message(
                            token=token,
                            title=title,
                            body=body,
                            data=data,
                        ),
                        headers=headers,
                    )
                    response.raise_for_status()
        except httpx.HTTPError:
            logger.exception("Failed to send FCM HTTP v1 push notification")

    async def _get_fcm_auth(self) -> tuple[str, str] | None:
        credentials_file = settings.google_application_credentials
        if not credentials_file:
            logger.info(
                "GOOGLE_APPLICATION_CREDENTIALS is not configured; "
                "skipped push notification"
            )
            return None

        try:
            credentials = service_account.Credentials.from_service_account_file(
                credentials_file,
                scopes=FCM_SCOPES,
            )
            project_id = settings.fcm_project_id or credentials.project_id
            if not project_id:
                logger.info("FCM_PROJECT_ID is not configured; skipped push notification")
                return None

            await asyncio.to_thread(credentials.refresh, Request())
            if not credentials.token:
                logger.info("Could not obtain FCM OAuth token; skipped push notification")
                return None
            return credentials.token, project_id
        except (OSError, ValueError):
            logger.exception("Failed to load Firebase service account credentials")
            return None

    def _build_fcm_message(
        self,
        token: str,
        title: str,
        body: str,
        data: dict[str, str],
    ) -> dict[str, object]:
        return {
            "message": {
                "token": token,
                "notification": {"title": title, "body": body},
                "data": data,
                "android": {"priority": "HIGH"},
                "apns": {"headers": {"apns-priority": "10"}},
            }
        }
