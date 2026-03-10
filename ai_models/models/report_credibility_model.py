"""Community report credibility scoring model.

Scores incoming community reports (flood, landslide, etc.) to assist
automated validation. Uses contextual features about each report to
predict whether the report is genuine.

Features (6 inputs):
    0  vouch_count       – how many community members vouched for this report
    1  description_length – character count of the report description
    2  has_precise_coords – 1 if lat/lon are provided, else 0
    3  report_age_hours   – hours since the report was submitted
    4  reporter_total_reports – total historical reports by this user
    5  proximity_to_risk_zone_km – distance to nearest known risk zone (km)

Output:
    confidence_score  – float in [0, 1]; higher = more likely genuine.
"""

from __future__ import annotations

import logging

import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split

logger = logging.getLogger(__name__)

FEATURE_NAMES = [
    "vouch_count",
    "description_length",
    "has_precise_coords",
    "report_age_hours",
    "reporter_total_reports",
    "proximity_to_risk_zone_km",
]

NUM_FEATURES = len(FEATURE_NAMES)


def _generate_synthetic_data(
    n_samples: int = 3_000,
    seed: int = 99,
) -> tuple[np.ndarray, np.ndarray]:
    """Generate synthetic report credibility training data.

    Domain assumptions:
    - More vouches → more credible
    - Longer, more detailed descriptions → more credible
    - Precise GPS coordinates → more credible
    - Very old reports → less credible (stale)
    - Users with more historical reports → more credible (trusted)
    - Reports near known risk zones → more credible
    """
    rng = np.random.default_rng(seed)

    vouches      = rng.poisson(lam=2, size=n_samples).clip(0, 30)
    desc_len     = rng.lognormal(mean=4.0, sigma=1.0, size=n_samples).clip(0, 1000).astype(int)
    has_coords   = rng.binomial(1, 0.85, size=n_samples)
    age_hours    = rng.exponential(scale=12, size=n_samples).clip(0, 168)
    user_reports = rng.poisson(lam=3, size=n_samples).clip(0, 50)
    risk_dist    = rng.exponential(scale=10, size=n_samples).clip(0, 100)

    # credibility logit
    logit = (
        0.5  * vouches
        + 0.005 * desc_len
        + 1.5  * has_coords
        - 0.03 * age_hours
        + 0.15 * user_reports
        - 0.08 * risk_dist
        - 1.5  # offset
    )
    noise  = rng.normal(0, 0.4, size=n_samples)
    prob   = 1.0 / (1.0 + np.exp(-(logit + noise)))
    labels = (prob >= 0.5).astype(int)

    X = np.column_stack([
        vouches, desc_len, has_coords,
        age_hours, user_reports, risk_dist,
    ])
    return X, labels


class ReportCredibilityModel:
    """Random-forest classifier for community report credibility.

    Trained at instantiation on synthetic data encoding domain knowledge
    about what makes a disaster report trustworthy.
    """

    def __init__(self, seed: int = 99) -> None:
        self.model_name = "ReportCredibilityRF"
        self.version = "1.0.0"

        X, y = _generate_synthetic_data(n_samples=3_000, seed=seed)
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=seed, stratify=y,
        )

        self._clf = RandomForestClassifier(
            n_estimators=100,
            max_depth=6,
            random_state=seed,
            n_jobs=-1,
        )
        self._clf.fit(X_train, y_train)

        acc = self._clf.score(X_test, y_test)
        logger.info(
            "ReportCredibilityRF trained — test accuracy %.2f%% on %d samples",
            acc * 100,
            len(X_test),
        )

    def predict(self, features: np.ndarray) -> np.ndarray:
        """Return credibility probability for each report.

        Args:
            features: shape (n_samples, 6) — see FEATURE_NAMES.

        Returns:
            1-D array of confidence scores in [0, 1].
        """
        features = np.atleast_2d(features)
        if features.shape[1] != NUM_FEATURES:
            raise ValueError(
                f"Expected {NUM_FEATURES} features, got {features.shape[1]}"
            )
        return self._clf.predict_proba(features)[:, 1]

    def feature_importances(self) -> dict[str, float]:
        """Return named feature importance scores."""
        return dict(zip(FEATURE_NAMES, self._clf.feature_importances_))
