from pydantic import BaseModel, Field


class MessageSuggestionRequest(BaseModel):
    tone: str | None = Field(default=None, max_length=120)
    instruction: str | None = Field(default=None, max_length=500)


class PostSuggestionRequest(BaseModel):
    topic: str | None = Field(default=None, max_length=500)
    draft: str | None = Field(default=None, max_length=2000)
    tone: str | None = Field(default=None, max_length=120)


class AiSuggestionResponse(BaseModel):
    text: str
    provider: str
    model: str
