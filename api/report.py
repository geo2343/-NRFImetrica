from __future__ import annotations

import os
from typing import Any
from uuid import uuid4

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from kernel.core import MOTHER_DOCUMENT_SHA256, MOTHER_PROTOCOL_ID, SYSTEM_VERSION, now_iso, stable_hash

SUPABASE_URL = os.getenv("SUPABASE_URL", "").rstrip("/")
SUPABASE_SECRET_KEY = os.getenv("SUPABASE_SECRET_KEY", "") or os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")

app = FastAPI(title="@NRFImetrica Mother V3 Final Report Gate", version="2.0")


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
        body = response.text[:700]
        raise HTTPException(status_code=422 if '23514' in body else 502, detail=f"SUPABASE_{table}_{response.status_code}:{body}")
    return response.json() if response.content else None


async def latest_trace_hash(run_id: str) -> str | None:
    rows = await sb(
        "GET",
        "trace_events",
        params={"select": "event_hash,occurred_at", "run_id": f"eq.{run_id}", "order": "occurred_at.desc", "limit": "1"},
    ) or []
    return rows[0]["event_hash"] if rows else None


class ReportRequest(BaseModel):
    run_id: str
    report: dict[str, Any] = Field(default_factory=dict)
    document_ref: str | None = None


@app.get("/")
async def report_gate_status():
    return {
        "service": "@NRFImetrica Mother V3 Final Report Gate",
        "system_version": SYSTEM_VERSION,
        "protocol_id": MOTHER_PROTOCOL_ID,
        "mother_document_sha256": MOTHER_DOCUMENT_SHA256,
        "validation_source": "SUPABASE_MOTHER_RUN_STAGE_TRIGGER",
        "legacy_decisions_report_gate": "SUPERSEDED",
    }


@app.post("/")
async def validate_report(req: ReportRequest):
    runs = await sb(
        "GET",
        "runs",
        params={"select": "run_id,status,mode,system_version", "run_id": f"eq.{req.run_id}", "limit": "1"},
    ) or []
    if not runs:
        raise HTTPException(status_code=404, detail="RUN_NOT_FOUND")
    if str(runs[0].get("system_version") or "") != SYSTEM_VERSION:
        raise HTTPException(status_code=409, detail="LEGACY_REPORT_GATE_SUPERSEDED_BY_MOTHER_V3")

    required = await sb(
        "GET",
        "protocol_run_state",
        params={
            "select": "stage_id,status,payload",
            "run_id": f"eq.{req.run_id}",
            "protocol_id": f"eq.{MOTHER_PROTOCOL_ID}",
            "stage_id": "in.(A0_CONSTITUTION_SEALED,A1_SLATE_ROUTED,A7_SLATE_ELIGIBILITY,A8_PORTFOLIO)",
        },
    ) or []
    completed = {row["stage_id"] for row in required if row.get("status") == "COMPLETE"}
    missing = [
        stage for stage in ("A0_CONSTITUTION_SEALED", "A1_SLATE_ROUTED", "A7_SLATE_ELIGIBILITY", "A8_PORTFOLIO")
        if stage not in completed
    ]
    if missing:
        raise HTTPException(status_code=409, detail={"code": "FINAL_REPORT_PREREQUISITES_INCOMPLETE", "missing": missing})

    submitted_at = now_iso()
    row = {
        "run_id": req.run_id,
        "protocol_id": MOTHER_PROTOCOL_ID,
        "stage_id": "FINAL_REPORT",
        "status": "COMPLETE",
        "payload": req.report,
        "evidence_ids": [],
        "output_text": req.document_ref or "MOTHER_V3_FINAL_REPORT",
        "submitted_at": submitted_at,
    }

    # The database MOTHER V3 trigger is the source of truth. It checks the
    # report against the real slate, A7 slate state, A8 portfolio, candidates,
    # probabilities and ticket evaluations before this row can exist.
    saved = await sb(
        "POST",
        "protocol_run_state",
        params={"on_conflict": "run_id,protocol_id,stage_id"},
        payload=row,
        prefer="resolution=merge-duplicates,return=representation",
    )

    report_hash = stable_hash(req.report)
    previous_hash = await latest_trace_hash(req.run_id)
    event = {
        "event_id": f"EVT-{uuid4().hex}",
        "run_id": req.run_id,
        "game_id": None,
        "task_id": "FINAL_REPORT",
        "event_type": "MOTHER_FINAL_REPORT_VALIDATED",
        "status": "COMPLETE",
        "occurred_at": submitted_at,
        "input_hash": report_hash,
        "output_hash": stable_hash(saved or row),
        "tool_name": "kernel.mother_report",
        "evidence_ids": [],
        "prev_event_hash": previous_hash,
        "details": {
            "protocol_id": MOTHER_PROTOCOL_ID,
            "mother_document_sha256": MOTHER_DOCUMENT_SHA256,
            "document_ref": req.document_ref,
        },
    }
    event["event_hash"] = stable_hash(event)
    await sb("POST", "trace_events", payload=event, prefer="return=minimal")

    return {
        "accepted": True,
        "run_id": req.run_id,
        "stage_id": "FINAL_REPORT",
        "report_hash": report_hash,
        "document_ref": req.document_ref,
        "close_authorized": True,
        "validation_source": "MOTHER_V3_DB_GATES",
    }
