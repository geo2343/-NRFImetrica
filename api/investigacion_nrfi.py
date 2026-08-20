from __future__ import annotations

import os
from datetime import date
from typing import Any
from uuid import uuid4

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from kernel.investigacion_nrfi import (
    AGENT_ID,
    AGENT_VERSION,
    KERNEL_VERSION,
    MOTHER_DOCUMENT_SHA256,
    PHASE_ORDER,
    PROTOCOL_ID,
    REAL_MONEY_AUTHORITY,
    REPORT_CONTRACT_VERSION,
    SOVEREIGN_PATCH,
    InvestigacionNRFIProtocolViolation,
    capacity_state,
    forbid_decision_keys,
    is_terminal_nonplayed_status,
    now_iso,
    stable_hash,
    validate_phase_order,
    validate_receipt,
    validate_report_contract,
    validate_temporal_evidence,
)
from providers.mlb import fetch_schedule

SUPABASE_URL = os.getenv("SUPABASE_URL", "").rstrip("/")
SUPABASE_SECRET_KEY = os.getenv("SUPABASE_SECRET_KEY", "") or os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")

app = FastAPI(title="@investigacionNRFI Connected Kernel", version="0.3")


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
    async with httpx.AsyncClient(timeout=25.0) as client:
        response = await client.request(
            method,
            f"{SUPABASE_URL}/rest/v1/{table}",
            headers=_headers(prefer),
            params=params,
            json=payload,
        )
    if response.status_code >= 300:
        raise HTTPException(status_code=502, detail=f"SUPABASE_{table}_{response.status_code}:{response.text[:700]}")
    return response.json() if response.content else None


async def rpc(name: str, payload: dict[str, Any]) -> Any:
    async with httpx.AsyncClient(timeout=25.0) as client:
        response = await client.post(
            f"{SUPABASE_URL}/rest/v1/rpc/{name}",
            headers=_headers(),
            json=payload,
        )
    if response.status_code >= 300:
        raise HTTPException(status_code=502, detail=f"SUPABASE_RPC_{name}_{response.status_code}:{response.text[:700]}")
    return response.json() if response.content else None


async def trace(daily_run_id: str, event_type: str, *, phase_id: str | None = None, input_payload: Any = None, output_payload: Any = None, details: dict[str, Any] | None = None) -> None:
    await sb(
        "POST",
        "investigacion_nrfi_trace",
        payload={
            "event_id": f"INVNRFI-TRACE-{uuid4().hex}",
            "daily_run_id": daily_run_id,
            "phase_id": phase_id,
            "event_type": event_type,
            "occurred_at": now_iso(),
            "input_hash": stable_hash(input_payload) if input_payload is not None else None,
            "output_hash": stable_hash(output_payload) if output_payload is not None else None,
            "details": details or {},
        },
        prefer="return=minimal",
    )


def _status_text(game: dict[str, Any]) -> str:
    return str(game.get("detailed_state") or game.get("abstract_game_state") or "UNKNOWN").strip()


def _is_final(game: dict[str, Any]) -> bool:
    abstract = str(game.get("abstract_game_state") or "").strip().lower()
    detailed = str(game.get("detailed_state") or "").strip().lower()
    return abstract == "final" or any(x in detailed for x in ("final", "game over", "completed"))


def _slate_row(daily_run_id: str, game: dict[str, Any]) -> dict[str, Any]:
    final = _is_final(game)
    status_text = _status_text(game)
    terminal_nonplayed = (not final) and is_terminal_nonplayed_status(status_text)
    if final:
        research_status = "PENDING"
        exclusion_reason = None
        disposition = "FINAL_PROCESS_REQUIRED"
    elif terminal_nonplayed:
        research_status = "EXCLUDED"
        exclusion_reason = f"OFFICIAL_SLATE_TERMINAL_NONPLAYED:{status_text}"
        disposition = "TERMINAL_NONPLAYED_EXCLUDED"
    else:
        research_status = "PENDING"
        exclusion_reason = None
        disposition = "WAITING_FOR_FINAL"
    return {
        "daily_run_id": daily_run_id,
        "game_pk": str(game.get("game_id")),
        "away_team": game.get("away_team"),
        "home_team": game.get("home_team"),
        "first_pitch_at": game.get("scheduled_start"),
        "scheduled_start_at": game.get("scheduled_start"),
        "final_status_text": status_text or "UNKNOWN",
        "finalized_verified": final,
        "research_status": research_status,
        "exclusion_reason": exclusion_reason,
        "identity_payload": game,
        "official_slate_member": True,
        "slate_disposition": disposition,
    }


