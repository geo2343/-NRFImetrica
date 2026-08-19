from __future__ import annotations

import os
from datetime import date
from typing import Any
from uuid import uuid4

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from kernel.core import (
    CALIBRATION_STATUS,
    KERNEL_VERSION,
    MODEL_STATUS,
    NUMERIC_ENGINE_STATUS,
    SYSTEM_SCOPE,
    SYSTEM_VERSION,
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

app = FastAPI(title="@NRFImetrica Kernel", version=KERNEL_VERSION)


def _db_headers(prefer: str | None = None) -> dict[str, str]:
    if not SUPABASE_URL or not SUPABASE_SECRET_KEY:
        raise HTTPException(status_code=503, detail="SUPABASE_RUNTIME_NOT_CONFIGURED")
    headers = {
        "apikey": SUPABASE_SECRET_KEY,
        "Content-Type": "application/json",
    }
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
    payload: Any | None = None,
    prefer: str | None = None,
) -> Any:
    headers = _db_headers(prefer)
    async with httpx.AsyncClient(timeout=20.0) as client:
        response = await client.request(
            method,
            f"{SUPABASE_URL}/rest/v1/{table}",
            headers=headers,
            params=params,
            json=payload,
        )
    if response.status_code >= 300:
        body = response.text[:500]
        if response.status_code == 409 or '"23505"' in body or "duplicate key" in body.lower():
            raise HTTPException(status_code=409, detail=f"DB_CONFLICT:{table}")
        raise HTTPException(
            status_code=502,
            detail=f"SUPABASE_{method.upper()}_FAILED:{table}:{response.status_code}:{body}",
        )
    if not response.content:
        return None
    return response.json()


async def sb_insert(table: str, payload: Any) -> Any:
    return await sb_request("POST", table, payload=payload, prefer="return=representation")


async def sb_select(
    table: str,
    *,
    select: str = "*",
    filters: dict[str, str] | None = None,
    order: str | None = None,
    limit: int | None = None,
) -> list[dict[str, Any]]:
    params: dict[str, str] = {"select": select}
    if filters:
        params.update(filters)
    if order:
        params["order"] = order
    if limit is not None:
        params["limit"] = str(limit)
    result = await sb_request("GET", table, params=params)
    return result or []


async def sb_update(
    table: str,
    *,
    filters: dict[str, str],
    payload: dict[str, Any],
) -> Any:
    return await sb_request(
        "PATCH",
        table,
        params=filters,
        payload=payload,
        prefer="return=representation",
    )


async def latest_trace_hash(run_id: str) -> str | None:
    rows = await sb_select(
        "trace_events",
        select="event_hash,occurred_at",
        filters={"run_id": f"eq.{run_id}"},
        order="occurred_at.desc",
        limit=1,
    )
    return rows[0]["event_hash"] if rows else None


async def record_trace(
    *,
    run_id: str,
    game_id: str | None,
    task_id: str,
    event_type: str,
    status: str,
    tool_name: str | None,
    input_payload: Any | None,
    output_payload: Any | None,
    evidence_ids: list[str] | None = None,
    details: dict[str, Any] | None = None,
) -> dict[str, Any]:
    occurred_at = now_iso()
    previous_event_hash = await latest_trace_hash(run_id)
    base = {
        "event_id": f"EVT-{uuid4().hex}",
        "run_id": run_id,
        "game_id": game_id,
        "task_id": task_id,
        "event_type": event_type,
        "status": status,
        "occurred_at": occurred_at,
        "input_hash": stable_hash(input_payload) if input_payload is not None else None,
        "output_hash": stable_hash(output_payload) if output_payload is not None else None,
        "tool_name": tool_name,
        "evidence_ids": evidence_ids or [],
        "prev_event_hash": previous_event_hash,
        "details": details or {},
    }
    base["event_hash"] = stable_hash(base)
    await sb_insert("trace_events", base)
    return base


class RunCreate(BaseModel):
    run_id: str = Field(min_length=3, max_length=120)
    run_date: str
    timezone: str = "America/Santo_Domingo"
    universe_hash: str | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)


class MLBRunCreate(BaseModel):
    run_date: str
    timezone: str = "America/Santo_Domingo"
    cutoff_minutes_before: int = Field(default=0, ge=0, le=60)


class RecoveryCreate(BaseModel):
    run_id: str
    game_id: str | None = None
    issue_id: str = Field(min_length=3, max_length=160)
    task_id: str | None = None
    reason: str = Field(min_length=3)
    outcome: str | None = None


