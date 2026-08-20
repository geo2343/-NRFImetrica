from __future__ import annotations

import hashlib
import ipaddress
import os
from typing import Any
from urllib.parse import urlparse
from uuid import uuid4

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from kernel.core import KERNEL_VERSION, MOTHER_PROTOCOL_ID, SYSTEM_VERSION, stable_hash

SUPABASE_URL = os.getenv("SUPABASE_URL", "").rstrip("/")
SUPABASE_SECRET_KEY = os.getenv("SUPABASE_SECRET_KEY", "") or os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")

app = FastAPI(title="@NRFImetrica Sports Research Chain", version="1.8")


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
    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.request(
            method,
            f"{SUPABASE_URL}/rest/v1/{table}",
            headers=_headers(prefer),
            params=params,
            json=payload,
        )
    if response.status_code >= 300:
        body = response.text[:1200]
        raise HTTPException(
            status_code=422 if "23514" in body else 502,
            detail=f"SUPABASE_{table}_{response.status_code}:{body}",
        )
    return response.json() if response.content else None


async def require_game(run_id: str, game_id: str) -> dict[str, Any]:
    rows = await sb(
        "GET",
        "games",
        params={"select": "*", "run_id": f"eq.{run_id}", "game_id": f"eq.{game_id}", "limit": "1"},
    ) or []
    if not rows:
        raise HTTPException(status_code=404, detail="GAME_NOT_REGISTERED_IN_RUN")
    return rows[0]


def sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def validate_public_http_url(url: str) -> None:
    parsed = urlparse(url)
    if parsed.scheme not in {"http", "https"} or not parsed.hostname:
        raise HTTPException(status_code=422, detail="SOURCE_URL_MUST_BE_HTTP_OR_HTTPS")
    host = parsed.hostname.lower()
    if host in {"localhost", "localhost.localdomain"} or host.endswith(".local"):
        raise HTTPException(status_code=422, detail="PRIVATE_SOURCE_HOST_FORBIDDEN")
    try:
        ip = ipaddress.ip_address(host)
    except ValueError:
        return
    if ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_multicast or ip.is_reserved:
        raise HTTPException(status_code=422, detail="PRIVATE_SOURCE_IP_FORBIDDEN")


class SourceFetchRequest(BaseModel):
    run_id: str
    game_id: str
    query_text: str
    query_scope: str = "SPORTS_REASONING"
    source_url: str
    source_ref: str | None = None
    original_publisher: str | None = None
    source_published_at: str | None = None
    material_new_info: bool | None = None
    max_chars: int = Field(default=120000, ge=1000, le=500000)


class EvidenceRequest(BaseModel):
    run_id: str
    game_id: str
    tool_event_id: str
    tool_name: str = "KERNEL_HTTP_FETCH"
    source_ref: str | None = None
    source_url: str | None = None
    original_publisher: str | None = None
    payload: Any
    snapshot_text: str
    snapshot_drive_file_id: str
    snapshot_drive_hash: str
    factual_extract_text: str
    claims_extracted: list[str] = Field(default_factory=list)


class PacketCreateRequest(BaseModel):
    run_id: str
    game_id: str
    version: int = 1
    previous_packet_hash: str | None = None
    complexity_tier: str


class ClaimRequest(BaseModel):
    packet_id: str
    claim_type: str
    claim_text: str
    evidence_ids: list[str] = Field(default_factory=list)


