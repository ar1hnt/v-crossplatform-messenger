from collections.abc import Callable

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse


class AppException(Exception):
    def __init__(self, status_code: int, code: str, message: str) -> None:
        self.status_code = status_code
        self.code = code
        self.message = message
        super().__init__(message)


class NotFoundException(AppException):
    def __init__(self, message: str = "Ресурс не найден") -> None:
        super().__init__(status.HTTP_404_NOT_FOUND, "not_found", message)


class UnauthorizedException(AppException):
    def __init__(self, message: str = "Требуется авторизация") -> None:
        super().__init__(status.HTTP_401_UNAUTHORIZED, "unauthorized", message)


class ForbiddenException(AppException):
    def __init__(self, message: str = "Недостаточно прав") -> None:
        super().__init__(status.HTTP_403_FORBIDDEN, "forbidden", message)


class ConflictException(AppException):
    def __init__(self, message: str = "Конфликт данных") -> None:
        super().__init__(status.HTTP_409_CONFLICT, "conflict", message)


class BadRequestException(AppException):
    def __init__(self, message: str = "Некорректный запрос") -> None:
        super().__init__(status.HTTP_400_BAD_REQUEST, "bad_request", message)


def register_exception_handlers(app: FastAPI) -> None:
    async def app_exception_handler(_: Request, exc: AppException) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content={"error": {"code": exc.code, "message": exc.message}},
        )

    async def validation_exception_handler(
        _: Request,
        exc: RequestValidationError,
    ) -> JSONResponse:
        return JSONResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            content={
                "error": {
                    "code": "validation_error",
                    "message": _format_validation_error(exc),
                },
            },
        )

    async def unexpected_exception_handler(_: Request, exc: Exception) -> JSONResponse:
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={"error": {"code": "internal_error", "message": "Внутренняя ошибка сервера"}},
        )

    handlers: list[tuple[type[Exception], Callable]] = [
        (AppException, app_exception_handler),
        (RequestValidationError, validation_exception_handler),
        (Exception, unexpected_exception_handler),
    ]
    for exception_type, handler in handlers:
        app.add_exception_handler(exception_type, handler)


def _format_validation_error(exc: RequestValidationError) -> str:
    errors = exc.errors()
    if not errors:
        return "Некорректные данные"

    error = errors[0]
    field_name = _translate_field_name(error.get("loc", ()))
    error_type = error.get("type", "")
    context = error.get("ctx", {})

    if error_type == "missing":
        return f"Поле \"{field_name}\" обязательно"
    if error_type == "string_too_short":
        min_length = context.get("min_length")
        if min_length is not None:
            return f"Поле \"{field_name}\" должно содержать минимум {min_length} символов"
    if error_type == "string_too_long":
        max_length = context.get("max_length")
        if max_length is not None:
            return f"Поле \"{field_name}\" должно содержать не больше {max_length} символов"
    if "email" in error_type:
        return "Введите корректный email"

    default_message = error.get("msg")
    if isinstance(default_message, str) and default_message.strip():
        return default_message.strip()
    return "Некорректные данные"


def _translate_field_name(location: tuple[object, ...]) -> str:
    field = location[-1] if location else "поле"
    field_names = {
        "email": "Email",
        "password": "Пароль",
        "full_name": "ФИО",
        "phone": "Телефон",
        "q": "Поисковый запрос",
    }
    return field_names.get(str(field), str(field))
