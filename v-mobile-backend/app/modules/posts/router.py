from fastapi import APIRouter, Depends, Header, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db_session
from app.modules.auth.service import AuthService
from app.modules.posts.schemas import (
    PostCommentCreateRequest,
    PostCommentResponse,
    PostCreateRequest,
    PostListResponse,
    PostResponse,
)
from app.modules.posts.service import PostService

router = APIRouter()


@router.post("", response_model=PostResponse, status_code=status.HTTP_201_CREATED)
async def create_post(
    payload: PostCreateRequest,
    authorization: str = Header(default=""),
    session: AsyncSession = Depends(get_db_session),
) -> PostResponse:
    auth_service = AuthService(session)
    user = await auth_service.get_current_user_from_header(authorization)
    service = PostService(session)
    post = await service.create_post(user, payload)
    return await service.build_post_response(post, user)


@router.get("/feed", response_model=PostListResponse)
async def get_feed_posts(
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    authorization: str = Header(default=""),
    session: AsyncSession = Depends(get_db_session),
) -> PostListResponse:
    auth_service = AuthService(session)
    user = await auth_service.get_current_user_from_header(authorization)
    service = PostService(session)
    return await service.list_social_feed(user, limit, offset)


@router.get("/users/{user_id}", response_model=PostListResponse)
async def get_user_posts(
    user_id: str,
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    authorization: str = Header(default=""),
    session: AsyncSession = Depends(get_db_session),
) -> PostListResponse:
    current_user = None
    if authorization:
        current_user = await AuthService(session).get_current_user_from_header(authorization)
    service = PostService(session)
    return await service.list_user_posts(user_id, limit, offset, current_user)


@router.post("/{post_id}/likes", status_code=status.HTTP_204_NO_CONTENT)
async def like_post(
    post_id: str,
    authorization: str = Header(default=""),
    session: AsyncSession = Depends(get_db_session),
) -> None:
    auth_service = AuthService(session)
    user = await auth_service.get_current_user_from_header(authorization)
    service = PostService(session)
    await service.add_like(post_id, user)


@router.delete("/{post_id}/likes", status_code=status.HTTP_204_NO_CONTENT)
async def unlike_post(
    post_id: str,
    authorization: str = Header(default=""),
    session: AsyncSession = Depends(get_db_session),
) -> None:
    auth_service = AuthService(session)
    user = await auth_service.get_current_user_from_header(authorization)
    service = PostService(session)
    await service.remove_like(post_id, user)


@router.get("/{post_id}/comments", response_model=list[PostCommentResponse])
async def get_comments(
    post_id: str,
    session: AsyncSession = Depends(get_db_session),
) -> list[PostCommentResponse]:
    service = PostService(session)
    return await service.list_comments(post_id)


@router.post("/{post_id}/comments", response_model=PostCommentResponse, status_code=status.HTTP_201_CREATED)
async def create_comment(
    post_id: str,
    payload: PostCommentCreateRequest,
    authorization: str = Header(default=""),
    session: AsyncSession = Depends(get_db_session),
) -> PostCommentResponse:
    auth_service = AuthService(session)
    user = await auth_service.get_current_user_from_header(authorization)
    service = PostService(session)
    return await service.create_comment(post_id, user, payload)
