from fastapi import APIRouter, Depends, File, Form, Header, HTTPException, UploadFile, status
from fastapi.responses import Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db_session
from app.modules.auth.service import AuthService
from app.modules.files.schemas import FileDownloadUrlResponse, UploadedFileResponse
from app.modules.files.service import FileService

router = APIRouter()


def _parse_range_header(range_header: str, file_size: int) -> tuple[int, int]:
    if not range_header.startswith("bytes="):
        raise HTTPException(status_code=status.HTTP_416_REQUESTED_RANGE_NOT_SATISFIABLE)

    range_value = range_header[len("bytes=") :].strip()
    if "," in range_value:
        raise HTTPException(status_code=status.HTTP_416_REQUESTED_RANGE_NOT_SATISFIABLE)

    start_value, _, end_value = range_value.partition("-")
    if not start_value and not end_value:
        raise HTTPException(status_code=status.HTTP_416_REQUESTED_RANGE_NOT_SATISFIABLE)

    if not start_value:
        length = int(end_value)
        if length <= 0:
            raise HTTPException(status_code=status.HTTP_416_REQUESTED_RANGE_NOT_SATISFIABLE)
        start = max(file_size - length, 0)
        end = file_size - 1
        return start, end

    start = int(start_value)
    end = file_size - 1 if not end_value else int(end_value)

    if start < 0 or end < start or start >= file_size:
        raise HTTPException(status_code=status.HTTP_416_REQUESTED_RANGE_NOT_SATISFIABLE)

    end = min(end, file_size - 1)
    return start, end


@router.post("/upload", response_model=UploadedFileResponse, status_code=status.HTTP_201_CREATED)
async def upload_file(
    file: UploadFile = File(...),
    kind: str = Form(...),
    authorization: str = Header(default=""),
    session: AsyncSession = Depends(get_db_session),
) -> UploadedFileResponse:
    auth_service = AuthService(session)
    user = await auth_service.get_current_user_from_header(authorization)
    service = FileService(session)
    stored_file = await service.upload_file(user, file, kind)
    return UploadedFileResponse.model_validate(stored_file)


@router.get("/{file_id}/download-url", response_model=FileDownloadUrlResponse)
async def get_download_url(
    file_id: str,
    authorization: str = Header(default=""),
    session: AsyncSession = Depends(get_db_session),
) -> FileDownloadUrlResponse:
    auth_service = AuthService(session)
    user = await auth_service.get_current_user_from_header(authorization)
    service = FileService(session)
    return await service.get_download_url(file_id, user)


@router.get("/{file_id}/content")
async def get_file_content(
    file_id: str,
    authorization: str = Header(default=""),
    range_header: str | None = Header(default=None, alias="Range"),
    session: AsyncSession = Depends(get_db_session),
) -> Response:
    auth_service = AuthService(session)
    user = await auth_service.get_current_user_from_header(authorization)
    service = FileService(session)
    stored_file = await service.get_file_record(file_id, user)
    object_stat = service.storage.stat(stored_file.object_name)
    total_size = stored_file.size or object_stat.size
    content_type = stored_file.content_type or object_stat.content_type or "application/octet-stream"

    base_headers = {
        "Content-Disposition": f'inline; filename="{stored_file.original_name}"',
        "Cache-Control": "private, max-age=300",
        "Accept-Ranges": "bytes",
    }

    if range_header:
        start, end = _parse_range_header(range_header, total_size)
        content_length = end - start + 1
        content, detected_content_type = service.storage.download(
            stored_file.object_name,
            offset=start,
            length=content_length,
        )
        return Response(
            content=content,
            status_code=status.HTTP_206_PARTIAL_CONTENT,
            media_type=detected_content_type or content_type,
            headers={
                **base_headers,
                "Content-Length": str(content_length),
                "Content-Range": f"bytes {start}-{end}/{total_size}",
            },
        )

    content, detected_content_type = service.storage.download(stored_file.object_name)
    return Response(
        content=content,
        media_type=detected_content_type or content_type,
        headers={**base_headers, "Content-Length": str(total_size)},
    )
