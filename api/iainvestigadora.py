from __future__ import annotations

import os
from datetime import date
from typing import Any
from uuid import uuid4

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from kernel.iainvestigadora import (
    AGENT_ID, AGENT_VERSION, KERNEL_VERSION, PATCH_SHA256, PHASE_ORDER,
    PROTOCOL_ID, REAL_MONEY_AUTHORITY, SYSTEM_VERSION,
    IAInvestigadoraViolation, validate_phase_submission,
)

SUPABASE_URL = os.getenv("SUPABASE_URL", "").rstrip("/")
SUPABASE_SECRET_KEY = os.getenv("SUPABASE_SECRET_KEY", "") or os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
app = FastAPI(title="@iainvestigadora Connected Kernel", version="1.4")


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
        response = await client.request(f"{SUPABASE_URL}/rest/v1/{table}", method=method, headers=_headers(prefer), params=params, json=payload)
    if response.status_code >= 300:
        code = 422 if "23514" in response.text else 502
        raise HTTPException(status_code=code, detail=f"SUPABASE_{table}_{response.status_code}:{response.text[:900]}")
    return response.json() if response.content else None


async def rpc(name: str, payload: dict[str, Any]) -> Any:
    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(f"{SUPABASE_URL}/rest/v1/rpc/{name}", headers=_headers(), json=payload)
    if response.status_code >= 300:
        code = 422 if "23514" in response.text else 502
        raise HTTPException(status_code=code, detail=f"SUPABASE_RPC_{name}_{response.status_code}:{response.text[:900]}")
    return response.json() if response.content else None


class RunStart(BaseModel):
    run_date: str
    game_id: str
    away_team: str
    home_team: str
    scheduled_start: str
    cutoff_at: str | None = None
    venue: str | None = None
    target_source: str = "USER_EXPLICIT_TARGET"
    metadata: dict[str, Any] = Field(default_factory=dict)


class KernelQueryCreate(BaseModel):
    run_id: str
    game_id: str
    query_text: str
    query_scope: str = "DISCOVERY"


class ToolEventCreate(BaseModel):
    run_id: str
    game_id: str
    kernel_query_id: str
    tool_name: str
    operation: str
    retrieval_mode: str
    request_hash: str | None = None
    response_hash: str
    source_ref: str | None = None
    source_url: str | None = None
    source_published_at: str | None = None
    data_available_since_kernel: str | None = None
    material_new_info: bool | None = None


class EvidenceCreate(BaseModel):
    run_id: str
    game_id: str
    tool_event_id: str
    tool_name: str
    source_ref: str | None = None
    source_url: str | None = None
    original_publisher: str | None = None
    payload: dict[str, Any]
    snapshot_hash: str
    factual_extract_text: str
    claims_extracted: list[str] = Field(default_factory=list)


class PhaseSubmit(BaseModel):
    run_id: str
    game_id: str
    phase_id: str
    status: str = "COMPLETE"
    payload: dict[str, Any]
    evidence_ids: list[str] = Field(default_factory=list)
    source_calls: list[dict[str, Any]] = Field(default_factory=list)
    documents_analyzed: list[str] = Field(default_factory=list)
    output_text: str = ""
    skip_reason: str | None = None


class ReportDocumentCreate(BaseModel):
    run_id: str
    drive_file_id: str
    document_title: str


class ReportPrepare(BaseModel):
    run_id: str
    drive_file_id: str
    report_hash: str
    chat_report_complete: bool = True


class DriveArtifactCreate(BaseModel):
    run_id: str
    game_id: str
    drive_file_id: str
    content_hash: str


@app.get("/")
async def root():
    return {
        "agent_id": AGENT_ID,
        "agent_version": AGENT_VERSION,
        "system_version": SYSTEM_VERSION,
        "kernel_version": KERNEL_VERSION,
        "protocol_id": PROTOCOL_ID,
        "patch_sha256": PATCH_SHA256,
        "target_scope": "ONE_EXPLICIT_MLB_GAME_PER_RUN",
        "workflow": list(PHASE_ORDER),
        "handoff_destination": "@ianalista",
        "real_money_authority": REAL_MONEY_AUTHORITY,
    }


