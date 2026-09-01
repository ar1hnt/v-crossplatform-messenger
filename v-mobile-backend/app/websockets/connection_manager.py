from collections import defaultdict
from typing import Any

from fastapi import WebSocket
from starlette.websockets import WebSocketDisconnect


class ConnectionManager:
    def __init__(self) -> None:
        self.user_connections: dict[str, set[WebSocket]] = defaultdict(set)
        self.chat_subscriptions: dict[str, set[str]] = defaultdict(set)

    async def connect(self, user_id: str, websocket: WebSocket) -> None:
        await websocket.accept()
        self.user_connections[user_id].add(websocket)

    def disconnect(self, user_id: str, websocket: WebSocket) -> None:
        connections = self.user_connections.get(user_id, set())
        if websocket in connections:
            connections.remove(websocket)
        if not connections:
            self.user_connections.pop(user_id, None)

    def subscribe_chat(self, user_id: str, chat_id: str) -> None:
        self.chat_subscriptions[chat_id].add(user_id)

    def has_active_connection(self, user_id: str) -> bool:
        return bool(self.user_connections.get(user_id))

    async def send_personal_event(self, user_id: str, payload: dict[str, Any]) -> None:
        for connection in list(self.user_connections.get(user_id, set())):
            try:
                await connection.send_json(payload)
            except (RuntimeError, WebSocketDisconnect):
                self.disconnect(user_id, connection)

    async def broadcast_to_chat(self, chat_id: str, payload: dict[str, Any]) -> None:
        for user_id in list(self.chat_subscriptions.get(chat_id, set())):
            await self.send_personal_event(user_id, payload)


connection_manager = ConnectionManager()
