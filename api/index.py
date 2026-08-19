from __future__ import annotations

import os
from datetime import date
from typing import Any
from uuid import uuid4

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from kernel.core import (
    AI_ANALYST_STATUS,
    CALIBRATION_STATUS,
    INDEPENDENT_AUDITOR_STATUS,
    KERNEL_VERSION,
    MODEL_STATUS,
    MOTHER_DOCUMENT_SHA256,
    MOTHER_PROTOCOL_ID,
    NRFI_PRENSA_BRIDGE_STATUS,
    NUMERIC_ENGINE_STATUS,
    REAL_MONEY_AUTHORITY,
    SYSTEM_SCOPE,
    SYSTEM_STATE,
    SYSTEM_VERSION,
    classify_game_status,
    now_iso,
    stable_hash,
    validate_decision,
)
from providers.mlb import fetch_schedule

SUPABASE_URL = os.getenv("SUPABASE_URL", "").rstrip("/")
SUPABASE_SECRET_KEY = (
    os.getenv("SUPABASE_SECRET_KEY", "")
    or os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
)

app = FastAPI(title="@NRFImetrica Mother Kernel", version="0.5")


def _headers(prefer: str | None = None) -> dict[str, str]:
    if not SUPABASE_URL or not SUPABASE_SECRET_KEY:
        raise HTTPException(status_code=503, detail="SUPABASE_RUNTIME_NOT_CONFIGURED")
    headers = {"apikey": SUPABASE_SECRET_KEY, "Content-Type": "application/json"}
    if SUPABASE_SECRET_KEY.count(".") == 2:
        headers["Authorization"] = f"Bearer {SUPABASE_SECRET_KEY}"
    if prefer:
        headers["Prefer"] = prefer
    return headers


async def sb_request(
    method: str,
    table: str,
    *,
    params: dict[str, str] | None = None,
    payload: Any = None,
    prefer: str | None = None,
) -> Any:
    async with httpx.AsyncClient(timeout=25.0) as client:
        response = await client.request(
            method,
            f"{SUPABASE_URL}/rest/v1/{table}",
            headers=_headers(prefer),
            params=params,
            json=payload,
        )
    if response.status_code >= 300:
        raise HTTPException(
            status_code=502,
            detail={
                "code": f"SUPABASE_{table}_{response.status_code}",
                "body": response.text[:800],
            },
        )
    return response.json() if response.content else None


async def latest_trace_hash(run_id: str) -> str | None:
    rows = await sb_request(
        "GET",
        "trace_events",
        params={
            "select": "event_hash,occurred_at",
            "run_id": f"eq.{run_id}",
            "order": "occurred_at.desc",
            "limit": "1",
        },
    ) or []
    return rows[0]["event_hash"] if rows else None


async def persist_trace(
    *,
    run_id: str,
    game_id: str | None,
    task_id: str,
    event_type: str,
    status: str,
    input_payload: Any = None,
    output_payload: Any = None,
    tool_name: str | None = None,
    evidence_ids: list[str] | None = None,
    details: dict[str, Any] | None = None,
) -> dict[str, Any]:
    previous = await latest_trace_hash(run_id)
    base = {
        "event_id": f"EVT-{uuid4().hex}",
        "run_id": run_id,
        "game_id": game_id,
        "task_id": task_id,
        "event_type": event_type,
        "status": status,
        "occurred_at": now_iso(),
        "input_hash": stable_hash(input_payload) if input_payload is not None else None,
        "output_hash": stable_hash(output_payload) if output_payload is not None else None,
        "tool_name": tool_name,
        "evidence_ids": evidence_ids or [],
        "prev_event_hash": previous,
        "details": details or {},
    }
    base["event_hash"] = stable_hash(base)
    await sb_request("POST", "trace_events", payload=base, prefer="return=minimal")
    return base