class PacketFinalizeRequest(BaseModel):
    status: str
    sports_verdict: str | None = None
    evidence_ids: list[str] = Field(default_factory=list)
    lineup_status: str = "PROJECTED"
    projected_analysis: dict[str, Any] = Field(default_factory=dict)
    confirmed_analysis: dict[str, Any] = Field(default_factory=dict)
    top_1st_analysis: dict[str, Any] = Field(default_factory=dict)
    bottom_1st_analysis: dict[str, Any] = Field(default_factory=dict)
    central_nrfi_case: dict[str, Any] = Field(default_factory=dict)
    best_yrfi_rival: dict[str, Any] = Field(default_factory=dict)
    strongest_counterevidence: dict[str, Any] = Field(default_factory=dict)
    falsification_attempts: list[dict[str, Any]] = Field(default_factory=list)
    causal_clusters: list[dict[str, Any]] = Field(default_factory=list)
    dominant_factor: dict[str, Any] = Field(default_factory=dict)
    governing_uncertainty: dict[str, Any] = Field(default_factory=dict)
    what_would_change: dict[str, Any] = Field(default_factory=dict)
    why_research_stopped: str | None = None
    why_stop_detail: str | None = None
    dimensions_covered: list[str] = Field(default_factory=list)
    dimensions_missing: list[Any] = Field(default_factory=list)
    research_depth_justification: str | None = None
    known_unknowns: list[Any] = Field(default_factory=list)
    full_game_proxies: list[dict[str, Any]] = Field(default_factory=list)
    packet_payload: dict[str, Any] = Field(default_factory=dict)
    first_inning_factors: list[dict[str, Any]] = Field(default_factory=list)
    unresolved_contradictions: list[dict[str, Any]] = Field(default_factory=list)
    adversarial_balance: dict[str, Any] = Field(default_factory=dict)
    saturation_reached: bool = False
    cognitive_contract_version: str = "COGNITIVE-1.0"
    press_intake_id: str | None = None
    provisional_representation: dict[str, Any] = Field(default_factory=dict)
    autonomous_questions: list[dict[str, Any]] = Field(default_factory=list)
    second_pass_review: dict[str, Any] = Field(default_factory=dict)
    causal_bottlenecks: list[dict[str, Any]] = Field(default_factory=list)
    directional_bias_check: dict[str, Any] = Field(default_factory=dict)
    epistemic_compression: dict[str, Any] = Field(default_factory=dict)
    semantic_reclassifications: list[str] = Field(default_factory=list)
    press_disposition_summary: dict[str, Any] = Field(default_factory=dict)


class DriveArtifactRequest(BaseModel):
    run_id: str
    game_id: str | None = None
    packet_id: str | None = None
    artifact_type: str
    drive_file_id: str
    content_hash: str
    verification_method: str = "GOOGLE_DRIVE_CONNECTOR_READBACK"


class GameArtifactRequest(BaseModel):
    run_id: str
    game_id: str
    artifact_kind: str
    drive_file_id: str
    content_hash: str | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)


class ProcessAuditRequest(BaseModel):
    packet_id: str
    clone_risk: str = "NOT_EVALUATED"
    findings: dict[str, Any] = Field(default_factory=dict)


@app.get("/")
async def root():
    return {
        "service": "@NRFImetrica Sports Research Chain",
        "system_version": SYSTEM_VERSION,
        "kernel_version": KERNEL_VERSION,
        "protocol_id": MOTHER_PROTOCOL_ID,
        "packet_version": "2.0",
        "semantic_custody": "SEMANTIC-CUSTODY-1.0",
        "process_auditor": "KERNEL_PROCESS_AUDITOR_0.3",
        "query_before_event": True,
        "trusted_retrieval_mode": "KERNEL_SERVER_FETCH",
        "rule": "NO_CLAIM_OF_RESEARCH_WITHOUT_PHYSICAL_CHAIN_OF_CUSTODY",
    }


