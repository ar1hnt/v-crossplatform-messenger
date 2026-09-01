from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.common.exceptions import NotFoundException
from app.common.pagination import PageMeta
from app.modules.files.models import StoredFile
from app.modules.posts.models import Post, PostAttachment, PostComment, PostLike
from app.modules.posts.repository import PostRepository
from app.modules.posts.schemas import (
    PostCommentCreateRequest,
    PostCommentResponse,
    PostCreateRequest,
    PostListResponse,
    PostResponse,
)
from app.modules.users.models import User
from app.modules.users.repository import UserRepository
from app.modules.users.schemas import UserProfileResponse


class PostService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.posts = PostRepository(session)
        self.users = UserRepository(session)

    async def create_post(self, user: User, payload: PostCreateRequest) -> Post:
        post = Post(author_id=user.id, text=payload.text)
        self.session.add(post)
        await self.session.flush()

        if payload.attachment_ids:
            files = list(
                (
                    await self.session.scalars(
                        select(StoredFile).where(StoredFile.id.in_(payload.attachment_ids))
                    )
                ).all()
            )
            for index, file in enumerate(files):
                self.session.add(PostAttachment(post_id=post.id, file_id=file.id, order_index=index))

        await self.session.commit()
        return await self._get_post_or_raise(str(post.id))

    async def list_user_posts(
        self,
        user_id: str,
        limit: int,
        offset: int,
        current_user: User | None = None,
    ) -> PostListResponse:
        items, total = await self.posts.list_by_author(user_id, limit, offset)
        return PostListResponse(
            items=[await self.build_post_response(item, current_user) for item in items],
            meta=PageMeta(limit=limit, offset=offset, total=total),
        )

    async def list_social_feed(self, current_user: User, limit: int, offset: int) -> PostListResponse:
        items, total = await self.posts.list_social_feed(current_user.id, limit, offset)
        return PostListResponse(
            items=[await self.build_post_response(item, current_user) for item in items],
            meta=PageMeta(limit=limit, offset=offset, total=total),
        )

    async def add_like(self, post_id: str, user: User) -> None:
        post = await self.posts.get_by_id(post_id)
        if post is None:
            raise NotFoundException("Пост не найден")
        if await self.posts.is_liked_by_user(post_id, user.id):
            return
        self.session.add(PostLike(post_id=post.id, user_id=user.id))
        await self.session.commit()

    async def remove_like(self, post_id: str, user: User) -> None:
        await self.posts.delete_like(post_id, str(user.id))
        await self.session.commit()

    async def list_comments(self, post_id: str) -> list[PostCommentResponse]:
        post = await self.posts.get_by_id(post_id)
        if post is None:
            raise NotFoundException("Пост не найден")
        comments = await self.posts.list_comments(post_id)
        return [await self.build_comment_response(comment) for comment in comments]

    async def create_comment(
        self,
        post_id: str,
        user: User,
        payload: PostCommentCreateRequest,
    ) -> PostCommentResponse:
        post = await self.posts.get_by_id(post_id)
        if post is None:
            raise NotFoundException("Пост не найден")
        comment = PostComment(post_id=post.id, author_id=user.id, text=payload.text)
        self.session.add(comment)
        await self.session.commit()
        await self.session.refresh(comment)
        return await self.build_comment_response(comment)

    async def _get_post_or_raise(self, post_id: str) -> Post:
        post = await self.posts.get_by_id(post_id)
        if post is None:
            raise NotFoundException("Пост не найден")
        return post

    async def build_post_response(self, post: Post, current_user: User | None) -> PostResponse:
        author = await self.users.get_by_id(post.author_id)
        response = PostResponse.model_validate(post)
        return response.model_copy(
            update={
                "author": UserProfileResponse.model_validate(author) if author else None,
                "likes_count": await self.posts.count_likes(post.id),
                "comments_count": await self.posts.count_comments(post.id),
                "is_liked": (
                    await self.posts.is_liked_by_user(post.id, current_user.id)
                    if current_user is not None
                    else False
                ),
            }
        )

    async def build_comment_response(self, comment: PostComment) -> PostCommentResponse:
        author = await self.users.get_by_id(comment.author_id)
        response = PostCommentResponse.model_validate(comment)
        return response.model_copy(
            update={"author": UserProfileResponse.model_validate(author) if author else None}
        )