async def ensure_mother_a0(run_id: str) -> dict[str, Any]:
    rows = await sb_request(
        "GET",
        "protocol_run_state",
        params={
            "select": "*",
            "run_id": f"eq.{run_id}",
            "protocol_id": f"eq.{MOTHER_PROTOCOL_ID}",
            "stage_id": "eq.A0_CONSTITUTION_SEALED",
            "limit": "1",
        },
    ) or []
    if rows:
        return rows[0]

    payload = {
        "mother_document_sha256": MOTHER_DOCUMENT_SHA256,
        "authority": "@NRFImetrica DOCUMENTO MADRE",
        "precedence": "LATEST_SOVEREIGN_PATCH_WINS",
        "latest_sovereign_patch": "A0-GOV.18 — REFORMA OPERATIVA SOBERANA V3",
        "manual_phase_authorization_required": False,
        "automatic_gate_advancement": True,
        "system_state": SYSTEM_STATE,
        "sealed_at": now_iso(),
    }
    row = {
        "run_id": run_id,
        "protocol_id": MOTHER_PROTOCOL_ID,
        "stage_id": "A0_CONSTITUTION_SEALED",
        "status": "COMPLETE",
        "payload": payload,
        "evidence_ids": [],
        "output_text": "A0 mother constitution sealed automatically by Kernel.",
        "submitted_at": now_iso(),
    }
    saved = await sb_request(
        "POST",
        "protocol_run_state",
        params={"on_conflict": "run_id,protocol_id,stage_id"},
        payload=row,
        prefer="resolution=merge-duplicates,return=representation",
    )
    await persist_trace(
        run_id=run_id,
        game_id=None,
        task_id="A0_CONSTITUTION_SEALED",
        event_type="MOTHER_CONSTITUTION_AUTO_SEALED",
        status="COMPLETE",
        input_payload={"run_id": run_id},
        output_payload=payload,
        tool_name="kernel.mother",
        details={"mother_document_sha256": MOTHER_DOCUMENT_SHA256},
    )
    return (saved or [row])[0]


async def create_run_row(
    *,
    run_date: str,
    run_id: str | None,
    timezone: str,
    mode: str,
    metadata: dict[str, Any] | None,
) -> dict[str, Any]:
    rid = run_id or f"NRFIM-MOTHER-{run_date.replace('-', '')}-{uuid4().hex[:8]}"
    row = {
        "run_id": rid,
        "system_version": SYSTEM_VERSION,
        "run_date": run_date,
        "timezone": timezone,
        "status": "OPEN",
        "mode": mode,
        "metadata": {
            **(metadata or {}),
            "kernel_version": KERNEL_VERSION,
            "protocol_id": MOTHER_PROTOCOL_ID,
            "mother_document_sha256": MOTHER_DOCUMENT_SHA256,
            "system_state": SYSTEM_STATE,
            "real_money_authority": REAL_MONEY_AUTHORITY,
            "numeric_engine_status": NUMERIC_ENGINE_STATUS,
            "independent_auditor_status": INDEPENDENT_AUDITOR_STATUS,
            "nrfiprensa_bridge_status": NRFI_PRENSA_BRIDGE_STATUS,
            "calibration_status": CALIBRATION_STATUS,
        },
    }
    saved = await sb_request("POST", "runs", payload=row, prefer="return=representation")
    await ensure_mother_a0(rid)
    return (saved or [row])[0]


class RunCreate(BaseModel):
    run_date: str
    run_id: str | None = None
    timezone: str = "America/Santo_Domingo"
    mode: str = "CONTROLLED_REAL"
    metadata: dict[str, Any] = Field(default_factory=dict)


class SyncMlbRequest(BaseModel):
    run_date: str
    run_id: str | None = None
    timezone: str = "America/Santo_Domingo"
    mode: str = "CONTROLLED_REAL"
    metadata: dict[str, Any] = Field(default_factory=dict)


class EvidenceCreate(BaseModel):
    run_id: str
    game_id: str | None = None
    evidence_id: str | None = None
    tool_name: str
    source_ref: str | None = None
    source_url: str | None = None
    retrieved_at: str | None = None
    data_available_at: str | None = None
    input_payload: Any = None
    payload: Any


