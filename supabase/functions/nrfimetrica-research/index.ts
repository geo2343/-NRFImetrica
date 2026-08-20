const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const FUNCTION_SLUG = "nrfimetrica-research";
const PROTOCOL_ID = "NRFIMETRICA_MOTHER_V3_AUTONOMOUS";
const KERNEL_VERSION = "NRFIM-KERNEL-1.8.1-SUPABASE-EDGE-RUNTIME";

const jsonHeaders = { "content-type": "application/json; charset=utf-8" };
function reply(data: unknown, status = 200) { return new Response(JSON.stringify(data), { status, headers: jsonHeaders }); }
function fail(message: string, status = 422) { return reply({ error: message }, status); }
function stableStringify(value: unknown): string {
  if (value === null || typeof value !== "object") return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(stableStringify).join(",")}]`;
  const obj = value as Record<string, unknown>;
  return `{${Object.keys(obj).sort().map(k => `${JSON.stringify(k)}:${stableStringify(obj[k])}`).join(",")}}`;
}
async function sha256Text(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest)).map(b => b.toString(16).padStart(2, "0")).join("");
}
function uuid(prefix: string) { return `${prefix}${crypto.randomUUID().replaceAll("-", "")}`; }
function routeOf(req: Request): string {
  const parts = new URL(req.url).pathname.split("/").filter(Boolean);
  const i = parts.lastIndexOf(FUNCTION_SLUG);
  return "/" + (i >= 0 ? parts.slice(i + 1) : parts).join("/");
}
function validatePublicUrl(raw: string) {
  const u = new URL(raw);
  if (!['http:', 'https:'].includes(u.protocol)) throw new Error("SOURCE_URL_MUST_BE_HTTP_OR_HTTPS");
  const h = u.hostname.toLowerCase();
  if (h === "localhost" || h.endsWith(".local") || h === "0.0.0.0" || h === "::1" || h.startsWith("127.")) throw new Error("PRIVATE_SOURCE_HOST_FORBIDDEN");
  if (/^10\./.test(h) || /^192\.168\./.test(h) || /^169\.254\./.test(h) || /^172\.(1[6-9]|2\d|3[01])\./.test(h)) throw new Error("PRIVATE_SOURCE_IP_FORBIDDEN");
}
async function sb(method: string, table: string, opts: { params?: Record<string,string>; body?: unknown; prefer?: string } = {}) {
  if (!SUPABASE_URL || !SERVICE_KEY) throw new Error("SUPABASE_EDGE_RUNTIME_NOT_CONFIGURED");
  const u = new URL(`${SUPABASE_URL}/rest/v1/${table}`);
  for (const [k,v] of Object.entries(opts.params ?? {})) u.searchParams.set(k,v);
  const headers: Record<string,string> = { apikey: SERVICE_KEY, authorization: `Bearer ${SERVICE_KEY}`, "content-type": "application/json" };
  if (opts.prefer) headers.prefer = opts.prefer;
  const res = await fetch(u, { method, headers, body: opts.body === undefined ? undefined : JSON.stringify(opts.body) });
  const text = await res.text();
  if (!res.ok) throw new Error(`SUPABASE_${table}_${res.status}:${text.slice(0,1200)}`);
  return text ? JSON.parse(text) : null;
}
async function requireGame(runId: string, gameId: string) {
  const rows = await sb("GET", "games", { params: { select: "run_id,game_id,status,scheduled_start", run_id: `eq.${runId}`, game_id: `eq.${gameId}`, limit: "1" } }) as unknown[];
  if (!rows?.length) throw new Error("GAME_NOT_REGISTERED_IN_RUN");
  return rows[0];
}
async function fetchSource(body: Record<string, unknown>) {
  const runId = String(body.run_id ?? ""), gameId = String(body.game_id ?? ""), queryText = String(body.query_text ?? ""), sourceUrl = String(body.source_url ?? "");
  if (!runId || !gameId || queryText.trim().length < 3 || !sourceUrl) throw new Error("RUN_GAME_QUERY_AND_SOURCE_URL_REQUIRED");
  await requireGame(runId, gameId); validatePublicUrl(sourceUrl);
  const qRows = await sb("POST", "research_kernel_queries", { body: { run_id: runId, game_id: gameId, query_text: queryText, query_scope: String(body.query_scope ?? "SPORTS_REASONING") }, prefer: "return=representation" }) as Record<string, unknown>[];
  const q = qRows[0];
  const maxChars = Math.min(Math.max(Number(body.max_chars ?? 120000), 1000), 500000);
  const sourceRes = await fetch(sourceUrl, { redirect: "follow", headers: { "user-agent": "NRFImetrica-Kernel/1.8.1" } });
  const sourceText = (await sourceRes.text()).slice(0, maxChars);
  if (!sourceRes.ok) throw new Error(`SOURCE_FETCH_${sourceRes.status}`);
  const responseHash = await sha256Text(sourceText);
  const requestHash = await sha256Text(stableStringify({ query_text: queryText, source_url: sourceUrl }));
  const eRows = await sb("POST", "research_tool_events", { body: { event_id: uuid("RTE-"), run_id: runId, game_id: gameId, kernel_query_id: q.query_id, tool_name: "KERNEL_HTTP_FETCH", operation: "FETCH", retrieval_mode: "KERNEL_SERVER_FETCH", request_hash: requestHash, response_hash: responseHash, source_ref: body.source_ref ?? null, source_url: sourceUrl, source_published_at: body.source_published_at ?? null, data_available_since_kernel: body.source_published_at ?? null, material_new_info: body.material_new_info ?? null, kernel_attested: true, custody_version: "SEMANTIC-CUSTODY-1.0" }, prefer: "return=representation" }) as Record<string, unknown>[];
  return { query: q, event: eRows[0], source: { url: sourceUrl, status: sourceRes.status, response_hash: responseHash, text: sourceText } };
}
async function registerEvidence(body: Record<string, unknown>) {
  const runId = String(body.run_id ?? ""), gameId = String(body.game_id ?? ""), eventId = String(body.tool_event_id ?? ""), snapshot = String(body.snapshot_text ?? ""), extract = String(body.factual_extract_text ?? "");
  if (!runId || !gameId || !eventId || !snapshot || extract.trim().length < 8) throw new Error("EVIDENCE_REQUIRED_FIELDS_MISSING");
  await requireGame(runId, gameId);
  const snapshotHash = await sha256Text(snapshot);
  if (body.snapshot_drive_hash && String(body.snapshot_drive_hash) !== snapshotHash) throw new Error("SNAPSHOT_DRIVE_HASH_MUST_MATCH_CAPTURED_TEXT_HASH");
  const payload = body.payload ?? {}, payloadHash = await sha256Text(stableStringify(payload));
  const ev = await sb("GET", "research_tool_events", { params: { select: "request_hash,source_ref,source_url", event_id: `eq.${eventId}`, limit: "1" } }) as Record<string, unknown>[];
  if (!ev?.length) throw new Error("TOOL_EVENT_NOT_FOUND");
  const rows = await sb("POST", "evidence", { body: { evidence_id: uuid("EVID-SR-"), run_id: runId, game_id: gameId, tool_name: String(body.tool_name ?? "KERNEL_HTTP_FETCH"), tool_event_id: eventId, source_ref: body.source_ref ?? ev[0].source_ref ?? null, source_url: body.source_url ?? ev[0].source_url ?? null, original_publisher: body.original_publisher ?? null, input_hash: ev[0].request_hash ?? null, payload_hash: payloadHash, payload, snapshot_hash: snapshotHash, snapshot_drive_file_id: body.snapshot_drive_file_id ?? null, snapshot_drive_hash: String(body.snapshot_drive_hash ?? snapshotHash), factual_extract_text: extract, claims_extracted: body.claims_extracted ?? [], evidence_scope: "SPORTS_REASONING", kernel_attested: true, custody_version: "SEMANTIC-CUSTODY-1.0" }, prefer: "return=representation" }) as Record<string, unknown>[];
  await sb("PATCH", "research_tool_events", { params: { event_id: `eq.${eventId}` }, body: { evidence_id: rows[0].evidence_id }, prefer: "return=minimal" });
  return rows[0];
}
async function createPacket(body: Record<string, unknown>) {
  const runId = String(body.run_id ?? ""), gameId = String(body.game_id ?? ""), version = Number(body.version ?? 1);
  await requireGame(runId, gameId);
  const packetId = String(body.packet_id ?? `SRP-${runId}-${gameId}-v${version}`);
  const rows = await sb("POST", "sports_reasoning_packets", { body: { packet_id: packetId, run_id: runId, game_id: gameId, protocol_id: PROTOCOL_ID, version, previous_packet_hash: body.previous_packet_hash ?? null, complexity_tier: String(body.complexity_tier ?? "NORMAL").toUpperCase(), status: "IN_PROGRESS", custody_version: "SEMANTIC-CUSTODY-1.0", cognitive_contract_version: "COGNITIVE-CONTRACT-1.0" }, prefer: "return=representation" }) as Record<string, unknown>[];
  return rows[0];
}
async function finalizePacket(body: Record<string, unknown>) {
  const packetId = String(body.packet_id ?? ""); if (!packetId) throw new Error("PACKET_ID_REQUIRED");
  const update = { ...body } as Record<string, unknown>; delete update.packet_id;
  if (update.status) update.status = String(update.status).toUpperCase(); if (update.sports_verdict) update.sports_verdict = String(update.sports_verdict).toUpperCase();
  const rows = await sb("PATCH", "sports_reasoning_packets", { params: { packet_id: `eq.${packetId}` }, body: update, prefer: "return=representation" }) as Record<string, unknown>[];
  if (!rows?.length) throw new Error("PACKET_NOT_FOUND"); return rows[0];
}
async function addClaim(body: Record<string, unknown>) {
  const rows = await sb("POST", "sports_reasoning_claims", { body: { claim_id: uuid("CLM-"), packet_id: body.packet_id, run_id: "SET_BY_DB", game_id: "SET_BY_DB", claim_type: String(body.claim_type ?? "").toUpperCase(), claim_text: String(body.claim_text ?? ""), evidence_ids: body.evidence_ids ?? [] }, prefer: "return=representation" }) as Record<string, unknown>[];
  return rows[0];
}
async function driveArtifact(body: Record<string, unknown>) {
  const rows = await sb("POST", "research_drive_artifacts", { body: { artifact_id: uuid("DRV-"), run_id: body.run_id, game_id: body.game_id ?? null, packet_id: body.packet_id ?? null, artifact_type: String(body.artifact_type ?? "").toUpperCase(), drive_file_id: body.drive_file_id, content_hash: body.content_hash, verification_method: body.verification_method ?? "GOOGLE_DRIVE_CONNECTOR_READBACK", immutable: true }, prefer: "return=representation" }) as Record<string, unknown>[];
  return rows[0];
}
async function gameArtifact(body: Record<string, unknown>) {
  const rows = await sb("POST", "nrfimetrica_game_artifacts", { body: { run_id: body.run_id, game_id: body.game_id, artifact_kind: String(body.artifact_kind ?? "").toUpperCase(), drive_file_id: body.drive_file_id, content_hash: body.content_hash ?? null, verified_at: body.verified_at ?? new Date().toISOString(), metadata: body.metadata ?? {} }, prefer: "return=representation" }) as Record<string, unknown>[];
  return rows[0];
}
async function processAudit(body: Record<string, unknown>) {
  const rows = await sb("POST", "sports_process_audits", { body: { audit_id: uuid("PAUD-"), packet_id: body.packet_id, run_id: "SET_BY_DB", game_id: "SET_BY_DB", auditor_id: "KERNEL_PROCESS_AUDITOR_0.3", structural_pass: false, temporal_pass: false, evidence_pass: false, falsification_pass: false, independence_pass: false, semantic_custody_pass: false, adversarial_balance_pass: false, adaptive_depth_pass: false, first_inning_materiality_pass: false, clone_risk: String(body.clone_risk ?? "NOT_EVALUATED").toUpperCase(), findings: body.findings ?? {}, status: "FAIL" }, prefer: "return=representation" }) as Record<string, unknown>[];
  return rows[0];
}
async function sealSportsSlate(body: Record<string, unknown>) {
  const runId = String(body.run_id ?? "");
  const games = await sb("GET", "games", { params: { select: "game_id", run_id: `eq.${runId}` } }) as Record<string, unknown>[];
  const packets = await sb("GET", "sports_reasoning_packets", { params: { select: "*", run_id: `eq.${runId}`, order: "game_id.asc,version.desc" } }) as Record<string, unknown>[];
  const latest = new Map<string, Record<string, unknown>>(); for (const p of packets ?? []) if (!latest.has(String(p.game_id))) latest.set(String(p.game_id), p);
  const terminal = new Set(["ANALYSIS_COMPLETE","RESEARCH_INCOMPLETE","INFORMATION_UNAVAILABLE","NOT_EXECUTABLE","WITHDRAWN_POST_FREEZE","PROCESS_FAIL"]);
  const terminalRows = [...latest.values()].filter(p => terminal.has(String(p.status)) && p.drive_verified_at && p.drive_content_hash === p.packet_hash);
  const complete = terminalRows.filter(p => p.status === "ANALYSIS_COMPLETE" && p.process_audit_status === "PASS"), incomplete = terminalRows.filter(p => p.status === "RESEARCH_INCOMPLETE"), unavailable = terminalRows.filter(p => ["INFORMATION_UNAVAILABLE","NOT_EXECUTABLE","WITHDRAWN_POST_FREEZE"].includes(String(p.status))), failed = terminalRows.filter(p => p.status === "PROCESS_FAIL" || p.process_audit_status === "FAIL");
  const payload = { total_games: games?.length ?? 0, terminal_packet_count: terminalRows.length, analysis_complete_count: complete.length, research_incomplete_count: incomplete.length, information_unavailable_count: unavailable.length, process_fail_count: failed.length, analysis_statement: `${complete.length}/${games?.length ?? 0} ANALISIS_COMPLETOS` };
  const rows = await sb("POST", "protocol_run_state", { params: { on_conflict: "run_id,protocol_id,stage_id" }, body: { run_id: runId, protocol_id: PROTOCOL_ID, stage_id: "SPORTS_REASONING_SLATE", status: "COMPLETE", payload, evidence_ids: [], output_text: payload.analysis_statement }, prefer: "resolution=merge-duplicates,return=representation" }) as Record<string, unknown>[];
  return rows[0];
}
async function runState(runId: string) {
  const run = await sb("GET", "runs", { params: { select: "run_id,status,tool_call_count,metadata", run_id: `eq.${runId}`, limit: "1" } }) as Record<string, unknown>[];
  const packets = await sb("GET", "sports_reasoning_packets", { params: { select: "*", run_id: `eq.${runId}`, order: "game_id.asc,version.desc" } });
  const events = await sb("GET", "research_tool_events", { params: { select: "*", run_id: `eq.${runId}`, order: "occurred_at.asc" } });
  const audits = await sb("GET", "sports_process_audits", { params: { select: "*", run_id: `eq.${runId}`, order: "created_at.asc" } });
  const artifacts = await sb("GET", "research_drive_artifacts", { params: { select: "*", run_id: `eq.${runId}`, order: "verified_at.asc" } });
  return { run: run?.[0] ?? null, packets, events, audits, artifacts };
}
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204 });
  try {
    const route = routeOf(req);
    if (req.method === "GET" && (route === "/" || route === "/health")) return reply({ service: "@NRFImetrica Sports Research Chain", runtime: "SUPABASE_EDGE_FUNCTION", runtime_version: "1.0", kernel_version: KERNEL_VERSION, protocol_id: PROTOCOL_ID, auth: "JWT_REQUIRED", status: "READY" });
    if (req.method === "GET" && route.startsWith("/run-state/")) return reply(await runState(route.split("/").pop() ?? ""));
    if (req.method !== "POST") return fail("METHOD_NOT_ALLOWED", 405);
    const body = await req.json() as Record<string, unknown>;
    if (route === "/fetch-source") return reply(await fetchSource(body));
    if (route === "/evidence") return reply(await registerEvidence(body));
    if (route === "/packets") return reply(await createPacket(body));
    if (route === "/packets/finalize") return reply(await finalizePacket(body));
    if (route === "/claims") return reply(await addClaim(body));
    if (route === "/drive-artifacts") return reply(await driveArtifact(body));
    if (route === "/game-artifacts") return reply(await gameArtifact(body));
    if (route === "/process-audits") return reply(await processAudit(body));
    if (route === "/seal-sports-slate") return reply(await sealSportsSlate(body));
    return fail("ROUTE_NOT_FOUND", 404);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return fail(message, message.includes("NOT_FOUND") ? 404 : message.includes("NOT_CONFIGURED") ? 503 : 422);
  }
});
