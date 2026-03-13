"""Multi-agent AI analysis service for disaster reports using Claude tool use."""

from __future__ import annotations

import json
import logging
import re

import httpx

from app.core.config import ANTHROPIC_API_KEY

logger = logging.getLogger(__name__)


# ── Sub-agent tool implementations ────────────────────────────────────────────

def _news_agent(query: str) -> str:
    """Search DuckDuckGo Instant Answer API for related news (free, no key)."""
    try:
        url = "https://api.duckduckgo.com/"
        params = {"q": query, "format": "json", "no_html": "1", "skip_disambig": "1"}
        resp = httpx.get(url, params=params, timeout=8.0)
        data = resp.json()
        abstract = data.get("AbstractText", "")
        related = [r.get("Text", "") for r in data.get("RelatedTopics", [])[:3] if isinstance(r, dict)]
        result = abstract or " | ".join(filter(None, related))
        return result or "No relevant news found for this query."
    except Exception as exc:
        return f"News search unavailable: {exc}"


def _weather_agent(latitude: float, longitude: float) -> str:
    """Fetch current weather from Open-Meteo (free, no API key required)."""
    try:
        url = "https://api.open-meteo.com/v1/forecast"
        params = {
            "latitude": latitude,
            "longitude": longitude,
            "current": "precipitation,rain,weather_code,wind_speed_10m,relative_humidity_2m",
            "forecast_days": 1,
        }
        resp = httpx.get(url, params=params, timeout=8.0)
        data = resp.json()
        current = data.get("current", {})
        rain = current.get("rain", 0) or 0
        precip = current.get("precipitation", 0) or 0
        wind = current.get("wind_speed_10m", 0) or 0
        humidity = current.get("relative_humidity_2m", 0) or 0
        assessment = "Heavy rainfall conditions — flood risk is ELEVATED." if rain > 10 or precip > 15 else \
                     "Moderate rain detected — some flood risk." if rain > 2 or precip > 5 else \
                     "Light or no rain — flood risk from weather alone is LOW."
        return (
            f"Weather at ({latitude:.3f}, {longitude:.3f}): "
            f"rain={rain}mm, precipitation={precip}mm, wind={wind}km/h, humidity={humidity}%. "
            f"{assessment}"
        )
    except Exception as exc:
        return f"Weather data unavailable: {exc}"


def _gov_alert_agent(latitude: float, longitude: float) -> str:
    """Check MetMalaysia flood events stored in Supabase DB."""
    try:
        from app.db.supabase_client import get_client
        sb = get_client()
        res = (
            sb.table("flood_events")
            .select("area, severity, river_name, created_at, active")
            .eq("active", True)
            .limit(5)
            .execute()
        )
        events = res.data or []
        if not events:
            return "No active MetMalaysia flood events in the database currently."
        summary = "; ".join(
            f"{e.get('area', '?')} (severity: {e.get('severity', '?')}, river: {e.get('river_name', 'N/A')})"
            for e in events
        )
        return f"Active government flood alerts ({len(events)} events): {summary}"
    except Exception as exc:
        return f"Government alert data unavailable: {exc}"


# ── Claude tool definitions ────────────────────────────────────────────────────

_TOOLS = [
    {
        "name": "search_news",
        "description": (
            "Search for recent news about a flood or disaster at the given location. "
            "Use to verify if media reports confirm the incident."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "Search query, e.g. 'flood Kuala Lumpur March 2025' or 'banjir Kuantan'",
                }
            },
            "required": ["query"],
        },
    },
    {
        "name": "check_weather",
        "description": (
            "Get current weather conditions at the exact report location. "
            "Use to assess whether current weather supports a flood being plausible."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "latitude":  {"type": "number", "description": "Latitude of the report location"},
                "longitude": {"type": "number", "description": "Longitude of the report location"},
            },
            "required": ["latitude", "longitude"],
        },
    },
    {
        "name": "check_gov_alerts",
        "description": (
            "Check official MetMalaysia government flood alerts in the database. "
            "Use to see if authorities have already issued warnings for this area."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "latitude":  {"type": "number"},
                "longitude": {"type": "number"},
            },
            "required": ["latitude", "longitude"],
        },
    },
]

