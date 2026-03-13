"""Pydantic schemas for chatbot assistant requests/responses."""

from pydantic import BaseModel, Field


class AssistantChatRequest(BaseModel):
    """Incoming user chat message for the OpenAI Assistant."""

    message: str = Field(..., min_length=1, max_length=4000)
    thread_id: str | None = None


class AssistantChatResponse(BaseModel):
    """Assistant reply plus thread id for conversation continuity."""

    reply: str
    thread_id: str
