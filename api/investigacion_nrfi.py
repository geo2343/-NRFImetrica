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
    SYSTEM_VERSION,
    InvestigacionNRFIProtocolViolation,
    capacity_state,
    forbid_decision_keys,
    now_iso,
    stable_hash,
    validate_phase_order,
    validate_receipt,
    validate_temporal_evidence,
)
from providers.mlb import fetch_schedule

SUPABASE_URL = os.getenv("SUPABASE_URL", "").rstrip("/")
SUPABASE_SECRET_KEY = os.getenv("SUPABASE_SECRET_KEY", "") or os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")

app = FastAPI(title="@investigacionNRFI Connected Kernel", version="0.1")


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


def _is_final(game: dict[str, Any]) -> bool:
    abstract = str(game.get("abstract_game_state") or "").strip().lower()
    detailed = str(game.get("detailed_state") or "").strip().lower()
    return abstract == "final" or any(x in detailed for x in ("final", "game over", "completed"))


class DailyRunStart(BaseModel):
    run_date: str
    run_type: str = "ORIGINAL"
    parent_run_id: str | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)


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
    source_family_id: str
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


class RunAccountingUpdate(BaseModel):
    expected_finalized_count: int
    processed_count: int
    excluded_count: int
    metadata: dict[str, Any] = Field(default_factory=dict)


@app.get("/")
async def root():
    return {
        "agent_id": AGENT_ID,
        "agent_version": AGENT_VERSION,
        "system_version": SYSTEM_VERSION,
        "kernel_version": KERNEL_VERSION,
        "protocol_id": PROTOCOL_ID,
        "mother_document_sha256": MOTHER_DOCUMENT_SHA256,
        "real_money_authority": REAL_MONEY_AUTHORITY,
        "workflow": list(PHASE_ORDER),
        "kernel_role": "PROCESS_TEMPORAL_CUSTODY_AND_VOLUME_ENFORCEMENT_NOT_SPORTS_VOTER",
    }


@app.get("/health")
async def health():
    agents = await sb("GET", "agent_registry", params={"select": "agent_id,agent_version,status,protocol_id,kernel_version", "agent_id": f"eq.{AGENT_ID}", "limit": "1"}) or []
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
    finals = [g for g in provider.get("games", []) if _is_final(g)]
    run_id = f"INVNRFI-{req.run_date.replace('-', '')}-{uuid4().hex[:8]}"
    metadata = {
        **req.metadata,
        "provider": provider.get("provider"),
        "finalized_game_pks": [str(g.get("game_id")) for g in finals],
        "schedule_payload_hash": provider.get("raw_payload_hash") or stable_hash(provider),
        "mother_document_sha256": MOTHER_DOCUMENT_SHA256,
    }
    row = {
        "daily_run_id": run_id,
        "agent_id": AGENT_ID,
        "protocol_id": PROTOCOL_ID,
        "system_version": SYSTEM_VERSION,
        "kernel_version": KERNEL_VERSION,
        "run_date": req.run_date,
        "run_type": req.run_type,
        "parent_run_id": req.parent_run_id,
        "volume_id": volume["volume_id"],
        "status": "OPEN",
        "expected_finalized_count": len(finals),
        "metadata": metadata,
    }
    saved = await sb("POST", "investigacion_nrfi_runs", payload=row, prefer="return=representation")
    await trace(run_id, "DAILY_RUN_STARTED", input_payload=req.model_dump(), output_payload=row, details={"expected_finalized": len(finals)})
    return {"run": (saved or [row])[0], "finalized_games": finals, "active_volume": volume}


@app.patch("/daily-runs/{daily_run_id}/accounting")
async def update_accounting(daily_run_id: str, req: RunAccountingUpdate):
    if min(req.expected_finalized_count, req.processed_count, req.excluded_count) < 0:
        raise HTTPException(status_code=422, detail="NEGATIVE_COUNT_FORBIDDEN")
    payload = {
        "expected_finalized_count": req.expected_finalized_count,
        "processed_count": req.processed_count,
        "excluded_count": req.excluded_count,
        "status": "IN_PROGRESS",
        "metadata": req.metadata,
    }
    saved = await sb("PATCH", "investigacion_nrfi_runs", params={"daily_run_id": f"eq.{daily_run_id}"}, payload=payload, prefer="return=representation")
    if not saved:
        raise HTTPException(status_code=404, detail="DAILY_RUN_NOT_FOUND")
    await trace(daily_run_id, "DAILY_UNIVERSE_ACCOUNTING_UPDATED", input_payload=req.model_dump(), output_payload=saved[0])
    return saved[0]


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
    family = {
        "source_family_id": req.source_family_id,
        "canonical_origin": req.canonical_origin,
        "publisher": req.publisher,
        "family_hash": family_hash,
    }
    await sb("POST", "investigacion_nrfi_source_families", params={"on_conflict": "source_family_id"}, payload=family, prefer="resolution=merge-duplicates,return=minimal")

    evidence_id = req.evidence_id or f"INVNRFI-EVID-{uuid4().hex}"
    payload_hash = stable_hash(req.object_payload)
    row = {
        "evidence_id": evidence_id,
        "daily_run_id": req.daily_run_id,
        "game_pk": req.game_pk,
        "phase_id": req.phase_id,
        "tool_event_id": req.tool_event_id,
        "source_family_id": req.source_family_id,
        "source_url": req.source_url,
        "temporal_lane": req.temporal_lane,
        "epistemic_lane": req.epistemic_lane,
        "retrieved_at": req.retrieved_at,
        "available_at": req.available_at,
        "first_pitch_at": req.first_pitch_at,
        "event_time": req.event_time,
        "payload_hash": payload_hash,
        "snapshot_hash": stable_hash({"source_url": req.source_url, "payload": req.object_payload, "retrieved_at": req.retrieved_at}),
        "data_coverage_state": req.data_coverage_state,
        "object_payload": req.object_payload,
    }
    await sb("POST", "investigacion_nrfi_evidence", payload=row, prefer="return=minimal")
    await trace(req.daily_run_id, "EVIDENCE_RECORDED", phase_id=req.phase_id, input_payload=req.model_dump(), output_payload=row, details={"evidence_id": evidence_id, "source_family_id": req.source_family_id})
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
    }
    saved = await sb("POST", "investigacion_nrfi_drive_appends", params={"on_conflict": "daily_run_id"}, payload=row, prefer="resolution=merge-duplicates,return=representation")
    await sb("PATCH", "investigacion_nrfi_volumes", params={"volume_id": f"eq.{req.volume_id}"}, payload={"character_count": req.character_count_after, "capacity_state": state}, prefer="return=minimal")
    await sb("PATCH", "investigacion_nrfi_runs", params={"daily_run_id": f"eq.{req.daily_run_id}"}, payload={"drive_append_verified": True}, prefer="return=minimal")
    await trace(req.daily_run_id, "DRIVE_APPEND_READBACK_VERIFIED", input_payload=req.model_dump(), output_payload={"verified": True, "capacity_state": state})
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
    return {"authorized": True, "volume": result, "note": "This endpoint must only be called after explicit user authorization."}
