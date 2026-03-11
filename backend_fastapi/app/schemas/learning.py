"""Pydantic schemas for the AI-driven adaptive learning / quiz system."""

from __future__ import annotations

from datetime import datetime
from typing import Dict, List, Optional

from pydantic import BaseModel, Field


# ── Quiz Generation ───────────────────────────────────────────────────────────

class QuizGenerateRequest(BaseModel):
    hazard_type: str = Field(..., description="e.g. flood, landslide, earthquake")
    num_questions: int = Field(5, ge=1, le=15)


class QuizQuestion(BaseModel):
    index: int
    text: str
    options: Dict[str, str]
    phase: str
    difficulty: int


class QuizGenerateResponse(BaseModel):
    hazard_type: str
    questions: List[QuizQuestion]
    total: int
    adaptive_info: str = Field(
        default="Questions selected by AI based on your learning history."
    )


# ── Quiz Submission ───────────────────────────────────────────────────────────

class QuizAnswerItem(BaseModel):
    question_text: str
    selected: str = Field(..., pattern=r"^[A-D]$")


class QuizSubmitRequest(BaseModel):
    hazard_type: str
    answers: List[QuizAnswerItem]


class QuizResultItem(BaseModel):
    question: str
    selected: str
    correct: str
    is_correct: bool
    explanation: str
    phase: str


class QuizSubmitResponse(BaseModel):
    score: int
    total: int
    percentage: float
    phase_scores: Dict[str, Optional[float]]
    results: List[QuizResultItem]
    weak_areas: List[str]
    recommendations: List[str]
    mastery_level: float = Field(
        0.0, description="Updated overall mastery 0-1 after this attempt"
    )


# ── Learning Progress ─────────────────────────────────────────────────────────

class HazardProgress(BaseModel):
    hazard_type: str
    total_attempts: int = 0
    best_score: float = 0
    latest_score: float = 0
    mastery_level: float = 0
    phase_scores: Dict[str, Optional[float]] = {}
    weak_areas: List[str] = []
    last_attempt_at: Optional[datetime] = None


class LearningProgressResponse(BaseModel):
    progress: List[HazardProgress]
    overall_mastery: float = Field(
        0.0, description="Average mastery across all hazard types attempted"
    )
    total_quizzes: int = 0
    recommendations: List[str] = []
