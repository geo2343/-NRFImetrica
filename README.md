# @NRFImetrica

Agente causal MLB de primera entrada gobernado por `MOTHER V3`.

## Estado vigente

- `SYSTEM_VERSION = NRFIM MOTHER V3`
- `AGENT_VERSION = MOTHER-V3-AGENT-1.14`
- `KERNEL_VERSION = NRFIM-KERNEL-1.8.1-SUPABASE-EDGE-RUNTIME`
- `PROTOCOL_ID = NRFIMETRICA_MOTHER_V3_AUTONOMOUS`
- `MOTHER_DOCUMENT_SHA256 = 799ccb5a483e7991f880ae7d49d2f191a98e292478ec64e76a55aa8250ec498b`
- `STATUS = ACTIVE`
- `RUNTIME_PLATFORM = SUPABASE_EDGE_FUNCTIONS`
- `RESEARCH_RUNTIME = nrfimetrica-research:v1`
- `VERCEL_DEPENDENCY = REMOVED`
- `REAL_MONEY_AUTHORITY = FALSE`
- migraciones requeridas hasta `075`.
- `V18_FORENSIC_PROCESS_REPAIR = 12/12 PASS`.
- `V18_SUPABASE_EDGE_RUNTIME = 6/6 PASS`.

La IA realiza el razonamiento causal deportivo. El Kernel valida autoridad, trazabilidad, temporalidad, bilateralidad, hashes, auditoría de proceso y separación SPORTS / PROCESS / EXECUTION.

## Runtime operativo

El runtime canónico de `@NRFImetrica` no es Vercel. La ejecución HTTP de investigación reside en Supabase Edge Functions mediante `nrfimetrica-research`, desplegada con JWT obligatorio.

La Edge Function cubre la cadena física de investigación: `RESEARCH_KERNEL_QUERY -> KERNEL_SERVER_FETCH -> RESEARCH_TOOL_EVENT -> EVIDENCE -> SPORTS_REASONING_PACKET -> CLAIMS -> DRIVE ARTIFACTS -> PROCESS AUDIT -> SPORTS_REASONING_SLATE`.

## Política transversal de independencia del runtime

`RUNTIME-INDEPENDENCE-1.0` gobierna todos los agentes del ecosistema. Vercel es únicamente `OPTIONAL_HTTP_ADAPTER_NON_BLOCKING`.

`VERCEL_REQUIRED = FALSE`

`VERCEL_FAILURE_BLOCKS_EXECUTION = FALSE`

Un límite de builds, ausencia de proyecto visible, fallo de deployment o caída de Vercel puede afectar una operación explícitamente Vercel-specific, pero no puede bloquear por sí solo el RUN del agente si su ruta canónica continúa disponible. `vercel.json` y los handlers `api/` se conservan como compatibilidad opcional y no constituyen autoridad de ejecución.

La política física vive en `public.agent_runtime_policy` y se documenta en `docs/RUNTIME_INDEPENDENCE_POLICY_V1.md`.

## Autoridad A0

A0 resuelve dinámicamente:

`agent_registry.mother_document_sha256 == protocol_authority.document_sha256`

Si falta una autoridad o ambas difieren: `AUTHORITY_CONFLICT`.

## Investigación deportiva independiente de A1–A8

`CERTIFICATION_CHAIN_BLOCKED != SPORTS_REASONING_FORBIDDEN`.

Cada partido debe terminar con packet o resolución terminal físicamente demostrable. Los descartes `NO_PLAY` tienen la misma carga investigativa que los candidatos.

`NRFI_LEAN` exige simultáneamente:

`TOP_HALF = NRFI_HALF_PASS AND BOTTOM_HALF = NRFI_HALF_PASS`.

No existe compensación entre mitades.

## Drive, shortlist y reporte

Un process audit no puede quedar `PASS` sin manifest físico verificado para el juego: `GAME_FOLDER`, `SPORTS_REASONING_PACKET`, `SOURCES_INDEX`, `CLAIM_EVIDENCE_MAP` y `TRACE_LOG`.

El shortlist procede únicamente del pool físico `SPORTS_CANDIDATE`. El reporte final deriva sus estados desde Supabase; sin packet la representación fail-closed es `WATCHLIST / PROCESS_MISSING / DO_NOT_BET`.

## Firewall económico

Mientras falten motor numérico game-specific `ACTIVE_TRUSTED`, auditor independiente `ACTIVE_TRUSTED`, auditoría certificada de confiabilidad, A7 release y A8 válido:

`BET_APPROVED = FALSE`.

Está prohibido fabricar P(NRFI), edge, EV o calibrated_probability por IA.

## Migraciones recientes

- `073_nrfimetrica_v18_forensic_process_repair.sql`
- `074_nrfimetrica_v18_supabase_edge_runtime.sql`
- `075_cross_agent_runtime_independence_v1.sql`

La corrida `NRFIM-MOTHER-20260820-ead3b6f3` permanece intacta como evidencia histórica incompleta.

Notion continúa como consulta solamente. `@NRFIprensa` no posee autoridad deportiva, probabilística, de ranking, de mercado ni de conclusión.

**EL PARTIDO SE ANALIZA. EL SISTEMA SE CALIBRA. VERCEL ES OPCIONAL. LA EJECUCIÓN NO DEPENDE DE UN PROVEEDOR HTTP ÚNICO.**
