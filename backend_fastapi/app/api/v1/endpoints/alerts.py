"""Alert-related API endpoints."""

from fastapi import APIRouter

from app.schemas.alert import (
    PingResponse,
    PredictRequest,
    PredictResponse,
    ReportScoreRequest,
    ReportScoreResponse,
)

router = APIRouter()


@router.get("/ping", response_model=PingResponse)
async def ping():
    """Simple liveness probe for the alerts service."""
    return PingResponse(message="pong", service="alerts")


@router.post("/predict", response_model=PredictResponse)
async def predict_risk(body: PredictRequest) -> PredictResponse:
    """Predict flood/disaster risk from environmental features.

    Accepts 7 features: rainfall_mm, elevation_m, slope_deg,
    soil_saturation, distance_to_river_km, historical_incidents,
    population_density.
    """
    from ai_models.services.inference import predict_risk as _predict

    result = _predict({"features": body.features})
    return PredictResponse(**result)


@router.post("/score-report", response_model=ReportScoreResponse)
async def score_report(body: ReportScoreRequest) -> ReportScoreResponse:
    """Score the credibility of a community disaster report using AI.

    Returns a confidence score (0–1) indicating how likely the report
    is genuine, based on contextual features.
    """
    from ai_models.services.inference import score_report as _score

    result = _score(
        vouch_count=body.vouch_count,
        description_length=body.description_length,
        has_precise_coords=body.has_precise_coords,
        report_age_hours=body.report_age_hours,
        reporter_total_reports=body.reporter_total_reports,
        proximity_to_risk_zone_km=body.proximity_to_risk_zone_km,
    )
    return ReportScoreResponse(**result)
