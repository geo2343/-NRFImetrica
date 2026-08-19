from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any
from uuid import uuid4

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from kernel.core import MOTHER_DOCUMENT_SHA256, MOTHER_PROTOCOL_ID, now_iso, stable_hash
from kernel.protocol import ProtocolViolation, validate_phase_submission

SUPABASE_URL = os.getenv("SUPABASE_URL", "").rstrip("/")
SUPABASE_SECRET_KEY = (
    os.getenv("SUPABASE_SECRET_KEY", "")
    or os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
)
MANIFEST_PATH = Path(__file__).resolve().parents[1] / "protocols" / "nrfimetrica_mother_v3_autonomous.json"
MANIFEST = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))

app = FastAPI(title="@NRFImetrica Mother Protocol Gate", version="2.0")


def _headers(prefer: str | None = None) -> dict[str, str]:
    if not SUPABASE_URL or not SUPABASE_SECRET_KEY:
        raise HTTPException(status_code=503, detail="SUPABASE_RUNTIME_NOT_CONFIGURED")
    headers = {"apikey": SUPABASE_SECRET_KEY, "Content-Type": "application/json"}
    if SUPABASE_SECRET_KEY.count(".") == 2:
        headers["Authorization"] = f"Bearer {SUPABASE_SECRET_KEY}"
    if prefer:
        headers["Prefer"] = prefer
    return headers


async def sb(
    method: str,
    table: str,
    *,
    params: dict[str, str] | None = None,
    payload: Any = None,
    prefer: str | None = None,
) -> Any:
    async with httpx.AsyncClient(timeout=20.0) as client:
        response = await client.request(
            method,
            f"{SUPABASE_URL}/rest/v1/{table}",
            headers=_headers(prefer),
            params=params,
            json=payload,
        )
    if response.status_code >= 300:
        raise HTTPException(status_code=502, detail=f"SUPABASE_{table}_{response.status_code}:{response.text[:500]}")
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


async def record_protocol_trace(
    *,
    run_id: str,
    game_id: str | None,
    task_id: str,
    event_type: str,
    status: str,
    input_payload: Any,
    output_payload: Any,
    evidence_ids: list[str] | None = None,
) -> dict[str, Any]:
    previous_hash = await latest_trace_hash(run_id)
    event_base = {
        "event_id": f"EVT-{uuid4().hex}",
        "run_id": run_id,
        "game_id": game_id,
        "task_id": task_id,
        "event_type": event_type,
        "status": status,
        "occurred_at": now_iso(),
        "input_hash": stable_hash(input_payload),
        "output_hash": stable_hash(output_payload),
        "tool_name": "kernel.mother_protocol",
        "evidence_ids": evidence_ids or [],
        "prev_event_hash": previous_hash,
        "details": {"protocol_id": MOTHER_PROTOCOL_ID, "mother_document_sha256": MOTHER_DOCUMENT_SHA256},
    }
    event_base["event_hash"] = stable_hash(event_base)
    await sb("POST", "trace_events", payload=event_base, prefer="return=minimal")
    return event_base


class ProtocolRequest(BaseModel):
    action: str
    run_id: str | None = None
    game_id: str | None = None
    phase_id: str | None = None
    stage_id: str | None = None
    payload: dict[str, Any] = Field(default_factory=dict)
    evidence_ids: list[str] = Field(default_factory=list)
    source_calls: list[dict[str, Any]] = Field(default_factory=list)
    documents_analyzed: list[str] = Field(default_factory=list)
    output_text: str = ""
    skip_reason: str | None = None