class RecoveryCreate(BaseModel):
    run_id: str
    game_id: str | None = None
    issue_id: str
    task_id: str | None = None
    reason: str
    outcome: str | None = None


class TraceCreate(BaseModel):
    run_id: str
    game_id: str | None = None
    task_id: str
    event_type: str
    status: str
    input_payload: Any = None
    output_payload: Any = None
    tool_name: str | None = None
    evidence_ids: list[str] = Field(default_factory=list)
    details: dict[str, Any] = Field(default_factory=dict)


class DecisionCreate(BaseModel):
    run_id: str
    game_id: str
    decision: str
    central_nrfi_case: Any = Field(default_factory=dict)
    best_yrfi_rival: Any = Field(default_factory=dict)
    decisive_factor: str = ""
    materiality: str = ""
    what_would_change: str = ""
    numeric_status: str = "NOT_EXECUTED"
    raw_p_nrfi: float | None = None
    model_version: str | None = "NOT_INTEGRATED"
    calibration_status: str | None = "NOT_CERTIFIED"


@app.get("/")
async def root():
    return {
        "service": "@NRFImetrica Mother Kernel",
        "system_version": SYSTEM_VERSION,
        "kernel_version": KERNEL_VERSION,
        "system_scope": SYSTEM_SCOPE,
        "protocol_id": MOTHER_PROTOCOL_ID,
        "mother_document_sha256": MOTHER_DOCUMENT_SHA256,
        "system_state": SYSTEM_STATE,
        "ai_analyst_status": AI_ANALYST_STATUS,
        "numeric_engine_status": NUMERIC_ENGINE_STATUS,
        "independent_auditor_status": INDEPENDENT_AUDITOR_STATUS,
        "nrfiprensa_bridge_status": NRFI_PRENSA_BRIDGE_STATUS,
        "model_status": MODEL_STATUS,
        "calibration_status": CALIBRATION_STATUS,
        "real_money_authority": REAL_MONEY_AUTHORITY,
        "active_flow": "A0_AUTO -> A1 -> A2 -> A3 -> A4 -> A5 -> A6 -> A7 -> A8 -> PORTFOLIO -> FINAL_REPORT",
        "legacy_competitive_decision_endpoint": "SUPERSEDED",
    }


@app.get("/health")
async def health():
    versions = await sb_request(
        "GET",
        "system_versions",
        params={
            "select": "system_version,kernel_version,model_version,calibration_status",
            "system_version": f"eq.{SYSTEM_VERSION}",
            "limit": "1",
        },
    ) or []
    authority = await sb_request(
        "GET",
        "protocol_authority",
        params={
            "select": "protocol_id,document_sha256,document_lines,precedence_rule,latest_sovereign_patch,manual_phase_authorization_required,active",
            "protocol_id": f"eq.{MOTHER_PROTOCOL_ID}",
            "limit": "1",
        },
    ) or []
    engines = await sb_request(
        "GET",
        "numeric_engine_registry",
        params={"select": "engine_id", "status": "eq.ACTIVE_TRUSTED"},
    ) or []
    auditors = await sb_request(
        "GET",
        "independent_auditor_registry",
        params={"select": "auditor_id", "status": "eq.ACTIVE_TRUSTED"},
    ) or []
    healthy = bool(versions and authority)
    return {
        "ok": healthy,
        "system_version": SYSTEM_VERSION,
        "kernel_version": KERNEL_VERSION,
        "protocol_authority": authority[0] if authority else None,
        "active_trusted_numeric_engines": len(engines),
        "active_trusted_independent_auditors": len(auditors),
        "real_money_authority": REAL_MONEY_AUTHORITY,
        "system_state": SYSTEM_STATE,
    }


@app.get("/mlb/schedule/{run_date}")
async def mlb_schedule(run_date: str):
    try:
        return await fetch_schedule(run_date)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"MLB_PROVIDER_ERROR:{exc}") from exc


