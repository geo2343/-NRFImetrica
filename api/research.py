from __future__ import annotations

import asyncio
import hashlib
import ipaddress
import os
import re
import socket
from email.utils import parsedate_to_datetime
from html import unescape
from typing import Any
from urllib.parse import urljoin, urlparse
from uuid import uuid4

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from kernel.core import (
    KERNEL_VERSION,
    MOTHER_PROTOCOL_ID,
    PROCESS_AUDITOR_ID,
    SEMANTIC_CUSTODY_VERSION,
    SYSTEM_VERSION,
    stable_hash,
)

SUPABASE_URL = os.getenv('SUPABASE_URL', '').rstrip('/')
SUPABASE_SECRET_KEY = os.getenv('SUPABASE_SECRET_KEY', '') or os.getenv('SUPABASE_SERVICE_ROLE_KEY', '')
MAX_FETCH_BYTES = 4_000_000
MAX_EXTRACT_CHARS = 200_000
TRUSTED_RETRIEVAL_MODES = {'KERNEL_SERVER_FETCH', 'KERNEL_PROVIDER_FETCH'}

app = FastAPI(title='@NRFImetrica Sports Research Chain', version='1.4')


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
        body = response.text[:1200]
        raise HTTPException(status_code=422 if '23514' in body else 502, detail=f'SUPABASE_{table}_{response.status_code}:{body}')
    return response.json() if response.content else None


async def require_game(run_id: str, game_id: str) -> dict[str, Any]:
    rows = await sb('GET', 'games', params={'select': '*', 'run_id': f'eq.{run_id}', 'game_id': f'eq.{game_id}', 'limit': '1'}) or []
    if not rows:
        raise HTTPException(status_code=404, detail='GAME_NOT_REGISTERED_IN_RUN')
    return rows[0]


async def require_kernel_query(query_id: str) -> dict[str, Any]:
    rows = await sb('GET', 'research_kernel_queries', params={'select': '*', 'query_id': f'eq.{query_id}', 'limit': '1'}) or []
    if not rows:
        raise HTTPException(status_code=404, detail='KERNEL_QUERY_NOT_FOUND')
    query = rows[0]
    if query.get('status') != 'REQUESTED':
        raise HTTPException(status_code=409, detail='KERNEL_QUERY_ALREADY_FULFILLED_OR_CANCELLED')
    await require_game(str(query['run_id']), str(query['game_id']))
    return query


def _sha256_bytes(blob: bytes) -> str:
    return hashlib.sha256(blob).hexdigest()


def _sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode('utf-8')).hexdigest()


def _plain_text(body: bytes, content_type: str) -> str:
    text = body.decode('utf-8', errors='replace')
    if 'html' in content_type.lower():
        text = re.sub(r'(?is)<(script|style|noscript).*?>.*?</\1>', ' ', text)
        text = re.sub(r'(?s)<[^>]+>', ' ', text)
        text = unescape(text)
    text = re.sub(r'\s+', ' ', text).strip()
    return text[:MAX_EXTRACT_CHARS]


def _parse_http_date(value: str | None) -> str | None:
    if not value:
        return None
    try:
        dt = parsedate_to_datetime(value)
        if dt.tzinfo is None:
            return None
        return dt.isoformat()
    except Exception:
        return None


async def _assert_public_https_url(url: str) -> None:
    parsed = urlparse(url)
    if parsed.scheme.lower() != 'https' or not parsed.hostname or parsed.username or parsed.password:
        raise HTTPException(status_code=422, detail='KERNEL_FETCH_REQUIRES_PUBLIC_HTTPS_URL')
    host = parsed.hostname
    try:
        infos = await asyncio.to_thread(socket.getaddrinfo, host, parsed.port or 443, type=socket.SOCK_STREAM)
    except OSError as exc:
        raise HTTPException(status_code=422, detail=f'KERNEL_FETCH_DNS_FAILED:{type(exc).__name__}') from exc
    if not infos:
        raise HTTPException(status_code=422, detail='KERNEL_FETCH_DNS_EMPTY')
    for info in infos:
        ip = ipaddress.ip_address(info[4][0])
        if ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_multicast or ip.is_reserved or ip.is_unspecified:
            raise HTTPException(status_code=422, detail='KERNEL_FETCH_PRIVATE_OR_RESERVED_ADDRESS_BLOCKED')


