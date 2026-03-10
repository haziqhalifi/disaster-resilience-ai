"""High-level inference service that wraps ML models.

Exposes two prediction functions:
  - predict_risk()       → flood / disaster risk scoring
  - score_report()       → community report credibility scoring
"""

from __future__ import annotations

import logging

import numpy as np

from ai_models.models.flood_risk_model import FloodRiskModel, FEATURE_NAMES as RISK_FEATURES
from ai_models.models.report_credibility_model import (
    ReportCredibilityModel,
    FEATURE_NAMES as REPORT_FEATURES,
)

logger = logging.getLogger(__name__)

# ── Singleton instances (lazy-loaded) ─────────────────────────────────────────

_risk_model: FloodRiskModel | None = None
_report_model: ReportCredibilityModel | None = None


def _get_risk_model() -> FloodRiskModel:
    global _risk_model
    if _risk_model is None:
        logger.info("Loading FloodRiskModel …")
        _risk_model = FloodRiskModel()
    return _risk_model


def _get_report_model() -> ReportCredibilityModel:
    global _report_model
    if _report_model is None:
        logger.info("Loading ReportCredibilityModel …")
        _report_model = ReportCredibilityModel()
    return _report_model


# ── Public API ────────────────────────────────────────────────────────────────

def predict_risk(input_data: dict) -> dict:
    """Run a flood-risk prediction.

    Args:
        input_data: Dict with ``"features"`` — a list of 7 numeric values
            corresponding to::

                rainfall_mm, elevation_m, slope_deg, soil_saturation,
                distance_to_river_km, historical_incidents, population_density

    Returns:
        Dict with ``risk_score``, ``risk_level``, ``model``, ``model_version``,
        and ``feature_importances``.
    """
    model = _get_risk_model()

    raw = input_data.get("features", [])
    if len(raw) != len(RISK_FEATURES):
        raise ValueError(
            f"Expected {len(RISK_FEATURES)} features ({RISK_FEATURES}), got {len(raw)}"
        )

    features = np.array(raw, dtype=float).reshape(1, -1)
    score = float(model.predict(features)[0])

    if score >= 0.80:
        level = "critical"
    elif score >= 0.60:
        level = "high"
    elif score >= 0.40:
        level = "moderate"
    elif score >= 0.20:
        level = "low"
    else:
        level = "minimal"

    return {
        "risk_score": round(score, 4),
        "risk_level": level,
        "model": model.model_name,
        "model_version": model.version,
        "feature_importances": model.feature_importances(),
    }


def score_report(
    *,
    vouch_count: int = 0,
    description_length: int = 0,
    has_precise_coords: bool = True,
    report_age_hours: float = 0.0,
    reporter_total_reports: int = 0,
    proximity_to_risk_zone_km: float = 50.0,
) -> dict:
    """Score the credibility of a community report.

    Returns:
        Dict with ``confidence_score``, ``is_credible``, ``model``,
        ``model_version``, and ``feature_importances``.
    """
    model = _get_report_model()

    features = np.array(
        [[
            vouch_count,
            description_length,
            int(has_precise_coords),
            report_age_hours,
            reporter_total_reports,
            proximity_to_risk_zone_km,
        ]],
        dtype=float,
    )

    score = float(model.predict(features)[0])

    return {
        "confidence_score": round(score, 4),
        "is_credible": score >= 0.6,
        "model": model.model_name,
        "model_version": model.version,
        "feature_importances": model.feature_importances(),
    }
