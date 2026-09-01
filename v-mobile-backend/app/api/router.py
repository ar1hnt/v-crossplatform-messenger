from fastapi import APIRouter

from app.modules.ai.router import router as ai_router
from app.modules.chats.router import router as chats_router
from app.modules.auth.router import router as auth_router
from app.modules.contacts.router import router as contacts_router
from app.modules.files.router import router as files_router
from app.modules.posts.router import router as posts_router
from app.modules.push.router import router as push_router
from app.modules.users.router import router as users_router

api_router = APIRouter()
api_router.include_router(ai_router, prefix="/ai", tags=["ai"])
api_router.include_router(auth_router, prefix="/auth", tags=["auth"])
api_router.include_router(users_router, prefix="/users", tags=["users"])
api_router.include_router(files_router, prefix="/files", tags=["files"])
api_router.include_router(posts_router, prefix="/posts", tags=["posts"])
api_router.include_router(chats_router, prefix="/chats", tags=["chats"])
api_router.include_router(contacts_router, prefix="/contacts", tags=["contacts"])
api_router.include_router(push_router, prefix="/push", tags=["push"])