class DailyRunStart(BaseModel):
    run_date: str
    run_type: str = "ORIGINAL"
    parent_run_id: str | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)


class GameStatusUpdate(BaseModel):
    research_status: str
    exclusion_reason: str | None = None


class ToolEventCreate(BaseModel):
    daily_run_id: str
    game_pk: str | None = None
    tool_name: str
    source_ref: str | None = None
    input_payload: Any = None
    output_payload: Any = None
    metadata: dict[str, Any] = Field(default_factory=dict)


class EvidenceCreate(BaseModel):
    daily_run_id: str
    evidence_id: str | None = None
    game_pk: str | None = None
    phase_id: str | None = None
    tool_event_id: str
    source_family_id: str | None = None
    canonical_origin: str
    publisher: str | None = None
    source_url: str | None = None
    temporal_lane: str
    epistemic_lane: str
    retrieved_at: str
    available_at: str | None = None
    first_pitch_at: str | None = None
    event_time: str | None = None
    data_coverage_state: str = "AVAILABLE"
    object_payload: dict[str, Any] = Field(default_factory=dict)


class PhaseSubmit(BaseModel):
    daily_run_id: str
    phase_id: str
    status: str = "COMPLETE"
    started_at: str
    ended_at: str | None = None
    payload: dict[str, Any] = Field(default_factory=dict)
    receipt: dict[str, Any] = Field(default_factory=dict)
    auditor_result: str | None = None


class DriveAppendCreate(BaseModel):
    daily_run_id: str
    volume_id: str
    drive_document_id: str
    block_marker: str
    pre_append_hash: str | None = None
    post_append_hash: str
    readback_hash: str
    readback_tool_event_id: str
    character_count_before: int | None = None
    character_count_after: int
    slate_row_count: int
    excluded_game_summary_count: int = 0
    game_block_count: int
    phase_section_count: int
    daily_block_character_count: int
    required_section_markers: dict[str, bool]
    report_contract_verified: bool = True
    delivery_contract_version: str = REPORT_CONTRACT_VERSION


@app.get("/")
async def root():
    return {
        "agent_id": AGENT_ID,
        "agent_version": AGENT_VERSION,
        "kernel_version": KERNEL_VERSION,
        "protocol_id": PROTOCOL_ID,
        "mother_document_sha256": MOTHER_DOCUMENT_SHA256,
        "sovereign_patch": SOVEREIGN_PATCH,
        "report_contract_version": REPORT_CONTRACT_VERSION,
        "real_money_authority": REAL_MONEY_AUTHORITY,
        "workflow": list(PHASE_ORDER),
        "activation_scope": "ONE_DATE_EQUALS_FULL_OFFICIAL_MLB_SLATE",
        "kernel_role": "PROCESS_TEMPORAL_CUSTODY_FULL_SLATE_AND_SEMANTIC_COMPLETENESS_NOT_SPORTS_VOTER",
    }


