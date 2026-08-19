from __future__ import annotations

import os
from typing import Any
from uuid import uuid4

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from kernel.core import KERNEL_VERSION, MOTHER_PROTOCOL_ID, SYSTEM_VERSION, stable_hash

SUPABASE_URL = os.getenv('SUPABASE_URL', '').rstrip('/')
SUPABASE_SECRET_KEY = os.getenv('SUPABASE_SECRET_KEY', '') or os.getenv('SUPABASE_SERVICE_ROLE_KEY', '')

app = FastAPI(title='@NRFImetrica Sports Research Chain', version='1.0')


def _headers(prefer: str | None = None) -> dict[str, str]:
    if not SUPABASE_URL or not SUPABASE_SECRET_KEY:
        raise HTTPException(status_code=503, detail='SUPABASE_RUNTIME_NOT_CONFIGURED')
    headers = {'apikey': SUPABASE_SECRET_KEY, 'Content-Type': 'application/json'}
    if SUPABASE_SECRET_KEY.count('.') == 2:
        headers['Authorization'] = f'Bearer {SUPABASE_SECRET_KEY}'
    if prefer:
        headers['Prefer'] = prefer
    return headers


async def sb(method: str, table: str, *, params: dict[str, str] | None = None, payload: Any = None, prefer: str | None = None) -> Any:
    async with httpx.AsyncClient(timeout=25.0) as client:
        response = await client.request(method, f'{SUPABASE_URL}/rest/v1/{table}', headers=_headers(prefer), params=params, json=payload)
    if response.status_code >= 300:
        body = response.text[:900]
        raise HTTPException(status_code=422 if '23514' in body else 502, detail=f'SUPABASE_{table}_{response.status_code}:{body}')
    return response.json() if response.content else None


async def require_game(run_id: str, game_id: str) -> dict[str, Any]:
    rows = await sb('GET', 'games', params={'select': '*', 'run_id': f'eq.{run_id}', 'game_id': f'eq.{game_id}', 'limit': '1'}) or []
    if not rows:
        raise HTTPException(status_code=404, detail='GAME_NOT_REGISTERED_IN_RUN')
    return rows[0]


class ToolEventRequest(BaseModel):
    run_id: str
    game_id: str
    tool_name: str
    operation: str
    request_payload: Any = None
    response_payload: Any = None
    source_ref: str | None = None
    source_url: str | None = None
    material_new_info: bool | None = None


class SourceFamilyRequest(BaseModel):
    run_id: str
    game_id: str
    original_publisher: str | None = None
    canonical_origin: str | None = None
    family_basis: str
    family_key: str


class EvidenceRequest(BaseModel):
    run_id: str
    game_id: str
    tool_event_id: str
    source_family_id: str
    tool_name: str
    source_ref: str | None = None
    source_url: str | None = None
    original_publisher: str | None = None
    published_or_updated_at: str | None = None
    data_available_since: str | None = None
    payload: Any
    snapshot_text: str
    snapshot_drive_file_id: str
    snapshot_drive_hash: str
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
    saturation_family_ids: list[str] = Field(default_factory=list)
    dimensions_covered: list[str] = Field(default_factory=list)
    dimensions_missing: list[Any] = Field(default_factory=list)
    research_depth_justification: str | None = None
    known_unknowns: list[Any] = Field(default_factory=list)
    full_game_proxies: list[dict[str, Any]] = Field(default_factory=list)
    packet_payload: dict[str, Any] = Field(default_factory=dict)


class DriveArtifactRequest(BaseModel):
    run_id: str
    game_id: str | None = None
    packet_id: str | None = None
    artifact_type: str
    drive_file_id: str
    content_hash: str
    verification_method: str = 'GOOGLE_DRIVE_CONNECTOR_READBACK'


class ProcessAuditRequest(BaseModel):
    packet_id: str
    auditor_id: str = 'KERNEL_PROCESS_AUDITOR_0.1'
    structural_pass: bool
    temporal_pass: bool
    evidence_pass: bool
    falsification_pass: bool
    independence_pass: bool
    clone_risk: str = 'NOT_EVALUATED'
    findings: dict[str, Any] = Field(default_factory=dict)
    status: str


@app.get('/')
async def root():
    return {'service': '@NRFImetrica Sports Research Chain', 'system_version': SYSTEM_VERSION, 'kernel_version': KERNEL_VERSION, 'protocol_id': MOTHER_PROTOCOL_ID, 'packet_version': '2.0', 'rule': 'NO_CLAIM_OF_RESEARCH_WITHOUT_PHYSICAL_CHAIN_OF_CUSTODY'}