class TraceCreate(BaseModel):
    run_id: str
    game_id: str | None = None
    task_id: str
    event_type: str
    status: str
    input_payload: Any | None = None
    output_payload: Any | None = None
    tool_name: str | None = None
    evidence_ids: list[str] = Field(default_factory=list)
    details: dict[str, Any] = Field(default_factory=dict)


class EvidenceCreate(BaseModel):
    run_id: str
    game_id: str | None = None
    tool_name: str
    source_ref: str | None = None
    source_url: str | None = None
    retrieved_at: str | None = None
    data_available_at: str | None = None
    input_payload: Any | None = None
    payload: Any


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
        "service": "@NRFImetrica Kernel",
        "system_version": SYSTEM_VERSION,
        "kernel_version": KERNEL_VERSION,
        "scope": SYSTEM_SCOPE,
        "status": "CONTROLLED_REAL_RUNTIME",
        "numeric_engine_status": NUMERIC_ENGINE_STATUS,
        "model_status": MODEL_STATUS,
        "calibration_status": CALIBRATION_STATUS,
        "real_money_authority": False,
    }


@app.get("/health")
async def health():
    configured = bool(SUPABASE_URL and SUPABASE_SECRET_KEY)
    db_reachable = False
    canonical: dict[str, Any] | None = None
    error: str | None = None
    if configured:
        try:
            rows = await sb_select(
                "system_versions",
                select="system_version,kernel_version,model_version,calibration_status",
                filters={"system_version": f"eq.{SYSTEM_VERSION}"},
                limit=1,
            )
            db_reachable = bool(rows)
            canonical = rows[0] if rows else None
        except Exception as exc:
            error = type(exc).__name__
    return {
        "ok": configured and db_reachable,
        "system_version": SYSTEM_VERSION,
        "kernel_version": KERNEL_VERSION,
        "supabase_configured": configured,
        "supabase_reachable": db_reachable,
        "canonical_version": canonical,
        "numeric_engine_status": NUMERIC_ENGINE_STATUS,
        "real_money_authority": False,
        "error": error,
    }


@app.get("/mlb/schedule/{run_date}")
async def mlb_schedule_probe(run_date: str):
    try:
        date.fromisoformat(run_date)
    except ValueError:
        raise HTTPException(status_code=400, detail="INVALID_DATE")
    try:
        result = await fetch_schedule(run_date)
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail=f"MLB_PROVIDER_FAILED:{type(exc).__name__}")
    return {
        "provider": result["provider"],
        "retrieved_at": result["retrieved_at"],
        "source_url": result["source_url"],
        "universe_hash": result["universe_hash"],
        "game_count": len(result["games"]),
        "games": result["games"],
    }


@app.post("/runs", status_code=201)
async def create_run(req: RunCreate):
    try:
        date.fromisoformat(req.run_date)
    except ValueError:
        raise HTTPException(status_code=400, detail="INVALID_DATE")
    payload = {
        "run_id": req.run_id,
        "system_version": SYSTEM_VERSION,
        "run_date": req.run_date,
        "timezone": req.timezone,
        "status": "OPEN",
        "mode": "CONTROLLED_REAL",
        "universe_hash": req.universe_hash,
        "metadata": req.metadata,
    }
    await sb_insert("runs", payload)
    await record_trace(
        run_id=req.run_id,
        game_id=None,
        task_id="RUN_OPEN",
        event_type="RUN_CREATED",
        status="OK",
        tool_name="kernel",
        input_payload=req.model_dump(),
        output_payload=payload,
    )
    return {"created": True, "run_id": req.run_id}