@app.get("/health")
async def health():
    rows = await sb("GET", "agent_registry", params={"select":"agent_id,agent_version,status,protocol_id,kernel_version,metadata", "agent_id":f"eq.{AGENT_ID}", "limit":"1"}) or []
    ok = bool(rows and rows[0].get("status") == "ACTIVE" and rows[0].get("protocol_id") == PROTOCOL_ID)
    return {"ok": ok, "agent": rows[0] if rows else None}


@app.post("/runs/start")
async def start_run(req: RunStart):
    try:
        date.fromisoformat(req.run_date)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail="RUN_DATE_MUST_BE_YYYY_MM_DD") from exc
    if not req.game_id.strip() or not req.away_team.strip() or not req.home_team.strip():
        raise HTTPException(status_code=422, detail="EXPLICIT_GAME_ID_AND_TEAMS_REQUIRED")
    run_id = f"IAINV-{req.run_date.replace('-', '')}-{uuid4().hex[:10]}"
    run_row = {
        "run_id": run_id,
        "system_version": SYSTEM_VERSION,
        "run_date": req.run_date,
        "status": "OPEN",
        "mode": "CONTROLLED_REAL",
        "metadata": {**req.metadata, "target_source": req.target_source, "requested_game_id": req.game_id},
    }
    saved_run = await sb("POST", "runs", payload=run_row, prefer="return=representation")
    game_row = {
        "run_id": run_id,
        "game_id": req.game_id,
        "away_team": req.away_team,
        "home_team": req.home_team,
        "scheduled_start": req.scheduled_start,
        "cutoff_at": req.cutoff_at or req.scheduled_start,
        "status": "PREGAME_TARGET",
        "decision_reason": {"venue": req.venue, "target_source": req.target_source},
    }
    try:
        saved_game = await sb("POST", "games", payload=game_row, prefer="return=representation")
    except Exception:
        await sb("DELETE", "runs", params={"run_id": f"eq.{run_id}"}, prefer="return=minimal")
        raise
    return {"run": (saved_run or [run_row])[0], "target": (saved_game or [game_row])[0]}


@app.post("/kernel-queries")
async def create_kernel_query(req: KernelQueryCreate):
    if req.query_scope not in {"DISCOVERY","SOURCE_EXTRACTION","STRUCTURED_PROVIDER","REVALIDATION"}:
        raise HTTPException(status_code=422, detail="INVALID_QUERY_SCOPE")
    row = {"query_id":"PLACEHOLDER", "run_id":req.run_id, "game_id":req.game_id, "query_text":req.query_text, "query_scope":req.query_scope, "status":"REQUESTED", "query_hash":"PLACEHOLDER", "requested_at":"1970-01-01T00:00:00Z"}
    saved = await sb("POST", "research_kernel_queries", payload=row, prefer="return=representation")
    return (saved or [row])[0]


@app.post("/tool-events")
async def create_tool_event(req: ToolEventCreate):
    row = {
        "event_id":"PLACEHOLDER", "run_id":req.run_id, "game_id":req.game_id,
        "tool_name":req.tool_name, "operation":req.operation.upper(),
        "request_hash":req.request_hash, "response_hash":req.response_hash,
        "source_ref":req.source_ref, "source_url":req.source_url,
        "material_new_info":req.material_new_info, "kernel_query_id":req.kernel_query_id,
        "retrieval_mode":req.retrieval_mode, "kernel_attested":True,
        "source_published_at":req.source_published_at,
        "data_available_since_kernel":req.data_available_since_kernel,
        "custody_version":"SEMANTIC-CUSTODY-1.0",
    }
    saved = await sb("POST", "research_tool_events", payload=row, prefer="return=representation")
    return (saved or [row])[0]


@app.post("/evidence")
async def create_evidence(req: EvidenceCreate):
    if len(req.factual_extract_text.strip()) < 8:
        raise HTTPException(status_code=422, detail="FACTUAL_EXTRACT_REQUIRED")
    row = {
        "evidence_id":"PLACEHOLDER", "run_id":req.run_id, "game_id":req.game_id,
        "tool_name":req.tool_name, "source_ref":req.source_ref, "source_url":req.source_url,
        "retrieved_at":"1970-01-01T00:00:00Z", "payload_hash":"PLACEHOLDER",
        "payload":req.payload, "tool_event_id":req.tool_event_id,
        "original_publisher":req.original_publisher, "snapshot_hash":req.snapshot_hash,
        "claims_extracted":req.claims_extracted, "evidence_scope":"SPORTS_REASONING",
        "factual_extract_text":req.factual_extract_text, "kernel_attested":True,
        "custody_version":"SEMANTIC-CUSTODY-1.0",
    }
    saved = await sb("POST", "evidence", payload=row, prefer="return=representation")
    return (saved or [row])[0]