async def _kernel_fetch(url: str) -> tuple[str, httpx.Response, bytes]:
    current = url
    headers = {'User-Agent': 'NRFImetrica-Kernel/1.4 evidence-extractor'}
    async with httpx.AsyncClient(timeout=25.0, follow_redirects=False, headers=headers) as client:
        for _ in range(5):
            await _assert_public_https_url(current)
            response = await client.get(current)
            if response.status_code in {301, 302, 303, 307, 308}:
                location = response.headers.get('location')
                if not location:
                    raise HTTPException(status_code=502, detail='KERNEL_FETCH_REDIRECT_WITHOUT_LOCATION')
                current = urljoin(current, location)
                continue
            if response.status_code >= 400:
                raise HTTPException(status_code=502, detail=f'KERNEL_FETCH_HTTP_{response.status_code}')
            body = response.content
            if len(body) > MAX_FETCH_BYTES:
                raise HTTPException(status_code=413, detail='KERNEL_FETCH_RESPONSE_TOO_LARGE')
            content_type = response.headers.get('content-type', '').lower()
            if not any(token in content_type for token in ('text/', 'json', 'xml', 'javascript')):
                raise HTTPException(status_code=415, detail=f'KERNEL_FETCH_UNSUPPORTED_CONTENT_TYPE:{content_type[:80]}')
            return current, response, body
    raise HTTPException(status_code=508, detail='KERNEL_FETCH_TOO_MANY_REDIRECTS')


class KernelQueryRequest(BaseModel):
    run_id: str
    game_id: str
    query_text: str
    query_scope: str = 'SOURCE_EXTRACTION'


class ToolEventRequest(BaseModel):
    kernel_query_id: str
    tool_name: str
    operation: str
    request_payload: Any = None
    response_payload: Any = None
    source_ref: str | None = None
    source_url: str | None = None
    material_new_info: bool | None = None


class KernelURLExtractionRequest(BaseModel):
    kernel_query_id: str
    url: str
    source_ref: str | None = None
    original_publisher: str | None = None


class EvidenceDriveAttestationRequest(BaseModel):
    drive_file_id: str
    content_hash: str


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
    lineup_status: str = 'UNKNOWN'
    projected_analysis: dict[str, Any] = Field(default_factory=dict)
    confirmed_analysis: dict[str, Any] = Field(default_factory=dict)
    first_inning_factors: list[dict[str, Any]] = Field(default_factory=list)
    top_1st_analysis: dict[str, Any] = Field(default_factory=dict)
    bottom_1st_analysis: dict[str, Any] = Field(default_factory=dict)
    central_nrfi_case: dict[str, Any] = Field(default_factory=dict)
    best_yrfi_rival: dict[str, Any] = Field(default_factory=dict)
    strongest_counterevidence: dict[str, Any] = Field(default_factory=dict)
    falsification_attempts: list[dict[str, Any]] = Field(default_factory=list)
    adversarial_balance: dict[str, Any] = Field(default_factory=dict)
    causal_clusters: list[dict[str, Any]] = Field(default_factory=list)
    dominant_factor: dict[str, Any] = Field(default_factory=dict)
    unresolved_contradictions: list[dict[str, Any]] = Field(default_factory=list)
    governing_uncertainty: dict[str, Any] = Field(default_factory=dict)
    what_would_change: dict[str, Any] = Field(default_factory=dict)
    why_research_stopped: str | None = None
    why_stop_detail: str | None = None
    saturation_reached: bool = False
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
    clone_risk: str = 'NOT_EVALUATED'
    findings: dict[str, Any] = Field(default_factory=dict)


