"""Lightweight geographic utilities — no external dependencies.

Uses the Haversine formula to compute great-circle distance between
two (latitude, longitude) pairs.
"""

from __future__ import annotations

import math

_EARTH_RADIUS_KM = 6_371.0  # mean radius


def haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Return the great-circle distance in **kilometres** between two points.

    Args:
        lat1, lon1: coordinates of point A (decimal degrees).
        lat2, lon2: coordinates of point B (decimal degrees).
    """
    rlat1, rlon1, rlat2, rlon2 = map(math.radians, (lat1, lon1, lat2, lon2))
    dlat = rlat2 - rlat1
    dlon = rlon2 - rlon1

    a = math.sin(dlat / 2) ** 2 + math.cos(rlat1) * math.cos(rlat2) * math.sin(dlon / 2) ** 2
    return 2 * _EARTH_RADIUS_KM * math.asin(math.sqrt(a))


def is_point_in_radius(
    user_lat: float,
    user_lon: float,
    centre_lat: float,
    centre_lon: float,
    radius_km: float,
) -> bool:
    """Return **True** when the user is within *radius_km* of the centre."""
    return haversine(user_lat, user_lon, centre_lat, centre_lon) <= radius_km
