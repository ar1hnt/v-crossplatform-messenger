from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from jwt import PyJWTError

from app.core.security import decode_token
from app.db.session import SessionLocal
from app.modules.chats.repository import ChatRepository
from app.modules.chats.service import ChatService
from app.modules.presence.service import PresenceService
from app.modules.users.repository import UserRepository
from app.websockets.connection_manager import connection_manager

router = APIRouter()


@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, token: str) -> None:
    try:
        payload = decode_token(token)
        if payload.get("type") != "access":
            await websocket.close(code=1008)
            return
    except PyJWTError:
        await websocket.close(code=1008)
        return

    user_id = str(payload["sub"])

    async with SessionLocal() as session:
        user = await UserRepository(session).get_by_id(user_id)
        if user is None:
            await websocket.close(code=1008)
            return

        await connection_manager.connect(user_id, websocket)
        await PresenceService(session).mark_online(user)

        chats = await ChatService(session).list_user_chats(user)
        for chat in chats:
            connection_manager.subscribe_chat(user_id, str(chat.id))

        await connection_manager.send_personal_event(
            user_id,
            {"event": "presence.updated", "data": {"user_id": user_id, "status": "online"}},
        )
        chat_repository = ChatRepository(session)
        for chat in chats:
            participant_ids = await chat_repository.list_participant_ids(chat.id)
            for participant_id in participant_ids:
                if participant_id != user_id:
                    peer_user = await UserRepository(session).get_by_id(participant_id)
                    if peer_user is not None:
                        await connection_manager.send_personal_event(
                            user_id,
                            {
                                "event": "presence.updated",
                                "data": {
                                    "user_id": participant_id,
                                    "status": (
                                        "online"
                                        if connection_manager.has_active_connection(participant_id)
                                        else str(peer_user.presence_status)
                                    ),
                                },
                            },
                        )
                    await connection_manager.send_personal_event(
                        participant_id,
                        {"event": "presence.updated", "data": {"user_id": user_id, "status": "online"}},
                    )

        try:
            while True:
                await websocket.receive_text()
        except WebSocketDisconnect:
            connection_manager.disconnect(user_id, websocket)
            if connection_manager.has_active_connection(user_id):
                return

            await PresenceService(session).mark_offline(user)
            for chat in chats:
                participant_ids = await chat_repository.list_participant_ids(chat.id)
                for participant_id in participant_ids:
                    if participant_id != user_id:
                        await connection_manager.send_personal_event(
                            participant_id,
                            {
                                "event": "presence.updated",
                                "data": {"user_id": user_id, "status": "offline"},
                            },
                        )