@app.post('/tool-events')
async def record_tool_event(req: ToolEventRequest):
    await require_game(req.run_id, req.game_id)
    row = {'event_id': f'RTE-{uuid4().hex}', 'run_id': req.run_id, 'game_id': req.game_id, 'tool_name': req.tool_name, 'operation': req.operation.upper(), 'request_hash': stable_hash(req.request_payload) if req.request_payload is not None else None, 'response_hash': stable_hash(req.response_payload) if req.response_payload is not None else None, 'source_ref': req.source_ref, 'source_url': req.source_url, 'material_new_info': req.material_new_info}
    saved = await sb('POST', 'research_tool_events', payload=row, prefer='return=representation')
    return (saved or [row])[0]


@app.post('/source-families')
async def register_source_family(req: SourceFamilyRequest):
    await require_game(req.run_id, req.game_id)
    family_id = 'FAM-' + stable_hash({'run_id': req.run_id, 'game_id': req.game_id, 'family_key': req.family_key})[:24]
    row = {'source_family_id': family_id, 'run_id': req.run_id, 'game_id': req.game_id, 'family_key': req.family_key, 'original_publisher': req.original_publisher, 'canonical_origin': req.canonical_origin, 'family_basis': req.family_basis}
    saved = await sb('POST', 'research_source_families', params={'on_conflict': 'run_id,game_id,family_key'}, payload=row, prefer='resolution=merge-duplicates,return=representation')
    return (saved or [row])[0]


@app.post('/evidence')
async def register_evidence(req: EvidenceRequest):
    await require_game(req.run_id, req.game_id)
    event = await sb('GET', 'research_tool_events', params={'select': '*', 'event_id': f'eq.{req.tool_event_id}', 'limit': '1'}) or []
    if not event:
        raise HTTPException(status_code=422, detail='TOOL_EVENT_NOT_FOUND')
    snapshot_hash = stable_hash(req.snapshot_text)
    if req.snapshot_drive_hash != snapshot_hash:
        raise HTTPException(status_code=422, detail='SNAPSHOT_DRIVE_HASH_MUST_MATCH_CAPTURED_TEXT_HASH')
    evidence_id = f'EVID-SR-{uuid4().hex}'
    row = {'evidence_id': evidence_id, 'run_id': req.run_id, 'game_id': req.game_id, 'tool_name': req.tool_name, 'source_ref': req.source_ref, 'source_url': req.source_url, 'input_hash': event[0].get('request_hash'), 'payload_hash': stable_hash(req.payload), 'payload': req.payload, 'tool_event_id': req.tool_event_id, 'source_family_id': req.source_family_id, 'original_publisher': req.original_publisher, 'published_or_updated_at': req.published_or_updated_at, 'data_available_since': req.data_available_since, 'snapshot_hash': snapshot_hash, 'snapshot_drive_file_id': req.snapshot_drive_file_id, 'snapshot_drive_hash': req.snapshot_drive_hash, 'claims_extracted': req.claims_extracted, 'evidence_scope': 'SPORTS_REASONING'}
    saved = await sb('POST', 'evidence', payload=row, prefer='return=representation')
    await sb('PATCH', 'research_tool_events', params={'event_id': f'eq.{req.tool_event_id}'}, payload={'evidence_id': evidence_id}, prefer='return=minimal')
    return (saved or [row])[0]


@app.post('/packets')
async def create_packet(req: PacketCreateRequest):
    await require_game(req.run_id, req.game_id)
    packet_id = f'SRP-{req.run_id}-{req.game_id}-v{req.version}'
    row = {'packet_id': packet_id, 'run_id': req.run_id, 'game_id': req.game_id, 'protocol_id': MOTHER_PROTOCOL_ID, 'version': req.version, 'previous_packet_hash': req.previous_packet_hash, 'complexity_tier': req.complexity_tier.upper(), 'status': 'IN_PROGRESS'}
    saved = await sb('POST', 'sports_reasoning_packets', payload=row, prefer='return=representation')
    return (saved or [row])[0]


@app.post('/claims')
async def add_claim(req: ClaimRequest):
    row = {'claim_id': f'CLM-{uuid4().hex}', 'packet_id': req.packet_id, 'run_id': 'SET_BY_DB', 'game_id': 'SET_BY_DB', 'claim_type': req.claim_type.upper(), 'claim_text': req.claim_text, 'evidence_ids': req.evidence_ids}
    saved = await sb('POST', 'sports_reasoning_claims', payload=row, prefer='return=representation')
    return (saved or [row])[0]


@app.patch('/packets/{packet_id}/finalize')
async def finalize_packet(packet_id: str, req: PacketFinalizeRequest):
    payload = req.model_dump(); payload['status'] = req.status.upper()
    if req.sports_verdict: payload['sports_verdict'] = req.sports_verdict.upper()
    saved = await sb('PATCH', 'sports_reasoning_packets', params={'packet_id': f'eq.{packet_id}'}, payload=payload, prefer='return=representation')
    if not saved: raise HTTPException(status_code=404, detail='PACKET_NOT_FOUND')
    return saved[0]


