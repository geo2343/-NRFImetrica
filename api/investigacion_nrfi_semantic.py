from __future__ import annotations

import os
from typing import Any

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from kernel.investigacion_nrfi import (
    AGENT_ID,
    AGENT_VERSION,
    KERNEL_VERSION,
    PROTOCOL_ID,
    InvestigacionNRFIProtocolViolation,
    forbid_decision_keys,
    validate_report_contract,
)

SUPABASE_URL = os.getenv("SUPABASE_URL", "").rstrip("/")
SUPABASE_SECRET_KEY = os.getenv("SUPABASE_SECRET_KEY", "") or os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")

app = FastAPI(title="@investigacionNRFI Semantic Persistence", version="1.1")


def _headers(prefer: str | None = None) -> dict[str, str]:
    if not SUPABASE_URL or not SUPABASE_SECRET_KEY:
        raise HTTPException(status_code=503, detail="SUPABASE_RUNTIME_NOT_CONFIGURED")
    headers = {"apikey": SUPABASE_SECRET_KEY, "Content-Type": "application/json"}
    if SUPABASE_SECRET_KEY.count(".") == 2:
        headers["Authorization"] = f"Bearer {SUPABASE_SECRET_KEY}"
    if prefer:
        headers["Prefer"] = prefer
    return headers


async def sb(method: str, table: str, *, params: dict[str, str] | None = None, payload: Any = None, prefer: str | None = None) -> Any:
    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.request(
            method,
            f"{SUPABASE_URL}/rest/v1/{table}",
            headers=_headers(prefer),
            params=params,
            json=payload,
        )
    if response.status_code >= 300:
        raise HTTPException(status_code=502, detail=f"SUPABASE_{table}_{response.status_code}:{response.text[:900]}")
    return response.json() if response.content else None


async def rpc(name: str, payload: dict[str, Any]) -> Any:
    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            f"{SUPABASE_URL}/rest/v1/rpc/{name}",
            headers=_headers(),
            json=payload,
        )
    if response.status_code >= 300:
        raise HTTPException(status_code=502, detail=f"SUPABASE_RPC_{name}_{response.status_code}:{response.text[:900]}")
    return response.json() if response.content else None


STRUCTURED_OBJECT_TABLES = {
    "lineup_entry": "investigacion_nrfi_lineup_entries",
    "half_inning": "investigacion_nrfi_half_innings",
    "plate_appearance": "investigacion_nrfi_plate_appearances",
    "pitch_event": "investigacion_nrfi_pitch_events",
    "first_inning": "investigacion_nrfi_first_innings",
    "starter_context": "investigacion_nrfi_starter_contexts",
    "feature_value": "investigacion_nrfi_feature_values",
    "human_claim": "investigacion_nrfi_human_claims",
    "cohort": "investigacion_nrfi_cohorts",
    "component_coverage": "investigacion_nrfi_component_coverage",
    "evidence_packet": "investigacion_nrfi_evidence_packets",
}


class GameIdentityPatch(BaseModel):
    scheduled_start_at: str | None = None
    actual_first_pitch_at: str
    first_pitch_verified: bool = True
    venue_id: str | None = None
    venue_name: str
    away_starter_id: str
    away_starter_name: str | None = None
    home_starter_id: str
    home_starter_name: str | None = None
    away_catcher_id: str | None = None
    home_catcher_id: str | None = None
    final_score_away: int
    final_score_home: int
    day_night: str | None = None
    roof_state: str | None = None
    weather_state: dict[str, Any] = Field(default_factory=dict)
    data_era: str


class StructuredObjectCreate(BaseModel):
    object_type: str
    daily_run_id: str
    game_pk: str | None = None
    payload: dict[str, Any]


class ReportContractPatch(BaseModel):
    volume_id: str
    drive_document_id: str
    game_block_count: int
    phase_section_count: int
    daily_block_character_count: int
    required_section_markers: dict[str, bool]
    report_contract_verified: bool