@app.get("/health")
async def health():
    agents = await sb("GET", "agent_registry", params={"select": "agent_id,agent_version,status,protocol_id,kernel_version,metadata", "agent_id": f"eq.{AGENT_ID}", "limit": "1"}) or []
    authority = await sb("GET", "protocol_authority", params={"select": "protocol_id,document_sha256,active", "protocol_id": f"eq.{PROTOCOL_ID}", "limit": "1"}) or []
    volumes = await sb("GET", "investigacion_nrfi_volumes", params={"select": "volume_id,status,drive_document_id,capacity_state,rollover_authorized", "status": "eq.OPEN", "limit": "2"}) or []
    ok = bool(agents and agents[0].get("status") == "ACTIVE" and authority and authority[0].get("active") and len(volumes) == 1)
    return {"ok": ok, "agent": agents[0] if agents else None, "authority": authority[0] if authority else None, "active_volume": volumes[0] if len(volumes) == 1 else None, "open_volume_count": len(volumes)}


@app.post("/daily-runs/start")
async def start_daily_run(req: DailyRunStart):
    try:
        date.fromisoformat(req.run_date)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail="RUN_DATE_MUST_BE_YYYY_MM_DD") from exc
    if req.run_type not in {"ORIGINAL", "AMENDMENT", "REVALIDATION"}:
        raise HTTPException(status_code=422, detail="INVALID_RUN_TYPE")
    if req.run_type != "ORIGINAL" and not req.parent_run_id:
        raise HTTPException(status_code=422, detail="PARENT_RUN_REQUIRED_FOR_NON_ORIGINAL")

    volumes = await sb("GET", "investigacion_nrfi_volumes", params={"select": "*", "status": "eq.OPEN", "limit": "2"}) or []
    if len(volumes) != 1:
        raise HTTPException(status_code=409, detail="ACTIVE_VOLUME_NOT_UNIQUE")
    volume = volumes[0]
    if volume.get("capacity_state") == "ROLLOVER_REQUIRED":
        raise HTTPException(status_code=409, detail="ACTIVE_VOLUME_ROLLOVER_REQUIRED_USER_AUTHORIZATION_NEEDED")

    provider = await fetch_schedule(req.run_date)
    official_games = list(provider.get("games", []))
    if not official_games:
        raise HTTPException(status_code=409, detail="OFFICIAL_MLB_SLATE_EMPTY_OR_UNRESOLVED")

    run_id = f"INVNRFI-{req.run_date.replace('-', '')}-{uuid4().hex[:8]}"
    schedule_hash = provider.get("raw_payload_hash") or stable_hash(provider)
    slate_rows = [_slate_row(run_id, g) for g in official_games]
    finalized_count = sum(1 for g in slate_rows if g["finalized_verified"])
    excluded_count = sum(1 for g in slate_rows if g["research_status"] == "EXCLUDED")
    waiting_count = sum(1 for g in slate_rows if g["slate_disposition"] == "WAITING_FOR_FINAL")

    row = {
        "daily_run_id": run_id,
        "agent_id": AGENT_ID,
        "protocol_id": PROTOCOL_ID,
        "system_version": "INVESTIGACION-NRFI-HISTORICAL-V1.0",
        "kernel_version": KERNEL_VERSION,
        "run_date": req.run_date,
        "run_type": req.run_type,
        "parent_run_id": req.parent_run_id,
        "volume_id": volume["volume_id"],
        "status": "OPEN",
        "expected_finalized_count": len(slate_rows),
        "official_slate_count": len(slate_rows),
        "finalized_game_count": finalized_count,
        "nonfinal_game_count": len(slate_rows) - finalized_count,
        "slate_universe_hash": stable_hash([g["game_pk"] for g in slate_rows]),
        "slate_complete": False,
        "delivery_contract_version": REPORT_CONTRACT_VERSION,
        "metadata": {
            **req.metadata,
            "provider": provider.get("provider"),
            "schedule_payload_hash": schedule_hash,
            "mother_document_sha256": MOTHER_DOCUMENT_SHA256,
            "sovereign_patch": SOVEREIGN_PATCH,
            "activation_scope": "FULL_OFFICIAL_SLATE",
            "official_slate_count": len(slate_rows),
            "finalized_at_freeze": finalized_count,
            "terminal_nonplayed_excluded_at_freeze": excluded_count,
            "waiting_for_final_at_freeze": waiting_count,
            "delivery_contract_version": REPORT_CONTRACT_VERSION,
        },
    }
    saved = await sb("POST", "investigacion_nrfi_runs", payload=row, prefer="return=representation")

    schedule_event_id = f"INVNRFI-TOOL-{uuid4().hex}"
    schedule_event = {
        "event_id": schedule_event_id,
        "daily_run_id": run_id,
        "tool_name": "providers.mlb.fetch_schedule",
        "source_ref": provider.get("source_ref") or provider.get("provider"),
        "invoked_at": provider.get("retrieved_at") or now_iso(),
        "completed_at": provider.get("retrieved_at") or now_iso(),
        "input_hash": stable_hash({"run_date": req.run_date}),
        "output_hash": schedule_hash,
        "metadata": {
            "run_date": req.run_date,
            "official_slate_count": len(slate_rows),
            "finalized_at_freeze": finalized_count,
            "waiting_for_final": waiting_count,
            "terminal_nonplayed_excluded": excluded_count,
        },
    }
    await sb("POST", "investigacion_nrfi_tool_events", payload=schedule_event, prefer="return=minimal")
    await sb("POST", "investigacion_nrfi_games", payload=slate_rows, prefer="return=minimal")
    accounting = await rpc("investigacion_nrfi_sync_run_accounting", {"p_daily_run_id": run_id})
    await trace(
        run_id,
        "DAILY_RUN_STARTED_AND_OFFICIAL_SLATE_LEDGER_FROZEN",
        input_payload=req.model_dump(),
        output_payload={"official_game_pks": [g["game_pk"] for g in slate_rows]},
        details={
            "official_slate_count": len(slate_rows),
            "finalized_at_freeze": finalized_count,
            "waiting_for_final": waiting_count,
            "terminal_nonplayed_excluded": excluded_count,
            "schedule_tool_event_id": schedule_event_id,
        },
    )
    return {
        "run": (saved or [row])[0],
        "official_slate_games": slate_rows,
        "slate_summary": {
            "official_slate_count": len(slate_rows),
            "finalized_at_freeze": finalized_count,
            "waiting_for_final": waiting_count,
            "terminal_nonplayed_excluded": excluded_count,
        },
        "accounting": accounting,
        "active_volume": volume,
        "schedule_tool_event_id": schedule_event_id,
    }


