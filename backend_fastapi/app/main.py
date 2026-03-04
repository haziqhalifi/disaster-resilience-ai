"""Disaster Resilience AI — FastAPI Backend.

Run with:
    uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.endpoints import alerts, auth

app = FastAPI(
    title="Disaster Resilience AI API",
    version="0.1.0",
    description="REST API for disaster alerts and ML-powered risk predictions.",
)

# Allow the Flutter app to call the API during development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routes ──────────────────────────────────────────────────────────────────

app.include_router(alerts.router, prefix="/api/v1/alerts", tags=["alerts"])
app.include_router(auth.router, prefix="/api/v1/auth", tags=["auth"])


@app.get("/", tags=["health"])
async def health_check():
    """Root health-check endpoint."""
    return {"status": "ok", "service": "disaster-resilience-ai-backend"}