@app.post("/fetch-source")
async def fetch_source(req: SourceFetchRequest):
    """Fetch the source inside the Kernel runtime and persist query + tool event.

    The caller may discover URLs elsewhere, but only content fetched here can become
    kernel-attested SPORTS_REASONING evidence.
    """
    await require_game(req.run_id, req.game_id)
    validate_public_http_url(req.source_url)

    query_rows = await sb(
        "POST",
        "research_kernel_queries",
        payload={
            "run_id": req.run_id,
            "game_id": req.game_id,
            "query_text": req.query_text,
            "query_scope": req.query_scope,
            "query_id": "SET_BY_DB",
            "query_hash": "SET_BY_DB",
            "requested_at": "1970-01-01T00:00:00Z",
        },
        prefer="return=representation",
    ) or []
    if not query_rows:
        raise HTTPException(status_code=502, detail="KERNEL_QUERY_NOT_PERSISTED")
    query = query_rows[0]

    async with httpx.AsyncClient(timeout=35.0, follow_redirects=True) as client:
        response = await client.get(
            req.source_url,
            headers={"User-Agent": "NRFImetrica-Kernel/1.8 (+sports-research)"},
        )
    if response.status_code >= 400:
        raise HTTPException(status_code=502, detail=f"SOURCE_FETCH_HTTP_{response.status_code}")

    snapshot_text = response.text[: req.max_chars]
    request_payload = {"url": req.source_url, "query": req.query_text, "scope": req.query_scope}
    response_hash = sha256_text(snapshot_text)

    event_rows = await sb(
        "POST",
        "research_tool_events",
        payload={
            "event_id": "SET_BY_DB",
            "run_id": req.run_id,
            "game_id": req.game_id,
            "tool_name": "KERNEL_HTTP_FETCH",
            "operation": "GET",
            "request_hash": stable_hash(request_payload),
            "response_hash": response_hash,
            "source_ref": req.source_ref,
            "source_url": str(response.url),
            "material_new_info": req.material_new_info,
            "kernel_query_id": query["query_id"],
            "retrieval_mode": "KERNEL_SERVER_FETCH",
            "source_published_at": req.source_published_at,
            "data_available_since_kernel": req.source_published_at,
        },
        prefer="return=representation",
    ) or []
    if not event_rows:
        raise HTTPException(status_code=502, detail="TOOL_EVENT_NOT_PERSISTED")

    return {
        "query": query,
        "tool_event": event_rows[0],
        "source_url": str(response.url),
        "http_status": response.status_code,
        "snapshot_text": snapshot_text,
        "snapshot_hash": response_hash,
        "original_publisher": req.original_publisher,
    }


@app.post("/evidence")
async def register_evidence(req: EvidenceRequest):
    await require_game(req.run_id, req.game_id)
    event = await sb(
        "GET",
        "research_tool_events",
        params={"select": "*", "event_id": f"eq.{req.tool_event_id}", "limit": "1"},
    ) or []
    if not event:
        raise HTTPException(status_code=422, detail="TOOL_EVENT_NOT_FOUND")
    if not event[0].get("kernel_attested") or event[0].get("retrieval_mode") not in {
        "KERNEL_SERVER_FETCH",
        "KERNEL_PROVIDER_FETCH",
    }:
        raise HTTPException(status_code=422, detail="TOOL_EVENT_NOT_KERNEL_ATTESTED")

    snapshot_hash = sha256_text(req.snapshot_text)
    if req.snapshot_drive_hash != snapshot_hash:
        raise HTTPException(status_code=422, detail="SNAPSHOT_DRIVE_HASH_MUST_MATCH_CAPTURED_TEXT_HASH")

    row = {
        "evidence_id": "SET_BY_DB",
        "run_id": req.run_id,
        "game_id": req.game_id,
        "tool_name": req.tool_name,
        "source_ref": req.source_ref,
        "source_url": req.source_url or event[0].get("source_url"),
        "input_hash": event[0].get("request_hash"),
        "payload_hash": stable_hash(req.payload),
        "payload": req.payload,
        "tool_event_id": req.tool_event_id,
        "original_publisher": req.original_publisher,
        "snapshot_hash": snapshot_hash,
        "snapshot_drive_file_id": req.snapshot_drive_file_id,
        "snapshot_drive_hash": req.snapshot_drive_hash,
        "claims_extracted": req.claims_extracted,
        "evidence_scope": "SPORTS_REASONING",
        "factual_extract_text": req.factual_extract_text,
    }
    saved = await sb("POST", "evidence", payload=row, prefer="return=representation") or []
    if not saved:
        raise HTTPException(status_code=502, detail="EVIDENCE_NOT_PERSISTED")
    evidence = saved[0]
    await sb(
        "PATCH",
        "research_tool_events",
        params={"event_id": f"eq.{req.tool_event_id}"},
        payload={"evidence_id": evidence["evidence_id"]},
        prefer="return=minimal",
    )
    return evidence


@app.post("/packets")
async def create_packet(req: PacketCreateRequest):
    await require_game(req.run_id, req.game_id)
    packet_id = f"SRP-{req.run_id}-{req.game_id}-v{req.version}"
    row = {
        "packet_id": packet_id,
        "run_id": req.run_id,
        "game_id": req.game_id,
        "protocol_id": MOTHER_PROTOCOL_ID,
        "version": req.version,
        "previous_packet_hash": req.previous_packet_hash,
        "complexity_tier": req.complexity_tier.upper(),
        "status": "IN_PROGRESS",
        "cognitive_contract_version": "COGNITIVE-1.0",
    }
    saved = await sb("POST", "sports_reasoning_packets", payload=row, prefer="return=representation")
    return (saved or [row])[0]