@app.post("/runs")
async def create_run(req: RunCreate):
    try:
        date.fromisoformat(req.run_date)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail="RUN_DATE_MUST_BE_YYYY_MM_DD") from exc
    return await create_run_row(
        run_date=req.run_date,
        run_id=req.run_id,
        timezone=req.timezone,
        mode=req.mode,
        metadata=req.metadata,
    )


@app.post("/runs/sync-mlb")
async def sync_mlb(req: SyncMlbRequest):
    try:
        date.fromisoformat(req.run_date)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail="RUN_DATE_MUST_BE_YYYY_MM_DD") from exc

    provider = await fetch_schedule(req.run_date)
    run = await create_run_row(
        run_date=req.run_date,
        run_id=req.run_id,
        timezone=req.timezone,
        mode=req.mode,
        metadata={**req.metadata, "provider": provider.get("provider")},
    )
    run_id = run["run_id"]

    games_payload: list[dict[str, Any]] = []
    for game in provider.get("games", []):
        runtime_status = game.get("runtime_status") or classify_game_status(
            game.get("abstract_game_state"), game.get("detailed_state")
        )
        games_payload.append(
            {
                "run_id": run_id,
                "game_id": str(game.get("game_id")),
                "away_team": game.get("away_team"),
                "home_team": game.get("home_team"),
                "scheduled_start": game.get("scheduled_start"),
                "cutoff_at": game.get("cutoff_at") or game.get("scheduled_start"),
                "status": runtime_status,
            }
        )
    if games_payload:
        await sb_request(
            "POST",
            "games",
            params={"on_conflict": "run_id,game_id"},
            payload=games_payload,
            prefer="resolution=merge-duplicates,return=minimal",
        )

    evidence_id = f"EVID-MLB-SLATE-{uuid4().hex}"
    evidence_row = {
        "evidence_id": evidence_id,
        "run_id": run_id,
        "game_id": None,
        "tool_name": "providers.mlb.fetch_schedule",
        "source_ref": provider.get("source_ref") or provider.get("provider"),
        "source_url": provider.get("source_url"),
        "retrieved_at": provider.get("retrieved_at") or now_iso(),
        "data_available_at": provider.get("retrieved_at") or now_iso(),
        "input_hash": stable_hash({"run_date": req.run_date}),
        "payload_hash": provider.get("raw_payload_hash") or stable_hash(provider),
        "payload": provider,
    }
    await sb_request("POST", "evidence", payload=evidence_row, prefer="return=minimal")

    universe_hash = provider.get("universe_hash") or stable_hash(games_payload)
    run_metadata = {
        **(run.get("metadata") or {}),
        "universe_hash": universe_hash,
        "game_count": len(games_payload),
        "slate_evidence_id": evidence_id,
    }
    await sb_request(
        "PATCH",
        "runs",
        params={"run_id": f"eq.{run_id}"},
        payload={"universe_hash": universe_hash, "metadata": run_metadata},
        prefer="return=minimal",
    )
    event = await persist_trace(
        run_id=run_id,
        game_id=None,
        task_id="A1_SLATE_DISCOVERY",
        event_type="MLB_REAL_UNIVERSE_SYNC",
        status="COMPLETE",
        input_payload={"run_date": req.run_date},
        output_payload={"game_count": len(games_payload), "universe_hash": universe_hash},
        tool_name="providers.mlb.fetch_schedule",
        evidence_ids=[evidence_id],
        details={"protocol_id": MOTHER_PROTOCOL_ID},
    )
    return {
        "run_id": run_id,
        "game_count": len(games_payload),
        "universe_hash": universe_hash,
        "evidence_id": evidence_id,
        "event_hash": event["event_hash"],
        "a0_status": "AUTO_SEALED",
    }


