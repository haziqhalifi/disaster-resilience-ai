"""Database layer for AI-driven adaptive learning & quiz system."""

from __future__ import annotations

import json
import uuid
from datetime import datetime, timezone

from app.db.supabase_client import get_client


# ── Quiz Attempts ─────────────────────────────────────────────────────────────

def create_quiz_attempt(
    *,
    user_id: str,
    hazard_type: str,
    score: int,
    total_questions: int,
    percentage: float,
    difficulty_avg: float,
    phase_scores: dict,
    weak_areas: list[str],
) -> dict:
    sb = get_client()
    row = {
        "id": str(uuid.uuid4()),
        "user_id": user_id,
        "hazard_type": hazard_type,
        "score": score,
        "total_questions": total_questions,
        "percentage": percentage,
        "difficulty_avg": difficulty_avg,
        "phase_scores": json.dumps(phase_scores),
        "weak_areas": json.dumps(weak_areas),
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    return sb.table("quiz_attempts").insert(row).execute().data[0]


def save_quiz_answers(attempt_id: str, results: list[dict]) -> None:
    sb = get_client()
    now = datetime.now(timezone.utc).isoformat()
    rows = []
    for idx, r in enumerate(results):
        rows.append({
            "id": str(uuid.uuid4()),
            "attempt_id": attempt_id,
            "question_index": idx,
            "question_text": r["question"],
            "phase": r["phase"],
            "difficulty": r.get("difficulty", 1),
            "selected_answer": r["selected"],
            "correct_answer": r["correct"],
            "is_correct": r["is_correct"],
            "explanation": r.get("explanation", ""),
            "created_at": now,
        })
    if rows:
        sb.table("quiz_answers").insert(rows).execute()


def get_user_attempts(user_id: str, hazard_type: str | None = None) -> list[dict]:
    sb = get_client()
    q = sb.table("quiz_attempts").select("*").eq("user_id", user_id)
    if hazard_type:
        q = q.eq("hazard_type", hazard_type)
    q = q.order("created_at", desc=True)
    return q.execute().data or []


# ── Learning Progress ─────────────────────────────────────────────────────────

def upsert_learning_progress(
    *,
    user_id: str,
    hazard_type: str,
    total_attempts: int,
    best_score: float,
    latest_score: float,
    mastery_level: float,
    phase_scores: dict,
    weak_areas: list[str],
) -> dict:
    sb = get_client()
    now = datetime.now(timezone.utc).isoformat()
    row = {
        "user_id": user_id,
        "hazard_type": hazard_type,
        "total_attempts": total_attempts,
        "best_score": best_score,
        "latest_score": latest_score,
        "mastery_level": mastery_level,
        "phase_scores": json.dumps(phase_scores),
        "weak_areas": json.dumps(weak_areas),
        "last_attempt_at": now,
        "updated_at": now,
    }
    # Try update first, insert if not found
    existing = (
        sb.table("learning_progress")
        .select("id")
        .eq("user_id", user_id)
        .eq("hazard_type", hazard_type)
        .execute()
        .data
    )
    if existing:
        row_id = existing[0]["id"]
        return (
            sb.table("learning_progress")
            .update(row)
            .eq("id", row_id)
            .execute()
            .data[0]
        )
    else:
        row["id"] = str(uuid.uuid4())
        return sb.table("learning_progress").insert(row).execute().data[0]


def get_user_progress(user_id: str) -> list[dict]:
    """Get learning progress across all hazard types for a user."""
    sb = get_client()
    return (
        sb.table("learning_progress")
        .select("*")
        .eq("user_id", user_id)
        .order("hazard_type")
        .execute()
        .data or []
    )


def get_user_hazard_progress(user_id: str, hazard_type: str) -> dict | None:
    sb = get_client()
    res = (
        sb.table("learning_progress")
        .select("*")
        .eq("user_id", user_id)
        .eq("hazard_type", hazard_type)
        .execute()
        .data
    )
    return res[0] if res else None