_SYSTEM = (
    "You are a disaster intelligence analyst for the LANDA Disaster Resilience Platform in Malaysia. "
    "You analyze community-submitted disaster reports to determine their legitimacy.\n\n"
    "Your job:\n"
    "1. Use ALL three provided tools to gather evidence: search_news, check_weather, check_gov_alerts\n"
    "2. Synthesize the evidence into a legitimacy assessment\n"
    "3. Return ONLY a JSON object (no markdown, no extra text) with these exact keys:\n"
    '   {"score": <int 0-100>, "reasoning": "<2-3 sentences>", "recommendation": "<approve|monitor|reject>"}\n\n'
    "Scoring guide: 80-100=very likely real, 60-79=probably real, 40-59=uncertain, "
    "20-39=probably false, 0-19=very likely false.\n"
    "recommendation: 'approve' if score>=70, 'monitor' if 40-69, 'reject' if <40."
)


# ── Orchestrator ───────────────────────────────────────────────────────────────

def analyze_report(report: dict) -> dict:
    """
    Run Claude-powered multi-agent analysis on a community report.

    Returns: {"score": int, "reasoning": str, "recommendation": str, "sources": list[str]}
    """
    if not ANTHROPIC_API_KEY:
        return {
            "score": 0,
            "reasoning": "ANTHROPIC_API_KEY not configured in backend .env",
            "recommendation": "monitor",
            "sources": [],
        }

    try:
        import anthropic
    except ImportError:
        return {
            "score": 0,
            "reasoning": "anthropic package not installed. Run: pip install anthropic",
            "recommendation": "monitor",
            "sources": [],
        }

    client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)

    user_message = (
        f"Analyze this community disaster report and determine if it is legitimate:\n\n"
        f"Type: {report.get('report_type', 'unknown')}\n"
        f"Location: {report.get('location_name', 'unknown')} "
        f"(lat={report.get('latitude', 0)}, lon={report.get('longitude', 0)})\n"
        f"Description: {report.get('description', '(no description)')}\n"
        f"Community vouches: {report.get('vouch_count', 0)}\n"
        f"Vulnerable person involved: {report.get('vulnerable_person', False)}\n\n"
        f"Use all three tools (search_news, check_weather, check_gov_alerts), then return your JSON assessment."
    )

    messages: list[dict] = [{"role": "user", "content": user_message}]
    sources_used: list[str] = []
    final_response = None

    for _iteration in range(6):  # max 6 iterations for the agentic loop
        response = client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=1024,
            system=_SYSTEM,
            tools=_TOOLS,
            messages=messages,
        )

        # Append assistant's response turn
        messages.append({"role": "assistant", "content": response.content})

        if response.stop_reason == "end_turn":
            final_response = response
            break

        if response.stop_reason == "tool_use":
            tool_results = []
            for block in response.content:
                if block.type != "tool_use":
                    continue
                sources_used.append(block.name)
                inp = block.input

                if block.name == "search_news":
                    result = _news_agent(inp.get("query", ""))
                elif block.name == "check_weather":
                    result = _weather_agent(float(inp.get("latitude", 0)), float(inp.get("longitude", 0)))
                elif block.name == "check_gov_alerts":
                    result = _gov_alert_agent(float(inp.get("latitude", 0)), float(inp.get("longitude", 0)))
                else:
                    result = "Unknown tool called."

                logger.debug("Tool %s result: %s", block.name, result[:100])
                tool_results.append({
                    "type": "tool_result",
                    "tool_use_id": block.id,
                    "content": result,
                })

            messages.append({"role": "user", "content": tool_results})
        else:
            # Unexpected stop reason — exit loop
            final_response = response
            break

    # Extract final text from the response
    final_text = ""
    if final_response:
        for block in final_response.content:
            if hasattr(block, "text") and block.text:
                final_text = block.text
                break

    # Parse JSON from the response
    match = re.search(r'\{[^{}]*"score"[^{}]*\}', final_text, re.DOTALL)
    if match:
        try:
            parsed = json.loads(match.group())
            score = max(0, min(100, int(parsed.get("score", 50))))
            reasoning = str(parsed.get("reasoning", "")).strip()[:500]
            recommendation = str(parsed.get("recommendation", "monitor")).lower()
            if recommendation not in ("approve", "monitor", "reject"):
                recommendation = "approve" if score >= 70 else "monitor" if score >= 40 else "reject"
            return {
                "score": score,
                "reasoning": reasoning,
                "recommendation": recommendation,
                "sources": list(dict.fromkeys(sources_used)),  # deduplicated, ordered
            }
        except (json.JSONDecodeError, ValueError) as exc:
            logger.warning("Failed to parse AI JSON response: %s — raw: %s", exc, final_text[:200])

    # Fallback if JSON parse fails
    return {
        "score": 50,
        "reasoning": final_text[:400] if final_text else "AI analysis completed but returned no structured result.",
        "recommendation": "monitor",
        "sources": list(dict.fromkeys(sources_used)),
    }
