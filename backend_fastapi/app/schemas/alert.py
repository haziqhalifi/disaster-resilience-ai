"""Pydantic schemas for alert endpoints."""

from pydantic import BaseModel, Field


class PingResponse(BaseModel):
    message: str = "pong"
    service: str = "alerts"


class PredictRequest(BaseModel):
    """Request body for the /alerts/predict endpoint.

    Features (7 values, in order):
        rainfall_mm, elevation_m, slope_deg, soil_saturation,
        distance_to_river_km, historical_incidents, population_density
    """

    features: list[float] = Field(
        ...,
        min_length=7,
        max_length=7,
        description=(
            "List of 7 numeric feature values: rainfall_mm, elevation_m, "
            "slope_deg, soil_saturation, distance_to_river_km, "
            "historical_incidents, population_density."
        ),
        examples=[[120.0, 15.0, 8.5, 0.75, 1.2, 5, 350.0]],
    )


class PredictResponse(BaseModel):
    """Response body for the /alerts/predict endpoint."""

    risk_score: float = Field(
        ..., ge=0.0, le=1.0, description="Predicted risk score between 0 and 1."
    )
    risk_level: str = Field(
        ..., description="Human-readable risk level: minimal, low, moderate, high, critical."
    )
    model: str = Field(..., description="Name of the model used.")
    model_version: str = Field(..., description="Version of the model used.")
    feature_importances: dict[str, float] = Field(
        default_factory=dict,
        description="Per-feature importance scores from the model.",
    )


class ReportScoreRequest(BaseModel):
    """Request body for the /alerts/score-report endpoint."""

    vouch_count: int = Field(default=0, ge=0)
    description_length: int = Field(default=0, ge=0)
    has_precise_coords: bool = True
    report_age_hours: float = Field(default=0.0, ge=0.0)
    reporter_total_reports: int = Field(default=0, ge=0)
    proximity_to_risk_zone_km: float = Field(default=50.0, ge=0.0)


class ReportScoreResponse(BaseModel):
    """Response body for the /alerts/score-report endpoint."""

    confidence_score: float = Field(
        ..., ge=0.0, le=1.0, description="AI-predicted credibility score."
    )
    is_credible: bool = Field(
        ..., description="True if confidence_score >= 0.6."
    )
    model: str
    model_version: str
    feature_importances: dict[str, float] = Field(default_factory=dict)