@app.post("/evidence")
async def add_evidence(req: EvidenceCreate):
    evidence_id = req.evidence_id or f"EVID-{uuid4().hex}"
    retrieved_at = req.retrieved_at or now_iso()
    row = {
        "evidence_id": evidence_id,
        "run_id": req.run_id,
        "game_id": req.game_id,
        "tool_name": req.tool_name,
        "source_ref": req.source_ref,
        "source_url": req.source_url,
        "retrieved_at": retrieved_at,
        "data_available_at": req.data_available_at or retrieved_at,
        "input_hash": stable_hash(req.input_payload) if req.input_payload is not None else None,
        "payload_hash": stable_hash(req.payload),
        "payload": req.payload,
    }
    saved = await sb_request("POST", "evidence", payload=row, prefer="return=representation")
    await persist_trace(
        run_id=req.run_id,
        game_id=req.game_id,
        task_id="EVIDENCE_CAPTURE",
        event_type="REAL_EVIDENCE_CAPTURED",
        status="COMPLETE",
        input_payload=req.input_payload,
        output_payload=req.payload,
        tool_name=req.tool_name,
        evidence_ids=[evidence_id],
        details={"source_ref": req.source_ref},
    )
    return (saved or [row])[0]


@app.post("/recoveries")
async def add_recovery(req: RecoveryCreate):
    row = {
        "run_id": req.run_id,
        "game_id": req.game_id,
        "issue_id": req.issue_id,
        "task_id": req.task_id,
        "reason": req.reason,
        "attempt": 1,
        "outcome": req.outcome,
        "occurred_at": now_iso(),
    }
    saved = await sb_request("POST", "recoveries", payload=row, prefer="return=representation")
    await persist_trace(
        run_id=req.run_id,
        game_id=req.game_id,
        task_id=req.task_id or "RECOVERY",
        event_type="ONE_MATERIAL_RECOVERY",
        status=req.outcome or "ATTEMPTED",
        input_payload={"issue_id": req.issue_id, "reason": req.reason},
        output_payload={"outcome": req.outcome},
        tool_name="kernel.recovery",
        details={"attempt": 1},
    )
    return (saved or [row])[0]


@app.post("/trace")
async def add_trace(req: TraceCreate):
    return await persist_trace(
        run_id=req.run_id,
        game_id=req.game_id,
        task_id=req.task_id,
        event_type=req.event_type,
        status=req.status,
        input_payload=req.input_payload,
        output_payload=req.output_payload,
        tool_name=req.tool_name,
        evidence_ids=req.evidence_ids,
        details=req.details,
    )


@app.post("/decisions")
async def legacy_decision(req: DecisionCreate):
    try:
        validate_decision(
            decision=req.decision,
            central_nrfi_case=req.central_nrfi_case,
            best_yrfi_rival=req.best_yrfi_rival,
            decisive_factor=req.decisive_factor,
            materiality=req.materiality,
            what_would_change=req.what_would_change,
            numeric_status=req.numeric_status,
            raw_p_nrfi=req.raw_p_nrfi,
            model_version=req.model_version,
            calibration_status=req.calibration_status,
        )
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc

    row = {
        "run_id": req.run_id,
        "game_id": req.game_id,
        "decision": req.decision,
        "central_nrfi_case": req.central_nrfi_case,
        "best_yrfi_rival": req.best_yrfi_rival,
        "decisive_factor": req.decisive_factor,
        "materiality": req.materiality,
        "what_would_change": req.what_would_change,
        "numeric_status": "NOT_EXECUTED",
        "raw_p_nrfi": None,
        "model_version": "NOT_INTEGRATED",
        "calibration_status": "NOT_CERTIFIED",
    }
    saved = await sb_request(
        "POST",
        "decisions",
        params={"on_conflict": "run_id,game_id"},
        payload=row,
        prefer="resolution=merge-duplicates,return=representation",
    )
    return {
        "legacy": True,
        "authority": "AUDIT_ONLY_ONLY",
        "decision": (saved or [row])[0],
    }


