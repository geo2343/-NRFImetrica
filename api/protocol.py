from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any
from uuid import uuid4

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from kernel.core import now_iso, stable_hash
from kernel.protocol import ProtocolViolation, validate_phase_submission

SUPABASE_URL = os.getenv("SUPABASE_URL", "").rstrip("/")
SUPABASE_SECRET_KEY = (
    os.getenv("SUPABASE_SECRET_KEY", "")
    or os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
)
MANIFEST_PATH = Path(__file__).resolve().parents[1] / "protocols" / "nrfimetrica_v21_ai_analyst.json"
MANIFEST = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))

app = FastAPI(title="@NRFImetrica Protocol Gate", version="1.0")


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
    async with httpx.AsyncClient(timeout=20.0) as client:
        response = await client.request(
            method,
            f"{SUPABASE_URL}/rest/v1/{table}",
            headers=_headers(prefer),
            params=params,
            json=payload,
        )
    if response.status_code >= 300:
        raise HTTPException(status_code=502, detail=f"SUPABASE_{table}_{response.status_code}:{response.text[:400]}")
    return response.json() if response.content else None


async def latest_trace_hash(run_id: str) -> str | None:
    rows = await sb(
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


class ProtocolRequest(BaseModel):
    action: str
    run_id: str | None = None
    game_id: str | None = None
    phase_id: str | None = None
    payload: dict[str, Any] = Field(default_factory=dict)
    evidence_ids: list[str] = Field(default_factory=list)
    source_calls: list[dict[str, Any]] = Field(default_factory=list)
    documents_analyzed: list[str] = Field(default_factory=list)
    output_text: str = ""
    skip_reason: str | None = None


@app.get("/")
async def get_protocol():
    return MANIFEST


@app.post("/")
async def protocol_action(req: ProtocolRequest):
    if req.action == "state":
        if not req.run_id:
            raise HTTPException(status_code=422, detail="RUN_ID_REQUIRED")
        filters = {"run_id": f"eq.{req.run_id}"}
        if req.game_id:
            filters["game_id"] = f"eq.{req.game_id}"
        rows = await sb(
            "GET",
            "protocol_phase_state",
            params={"select": "*", **filters, "order": "submitted_at.asc"},
        )
        return {"protocol_id": MANIFEST["protocol_id"], "phases": rows or []}

    if req.action != "submit_phase":
        raise HTTPException(status_code=422, detail="INVALID_ACTION")
    if not req.run_id or not req.game_id or not req.phase_id:
        raise HTTPException(status_code=422, detail="RUN_GAME_PHASE_REQUIRED")

    games = await sb(
        "GET",
        "games",
        params={
            "select": "run_id,game_id,status,cutoff_at",
            "run_id": f"eq.{req.run_id}",
            "game_id": f"eq.{req.game_id}",
            "limit": "1",
        },
    )
    if not games:
        raise HTTPException(status_code=404, detail="GAME_NOT_REGISTERED_IN_FROZEN_UNIVERSE")
    if games[0].get("status") == "AUDIT_ONLY":
        raise HTTPException(status_code=409, detail="AUDIT_ONLY_GAME_CANNOT_ENTER_PREGAME_REASONING")

    phase_rows = await sb(
        "GET",
        "protocol_phase_state",
        params={
            "select": "phase_id,status",
            "run_id": f"eq.{req.run_id}",
            "game_id": f"eq.{req.game_id}",
        },
    ) or []
    completed = {
        row["phase_id"] for row in phase_rows
        if row.get("status") in {"COMPLETE", "SKIPPED_NOT_TRIGGERED"}
    }

    evidence_rows = await sb(
        "GET",
        "evidence",
        params={"select": "evidence_id,game_id,retrieved_at,data_available_at", "run_id": f"eq.{req.run_id}"},
    ) or []
    valid_evidence = {row["evidence_id"] for row in evidence_rows}
    submitted_evidence = set(req.evidence_ids)
    submitted_evidence.update(str(x.get("evidence_id") or "") for x in req.source_calls)
    unknown = sorted(x for x in submitted_evidence if x and x not in valid_evidence)
    if unknown:
        raise HTTPException(status_code=422, detail={"code": "EVIDENCE_NOT_FOUND", "ids": unknown})

    cutoff = games[0].get("cutoff_at")
    if cutoff:
        late = [
            row["evidence_id"] for row in evidence_rows
            if row["evidence_id"] in submitted_evidence
            and row.get("data_available_at")
            and str(row["data_available_at"]) > str(cutoff)
        ]
        if late:
            raise HTTPException(status_code=422, detail={"code": "EVIDENCE_AFTER_CUTOFF", "ids": late})

    try:
        result = validate_phase_submission(
            manifest=MANIFEST,
            phase_id=req.phase_id,
            completed_phase_ids=completed,
            payload=req.payload,
            evidence_ids=req.evidence_ids,
            source_calls=req.source_calls,
            documents_analyzed=req.documents_analyzed,
            output_text=req.output_text,
            skip_reason=req.skip_reason,
        )
    except ProtocolViolation as exc:
        raise HTTPException(status_code=422, detail=str(exc))

    row = {
        "run_id": req.run_id,
        "game_id": req.game_id,
        "protocol_id": MANIFEST["protocol_id"],
        "phase_id": req.phase_id,
        "status": result["status"],
        "payload": req.payload,
        "evidence_ids": req.evidence_ids,
        "source_calls": req.source_calls,
        "documents_analyzed": req.documents_analyzed,
        "output_text": req.output_text,
        "skip_reason": req.skip_reason,
        "requirement_check": result["checks"],
        "submitted_at": now_iso(),
    }
    saved = await sb(
        "POST",
        "protocol_phase_state",
        params={"on_conflict": "run_id,game_id,phase_id"},
        payload=row,
        prefer="resolution=merge-duplicates,return=representation",
    )

    previous_hash = await latest_trace_hash(req.run_id)
    event_base = {
        "event_id": f"EVT-{uuid4().hex}",
        "run_id": req.run_id,
        "game_id": req.game_id,
        "task_id": req.phase_id,
        "event_type": "PROTOCOL_PHASE_GATE",
        "status": result["status"],
        "occurred_at": now_iso(),
        "input_hash": stable_hash(req.model_dump()),
        "output_hash": stable_hash(result),
        "tool_name": "kernel.protocol",
        "evidence_ids": req.evidence_ids,
        "prev_event_hash": previous_hash,
        "details": {"protocol_id": MANIFEST["protocol_id"], "checks": result["checks"]},
    }
    event_base["event_hash"] = stable_hash(event_base)
    await sb("POST", "trace_events", payload=event_base, prefer="return=minimal")

    return {
        "accepted": True,
        "phase_id": req.phase_id,
        "status": result["status"],
        "checks": result["checks"],
        "saved": bool(saved),
        "event_hash": event_base["event_hash"],
        "prev_event_hash": previous_hash,
    }