@app.get('/')
async def root():
    return {
        'service': '@NRFImetrica Sports Research Chain',
        'system_version': SYSTEM_VERSION,
        'kernel_version': KERNEL_VERSION,
        'protocol_id': MOTHER_PROTOCOL_ID,
        'packet_version': '2.0',
        'custody_version': SEMANTIC_CUSTODY_VERSION,
        'process_auditor': PROCESS_AUDITOR_ID,
        'process_audit_truth_values': 'DERIVED_BY_DATABASE',
        'evidence_rule': 'DISCOVERY_IS_NOT_EVIDENCE; ONLY_KERNEL_ATTESTED_EXTRACTION_CAN_CREATE_SPORTS_EVIDENCE',
        'id_rule': 'TOOL_EVENT_ID_AND_EVIDENCE_ID_ARE_DATABASE_GENERATED',
    }


@app.post('/research-queries')
async def create_research_query(req: KernelQueryRequest):
    await require_game(req.run_id, req.game_id)
    scope = req.query_scope.upper()
    if scope not in {'DISCOVERY', 'SOURCE_EXTRACTION', 'STRUCTURED_PROVIDER', 'REVALIDATION'}:
        raise HTTPException(status_code=422, detail='INVALID_KERNEL_QUERY_SCOPE')
    row = {'run_id': req.run_id, 'game_id': req.game_id, 'query_text': req.query_text, 'query_scope': scope}
    saved = await sb('POST', 'research_kernel_queries', payload=row, prefer='return=representation')
    if not saved:
        raise HTTPException(status_code=502, detail='KERNEL_QUERY_NOT_PERSISTED')
    return saved[0]


@app.post('/tool-events')
async def record_discovery_tool_event(req: ToolEventRequest):
    query = await require_kernel_query(req.kernel_query_id)
    row = {
        'run_id': query['run_id'],
        'game_id': query['game_id'],
        'kernel_query_id': req.kernel_query_id,
        'tool_name': req.tool_name,
        'operation': req.operation.upper(),
        'request_hash': stable_hash(req.request_payload) if req.request_payload is not None else None,
        'response_hash': stable_hash(req.response_payload) if req.response_payload is not None else None,
        'source_ref': req.source_ref,
        'source_url': req.source_url,
        'material_new_info': req.material_new_info,
        'retrieval_mode': 'DISCOVERY_ONLY',
    }
    saved = await sb('POST', 'research_tool_events', payload=row, prefer='return=representation')
    if not saved:
        raise HTTPException(status_code=502, detail='DISCOVERY_EVENT_NOT_PERSISTED')
    result = saved[0]
    result['warning'] = 'DISCOVERY_ONLY_CANNOT_SUPPORT_FACTUAL_SPORTS_CLAIMS'
    return result