@app.post("/runs/{run_id}/close")
async def close_run(run_id: str):
    runs = await sb_request(
        "GET",
        "runs",
        params={"select": "*", "run_id": f"eq.{run_id}", "limit": "1"},
    ) or []
    if not runs:
        raise HTTPException(status_code=404, detail="RUN_NOT_FOUND")
    run = runs[0]

    if run.get("system_version") == SYSTEM_VERSION:
        final_rows = await sb_request(
            "GET",
            "protocol_run_state",
            params={
                "select": "stage_id,status,payload,submitted_at",
                "run_id": f"eq.{run_id}",
                "protocol_id": f"eq.{MOTHER_PROTOCOL_ID}",
                "stage_id": "eq.FINAL_REPORT",
                "status": "eq.COMPLETE",
                "limit": "1",
            },
        ) or []
        if not final_rows:
            raise HTTPException(status_code=409, detail="MOTHER_FINAL_REPORT_GATE_INCOMPLETE")
        resolutions = await sb_request(
            "GET",
            "protocol_game_resolution",
            params={"select": "game_id,resolution_code,authority_level", "run_id": f"eq.{run_id}", "protocol_id": f"eq.{MOTHER_PROTOCOL_ID}"},
        ) or []
        stages = await sb_request(
            "GET",
            "protocol_run_state",
            params={"select": "stage_id,status", "run_id": f"eq.{run_id}", "protocol_id": f"eq.{MOTHER_PROTOCOL_ID}"},
        ) or []
        metadata = {
            **(run.get("metadata") or {}),
            "closed_by": "MOTHER_FINAL_REPORT_GATE",
            "protocol_id": MOTHER_PROTOCOL_ID,
            "run_stage_count": len(stages),
            "terminal_resolution_count": len(resolutions),
        }
    else:
        metadata = {**(run.get("metadata") or {}), "closed_by": "LEGACY_RUN"}

    closed = await sb_request(
        "PATCH",
        "runs",
        params={"run_id": f"eq.{run_id}"},
        payload={"status": "CLOSED", "closed_at": now_iso(), "metadata": metadata},
        prefer="return=representation",
    )
    event = await persist_trace(
        run_id=run_id,
        game_id=None,
        task_id="RUN_CLOSE",
        event_type="MOTHER_RUN_CLOSED" if run.get("system_version") == SYSTEM_VERSION else "LEGACY_RUN_CLOSED",
        status="CLOSED",
        input_payload={"run_id": run_id},
        output_payload={"closed": True},
        tool_name="kernel.close",
    )
    return {"run": (closed or [{}])[0], "event_hash": event["event_hash"]}


@app.get("/runs/{run_id}/snapshot")
async def snapshot(run_id: str):
    async def get(table: str, select: str = "*"):
        return await sb_request(
            "GET",
            table,
            params={"select": select, "run_id": f"eq.{run_id}"},
        ) or []

    runs = await get("runs")
    if not runs:
        raise HTTPException(status_code=404, detail="RUN_NOT_FOUND")

    games = await get("games")
    evidence = await get("evidence")
    recoveries = await get("recoveries")
    traces = await sb_request(
        "GET",
        "trace_events",
        params={"select": "*", "run_id": f"eq.{run_id}", "order": "occurred_at.asc"},
    ) or []
    decisions = await get("decisions")
    phase_state = await get("protocol_phase_state")
    resolutions = await get("protocol_game_resolution")
    run_stages = await get("protocol_run_state")

    return {
        "run": runs[0],
        "games": games,
        "evidence": evidence,
        "recoveries": recoveries,
        "trace_events": traces,
        "mother_phase_state": [x for x in phase_state if x.get("protocol_id") == MOTHER_PROTOCOL_ID],
        "mother_game_resolutions": [x for x in resolutions if x.get("protocol_id") == MOTHER_PROTOCOL_ID],
        "mother_run_stages": [x for x in run_stages if x.get("protocol_id") == MOTHER_PROTOCOL_ID],
        "legacy_decisions": decisions,
        "authority": {
            "protocol_id": MOTHER_PROTOCOL_ID,
            "mother_document_sha256": MOTHER_DOCUMENT_SHA256,
            "kernel_version": KERNEL_VERSION,
            "system_state": SYSTEM_STATE,
            "real_money_authority": REAL_MONEY_AUTHORITY,
        },
    }
