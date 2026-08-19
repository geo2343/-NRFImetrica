from __future__ import annotations

import os
from typing import Any
from uuid import uuid4

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from kernel.core import now_iso, stable_hash
from kernel.report import ReportViolation, validate_final_report

SUPABASE_URL = os.getenv("SUPABASE_URL", "").rstrip("/")
SUPABASE_SECRET_KEY = (
    os.getenv("SUPABASE_SECRET_KEY", "")
    or os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
)

app = FastAPI(title="@NRFImetrica Final Report Gate", version="1.0")


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
        params={"select": "event_hash,occurred_at", "run_id": f"eq.{run_id}", "order": "occurred_at.desc", "limit": "1"},
    ) or []
    return rows[0]["event_hash"] if rows else None


class ReportRequest(BaseModel):
    run_id: str
    report: dict[str, Any] = Field(default_factory=dict)
    document_ref: str | None = None


@app.post("/")
async def validate_report(req: ReportRequest):
    runs = await sb("GET", "runs", params={"select": "run_id,status,mode,started_at", "run_id": f"eq.{req.run_id}", "limit": "1"}) or []
    if not runs:
        raise HTTPException(status_code=404, detail="RUN_NOT_FOUND")

    games = await sb("GET", "games", params={"select": "*", "run_id": f"eq.{req.run_id}", "order": "scheduled_start.asc"}) or []
    decisions = await sb("GET", "decisions", params={"select": "*", "run_id": f"eq.{req.run_id}", "order": "created_at.asc"}) or []
    recoveries = await sb("GET", "recoveries", params={"select": "*", "run_id": f"eq.{req.run_id}", "order": "occurred_at.asc"}) or []

    try:
        expected = validate_final_report(
            report=req.report,
            games=games,
            decisions=decisions,
            recoveries=recoveries,
        )
    except ReportViolation as exc:
        raise HTTPException(status_code=422, detail=str(exc))

    report_hash = stable_hash(req.report)
    state_row = {
        "run_id": req.run_id,
        "status": "COMPLETE",
        "report_hash": report_hash,
        "document_ref": req.document_ref,
        "validated_summary": expected,
        "final_verdict_hash": stable_hash(req.report.get("final_verdict") or {}),
        "validated_at": now_iso(),
    }
    await sb(
        "POST",
        "run_report_state",
        params={"on_conflict": "run_id"},
        payload=state_row,
        prefer="resolution=merge-duplicates,return=minimal",
    )

    previous_hash = await latest_trace_hash(req.run_id)
    event = {
        "event_id": f"EVT-{uuid4().hex}",
        "run_id": req.run_id,
        "game_id": None,
        "task_id": "FINAL_REPORT_GATE",
        "event_type": "FINAL_REPORT_VALIDATED",
        "status": "COMPLETE",
        "occurred_at": now_iso(),
        "input_hash": report_hash,
        "output_hash": stable_hash(expected),
        "tool_name": "kernel.report",
        "evidence_ids": [],
        "prev_event_hash": previous_hash,
        "details": {"document_ref": req.document_ref, "summary": expected},
    }
    event["event_hash"] = stable_hash(event)
    await sb("POST", "trace_events", payload=event, prefer="return=minimal")

    return {
        "accepted": True,
        "report_hash": report_hash,
        "summary": expected,
        "close_authorized": True,
    }