@app.post('/extract-url')
async def extract_url(req: KernelURLExtractionRequest):
    query = await require_kernel_query(req.kernel_query_id)
    if query.get('query_scope') not in {'SOURCE_EXTRACTION', 'REVALIDATION', 'STRUCTURED_PROVIDER'}:
        raise HTTPException(status_code=422, detail='KERNEL_QUERY_SCOPE_NOT_VALID_FOR_EXTRACTION')

    final_url, response, body = await _kernel_fetch(req.url)
    content_type = response.headers.get('content-type', '')
    extract_text = _plain_text(body, content_type)
    if len(extract_text) < 8:
        raise HTTPException(status_code=422, detail='KERNEL_FETCH_EMPTY_FACTUAL_EXTRACT')

    response_hash = _sha256_bytes(body)
    snapshot_hash = _sha256_text(extract_text)
    published_at = _parse_http_date(response.headers.get('last-modified'))

    event_row = {
        'run_id': query['run_id'],
        'game_id': query['game_id'],
        'kernel_query_id': req.kernel_query_id,
        'tool_name': 'KERNEL_HTTP_EXTRACTOR',
        'operation': 'FETCH',
        'request_hash': stable_hash({'query_id': req.kernel_query_id, 'url': req.url}),
        'response_hash': response_hash,
        'source_ref': req.source_ref,
        'source_url': final_url,
        'retrieval_mode': 'KERNEL_SERVER_FETCH',
        'source_published_at': published_at,
        'data_available_since_kernel': published_at,
    }
    event_saved = await sb('POST', 'research_tool_events', payload=event_row, prefer='return=representation')
    if not event_saved:
        raise HTTPException(status_code=502, detail='KERNEL_FETCH_EVENT_NOT_PERSISTED')
    event = event_saved[0]
    if not event.get('kernel_attested'):
        raise HTTPException(status_code=500, detail='KERNEL_FETCH_EVENT_NOT_ATTESTED')

    evidence_row = {
        'run_id': query['run_id'],
        'game_id': query['game_id'],
        'tool_name': 'KERNEL_HTTP_EXTRACTOR',
        'source_ref': req.source_ref,
        'source_url': final_url,
        'input_hash': event.get('request_hash'),
        'payload_hash': response_hash,
        'payload': {
            'status_code': response.status_code,
            'content_type': content_type,
            'final_url': final_url,
            'response_hash': response_hash,
            'factual_extract': extract_text,
        },
        'tool_event_id': event['event_id'],
        'original_publisher': req.original_publisher,
        'snapshot_hash': snapshot_hash,
        'factual_extract_text': extract_text,
        'claims_extracted': [],
        'evidence_scope': 'SPORTS_REASONING',
    }
    evidence_saved = await sb('POST', 'evidence', payload=evidence_row, prefer='return=representation')
    if not evidence_saved:
        raise HTTPException(status_code=502, detail='KERNEL_EVIDENCE_NOT_PERSISTED')
    evidence = evidence_saved[0]
    await sb('PATCH', 'research_tool_events', params={'event_id': f"eq.{event['event_id']}"}, payload={'evidence_id': evidence['evidence_id']}, prefer='return=minimal')
    return {
        'kernel_query_id': req.kernel_query_id,
        'tool_event_id': event['event_id'],
        'evidence_id': evidence['evidence_id'],
        'source_family_id': evidence.get('source_family_id'),
        'family_assignment_method': evidence.get('family_assignment_method'),
        'retrieved_at': evidence.get('retrieved_at'),
        'published_or_updated_at': evidence.get('published_or_updated_at'),
        'data_available_since': evidence.get('data_available_since'),
        'response_hash': response_hash,
        'snapshot_hash': snapshot_hash,
        'factual_extract_text': extract_text,
        'drive_attestation_required_before_process_pass': True,
    }


@app.post('/source-families')
async def manual_source_family_disabled():
    raise HTTPException(status_code=410, detail='SOURCE_FAMILY_MANUAL_REGISTRATION_DISABLED_KERNEL_DERIVES_FAMILY')


@app.post('/evidence')
async def manual_sports_evidence_disabled():
    raise HTTPException(status_code=410, detail='MANUAL_SPORTS_EVIDENCE_DISABLED_USE_KERNEL_EXTRACTION')


@app.patch('/evidence/{evidence_id}/drive-attestation')
async def attest_evidence_drive_snapshot(evidence_id: str, req: EvidenceDriveAttestationRequest):
    rows = await sb('GET', 'evidence', params={'select': 'evidence_id,snapshot_hash,custody_version', 'evidence_id': f'eq.{evidence_id}', 'limit': '1'}) or []
    if not rows:
        raise HTTPException(status_code=404, detail='EVIDENCE_NOT_FOUND')
    evidence = rows[0]
    if evidence.get('custody_version') != SEMANTIC_CUSTODY_VERSION:
        raise HTTPException(status_code=409, detail='LEGACY_EVIDENCE_DRIVE_ATTESTATION_USES_LEGACY_FLOW')
    if req.content_hash != evidence.get('snapshot_hash'):
        raise HTTPException(status_code=422, detail='DRIVE_SNAPSHOT_HASH_MISMATCH')
    saved = await sb(
        'PATCH',
        'evidence',
        params={'evidence_id': f'eq.{evidence_id}'},
        payload={'snapshot_drive_file_id': req.drive_file_id, 'snapshot_drive_hash': req.content_hash},
        prefer='return=representation',
    )
    if not saved:
        raise HTTPException(status_code=502, detail='EVIDENCE_DRIVE_ATTESTATION_NOT_PERSISTED')
    return saved[0]