@app.post("/runs/sync-mlb", status_code=201)
async def create_real_mlb_run(req: MLBRunCreate):
    try:
        date.fromisoformat(req.run_date)
    except ValueError:
        raise HTTPException(status_code=400, detail="INVALID_DATE")

    try:
        provider = await fetch_schedule(req.run_date, cutoff_minutes_before=req.cutoff_minutes_before)
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail=f"MLB_PROVIDER_FAILED:{type(exc).__name__}")

    games = provider["games"]
    if not games:
        raise HTTPException(status_code=502, detail="MLB_PROVIDER_RETURNED_EMPTY_SLATE")

    run_id = f"NRFIM-V21-{req.run_date.replace('-', '')}-{uuid4().hex[:10]}"
    run_payload = {
        "run_id": run_id,
        "system_version": SYSTEM_VERSION,
        "run_date": req.run_date,
        "timezone": req.timezone,
        "status": "OPEN",
        "mode": "CONTROLLED_REAL",
        "universe_hash": provider["universe_hash"],
        "tool_call_count": 1,
        "metadata": {
            "universe_frozen": True,
            "provider": provider["provider"],
            "cutoff_minutes_before": req.cutoff_minutes_before,
            "game_count": len(games),
            "numeric_status": "NOT_EXECUTED",
            "model_status": "NOT_INTEGRATED",
            "real_money_authority": False,
        },
    }
    await sb_insert("runs", run_payload)

    game_rows = [
        {
            "run_id": run_id,
            "game_id": game["game_id"],
            "away_team": game["away_team"],
            "home_team": game["home_team"],
            "scheduled_start": game["scheduled_start"],
            "cutoff_at": game["cutoff_at"],
            "status": game["status"],
        }
        for game in games
    ]
    await sb_insert("games", game_rows)

    evidence_id = f"EVID-{uuid4().hex}"
    evidence_payload = {
        "evidence_id": evidence_id,
        "run_id": run_id,
        "game_id": None,
        "tool_name": "MLB_STATS_API.schedule",
        "source_ref": "/api/v1/schedule",
        "source_url": provider["source_url"],
        "retrieved_at": provider["retrieved_at"],
        "data_available_at": provider["retrieved_at"],
        "input_hash": stable_hash({"run_date": req.run_date, "sportId": 1, "cutoff_minutes_before": req.cutoff_minutes_before}),
        "payload_hash": provider["raw_payload_hash"],
        "payload": provider["raw"],
    }
    await sb_insert("evidence", evidence_payload)

    await record_trace(
        run_id=run_id,
        game_id=None,
        task_id="UNIVERSE_FREEZE",
        event_type="MLB_SLATE_FETCHED_AND_FROZEN",
        status="OK",
        tool_name="MLB_STATS_API.schedule",
        input_payload=req.model_dump(),
        output_payload=games,
        evidence_ids=[evidence_id],
        details={"game_count": len(games), "universe_hash": provider["universe_hash"]},
    )

    return {
        "created": True,
        "run_id": run_id,
        "universe_frozen": True,
        "universe_hash": provider["universe_hash"],
        "game_count": len(games),
        "games": games,
        "numeric_status": "NOT_EXECUTED",
        "real_money_authority": False,
    }


@app.post("/evidence", status_code=201)
async def create_evidence(req: EvidenceCreate):
    retrieved_at = req.retrieved_at or now_iso()
    evidence_id = f"EVID-{uuid4().hex}"
    row = {
        "evidence_id": evidence_id,
        "run_id": req.run_id,
        "game_id": req.game_id,
        "tool_name": req.tool_name,
        "source_ref": req.source_ref,
        "source_url": req.source_url,
        "retrieved_at": retrieved_at,
        "data_available_at": req.data_available_at,
        "input_hash": stable_hash(req.input_payload) if req.input_payload is not None else None,
        "payload_hash": stable_hash(req.payload),
        "payload": req.payload,
    }
    await sb_insert("evidence", row)
    await record_trace(
        run_id=req.run_id,
        game_id=req.game_id,
        task_id="EVIDENCE_CAPTURE",
        event_type="EVIDENCE_PERSISTED",
        status="OK",
        tool_name=req.tool_name,
        input_payload=req.input_payload,
        output_payload=req.payload,
        evidence_ids=[evidence_id],
    )
    return {"recorded": True, "evidence_id": evidence_id, "payload_hash": row["payload_hash"]}


@app.post("/recoveries", status_code=201)
async def create_recovery(req: RecoveryCreate):
    row = {
        "run_id": req.run_id,
        "game_id": req.game_id,
        "issue_id": req.issue_id,
        "task_id": req.task_id,
        "reason": req.reason,
        "attempt": 1,
        "outcome": req.outcome,
    }
    try:
        await sb_insert("recoveries", row)
    except HTTPException as exc:
        if exc.status_code == 409:
            raise HTTPException(status_code=409, detail="RECOVERY_LIMIT_REACHED")
        raise

    current = await sb_select("runs", select="recovery_count", filters={"run_id": f"eq.{req.run_id}"}, limit=1)
    if current:
        await sb_update(
            "runs",
            filters={"run_id": f"eq.{req.run_id}"},
            payload={"recovery_count": int(current[0].get("recovery_count") or 0) + 1},
        )

    await record_trace(
        run_id=req.run_id,
        game_id=req.game_id,
        task_id=req.task_id or "RECOVERY",
        event_type="RECOVERY_EXECUTED",
        status=req.outcome or "RECORDED",
        tool_name="kernel",
        input_payload={"issue_id": req.issue_id, "reason": req.reason},
        output_payload={"attempt": 1, "outcome": req.outcome},
    )
    return {"recorded": True, "issue_id": req.issue_id, "attempt": 1}