@app.post('/drive-artifacts')
async def register_drive_artifact(req: DriveArtifactRequest):
    row = {'artifact_id': f'DRV-{uuid4().hex}', 'run_id': req.run_id, 'game_id': req.game_id, 'packet_id': req.packet_id, 'artifact_type': req.artifact_type.upper(), 'drive_file_id': req.drive_file_id, 'content_hash': req.content_hash, 'verification_method': req.verification_method, 'immutable': True}
    saved = await sb('POST', 'research_drive_artifacts', payload=row, prefer='return=representation')
    return (saved or [row])[0]


@app.post('/process-audits')
async def register_process_audit(req: ProcessAuditRequest):
    row = {'audit_id': f'PAUD-{uuid4().hex}', 'packet_id': req.packet_id, 'run_id': 'SET_BY_DB', 'game_id': 'SET_BY_DB', 'auditor_id': req.auditor_id, 'structural_pass': req.structural_pass, 'temporal_pass': req.temporal_pass, 'evidence_pass': req.evidence_pass, 'falsification_pass': req.falsification_pass, 'independence_pass': req.independence_pass, 'clone_risk': req.clone_risk.upper(), 'findings': req.findings, 'status': req.status.upper()}
    saved = await sb('POST', 'sports_process_audits', payload=row, prefer='return=representation')
    return (saved or [row])[0]


@app.post('/runs/{run_id}/seal-sports-slate')
async def seal_sports_slate(run_id: str):
    games = await sb('GET', 'games', params={'select': 'game_id', 'run_id': f'eq.{run_id}'}) or []; total = len(games)
    packets = await sb('GET', 'sports_reasoning_packets', params={'select': '*', 'run_id': f'eq.{run_id}', 'order': 'game_id.asc,version.desc'}) or []
    latest: dict[str, dict[str, Any]] = {}
    for row in packets: latest.setdefault(str(row['game_id']), row)
    terminal = {'ANALYSIS_COMPLETE','RESEARCH_INCOMPLETE','INFORMATION_UNAVAILABLE','NOT_EXECUTABLE','WITHDRAWN_POST_FREEZE','PROCESS_FAIL'}
    terminal_rows = [p for p in latest.values() if p.get('status') in terminal and p.get('drive_verified_at') and p.get('drive_content_hash') == p.get('packet_hash')]
    complete = [p for p in terminal_rows if p.get('status') == 'ANALYSIS_COMPLETE' and p.get('process_audit_status') == 'PASS']; incomplete = [p for p in terminal_rows if p.get('status') == 'RESEARCH_INCOMPLETE']; unavailable = [p for p in terminal_rows if p.get('status') in {'INFORMATION_UNAVAILABLE','NOT_EXECUTABLE','WITHDRAWN_POST_FREEZE'}]; failed = [p for p in terminal_rows if p.get('status') == 'PROCESS_FAIL' or p.get('process_audit_status') == 'FAIL']
    payload = {'total_games': total, 'terminal_packet_count': len(terminal_rows), 'analysis_complete_count': len(complete), 'research_incomplete_count': len(incomplete), 'information_unavailable_count': len(unavailable), 'process_fail_count': len(failed), 'analysis_statement': f'{len(complete)}/{total} ANALISIS_COMPLETOS'}
    row = {'run_id': run_id, 'protocol_id': MOTHER_PROTOCOL_ID, 'stage_id': 'SPORTS_REASONING_SLATE', 'status': 'COMPLETE', 'payload': payload, 'evidence_ids': [], 'output_text': payload['analysis_statement']}
    saved = await sb('POST', 'protocol_run_state', params={'on_conflict': 'run_id,protocol_id,stage_id'}, payload=row, prefer='resolution=merge-duplicates,return=representation')
    return (saved or [row])[0]


@app.get('/runs/{run_id}/state')
async def run_research_state(run_id: str):
    run = await sb('GET', 'runs', params={'select': 'run_id,status,tool_call_count,metadata', 'run_id': f'eq.{run_id}', 'limit': '1'}) or []
    packets = await sb('GET', 'sports_reasoning_packets', params={'select': '*', 'run_id': f'eq.{run_id}', 'order': 'game_id.asc,version.desc'}) or []
    tool_events = await sb('GET', 'research_tool_events', params={'select': 'event_id,game_id,tool_name,operation,occurred_at,evidence_id', 'run_id': f'eq.{run_id}', 'order': 'occurred_at.asc'}) or []
    return {'run': run[0] if run else None, 'packets': packets, 'tool_events': tool_events}