@app.post('/packets')
async def create_packet(req: PacketCreateRequest):
    await require_game(req.run_id, req.game_id)
    packet_id = f'SRP-{req.run_id}-{req.game_id}-v{req.version}'
    row = {
        'packet_id': packet_id,
        'run_id': req.run_id,
        'game_id': req.game_id,
        'protocol_id': MOTHER_PROTOCOL_ID,
        'version': req.version,
        'previous_packet_hash': req.previous_packet_hash,
        'complexity_tier': req.complexity_tier.upper(),
        'status': 'IN_PROGRESS',
    }
    saved = await sb('POST', 'sports_reasoning_packets', payload=row, prefer='return=representation')
    return (saved or [row])[0]


@app.post('/claims')
async def add_claim(req: ClaimRequest):
    row = {
        'claim_id': f'CLM-{uuid4().hex}',
        'packet_id': req.packet_id,
        'run_id': 'SET_BY_DB',
        'game_id': 'SET_BY_DB',
        'claim_type': req.claim_type.upper(),
        'claim_text': req.claim_text,
        'evidence_ids': req.evidence_ids,
    }
    saved = await sb('POST', 'sports_reasoning_claims', payload=row, prefer='return=representation')
    return (saved or [row])[0]


@app.patch('/packets/{packet_id}/finalize')
async def finalize_packet(packet_id: str, req: PacketFinalizeRequest):
    payload = req.model_dump()
    payload['status'] = req.status.upper()
    payload['lineup_status'] = req.lineup_status.upper()
    if req.sports_verdict:
        payload['sports_verdict'] = req.sports_verdict.upper()
    # saturation_family_ids and adaptive_required_families are Kernel-owned in DB.
    payload.pop('saturation_family_ids', None)
    saved = await sb('PATCH', 'sports_reasoning_packets', params={'packet_id': f'eq.{packet_id}'}, payload=payload, prefer='return=representation')
    if not saved:
        raise HTTPException(status_code=404, detail='PACKET_NOT_FOUND')
    return saved[0]


@app.post('/drive-artifacts')
async def register_drive_artifact(req: DriveArtifactRequest):
    row = {
        'artifact_id': f'DRV-{uuid4().hex}',
        'run_id': req.run_id,
        'game_id': req.game_id,
        'packet_id': req.packet_id,
        'artifact_type': req.artifact_type.upper(),
        'drive_file_id': req.drive_file_id,
        'content_hash': req.content_hash,
        'verification_method': req.verification_method,
        'immutable': True,
    }
    saved = await sb('POST', 'research_drive_artifacts', payload=row, prefer='return=representation')
    return (saved or [row])[0]


@app.post('/process-audits')
async def register_process_audit(req: ProcessAuditRequest):
    row = {
        'audit_id': f'PAUD-{uuid4().hex}',
        'packet_id': req.packet_id,
        'run_id': 'SET_BY_DB',
        'game_id': 'SET_BY_DB',
        'auditor_id': PROCESS_AUDITOR_ID,
        'structural_pass': False,
        'temporal_pass': False,
        'evidence_pass': False,
        'falsification_pass': False,
        'independence_pass': False,
        'semantic_custody_pass': False,
        'adversarial_balance_pass': False,
        'adaptive_depth_pass': False,
        'first_inning_materiality_pass': False,
        'clone_risk': req.clone_risk.upper(),
        'findings': req.findings,
        'status': 'FAIL',
    }
    saved = await sb('POST', 'sports_process_audits', payload=row, prefer='return=representation')
    return (saved or [row])[0]