@app.post("/daily-runs/{daily_run_id}/slate/refresh")
async def refresh_daily_slate(daily_run_id: str):
    runs = await sb("GET", "investigacion_nrfi_runs", params={"select": "daily_run_id,run_date", "daily_run_id": f"eq.{daily_run_id}", "limit": "1"}) or []
    if not runs:
        raise HTTPException(status_code=404, detail="DAILY_RUN_NOT_FOUND")
    run_date = str(runs[0]["run_date"])
    provider = await fetch_schedule(run_date)
    official_games = list(provider.get("games", []))
    if not official_games:
        raise HTTPException(status_code=409, detail="OFFICIAL_MLB_SLATE_EMPTY_OR_UNRESOLVED")

    existing = await sb("GET", "investigacion_nrfi_games", params={"select": "game_pk,research_status", "daily_run_id": f"eq.{daily_run_id}"}) or []
    existing_status = {str(r["game_pk"]): r["research_status"] for r in existing}
    rows = [_slate_row(daily_run_id, g) for g in official_games]
    for row in rows:
        prior = existing_status.get(row["game_pk"])
        if prior == "PROCESSED" and row["finalized_verified"]:
            row["research_status"] = "PROCESSED"
            row["slate_disposition"] = "PROCESSED_FINAL"
        elif prior == "EXCLUDED" and row["finalized_verified"]:
            row["research_status"] = "PENDING"
            row["exclusion_reason"] = None
            row["slate_disposition"] = "FINAL_PROCESS_REQUIRED"
    await sb(
        "POST",
        "investigacion_nrfi_games",
        params={"on_conflict": "daily_run_id,game_pk"},
        payload=rows,
        prefer="resolution=merge-duplicates,return=minimal",
    )
    await sb(
        "PATCH",
        "investigacion_nrfi_runs",
        params={"daily_run_id": f"eq.{daily_run_id}"},
        payload={
            "official_slate_count": len(rows),
            "expected_finalized_count": len(rows),
            "slate_universe_hash": stable_hash([r["game_pk"] for r in rows]),
            "delivery_contract_version": REPORT_CONTRACT_VERSION,
        },
        prefer="return=minimal",
    )
    accounting = await rpc("investigacion_nrfi_sync_run_accounting", {"p_daily_run_id": daily_run_id})
    await trace(daily_run_id, "OFFICIAL_SLATE_REFRESHED", output_payload=accounting, details={"official_slate_count": len(rows)})
    return {"official_slate_games": rows, "accounting": accounting}


