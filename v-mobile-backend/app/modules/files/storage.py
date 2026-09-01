from datetime import timedelta
from io import BytesIO
from uuid import uuid4

from fastapi import UploadFile
from minio import Minio
from minio.datatypes import Object

from app.core.config import settings


class MinioStorage:
    def __init__(self) -> None:
        self.client = Minio(
            endpoint=settings.minio_endpoint,
            access_key=settings.minio_access_key,
            secret_key=settings.minio_secret_key,
            secure=settings.minio_secure,
        )
        self.bucket_name = settings.minio_bucket

    def ensure_bucket_exists(self) -> None:
        if not self.client.bucket_exists(self.bucket_name):
            self.client.make_bucket(self.bucket_name)

    async def upload(self, upload_file: UploadFile, owner_prefix: str) -> tuple[str, int]:
        content = await upload_file.read()
        object_name = f"{owner_prefix}/{uuid4()}-{upload_file.filename}"
        self.client.put_object(
            self.bucket_name,
            object_name,
            BytesIO(content),
            length=len(content),
            content_type=upload_file.content_type or "application/octet-stream",
        )
        return object_name, len(content)

    def generate_download_url(self, object_name: str) -> str:
        return self.client.presigned_get_object(self.bucket_name, object_name, expires=timedelta(minutes=15))

    def stat(self, object_name: str) -> Object:
        return self.client.stat_object(self.bucket_name, object_name)

    def download(
        self,
        object_name: str,
        *,
        offset: int = 0,
        length: int | None = None,
    ) -> tuple[bytes, str | None]:
        response = self.client.get_object(
            self.bucket_name,
            object_name,
            offset=offset,
            length=length or 0,
        )
        try:
            data = response.read()
            content_type = response.headers.get("Content-Type")
            return data, content_type
        finally:
            response.close()
            response.release_conn()
