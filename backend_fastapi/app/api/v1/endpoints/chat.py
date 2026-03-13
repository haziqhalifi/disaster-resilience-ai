"""Chat endpoint that proxies to OpenAI Assistants API."""

from __future__ import annotations

import asyncio

import httpx
from fastapi import APIRouter, HTTPException

from app.core.config import OPENAI_API_KEY, OPENAI_ASSISTANT_ID
from app.schemas.chat import AssistantChatRequest, AssistantChatResponse

router = APIRouter()

_OPENAI_BASE_URL = "https://api.openai.com/v1"


def _require_openai_config() -> None:
    if not OPENAI_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="OPENAI_API_KEY is not configured on the backend.",
        )
    if not OPENAI_ASSISTANT_ID:
        raise HTTPException(
            status_code=503,
            detail="OPENAI_ASSISTANT_ID is not configured on the backend.",
        )


def _openai_headers() -> dict[str, str]:
    return {
        "Authorization": f"Bearer {OPENAI_API_KEY}",
        "Content-Type": "application/json",
        "OpenAI-Beta": "assistants=v2",
    }


async def _extract_latest_assistant_reply(
    client: httpx.AsyncClient,
    thread_id: str,
) -> str:
    messages_resp = await client.get(
        f"{_OPENAI_BASE_URL}/threads/{thread_id}/messages",
        params={"order": "desc", "limit": 10},
        headers=_openai_headers(),
    )
    if messages_resp.status_code != 200:
        raise HTTPException(status_code=502, detail="Failed to fetch assistant reply.")

    messages_data = messages_resp.json()
    for message in messages_data.get("data", []):
        if message.get("role") != "assistant":
            continue
        for block in message.get("content", []):
            if block.get("type") != "text":
                continue
            text_value = block.get("text", {}).get("value")
            if isinstance(text_value, str) and text_value.strip():
                return text_value.strip()

    raise HTTPException(status_code=502, detail="Assistant returned an empty reply.")


@router.post("/assistant", response_model=AssistantChatResponse)
async def chat_with_assistant(body: AssistantChatRequest) -> AssistantChatResponse:
    """Send user message to configured OpenAI Assistant and return its reply."""
    _require_openai_config()

    async with httpx.AsyncClient(timeout=20.0) as client:
        thread_id = body.thread_id

        if not thread_id:
            thread_resp = await client.post(
                f"{_OPENAI_BASE_URL}/threads",
                headers=_openai_headers(),
                json={},
            )
            if thread_resp.status_code != 200:
                raise HTTPException(status_code=502, detail="Failed to create assistant thread.")
            thread_id = thread_resp.json().get("id")
            if not thread_id:
                raise HTTPException(status_code=502, detail="OpenAI thread id missing.")

        user_message_resp = await client.post(
            f"{_OPENAI_BASE_URL}/threads/{thread_id}/messages",
            headers=_openai_headers(),
            json={"role": "user", "content": body.message},
        )
        if user_message_resp.status_code != 200:
            raise HTTPException(status_code=502, detail="Failed to post user message.")

        run_resp = await client.post(
            f"{_OPENAI_BASE_URL}/threads/{thread_id}/runs",
            headers=_openai_headers(),
            json={"assistant_id": OPENAI_ASSISTANT_ID},
        )
        if run_resp.status_code != 200:
            raise HTTPException(status_code=502, detail="Failed to start assistant run.")

        run_id = run_resp.json().get("id")
        if not run_id:
            raise HTTPException(status_code=502, detail="OpenAI run id missing.")

        for _ in range(30):
            status_resp = await client.get(
                f"{_OPENAI_BASE_URL}/threads/{thread_id}/runs/{run_id}",
                headers=_openai_headers(),
            )
            if status_resp.status_code != 200:
                raise HTTPException(status_code=502, detail="Failed to poll assistant run.")

            run_status = status_resp.json().get("status")
            if run_status == "completed":
                reply = await _extract_latest_assistant_reply(client, thread_id)
                return AssistantChatResponse(reply=reply, thread_id=thread_id)

            if run_status in {"failed", "cancelled", "expired", "incomplete"}:
                raise HTTPException(
                    status_code=502,
                    detail=f"Assistant run ended with status: {run_status}",
                )

            await asyncio.sleep(0.8)

    raise HTTPException(status_code=504, detail="Assistant run timed out.")