@app.patch("/daily-runs/{daily_run_id}/games/{game_pk}")
async def update_game_status(daily_run_id: str, game_pk: str, req: GameStatusUpdate):
    if req.research_status not in {"PROCESSED", "EXCLUDED"}:
        raise HTTPException(status_code=422, detail="GAME_STATUS_MUST_BE_PROCESSED_OR_EXCLUDED")
    if req.research_status == "EXCLUDED" and not (req.exclusion_reason or "").strip():
        raise HTTPException(status_code=422, detail="EXCLUSION_REASON_REQUIRED")
    current = await sb("GET", "investigacion_nrfi_games", params={"select": "game_pk,finalized_verified", "daily_run_id": f"eq.{daily_run_id}", "game_pk": f"eq.{game_pk}", "limit": "1"}) or []
    if not current:
        raise HTTPException(status_code=404, detail="GAME_NOT_FOUND_IN_OFFICIAL_SLATE_LEDGER")
    if req.research_status == "PROCESSED" and not current[0].get("finalized_verified"):
        raise HTTPException(status_code=409, detail="NONFINAL_GAME_CANNOT_BE_PROCESSED")
    payload = {
        "research_status": req.research_status,
        "exclusion_reason": req.exclusion_reason,
        "slate_disposition": "PROCESSED_FINAL" if req.research_status == "PROCESSED" else "EXCLUDED_WITH_REASON",
        "updated_at": now_iso(),
    }
    saved = await sb("PATCH", "investigacion_nrfi_games", params={"daily_run_id": f"eq.{daily_run_id}", "game_pk": f"eq.{game_pk}"}, payload=payload, prefer="return=representation")
    await rpc("investigacion_nrfi_sync_run_accounting", {"p_daily_run_id": daily_run_id})
    await trace(daily_run_id, "GAME_RESEARCH_STATUS_UPDATED", input_payload=req.model_dump(), output_payload=saved[0], details={"game_pk": game_pk})
    return saved[0]


@app.post("/daily-runs/{daily_run_id}/accounting/sync")
async def sync_accounting(daily_run_id: str):
    return await rpc("investigacion_nrfi_sync_run_accounting", {"p_daily_run_id": daily_run_id})


@app.post("/tool-events")
async def create_tool_event(req: ToolEventCreate):
    event_id = f"INVNRFI-TOOL-{uuid4().hex}"
    row = {
        "event_id": event_id,
        "daily_run_id": req.daily_run_id,
        "game_pk": req.game_pk,
        "tool_name": req.tool_name,
        "source_ref": req.source_ref,
        "invoked_at": now_iso(),
        "completed_at": now_iso(),
        "input_hash": stable_hash(req.input_payload) if req.input_payload is not None else None,
        "output_hash": stable_hash(req.output_payload) if req.output_payload is not None else None,
        "metadata": req.metadata,
    }
    await sb("POST", "investigacion_nrfi_tool_events", payload=row, prefer="return=minimal")
    await trace(req.daily_run_id, "TOOL_EVENT_RECORDED", input_payload=req.model_dump(), output_payload=row, details={"tool_event_id": event_id})
    return row


