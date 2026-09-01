# V Messenger Backend

## Запуск

1. Скопировать `.env.example` в `.env`
2. Запустить инфраструктуру:

```bash
docker compose up --build
```

3. Применить миграции:

```bash
docker compose exec backend alembic upgrade head
```

4. Локальный запуск без Docker:

```bash
pip install -e .
uvicorn app.main:app --reload
```

## Что уже есть

- базовая конфигурация через `.env`
- async SQLAlchemy 2.0
- Alembic
- JWT auth с access/refresh
- пользователи и профиль
- загрузка файлов в MinIO
- посты, лайки, комментарии
- приватные чаты, сообщения и `message.read`
- WebSocket presence и real-time сообщения
- синхронизация контактов
- регистрация push-токенов устройств

## Ограничения текущего MVP

- push-слой подготовлен архитектурно, но без реальной отправки через FCM/APNs
- на Flutter сейчас реализован базовый UI для текстовых сообщений; вложения и голосовые сообщения уже поддержаны backend-структурой и могут быть добавлены следующим шагом
