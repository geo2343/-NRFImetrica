from __future__ import annotations

import hashlib
import json
import os
from datetime import datetime, timezone
from typing import Any

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

SYSTEM_VERSION = "NRFIM V2.1"
KERNEL_VERSION = "NRFIM-KERNEL-0.1-FOUNDATION"
SYSTEM_SCOPE = "NRFI_ONLY"

SUPABASE_URL = os.getenv("SUPABASE_URL", "").rstrip("/")
# Prefer the current Supabase server-side secret key. Legacy service_role remains
# supported temporarily for compatibility while Supabase completes its key migration.
SUPABASE_SECRET_KEY = (
    os.getenv("SUPABASE_SECRET_KEY", "")
    or os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
)

app = FastAPI(title="@NRFImetrica Kernel", version=KERNEL_VERSION)


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def stable_hash(value: Any) -> str:
    blob = json.dumps(value, sort_keys=True, default=str, separators=(",", ":"))
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()


def require_db() -> None:
    if not SUPABASE_URL or not SUPABASE_SECRET_KEY:
        raise HTTPException(status_code=503, detail="SUPABASE_RUNTIME_NOT_CONFIGURED")


async def supabase_insert(table: str, payload: dict[str, Any]) -> None:
    require_db()
    headers = {
        "apikey": SUPABASE_SECRET_KEY,
        "Content-Type": "application/json",
        "Prefer": "return=minimal",
    }
    async with httpx.AsyncClient(timeout=15.0) as client:
        r = await client.post(f"{SUPABASE_URL}/rest/v1/{table}", headers=headers, json=payload)
    if r.status_code >= 300:
        raise HTTPException(status_code=502, detail=f"SUPABASE_INSERT_FAILED:{table}:{r.status_code}:{r.text[:300]}")


class RunCreate(BaseModel):
    run_id: str = Field(min_length=3, max_length=120)
    run_date: str
    timezone: str = "America/Santo_Domingo"
    universe_hash: str | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)


class RecoveryCreate(BaseModel):
    run_id: str
    game_id: str | None = None
    issue_id: str
    task_id: str | None = None
    reason: str
    outcome: str | None = None


class TraceCreate(BaseModel):
    event_id: str
    run_id: str
    game_id: str | None = None
    task_id: str
    event_type: str
    status: str
    input_payload: Any | None = None
    output_payload: Any | None = None
    tool_name: str | None = None
    evidence_ids: list[str] = Field(default_factory=list)
    prev_event_hash: str | None = None
    details: dict[str, Any] = Field(default_factory=dict)


@app.get("/")
async def root():
    return {
        "service": "@NRFImetrica Kernel",
        "system_version": SYSTEM_VERSION,
        "kernel_version": KERNEL_VERSION,
        "scope": SYSTEM_SCOPE,
        "status": "FOUNDATION_REAL_RUNTIME_BUILDING",
        "real_money_authority": False,
    }


@app.get("/health")
async def health():
    return {
        "ok": True,
        "system_version": SYSTEM_VERSION,
        "kernel_version": KERNEL_VERSION,
        "supabase_configured": bool(SUPABASE_URL and SUPABASE_SECRET_KEY),
    }


@app.post("/runs", status_code=201)
async def create_run(req: RunCreate):
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
    await supabase_insert("runs", payload)
    return {"created": True, "run_id": req.run_id}


@app.post("/recoveries", status_code=201)
async def create_recovery(req: RecoveryCreate):
    # DB unique(run_id, issue_id) + attempt=1 enforces the V2.1 one-Recovery rule.
    payload = {
        "run_id": req.run_id,
        "game_id": req.game_id,
        "issue_id": req.issue_id,
        "task_id": req.task_id,
        "reason": req.reason,
        "attempt": 1,
        "outcome": req.outcome,
    }
    await supabase_insert("recoveries", payload)
    return {"recorded": True, "issue_id": req.issue_id, "attempt": 1}


@app.post("/trace", status_code=201)
async def create_trace(req: TraceCreate):
    occurred_at = now_iso()
    input_hash = stable_hash(req.input_payload) if req.input_payload is not None else None
    output_hash = stable_hash(req.output_payload) if req.output_payload is not None else None
    base = {
        "event_id": req.event_id,
        "run_id": req.run_id,
        "game_id": req.game_id,
        "task_id": req.task_id,
        "event_type": req.event_type,
        "status": req.status,
        "occurred_at": occurred_at,
        "input_hash": input_hash,
        "output_hash": output_hash,
        "tool_name": req.tool_name,
        "evidence_ids": req.evidence_ids,
        "prev_event_hash": req.prev_event_hash,
        "details": req.details,
    }
    base["event_hash"] = stable_hash(base)
    await supabase_insert("trace_events", base)
    return {"recorded": True, "event_id": req.event_id, "event_hash": base["event_hash"]}
