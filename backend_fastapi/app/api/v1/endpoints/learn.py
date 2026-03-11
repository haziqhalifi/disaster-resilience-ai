"""AI-driven adaptive learning & quiz endpoints."""

from __future__ import annotations

import json

from fastapi import APIRouter, Depends

from ai_models.models.adaptive_quiz import AdaptiveQuizEngine
from app.api.v1.dependencies import get_current_user
from app.db import learning as learn_db
from app.schemas.learning import (
    HazardProgress,
    LearningProgressResponse,
    QuizGenerateRequest,
    QuizGenerateResponse,
    QuizQuestion,
    QuizSubmitRequest,
    QuizSubmitResponse,
    QuizResultItem,
)
from app.schemas.user import UserOut

router = APIRouter()


# ── Generate adaptive quiz ────────────────────────────────────────────────────

@router.post("/quiz/generate", response_model=QuizGenerateResponse)
async def generate_quiz(
    body: QuizGenerateRequest,
    current_user: UserOut = Depends(get_current_user),
):
    """Generate an AI-adapted quiz based on the user's learning history."""
    # Fetch historical attempts to compute mastery
    attempts = learn_db.get_user_attempts(current_user.id, body.hazard_type)

    # Build input for the AI engine
    history = []
    for a in attempts:
        ps = a.get("phase_scores")
        if isinstance(ps, str):
            ps = json.loads(ps)
        history.append({
            "score": a["score"],
            "total": a["total_questions"],
            "phase_scores": ps or {},
        })

    mastery = AdaptiveQuizEngine.compute_mastery(history)

    questions = AdaptiveQuizEngine.generate_quiz(
        hazard_type=body.hazard_type,
        num_questions=body.num_questions,
        phase_scores=mastery["phase_scores"] or None,
        overall_mastery=mastery["overall_mastery"],
    )

    info = (
        f"Mastery: {mastery['overall_mastery']:.0%} "
        f"({mastery['total_attempts']} previous attempts). "
        "Questions weighted towards your weak areas."
        if mastery["total_attempts"] > 0
        else "First quiz — questions selected across all phases and difficulty levels."
    )

    return QuizGenerateResponse(
        hazard_type=body.hazard_type,
        questions=[QuizQuestion(**q) for q in questions],
        total=len(questions),
        adaptive_info=info,
    )


# ── Submit quiz answers ───────────────────────────────────────────────────────

@router.post("/quiz/submit", response_model=QuizSubmitResponse)
async def submit_quiz(
    body: QuizSubmitRequest,
    current_user: UserOut = Depends(get_current_user),
):
    """Grade the quiz, save results, update mastery, and return personalised feedback."""
    # Grade with the AI engine
    grading = AdaptiveQuizEngine.grade_quiz(
        hazard_type=body.hazard_type,
        answers=[a.model_dump() for a in body.answers],
    )

    # Compute average difficulty of the questions that were answered
    from ai_models.models.adaptive_quiz import QUESTION_BANK
    bank = QUESTION_BANK.get(body.hazard_type, [])
    lookup = {q["text"]: q for q in bank}
    diffs = [lookup[a.question_text]["difficulty"] for a in body.answers if a.question_text in lookup]
    avg_diff = sum(diffs) / len(diffs) if diffs else 1.0

    # Save attempt to DB
    attempt = learn_db.create_quiz_attempt(
        user_id=current_user.id,
        hazard_type=body.hazard_type,
        score=grading["score"],
        total_questions=grading["total"],
        percentage=grading["percentage"],
        difficulty_avg=avg_diff,
        phase_scores=grading["phase_scores"],
        weak_areas=grading["weak_areas"],
    )

    # Save individual answers
    learn_db.save_quiz_answers(attempt["id"], grading["results"])

    # Recompute mastery from all attempts
    all_attempts = learn_db.get_user_attempts(current_user.id, body.hazard_type)
    history = []
    for a in all_attempts:
        ps = a.get("phase_scores")
        if isinstance(ps, str):
            ps = json.loads(ps)
        history.append({
            "score": a["score"],
            "total": a["total_questions"],
            "phase_scores": ps or {},
        })

    mastery = AdaptiveQuizEngine.compute_mastery(history)

    # Update learning progress
    best_pct = max(a["percentage"] for a in all_attempts)
    learn_db.upsert_learning_progress(
        user_id=current_user.id,
        hazard_type=body.hazard_type,
        total_attempts=mastery["total_attempts"],
        best_score=best_pct,
        latest_score=grading["percentage"],
        mastery_level=mastery["overall_mastery"],
        phase_scores=mastery["phase_scores"],
        weak_areas=grading["weak_areas"],
    )

    return QuizSubmitResponse(
        score=grading["score"],
        total=grading["total"],
        percentage=grading["percentage"],
        phase_scores=grading["phase_scores"],
        results=[QuizResultItem(**r) for r in grading["results"]],
        weak_areas=grading["weak_areas"],
        recommendations=grading["recommendations"],
        mastery_level=mastery["overall_mastery"],
    )


# ── Learning progress ─────────────────────────────────────────────────────────

@router.get("/progress", response_model=LearningProgressResponse)
async def get_progress(current_user: UserOut = Depends(get_current_user)):
    """Get the user's learning progress across all hazard types."""
    rows = learn_db.get_user_progress(current_user.id)

    progress = []
    for r in rows:
        ps = r.get("phase_scores")
        if isinstance(ps, str):
            ps = json.loads(ps)
        wa = r.get("weak_areas")
        if isinstance(wa, str):
            wa = json.loads(wa)
        progress.append(HazardProgress(
            hazard_type=r["hazard_type"],
            total_attempts=r["total_attempts"],
            best_score=r["best_score"],
            latest_score=r["latest_score"],
            mastery_level=r["mastery_level"],
            phase_scores=ps or {},
            weak_areas=wa or [],
            last_attempt_at=r.get("last_attempt_at"),
        ))

    total_quizzes = sum(p.total_attempts for p in progress)
    mastery_vals = [p.mastery_level for p in progress if p.total_attempts > 0]
    overall = sum(mastery_vals) / len(mastery_vals) if mastery_vals else 0.0

    # Build overall recommendations
    recs = []
    if not progress:
        recs.append("Start learning by taking your first quiz! Choose a hazard module that is relevant to your area.")
    else:
        low_mastery = [p for p in progress if p.mastery_level < 0.6 and p.total_attempts > 0]
        if low_mastery:
            names = ", ".join(p.hazard_type.title() for p in low_mastery)
            recs.append(f"Focus on improving: {names} — review the learning modules and retake quizzes.")
        not_started = {"flood", "landslide", "earthquake", "storm", "tsunami", "haze"} - {p.hazard_type for p in progress}
        if not_started:
            recs.append(f"Modules not yet attempted: {', '.join(sorted(n.title() for n in not_started))}.")

    return LearningProgressResponse(
        progress=progress,
        overall_mastery=round(overall, 3),
        total_quizzes=total_quizzes,
        recommendations=recs,
    )