@app.post("/evidence")
async def create_evidence(req: EvidenceCreate):
    try:
        forbid_decision_keys(req.object_payload)
        validate_temporal_evidence(temporal_lane=req.temporal_lane, epistemic_lane=req.epistemic_lane, available_at=req.available_at, first_pitch_at=req.first_pitch_at)
    except InvestigacionNRFIProtocolViolation as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    tools = await sb("GET", "investigacion_nrfi_tool_events", params={"select": "event_id,daily_run_id", "event_id": f"eq.{req.tool_event_id}", "limit": "1"}) or []
    if not tools or tools[0]["daily_run_id"] != req.daily_run_id:
        raise HTTPException(status_code=422, detail="TOOL_EVENT_NOT_FOUND_IN_DAILY_RUN")

    family_hash = stable_hash({"canonical_origin": req.canonical_origin.lower().strip(), "publisher": (req.publisher or "").lower().strip()})
    family_id = req.source_family_id or f"INVNRFI-SRCF-{family_hash[:20]}"
    existing = await sb("GET", "investigacion_nrfi_source_families", params={"select": "source_family_id", "family_hash": f"eq.{family_hash}", "limit": "1"}) or []
    if existing:
        family_id = existing[0]["source_family_id"]
    else:
        await sb("POST", "investigacion_nrfi_source_families", payload={"source_family_id": family_id, "canonical_origin": req.canonical_origin, "publisher": req.publisher, "family_hash": family_hash}, prefer="return=minimal")

    evidence_id = req.evidence_id or f"INVNRFI-EVID-{uuid4().hex}"
    row = {
        "evidence_id": evidence_id,
        "daily_run_id": req.daily_run_id,
        "game_pk": req.game_pk,
        "phase_id": req.phase_id,
        "tool_event_id": req.tool_event_id,
        "source_family_id": family_id,
        "source_url": req.source_url,
        "temporal_lane": req.temporal_lane,
        "epistemic_lane": req.epistemic_lane,
        "retrieved_at": req.retrieved_at,
        "available_at": req.available_at,
        "first_pitch_at": req.first_pitch_at,
        "event_time": req.event_time,
        "payload_hash": stable_hash(req.object_payload),
        "snapshot_hash": stable_hash({"source_url": req.source_url, "payload": req.object_payload, "retrieved_at": req.retrieved_at}),
        "data_coverage_state": req.data_coverage_state,
        "object_payload": req.object_payload,
    }
    await sb("POST", "investigacion_nrfi_evidence", payload=row, prefer="return=minimal")
    await trace(req.daily_run_id, "EVIDENCE_RECORDED", phase_id=req.phase_id, input_payload=req.model_dump(), output_payload=row, details={"evidence_id": evidence_id, "source_family_id": family_id})
    return row


@app.post("/phases")
async def submit_phase(req: PhaseSubmit):
    rows = await sb("GET", "investigacion_nrfi_phase_state", params={"select": "phase_id,status", "daily_run_id": f"eq.{req.daily_run_id}"}) or []
    completed = {r["phase_id"] for r in rows if r.get("status") == "COMPLETE"}
    try:
        validate_phase_order(completed, req.phase_id)
        forbid_decision_keys(req.payload)
        if req.status == "COMPLETE":
            validate_receipt(req.phase_id, req.receipt)
    except InvestigacionNRFIProtocolViolation as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    row = {
        "daily_run_id": req.daily_run_id,
        "phase_id": req.phase_id,
        "status": req.status,
        "started_at": req.started_at,
        "ended_at": req.ended_at or now_iso(),
        "payload": req.payload,
        "receipt": req.receipt,
        "auditor_result": req.auditor_result or req.receipt.get("AUDITOR_RESULT"),
    }
    saved = await sb("POST", "investigacion_nrfi_phase_state", params={"on_conflict": "daily_run_id,phase_id"}, payload=row, prefer="resolution=merge-duplicates,return=representation")
    await trace(req.daily_run_id, "PHASE_STATE_ACCEPTED", phase_id=req.phase_id, input_payload=req.model_dump(), output_payload=row)
    return (saved or [row])[0]