@app.post("/claims")
async def add_claim(req: ClaimRequest):
    row = {
        "claim_id": f"CLM-{uuid4().hex}",
        "packet_id": req.packet_id,
        "run_id": "SET_BY_DB",
        "game_id": "SET_BY_DB",
        "claim_type": req.claim_type.upper(),
        "claim_text": req.claim_text,
        "evidence_ids": req.evidence_ids,
    }
    saved = await sb("POST", "sports_reasoning_claims", payload=row, prefer="return=representation")
    return (saved or [row])[0]


@app.patch("/packets/{packet_id}/finalize")
async def finalize_packet(packet_id: str, req: PacketFinalizeRequest):
    payload = req.model_dump()
    payload["status"] = req.status.upper()
    payload["lineup_status"] = req.lineup_status.upper()
    if req.sports_verdict:
        payload["sports_verdict"] = req.sports_verdict.upper()
    saved = await sb(
        "PATCH",
        "sports_reasoning_packets",
        params={"packet_id": f"eq.{packet_id}"},
        payload=payload,
        prefer="return=representation",
    )
    if not saved:
        raise HTTPException(status_code=404, detail="PACKET_NOT_FOUND")
    return saved[0]


@app.post("/drive-artifacts")
async def register_drive_artifact(req: DriveArtifactRequest):
    row = {
        "artifact_id": f"DRV-{uuid4().hex}",
        "run_id": req.run_id,
        "game_id": req.game_id,
        "packet_id": req.packet_id,
        "artifact_type": req.artifact_type.upper(),
        "drive_file_id": req.drive_file_id,
        "content_hash": req.content_hash,
        "verification_method": req.verification_method,
        "immutable": True,
    }
    saved = await sb("POST", "research_drive_artifacts", payload=row, prefer="return=representation")
    return (saved or [row])[0]


@app.post("/game-artifacts")
async def register_game_artifact(req: GameArtifactRequest):
    await require_game(req.run_id, req.game_id)
    row = {
        "run_id": req.run_id,
        "game_id": req.game_id,
        "artifact_kind": req.artifact_kind.upper(),
        "drive_file_id": req.drive_file_id,
        "content_hash": req.content_hash,
        "verified_at": "now()",
        "metadata": req.metadata,
    }
    # PostgREST cannot interpret now() as a timestamp literal; omit and let caller
    # provide actual readback by immediately patching with the returned server time.
    row.pop("verified_at")
    saved = await sb("POST", "nrfimetrica_game_artifacts", payload=row, prefer="return=representation") or []
    if not saved:
        raise HTTPException(status_code=502, detail="GAME_ARTIFACT_NOT_PERSISTED")
    artifact = saved[0]
    patched = await sb(
        "PATCH",
        "nrfimetrica_game_artifacts",
        params={"artifact_id": f"eq.{artifact['artifact_id']}"},
        payload={"verified_at": artifact.get("created_at")},
        prefer="return=representation",
    ) or []
    return (patched or [artifact])[0]


@app.post("/process-audits")
async def register_process_audit(req: ProcessAuditRequest):
    row = {
        "audit_id": f"PAUD-{uuid4().hex}",
        "packet_id": req.packet_id,
        "run_id": "SET_BY_DB",
        "game_id": "SET_BY_DB",
        "auditor_id": "KERNEL_PROCESS_AUDITOR_0.3",
        "structural_pass": False,
        "temporal_pass": False,
        "evidence_pass": False,
        "falsification_pass": False,
        "independence_pass": False,
        "semantic_custody_pass": False,
        "adversarial_balance_pass": False,
        "adaptive_depth_pass": False,
        "first_inning_materiality_pass": False,
        "clone_risk": req.clone_risk.upper(),
        "findings": req.findings,
        "status": "FAIL",
    }
    saved = await sb("POST", "sports_process_audits", payload=row, prefer="return=representation")
    return (saved or [row])[0]