@app.post('/runs/{run_id}/seal-sports-slate')
async def seal_sports_slate(run_id: str):
    games = await sb('GET', 'games', params={'select': 'game_id', 'run_id': f'eq.{run_id}'}) or []
    total = len(games)
    packets = await sb('GET', 'sports_reasoning_packets', params={'select': '*', 'run_id': f'eq.{run_id}', 'order': 'game_id.asc,version.desc'}) or []
    latest: dict[str, dict[str, Any]] = {}
    for row in packets:
        latest.setdefault(str(row['game_id']), row)
    terminal = {'ANALYSIS_COMPLETE', 'RESEARCH_INCOMPLETE', 'INFORMATION_UNAVAILABLE', 'NOT_EXECUTABLE', 'WITHDRAWN_POST_FREEZE', 'PROCESS_FAIL'}
    terminal_rows = [p for p in latest.values() if p.get('status') in terminal and p.get('drive_verified_at') and p.get('drive_content_hash') == p.get('packet_hash')]
    complete = [p for p in terminal_rows if p.get('status') == 'ANALYSIS_COMPLETE' and p.get('process_audit_status') == 'PASS']
    incomplete = [p for p in terminal_rows if p.get('status') == 'RESEARCH_INCOMPLETE']
    unavailable = [p for p in terminal_rows if p.get('status') in {'INFORMATION_UNAVAILABLE', 'NOT_EXECUTABLE', 'WITHDRAWN_POST_FREEZE'}]
    failed = [p for p in terminal_rows if p.get('status') == 'PROCESS_FAIL' or p.get('process_audit_status') == 'FAIL']
    payload = {
        'total_games': total,
        'terminal_packet_count': len(terminal_rows),
        'analysis_complete_count': len(complete),
        'research_incomplete_count': len(incomplete),
        'information_unavailable_count': len(unavailable),
        'process_fail_count': len(failed),
        'analysis_statement': f'{len(complete)}/{total} ANALISIS_COMPLETOS',
    }
    row = {
        'run_id': run_id,
        'protocol_id': MOTHER_PROTOCOL_ID,
        'stage_id': 'SPORTS_REASONING_SLATE',
        'status': 'COMPLETE',
        'payload': payload,
        'evidence_ids': [],
        'output_text': payload['analysis_statement'],
    }
    saved = await sb('POST', 'protocol_run_state', params={'on_conflict': 'run_id,protocol_id,stage_id'}, payload=row, prefer='resolution=merge-duplicates,return=representation')
    return (saved or [row])[0]


@app.get('/runs/{run_id}/state')
async def run_research_state(run_id: str):
    run = await sb('GET', 'runs', params={'select': 'run_id,status,tool_call_count,metadata', 'run_id': f'eq.{run_id}', 'limit': '1'}) or []
    queries = await sb('GET', 'research_kernel_queries', params={'select': '*', 'run_id': f'eq.{run_id}', 'order': 'requested_at.asc'}) or []
    packets = await sb('GET', 'sports_reasoning_packets', params={'select': '*', 'run_id': f'eq.{run_id}', 'order': 'game_id.asc,version.desc'}) or []
    tool_events = await sb('GET', 'research_tool_events', params={'select': 'event_id,kernel_query_id,game_id,tool_name,operation,retrieval_mode,kernel_attested,occurred_at,evidence_id', 'run_id': f'eq.{run_id}', 'order': 'occurred_at.asc'}) or []
    process_audits = await sb('GET', 'sports_process_audits', params={'select': '*', 'run_id': f'eq.{run_id}', 'order': 'created_at.asc'}) or []
    drive_artifacts = await sb('GET', 'research_drive_artifacts', params={'select': '*', 'run_id': f'eq.{run_id}', 'order': 'verified_at.asc'}) or []
    return {
        'run': run[0] if run else None,
        'kernel_queries': queries,
        'packets': packets,
        'tool_events': tool_events,
        'process_audits': process_audits,
        'drive_artifacts': drive_artifacts,
    }
