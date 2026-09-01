# NEOCHAT Frontend

## Запуск

```bash
flutter pub get
flutter run
```

## Что уже есть

- feature-based структура
- Riverpod
- Dio
- go_router
- secure storage для токенов
- базовый theme и экраны `auth`, `feed`, `chats`, `chat detail`, `contacts`, `profile`
- REST-интеграция с backend для auth/profile/posts/chats/contacts
- WebSocket-подключение для live-сообщений и presence
- синхронизация контактов через `flutter_contacts`

## Дальше

- UI для вложений и голосовых сообщений
- push-токены устройств на клиенте
- полировка экранов под production-уровень