@app.post("/runs/{run_id}/seal-sports-slate")
async def seal_sports_slate(run_id: str):
    games = await sb("GET", "games", params={"select": "game_id", "run_id": f"eq.{run_id}"}) or []
    total = len(games)
    packets = await sb(
        "GET",
        "sports_reasoning_packets",
        params={"select": "*", "run_id": f"eq.{run_id}", "order": "game_id.asc,version.desc"},
    ) or []
    latest: dict[str, dict[str, Any]] = {}
    for row in packets:
        latest.setdefault(str(row["game_id"]), row)
    terminal = {
        "ANALYSIS_COMPLETE",
        "RESEARCH_INCOMPLETE",
        "INFORMATION_UNAVAILABLE",
        "NOT_EXECUTABLE",
        "WITHDRAWN_POST_FREEZE",
        "PROCESS_FAIL",
    }
    terminal_rows = [
        p
        for p in latest.values()
        if p.get("status") in terminal
        and p.get("drive_verified_at")
        and p.get("drive_content_hash") == p.get("packet_hash")
    ]
    complete = [p for p in terminal_rows if p.get("status") == "ANALYSIS_COMPLETE" and p.get("process_audit_status") == "PASS"]
    incomplete = [p for p in terminal_rows if p.get("status") == "RESEARCH_INCOMPLETE"]
    unavailable = [p for p in terminal_rows if p.get("status") in {"INFORMATION_UNAVAILABLE", "NOT_EXECUTABLE", "WITHDRAWN_POST_FREEZE"}]
    failed = [p for p in terminal_rows if p.get("status") == "PROCESS_FAIL" or p.get("process_audit_status") == "FAIL"]
    payload = {
        "total_games": total,
        "terminal_packet_count": len(terminal_rows),
        "analysis_complete_count": len(complete),
        "research_incomplete_count": len(incomplete),
        "information_unavailable_count": len(unavailable),
        "process_fail_count": len(failed),
        "analysis_statement": f"{len(complete)}/{total} ANALISIS_COMPLETOS",
    }
    row = {
        "run_id": run_id,
        "protocol_id": MOTHER_PROTOCOL_ID,
        "stage_id": "SPORTS_REASONING_SLATE",
        "status": "COMPLETE",
        "payload": payload,
        "evidence_ids": [],
        "output_text": payload["analysis_statement"],
    }
    saved = await sb(
        "POST",
        "protocol_run_state",
        params={"on_conflict": "run_id,protocol_id,stage_id"},
        payload=row,
        prefer="resolution=merge-duplicates,return=representation",
    )
    return (saved or [row])[0]


@app.get("/runs/{run_id}/state")
async def run_research_state(run_id: str):
    run = await sb("GET", "runs", params={"select": "run_id,status,tool_call_count,metadata", "run_id": f"eq.{run_id}", "limit": "1"}) or []
    packets = await sb("GET", "sports_reasoning_packets", params={"select": "*", "run_id": f"eq.{run_id}", "order": "game_id.asc,version.desc"}) or []
    queries = await sb("GET", "research_kernel_queries", params={"select": "*", "run_id": f"eq.{run_id}", "order": "requested_at.asc"}) or []
    tool_events = await sb("GET", "research_tool_events", params={"select": "*", "run_id": f"eq.{run_id}", "order": "occurred_at.asc"}) or []
    process_audits = await sb("GET", "sports_process_audits", params={"select": "*", "run_id": f"eq.{run_id}", "order": "created_at.asc"}) or []
    drive_artifacts = await sb("GET", "research_drive_artifacts", params={"select": "*", "run_id": f"eq.{run_id}", "order": "verified_at.asc"}) or []
    game_artifacts = await sb("GET", "nrfimetrica_game_artifacts", params={"select": "*", "run_id": f"eq.{run_id}", "order": "created_at.asc"}) or []
    readiness = await sb("GET", "nrfimetrica_sports_reasoning_readiness_v18", params={"select": "*", "run_id": f"eq.{run_id}"}) or []
    return {
        "run": run[0] if run else None,
        "queries": queries,
        "packets": packets,
        "tool_events": tool_events,
        "process_audits": process_audits,
        "drive_artifacts": drive_artifacts,
        "game_artifacts": game_artifacts,
        "sports_readiness": readiness,
    }