@app.post("/drive-appends")
async def record_drive_append(req: DriveAppendCreate):
    runs = await sb("GET", "investigacion_nrfi_runs", params={"select": "official_slate_count,processed_count,excluded_count", "daily_run_id": f"eq.{req.daily_run_id}", "limit": "1"}) or []
    if not runs:
        raise HTTPException(status_code=404, detail="DAILY_RUN_NOT_FOUND")
    run = runs[0]
    try:
        validate_report_contract(
            official_slate_count=int(run.get("official_slate_count") or 0),
            nonexcluded_games=int(run.get("processed_count") or 0),
            excluded_games=int(run.get("excluded_count") or 0),
            slate_row_count=req.slate_row_count,
            excluded_game_summary_count=req.excluded_game_summary_count,
            game_block_count=req.game_block_count,
            phase_section_count=req.phase_section_count,
            daily_block_character_count=req.daily_block_character_count,
            markers=req.required_section_markers,
            report_contract_verified=req.report_contract_verified,
            delivery_contract_version=req.delivery_contract_version,
        )
    except InvestigacionNRFIProtocolViolation as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    state = capacity_state(req.character_count_after)
    row = {
        "daily_run_id": req.daily_run_id,
        "volume_id": req.volume_id,
        "drive_document_id": req.drive_document_id,
        "block_marker": req.block_marker,
        "pre_append_hash": req.pre_append_hash,
        "post_append_hash": req.post_append_hash,
        "readback_hash": req.readback_hash,
        "readback_tool_event_id": req.readback_tool_event_id,
        "character_count_before": req.character_count_before,
        "character_count_after": req.character_count_after,
        "verified": True,
        "slate_row_count": req.slate_row_count,
        "excluded_game_summary_count": req.excluded_game_summary_count,
        "game_block_count": req.game_block_count,
        "phase_section_count": req.phase_section_count,
        "daily_block_character_count": req.daily_block_character_count,
        "required_section_markers": req.required_section_markers,
        "report_contract_verified": req.report_contract_verified,
        "delivery_contract_version": req.delivery_contract_version,
    }
    saved = await sb("POST", "investigacion_nrfi_drive_appends", params={"on_conflict": "daily_run_id"}, payload=row, prefer="resolution=merge-duplicates,return=representation")
    await sb("PATCH", "investigacion_nrfi_volumes", params={"volume_id": f"eq.{req.volume_id}"}, payload={"character_count": req.character_count_after, "capacity_state": state}, prefer="return=minimal")
    await sb("PATCH", "investigacion_nrfi_runs", params={"daily_run_id": f"eq.{req.daily_run_id}"}, payload={"drive_append_verified": True, "delivery_contract_version": REPORT_CONTRACT_VERSION}, prefer="return=minimal")
    await trace(req.daily_run_id, "DRIVE_APPEND_READBACK_VERIFIED_V2", input_payload=req.model_dump(), output_payload={"verified": True, "capacity_state": state})
    return {"append": (saved or [row])[0], "capacity_state": state}


@app.post("/daily-runs/{daily_run_id}/audit")
async def derive_audit(daily_run_id: str):
    result = await rpc("investigacion_nrfi_derive_audit", {"p_daily_run_id": daily_run_id})
    await trace(daily_run_id, "DAILY_AUDIT_DERIVED", output_payload=result)
    return result


@app.post("/daily-runs/{daily_run_id}/close")
async def close_daily_run(daily_run_id: str):
    result = await rpc("investigacion_nrfi_close_daily_run", {"p_daily_run_id": daily_run_id})
    await trace(daily_run_id, "DAILY_RUN_CLOSE_ATTEMPT", output_payload=result)
    return result


@app.post("/volumes/{volume_id}/authorize-rollover")
async def authorize_rollover(volume_id: str):
    result = await rpc("investigacion_nrfi_authorize_rollover", {"p_volume_id": volume_id})
    return {"authorized": True, "volume": result, "note": "Call only after explicit user authorization."}