@app.post("/phases")
async def submit_phase(req: PhaseSubmit):
    rows = await sb("GET", "protocol_phase_state", params={"select":"phase_id,status", "run_id":f"eq.{req.run_id}", "game_id":f"eq.{req.game_id}", "protocol_id":f"eq.{PROTOCOL_ID}"}) or []
    completed = {r["phase_id"] for r in rows if r.get("status") in {"COMPLETE","SKIPPED_NOT_TRIGGERED"}}
    try:
        validate_phase_submission(phase_id=req.phase_id, status=req.status, game_id=req.game_id, payload=req.payload, completed=completed)
    except IAInvestigadoraViolation as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    row = {
        "run_id":req.run_id, "game_id":req.game_id, "protocol_id":PROTOCOL_ID,
        "phase_id":req.phase_id, "status":req.status, "payload":req.payload,
        "evidence_ids":req.evidence_ids, "source_calls":req.source_calls,
        "documents_analyzed":req.documents_analyzed, "output_text":req.output_text,
        "skip_reason":req.skip_reason,
    }
    saved = await sb("POST", "protocol_phase_state", payload=row, prefer="return=representation")
    return (saved or [row])[0]


@app.post("/report-document")
async def register_report_document(req: ReportDocumentCreate):
    runs = await sb("GET", "runs", params={"select":"invocation_id", "run_id":f"eq.{req.run_id}", "limit":"1"}) or []
    if not runs:
        raise HTTPException(status_code=404, detail="RUN_NOT_FOUND")
    row = {"report_document_id":f"IAINV-RPT-{uuid4().hex}", "run_id":req.run_id, "invocation_id":runs[0].get("invocation_id") or "SET_BY_DB", "drive_file_id":req.drive_file_id, "document_title":req.document_title, "status":"DRAFT"}
    saved = await sb("POST", "run_report_documents", payload=row, prefer="return=representation")
    return (saved or [row])[0]


@app.post("/final-report/prepare")
async def prepare_final_report(req: ReportPrepare):
    return await rpc("iainv_prepare_final_report", {"p_run_id":req.run_id,"p_drive_file_id":req.drive_file_id,"p_report_hash":req.report_hash,"p_chat_report_complete":req.chat_report_complete})


@app.post("/final-report/artifact")
async def register_final_artifact(req: DriveArtifactCreate):
    row = {"artifact_id":f"IAINV-DRV-{uuid4().hex}", "run_id":req.run_id, "game_id":req.game_id, "packet_id":None, "artifact_type":"IAINV_FINAL_REPORT", "drive_file_id":req.drive_file_id, "content_hash":req.content_hash, "verification_method":"GOOGLE_DRIVE_CONNECTOR_READBACK", "immutable":True}
    saved = await sb("POST", "research_drive_artifacts", payload=row, prefer="return=representation")
    return (saved or [row])[0]


@app.get("/runs/{run_id}/audit")
async def audit(run_id: str):
    return await rpc("iainv_derive_audit", {"p_run_id":run_id})


@app.post("/runs/{run_id}/close")
async def close(run_id: str):
    return await rpc("iainv_close_run", {"p_run_id":run_id})


@app.get("/runs/{run_id}/state")
async def state(run_id: str):
    run = await sb("GET", "runs", params={"select":"*", "run_id":f"eq.{run_id}", "limit":"1"}) or []
    games = await sb("GET", "games", params={"select":"*", "run_id":f"eq.{run_id}"}) or []
    phases = await sb("GET", "protocol_phase_state", params={"select":"*", "run_id":f"eq.{run_id}", "protocol_id":f"eq.{PROTOCOL_ID}", "order":"submitted_at.asc"}) or []
    stages = await sb("GET", "protocol_run_state", params={"select":"*", "run_id":f"eq.{run_id}", "protocol_id":f"eq.{PROTOCOL_ID}", "order":"submitted_at.asc"}) or []
    reports = await sb("GET", "run_report_documents", params={"select":"*", "run_id":f"eq.{run_id}"}) or []
    return {"run":run[0] if run else None,"targets":games,"phases":phases,"stages":stages,"reports":reports}
