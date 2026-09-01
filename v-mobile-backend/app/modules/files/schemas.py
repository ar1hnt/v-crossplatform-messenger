from uuid import UUID

from pydantic import BaseModel, ConfigDict


class UploadedFileResponse(BaseModel):
    id: UUID
    original_name: str
    content_type: str
    size: int
    kind: str

    model_config = ConfigDict(from_attributes=True)


class FileDownloadUrlResponse(BaseModel):
    url: str
