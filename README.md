# @NRFImetrica

Agente causal MLB de primera entrada gobernado por `MOTHER V3`.

## Estado vigente

- `SYSTEM_VERSION = NRFIM MOTHER V3`
- `AGENT_VERSION = MOTHER-V3-AGENT-1.13`
- `KERNEL_VERSION = NRFIM-KERNEL-1.8-FORENSIC-REPAIR`
- `PROTOCOL_ID = NRFIMETRICA_MOTHER_V3_AUTONOMOUS`
- `MOTHER_DOCUMENT_SHA256 = 799ccb5a483e7991f880ae7d49d2f191a98e292478ec64e76a55aa8250ec498b`
- `STATUS = ACTIVE`
- `REAL_MONEY_AUTHORITY = FALSE`
- migraciones requeridas hasta `073`.
- `V18_FORENSIC_PROCESS_REPAIR = 12/12 PASS`.

La IA realiza el razonamiento causal deportivo. El Kernel valida autoridad, trazabilidad, temporalidad, bilateralidad, hashes, auditoría de proceso y separación SPORTS / PROCESS / EXECUTION. No convierte métricas en votos ni permite que un bloqueo económico borre un juicio deportivo físicamente demostrado.

## Autoridad A0

A0 ya no compara contra un hash histórico incrustado en una función. La autoridad se resuelve dinámicamente:

`agent_registry.mother_document_sha256 == protocol_authority.document_sha256`

Si falta una autoridad o ambas difieren: `AUTHORITY_CONFLICT` y la certificación no avanza. Un RUN válido guarda ese hash como snapshot en `A0_CONSTITUTION_SEALED`.

## Investigación deportiva independiente de A1–A8

`CERTIFICATION_CHAIN_BLOCKED != SPORTS_REASONING_FORBIDDEN`.

A0P puede resolverse como preanálisis deportivo aun cuando A0 de certificación esté bloqueado. Esto permite continuar la investigación y construir `SPORTS_REASONING_PACKET V2`. A1–A8, sin embargo, siguen exigiendo un A0 válido.

Cada partido debe terminar con packet o resolución terminal físicamente demostrable. Los descartes `NO_PLAY` tienen la misma carga investigativa que los candidatos.

Cada `ANALYSIS_COMPLETE` conserva:

- consultas físicas y `RESEARCH_TOOL_EVENT`;
- `EVIDENCE_ID` y familias de fuente;
- snapshots y hashes;
- factual claims con evidence IDs;
- `TOP_1ST_ANALYSIS` y `BOTTOM_1ST_ANALYSIS` independientes;
- versión actual, matchup, BB, HR/contact damage, tráfico y evidencia de primera entrada;
- caso NRFI y mejor rival YRFI respaldado;
- falsificación bilateral de tesis;
- second-pass review;
- directional-bias check;
- causal bottlenecks;
- condición observable de qué cambiaría la decisión;
- hash de packet y verificación Drive;
- auditoría determinista de proceso.

`NRFI_LEAN` exige simultáneamente:

`TOP_HALF = NRFI_HALF_PASS AND BOTTOM_HALF = NRFI_HALF_PASS`.

No existe compensación entre mitades.

## Drive y auditoría

Un process audit no puede quedar `PASS` sin manifest físico verificado para el juego:

- `GAME_FOLDER`
- `SPORTS_REASONING_PACKET`
- `SOURCES_INDEX`
- `CLAIM_EVIDENCE_MAP`
- `TRACE_LOG`

El packet debe conservar igualdad entre `PACKET_HASH` y el hash de su artefacto Drive. La evidencia deportiva mantiene snapshots con identidad y hash propios.

## Shortlist y reporte

El shortlist procede únicamente del pool físico `SPORTS_CANDIDATE`; no puede derivarse de párrafos narrativos. Con pool >=2 se requieren dos principales y un tercero solo de forma excepcional.

El estado físico del reporte se deriva de `nrfimetrica_game_dual_status`, `nrfimetrica_user_action` y `nrfimetrica_sports_shortlists` mediante `nrfimetrica_build_report_snapshot_v18()`.

Sin packet, la representación fail-closed es:

`SPORTS_STATUS=WATCHLIST / PROCESS_STATUS=MISSING / USER_ACTION=DO_NOT_BET`.

El reporte no puede elevar manualmente ese estado a `NRFI_LEAN`, `NO_PLAY` o `SPORTS_CANDIDATE`.

## Firewall económico

La reparación no suaviza la autoridad económica. Mientras falten un motor numérico game-specific `ACTIVE_TRUSTED`, auditor independiente `ACTIVE_TRUSTED`, auditoría certificada de confiabilidad, A7 release y A8 válido:

`BET_APPROVED = FALSE`.

Está prohibido fabricar P(NRFI), edge, EV o calibrated_probability por IA.

## Secuencia de migraciones

Las correcciones recientes son:

- `069_nrfimetrica_v17_self_audit_hardening.sql`
- `070_nrfimetrica_v17_unresolved_reanalysis_assertion.sql`
- `071_nrfimetrica_v17_lock_client_dml_views.sql`
- `072_nrfimetrica_v17_activate_after_terminal_audit.sql`
- `073_nrfimetrica_v18_forensic_process_repair.sql`

La corrida `NRFIM-MOTHER-20260820-ead3b6f3` permanece sin modificación retroactiva y conserva su condición histórica incompleta. La reparación aplica a nuevas invocaciones.

Notion continúa como consulta solamente. `@NRFIprensa` no posee autoridad deportiva, probabilística, de ranking, de mercado ni de conclusión.

**EL PARTIDO SE ANALIZA. EL SISTEMA SE CALIBRA. EL REPORTE SOLO DECLARA LO QUE EXISTE FÍSICAMENTE.**