@app.post("/trace", status_code=201)
async def create_trace(req: TraceCreate):
    event = await record_trace(
        run_id=req.run_id,
        game_id=req.game_id,
        task_id=req.task_id,
        event_type=req.event_type,
        status=req.status,
        tool_name=req.tool_name,
        input_payload=req.input_payload,
        output_payload=req.output_payload,
        evidence_ids=req.evidence_ids,
        details=req.details,
    )
    return {
        "recorded": True,
        "event_id": event["event_id"],
        "event_hash": event["event_hash"],
        "prev_event_hash": event["prev_event_hash"],
    }


@app.post("/decisions", status_code=201)
async def create_decision(req: DecisionCreate):
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
        raise HTTPException(status_code=422, detail=str(exc))

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
    await sb_insert("decisions", row)
    await sb_update(
        "games",
        filters={"run_id": f"eq.{req.run_id}", "game_id": f"eq.{req.game_id}"},
        payload={
            "decision": req.decision,
            "central_nrfi_case": req.central_nrfi_case,
            "best_yrfi_rival": req.best_yrfi_rival,
            "decision_reason": {
                "decisive_factor": req.decisive_factor,
                "materiality": req.materiality,
                "what_would_change": req.what_would_change,
            },
        },
    )
    await record_trace(
        run_id=req.run_id,
        game_id=req.game_id,
        task_id="DECISION",
        event_type="SPORTS_DECISION_PERSISTED",
        status=req.decision,
        tool_name="llm_reasoning_contract",
        input_payload=req.model_dump(),
        output_payload=row,
        details={"numeric_engine_status": NUMERIC_ENGINE_STATUS, "real_money_authority": False},
    )
    return {
        "recorded": True,
        "decision": req.decision,
        "numeric_status": "NOT_EXECUTED",
        "real_money_authority": False,
    }


@app.post("/runs/{run_id}/close")
async def close_run(run_id: str):
    games = await sb_select("games", filters={"run_id": f"eq.{run_id}"})
    if not games:
        raise HTTPException(status_code=404, detail="RUN_NOT_FOUND_OR_EMPTY")

    decisions = await sb_select("decisions", filters={"run_id": f"eq.{run_id}"})
    recoveries = await sb_select("recoveries", filters={"run_id": f"eq.{run_id}"})
    decision_counts: dict[str, int] = {}
    for item in decisions:
        key = item["decision"]
        decision_counts[key] = decision_counts.get(key, 0) + 1

    audit_only = sum(1 for g in games if g.get("status") == "AUDIT_ONLY")
    unresolved = [g["game_id"] for g in games if g.get("status") != "AUDIT_ONLY" and not g.get("decision")]
    summary = {
        "total_games": len(games),
        "audit_only": audit_only,
        "decision_counts": decision_counts,
        "recoveries": len(recoveries),
        "unresolved_games": unresolved,
        "numeric_status": "NOT_EXECUTED",
        "model_status": "NOT_INTEGRATED",
        "real_money_authority": False,
    }
    if unresolved:
        raise HTTPException(status_code=409, detail={"code": "RUN_INCOMPLETE", "summary": summary})

    await sb_update(
        "runs",
        filters={"run_id": f"eq.{run_id}"},
        payload={
            "status": "CLOSED",
            "closed_at": now_iso(),
            "recovery_count": len(recoveries),
            "metadata": summary,
        },
    )
    await record_trace(
        run_id=run_id,
        game_id=None,
        task_id="RUN_CLOSE",
        event_type="RUN_CLOSED",
        status="OK",
        tool_name="kernel",
        input_payload={"run_id": run_id},
        output_payload=summary,
    )
    return {"closed": True, "run_id": run_id, "summary": summary}


@app.get("/runs/{run_id}/snapshot")
async def run_snapshot(run_id: str):
    runs = await sb_select("runs", filters={"run_id": f"eq.{run_id}"}, limit=1)
    if not runs:
        raise HTTPException(status_code=404, detail="RUN_NOT_FOUND")
    games = await sb_select("games", filters={"run_id": f"eq.{run_id}"}, order="scheduled_start.asc")
    decisions = await sb_select("decisions", filters={"run_id": f"eq.{run_id}"}, order="created_at.asc")
    recoveries = await sb_select("recoveries", filters={"run_id": f"eq.{run_id}"}, order="occurred_at.asc")
    trace = await sb_select("trace_events", filters={"run_id": f"eq.{run_id}"}, order="occurred_at.asc")
    return {
        "run": runs[0],
        "games": games,
        "decisions": decisions,
        "recoveries": recoveries,
        "trace": trace,
    }
