from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

import httpx

from kernel.core import classify_game_status, stable_hash

MLB_STATS_API = "https://statsapi.mlb.com/api/v1"


def _iso_or_none(value: str | None) -> str | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(timezone.utc).isoformat()
    except ValueError:
        return value


def normalize_schedule(raw: dict[str, Any], cutoff_minutes_before: int = 0) -> list[dict[str, Any]]:
    games: list[dict[str, Any]] = []
    for date_block in raw.get("dates", []):
        for game in date_block.get("games", []):
            teams = game.get("teams", {})
            away = teams.get("away", {})
            home = teams.get("home", {})
            status = game.get("status", {})
            start_raw = game.get("gameDate")
            start_iso = _iso_or_none(start_raw)
            cutoff_iso = start_iso
            if start_iso and cutoff_minutes_before:
                dt = datetime.fromisoformat(start_iso)
                cutoff_iso = (dt - timedelta(minutes=cutoff_minutes_before)).isoformat()

            away_pp = away.get("probablePitcher") or {}
            home_pp = home.get("probablePitcher") or {}
            normalized = {
                "game_id": str(game.get("gamePk")),
                "away_team": (away.get("team") or {}).get("name"),
                "home_team": (home.get("team") or {}).get("name"),
                "scheduled_start": start_iso,
                "cutoff_at": cutoff_iso,
                "status": classify_game_status(status.get("abstractGameState"), status.get("detailedState")),
                "mlb_status": {
                    "abstract": status.get("abstractGameState"),
                    "detailed": status.get("detailedState"),
                    "coded": status.get("codedGameState"),
                },
                "probable_pitchers": {
                    "away": {"id": away_pp.get("id"), "name": away_pp.get("fullName")},
                    "home": {"id": home_pp.get("id"), "name": home_pp.get("fullName")},
                },
                "venue": (game.get("venue") or {}).get("name"),
            }
            games.append(normalized)
    return games


async def fetch_schedule(run_date: str, cutoff_minutes_before: int = 0) -> dict[str, Any]:
    params = {
        "sportId": 1,
        "date": run_date,
        "hydrate": "probablePitcher,team,venue",
    }
    async with httpx.AsyncClient(timeout=20.0, follow_redirects=True) as client:
        response = await client.get(f"{MLB_STATS_API}/schedule", params=params)
    response.raise_for_status()
    raw = response.json()
    games = normalize_schedule(raw, cutoff_minutes_before=cutoff_minutes_before)
    return {
        "provider": "MLB_STATS_API",
        "source_url": str(response.url),
        "retrieved_at": datetime.now(timezone.utc).isoformat(),
        "raw_payload_hash": stable_hash(raw),
        "raw": raw,
        "games": games,
        "universe_hash": stable_hash(games),
    }