@app.get("/")
async def root():
    return {
        "agent_id": AGENT_ID,
        "agent_version": AGENT_VERSION,
        "kernel_version": KERNEL_VERSION,
        "protocol_id": PROTOCOL_ID,
        "semantic_persistence": True,
        "structured_object_types": sorted(STRUCTURED_OBJECT_TABLES),
    }


@app.patch("/daily-runs/{daily_run_id}/games/{game_pk}/identity")
async def patch_game_identity(daily_run_id: str, game_pk: str, req: GameIdentityPatch):
    if not req.first_pitch_verified:
        raise HTTPException(status_code=422, detail="ACTUAL_FIRST_PITCH_MUST_BE_VERIFIED_FOR_F1_COMPLETION")
    payload = req.model_dump()
    saved = await sb(
        "PATCH",
        "investigacion_nrfi_games",
        params={"daily_run_id": f"eq.{daily_run_id}", "game_pk": f"eq.{game_pk}"},
        payload=payload,
        prefer="return=representation",
    )
    if not saved:
        raise HTTPException(status_code=404, detail="GAME_NOT_FOUND")
    return saved[0]


@app.post("/structured-objects")
async def create_structured_object(req: StructuredObjectCreate):
    table = STRUCTURED_OBJECT_TABLES.get(req.object_type)
    if not table:
        raise HTTPException(status_code=422, detail="UNSUPPORTED_STRUCTURED_OBJECT_TYPE")
    try:
        forbid_decision_keys(req.payload)
    except InvestigacionNRFIProtocolViolation as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    payload = dict(req.payload)
    payload["daily_run_id"] = req.daily_run_id
    if req.game_pk is not None:
        payload["game_pk"] = req.game_pk
    elif req.object_type not in {"feature_value", "human_claim", "cohort", "evidence_packet"}:
        raise HTTPException(status_code=422, detail="GAME_PK_REQUIRED_FOR_OBJECT_TYPE")

    saved = await sb("POST", table, payload=payload, prefer="return=representation")
    return {"object_type": req.object_type, "table": table, "saved": (saved or [payload])[0]}


@app.get("/daily-runs/{daily_run_id}/semantic")
async def semantic_snapshot(daily_run_id: str):
    return await rpc("investigacion_nrfi_semantic_completeness", {"p_daily_run_id": daily_run_id})


@app.get("/daily-runs/{daily_run_id}/games/{game_pk}/semantic")
async def game_semantic_snapshot(daily_run_id: str, game_pk: str):
    return await rpc("investigacion_nrfi_game_semantic_ready", {"p_daily_run_id": daily_run_id, "p_game_pk": game_pk})


@app.patch("/daily-runs/{daily_run_id}/report-contract")
async def patch_report_contract(daily_run_id: str, req: ReportContractPatch):
    games = await sb(
        "GET",
        "investigacion_nrfi_games",
        params={"select": "game_pk,research_status", "daily_run_id": f"eq.{daily_run_id}"},
    ) or []
    nonexcluded = sum(1 for row in games if row.get("research_status") != "EXCLUDED")
    try:
        validate_report_contract(
            nonexcluded_games=nonexcluded,
            game_block_count=req.game_block_count,
            phase_section_count=req.phase_section_count,
            daily_block_character_count=req.daily_block_character_count,
            markers=req.required_section_markers,
            report_contract_verified=req.report_contract_verified,
        )
    except InvestigacionNRFIProtocolViolation as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    saved = await sb(
        "PATCH",
        "investigacion_nrfi_drive_appends",
        params={"daily_run_id": f"eq.{daily_run_id}", "volume_id": f"eq.{req.volume_id}", "drive_document_id": f"eq.{req.drive_document_id}"},
        payload={
            "game_block_count": req.game_block_count,
            "phase_section_count": req.phase_section_count,
            "daily_block_character_count": req.daily_block_character_count,
            "required_section_markers": req.required_section_markers,
            "report_contract_verified": True,
        },
        prefer="return=representation",
    )
    if not saved:
        raise HTTPException(status_code=404, detail="DRIVE_APPEND_ROW_NOT_FOUND")
    return saved[0]
