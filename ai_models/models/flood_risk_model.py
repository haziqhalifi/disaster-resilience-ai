"""Flood risk prediction model trained on synthetic ASEAN disaster data.

Features (7 inputs):
    0  rainfall_mm          – 24-hour cumulative rainfall in millimetres
    1  elevation_m          – ground elevation above sea level (metres)
    2  slope_deg            – terrain slope in degrees
    3  soil_saturation      – soil moisture saturation ratio (0.0 – 1.0)
    4  distance_to_river_km – distance to nearest river/waterway (km)
    5  historical_incidents – number of past flood events in the area (last 10 yr)
    6  population_density   – people per km² (used to weight urgency, not causation)

Output:
    risk_score  – float in [0, 1] representing probability of flood impact.
"""

from __future__ import annotations

import logging

import numpy as np
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.model_selection import train_test_split

logger = logging.getLogger(__name__)

# Feature names expected by this model
FEATURE_NAMES = [
    "rainfall_mm",
    "elevation_m",
    "slope_deg",
    "soil_saturation",
    "distance_to_river_km",
    "historical_incidents",
    "population_density",
]

NUM_FEATURES = len(FEATURE_NAMES)


def _generate_synthetic_data(
    n_samples: int = 5_000,
    seed: int = 42,
) -> tuple[np.ndarray, np.ndarray]:
    """Generate synthetic flood risk training data.

    The data encodes domain knowledge about flood causation in ASEAN:
    - Heavy rainfall + low elevation + high soil saturation → high risk
    - Proximity to rivers increases risk
    - Steep slopes increase landslide-induced flash flood risk
    - Areas with historical incidents are inherently riskier
    """
    rng = np.random.default_rng(seed)

    rainfall   = rng.exponential(scale=40, size=n_samples).clip(0, 500)
    elevation  = rng.uniform(0, 800, size=n_samples)
    slope      = rng.uniform(0, 60, size=n_samples)
    saturation = rng.beta(2, 3, size=n_samples)
    river_dist = rng.exponential(scale=5, size=n_samples).clip(0, 50)
    history    = rng.poisson(lam=2, size=n_samples).clip(0, 20)
    pop_dens   = rng.lognormal(mean=4.5, sigma=1.2, size=n_samples).clip(10, 10_000)

    # --- deterministic risk scoring (domain rules) ---
    risk_logit = (
        0.03  * rainfall
        - 0.008 * elevation
        + 0.02  * slope
        + 2.5   * saturation
        - 0.15  * river_dist
        + 0.25  * history
        + 0.0001 * pop_dens
        - 3.0   # baseline offset
    )
    noise = rng.normal(0, 0.5, size=n_samples)
    prob  = 1.0 / (1.0 + np.exp(-(risk_logit + noise)))
    labels = (prob >= 0.5).astype(int)

    X = np.column_stack([
        rainfall, elevation, slope, saturation,
        river_dist, history, pop_dens,
    ])
    return X, labels


class FloodRiskModel:
    """Gradient-boosted classifier for flood risk prediction.

    Trained at instantiation time on synthetic data that encodes
    ASEAN flood-risk domain knowledge.  In production this would be
    replaced by a model trained on real historical data.
    """

    def __init__(self, seed: int = 42) -> None:
        self.model_name = "FloodRiskGBM"
        self.version = "1.0.0"

        X, y = _generate_synthetic_data(n_samples=5_000, seed=seed)
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=seed, stratify=y,
        )

        self._clf = GradientBoostingClassifier(
            n_estimators=120,
            max_depth=4,
            learning_rate=0.1,
            subsample=0.8,
            random_state=seed,
        )
        self._clf.fit(X_train, y_train)

        acc = self._clf.score(X_test, y_test)
        logger.info(
            "FloodRiskGBM trained — test accuracy %.2f%% on %d samples",
            acc * 100,
            len(X_test),
        )

    def predict(self, features: np.ndarray) -> np.ndarray:
        """Return flood risk probability for each row.

        Args:
            features: shape (n_samples, 7) — see FEATURE_NAMES.

        Returns:
            1-D array of risk scores in [0, 1].
        """
        features = np.atleast_2d(features)
        if features.shape[1] != NUM_FEATURES:
            raise ValueError(
                f"Expected {NUM_FEATURES} features, got {features.shape[1]}"
            )
        # probability of class 1 (flood risk)
        return self._clf.predict_proba(features)[:, 1]

    def feature_importances(self) -> dict[str, float]:
        """Return named feature importance scores."""
        return dict(zip(FEATURE_NAMES, self._clf.feature_importances_))
