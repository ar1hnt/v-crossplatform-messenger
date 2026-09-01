from uuid import UUID

from sqlalchemy import Select, delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.modules.chats.models import ChatParticipant
from app.modules.contacts.models import ContactSync
from app.modules.posts.models import Post, PostAttachment, PostComment, PostLike


class PostRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_by_id(self, post_id: str) -> Post | None:
        query: Select[tuple[Post]] = (
            select(Post)
            .options(selectinload(Post.attachments).selectinload(PostAttachment.file))
            .where(Post.id == post_id)
        )
        return await self.session.scalar(query)

    async def list_by_author(self, author_id: str, limit: int, offset: int) -> tuple[list[Post], int]:
        query = (
            select(Post)
            .options(selectinload(Post.attachments).selectinload(PostAttachment.file))
            .where(Post.author_id == author_id)
            .order_by(Post.created_at.desc())
            .limit(limit)
            .offset(offset)
        )
        count_query = select(func.count()).select_from(Post).where(Post.author_id == author_id)
        items = list((await self.session.scalars(query)).all())
        total = await self.session.scalar(count_query) or 0
        return items, total

    async def list_social_feed(self, user_id: UUID, limit: int, offset: int) -> tuple[list[Post], int]:
        user_chat_ids = select(ChatParticipant.chat_id).where(ChatParticipant.user_id == user_id)
        chat_author_ids = (
            select(ChatParticipant.user_id)
            .where(ChatParticipant.chat_id.in_(user_chat_ids))
            .where(ChatParticipant.user_id != user_id)
        )
        contact_author_ids = (
            select(ContactSync.matched_user_id)
            .where(ContactSync.owner_id == user_id)
            .where(ContactSync.matched_user_id.is_not(None))
            .where(ContactSync.matched_user_id != user_id)
        )
        author_ids = chat_author_ids.union(contact_author_ids).subquery()

        query = (
            select(Post)
            .options(selectinload(Post.attachments).selectinload(PostAttachment.file))
            .where(Post.author_id.in_(select(author_ids.c.user_id)))
            .where(Post.author_id != user_id)
            .order_by(Post.created_at.desc())
            .limit(limit)
            .offset(offset)
        )
        count_query = (
            select(func.count())
            .select_from(Post)
            .where(Post.author_id.in_(select(author_ids.c.user_id)))
            .where(Post.author_id != user_id)
        )
        items = list((await self.session.scalars(query)).all())
        total = await self.session.scalar(count_query) or 0
        return items, total

    async def count_likes(self, post_id: str | UUID) -> int:
        query = select(func.count()).select_from(PostLike).where(PostLike.post_id == post_id)
        return await self.session.scalar(query) or 0

    async def count_comments(self, post_id: str | UUID) -> int:
        query = select(func.count()).select_from(PostComment).where(PostComment.post_id == post_id)
        return await self.session.scalar(query) or 0

    async def is_liked_by_user(self, post_id: str | UUID, user_id: str | UUID) -> bool:
        query = select(PostLike.post_id).where(PostLike.post_id == post_id, PostLike.user_id == user_id)
        return await self.session.scalar(query) is not None

    async def delete_like(self, post_id: str, user_id: str) -> None:
        await self.session.execute(delete(PostLike).where(PostLike.post_id == post_id, PostLike.user_id == user_id))

    async def list_comments(self, post_id: str) -> list[PostComment]:
        query = select(PostComment).where(PostComment.post_id == post_id).order_by(PostComment.created_at.asc())
        return list((await self.session.scalars(query)).all())