async def ensure_a0_sealed(run_id: str) -> dict[str, Any]:
    rows = await sb(
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
        "system_state": "TRADING_HALT_RESEARCH",
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
    saved = await sb(
        "POST",
        "protocol_run_state",
        params={"on_conflict": "run_id,protocol_id,stage_id"},
        payload=row,
        prefer="resolution=merge-duplicates,return=representation",
    )
    await record_protocol_trace(
        run_id=run_id,
        game_id=None,
        task_id="A0_CONSTITUTION_SEALED",
        event_type="MOTHER_CONSTITUTION_AUTO_SEALED",
        status="COMPLETE",
        input_payload={"run_id": run_id},
        output_payload=payload,
    )
    return (saved or [row])[0]


@app.get("/")
async def get_protocol():
    return MANIFEST


@app.post("/")
async def protocol_action(req: ProtocolRequest):
    if req.action == "state":
        if not req.run_id:
            raise HTTPException(status_code=422, detail="RUN_ID_REQUIRED")
        filters = {"run_id": f"eq.{req.run_id}", "protocol_id": f"eq.{MOTHER_PROTOCOL_ID}"}
        if req.game_id:
            filters["game_id"] = f"eq.{req.game_id}"
        rows = await sb(
            "GET",
            "protocol_phase_state",
            params={"select": "*", **filters, "order": "submitted_at.asc"},
        )
        return {"protocol_id": MOTHER_PROTOCOL_ID, "phases": rows or []}

    if req.action == "run_state":
        if not req.run_id:
            raise HTTPException(status_code=422, detail="RUN_ID_REQUIRED")
        rows = await sb(
            "GET",
            "protocol_run_state",
            params={
                "select": "*",
                "run_id": f"eq.{req.run_id}",
                "protocol_id": f"eq.{MOTHER_PROTOCOL_ID}",
                "order": "submitted_at.asc",
            },
        )
        return {"protocol_id": MOTHER_PROTOCOL_ID, "run_stages": rows or []}

    if req.action == "seal_a0":
        if not req.run_id:
            raise HTTPException(status_code=422, detail="RUN_ID_REQUIRED")
        state = await ensure_a0_sealed(req.run_id)
        return {"accepted": True, "stage_id": "A0_CONSTITUTION_SEALED", "state": state}

    if req.action == "submit_run_stage":
        if not req.run_id or not req.stage_id:
            raise HTTPException(status_code=422, detail="RUN_STAGE_REQUIRED")
        if req.stage_id != "A0_CONSTITUTION_SEALED":
            await ensure_a0_sealed(req.run_id)
        if req.stage_id == "A0_CONSTITUTION_SEALED":
            state = await ensure_a0_sealed(req.run_id)
            return {"accepted": True, "stage_id": req.stage_id, "state": state}
        if req.stage_id not in set(MANIFEST.get("run_stages", [])):
            raise HTTPException(status_code=422, detail="UNKNOWN_RUN_STAGE")

        row = {
            "run_id": req.run_id,
            "protocol_id": MOTHER_PROTOCOL_ID,
            "stage_id": req.stage_id,
            "status": "COMPLETE",
            "payload": req.payload,
            "evidence_ids": req.evidence_ids,
            "output_text": req.output_text,
            "submitted_at": now_iso(),
        }
        saved = await sb(
            "POST",
            "protocol_run_state",
            params={"on_conflict": "run_id,protocol_id,stage_id"},
            payload=row,
            prefer="resolution=merge-duplicates,return=representation",
        )
        event = await record_protocol_trace(
            run_id=req.run_id,
            game_id=None,
            task_id=req.stage_id,
            event_type="MOTHER_RUN_STAGE_GATE",
            status="COMPLETE",
            input_payload=req.model_dump(),
            output_payload=row,
            evidence_ids=req.evidence_ids,
        )
        return {"accepted": True, "stage_id": req.stage_id, "saved": bool(saved), "event_hash": event["event_hash"]}

    if req.action != "submit_phase":
        raise HTTPException(status_code=422, detail="INVALID_ACTION")
    if not req.run_id or not req.game_id or not req.phase_id:
        raise HTTPException(status_code=422, detail="RUN_GAME_PHASE_REQUIRED")

    await ensure_a0_sealed(req.run_id)

    games = await sb(
        "GET",
        "games",
        params={
            "select": "run_id,game_id,status,cutoff_at,scheduled_start",
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
            "protocol_id": f"eq.{MOTHER_PROTOCOL_ID}",
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

    cutoff = games[0].get("cutoff_at") or games[0].get("scheduled_start")
    if cutoff:
        late = [
            row["evidence_id"] for row in evidence_rows
            if row["evidence_id"] in submitted_evidence
            and row.get("data_available_at")
            and str(row["data_available_at"]) > str(cutoff)
        ]
        if late:
            raise HTTPException(status_code=422, detail={"code": "EVIDENCE_AFTER_PREGAME_CUTOFF", "ids": late})

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
        "protocol_id": MOTHER_PROTOCOL_ID,
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

    event = await record_protocol_trace(
        run_id=req.run_id,
        game_id=req.game_id,
        task_id=req.phase_id,
        event_type="MOTHER_PHASE_GATE",
        status=result["status"],
        input_payload=req.model_dump(),
        output_payload=result,
        evidence_ids=req.evidence_ids,
    )

    return {
        "accepted": True,
        "phase_id": req.phase_id,
        "status": result["status"],
        "checks": result["checks"],
        "saved": bool(saved),
        "event_hash": event["event_hash"],
        "prev_event_hash": event["prev_event_hash"],
        "next_phase_authorization": "AUTOMATIC_IF_GATE_PASS",
    }
