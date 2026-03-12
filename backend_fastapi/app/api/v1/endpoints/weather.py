"""Weather proxy — forwards requests to Open-Meteo to avoid CORS in browser."""

from fastapi import APIRouter, Query
import httpx

router = APIRouter()
OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"


@router.get("/forecast")
async def get_weather_forecast(
    latitude: float = Query(..., ge=-90, le=90),
    longitude: float = Query(..., ge=-180, le=180),
    timezone: str = Query(default="Asia/Kuala_Lumpur"),
    forecast_days: int = Query(default=7, ge=1, le=16),
):
    """Proxy to Open-Meteo API. Avoids CORS when Flutter web runs in browser."""
    params = {
        "latitude": latitude,
        "longitude": longitude,
        "current": "temperature_2m,weathercode,windspeed_10m,relative_humidity_2m",
        "daily": "weathercode,temperature_2m_max,temperature_2m_min,precipitation_sum",
        "timezone": timezone,
        "forecast_days": forecast_days,
    }
    async with httpx.AsyncClient(timeout=15.0) as client:
        resp = await client.get(OPEN_METEO_URL, params=params)
        resp.raise_for_status()
        return resp.json()
