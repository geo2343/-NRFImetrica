# @NRFImetrica

Agente técnico-estadístico y causal para primera entrada MLB, gobernado por el **DOCUMENTO MADRE MOTHER V3** y protegido por un Kernel externo.

## Autoridad activa

- `SYSTEM_VERSION = NRFIM MOTHER V3`
- `AGENT_VERSION = MOTHER-V3-AGENT-1.3`
- `KERNEL_VERSION = NRFIM-KERNEL-0.8-DUAL-STATUS`
- `PROTOCOL_ID = NRFIMETRICA_MOTHER_V3_AUTONOMOUS`
- extensiones obligatorias: `NRFIMETRICA_SPORTS_REASONING_PACKET_V2` y `NRFIMETRICA_DUAL_STATUS_V1`
- `MOTHER_DOCUMENT_SHA256 = d16896eba602af272117a5c83b56245aa201979d394301781d424e705b3642d3`
- `MANUAL_PHASE_AUTHORIZATION_REQUIRED = FALSE`
- `SYSTEM_STATE = TRADING_HALT_RESEARCH`
- `REAL_MONEY_AUTHORITY = FALSE`

V2.1/V1.x se conservan exclusivamente como histórico y no tienen autoridad runtime.

## Arquitectura

- **Documento Madre = constitución.**
- **ChatGPT/IA = analista causal.** Investiga, interpreta, compara NRFI contra la mejor tesis YRFI, falsifica y toma posición. No fabrica probabilidades.
- **Kernel = enforcement.** Controla orden, evidencia, timestamps, hashes, freeze, clean room, estado y cierre; no decide el partido mediante un score.
- **Supabase = estado técnico persistente y enforcement físico.**
- **Drive = expediente humano-legible, snapshots y hashes.**
- **GitHub = código, manifests, migraciones y pruebas.**
- **Vercel = runtime HTTP cuando el despliegue está disponible.**
- **@NRFIprensa = agente separado.** No funciona como voto.

## CLEAN ROOM

Cada nueva invocación debe crear:

`RUN_ID NUEVO + INVOCATION_ID NUEVO + DOCUMENTO DRIVE NUEVO + BÚSQUEDAS NUEVAS + EVIDENCIA NUEVA + RAZONAMIENTO NUEVO`.

Reportes, packets o razonamiento de una corrida anterior no pueden utilizarse como evidencia deportiva de la nueva corrida. El documento de reporte propio debe existir antes del primer `SPORTS_REASONING_PACKET`.

## SPORTS_REASONING_PACKET V2

Cada juego tiene su propio packet. Cadena física:

`TOOL EVENT -> SOURCE FAMILY -> EVIDENCE + SNAPSHOT/HASH -> CLAIM -> CAUSAL REASONING -> NRFI vs YRFI -> FALSIFICATION -> SPORTS VERDICT -> FREEZE/HASH -> DRIVE -> PROCESS AUDIT`.

Un `ANALYSIS_COMPLETE` exige análisis bilateral `TOP_1ST/BOTTOM_1ST`, abridores actuales, top order, especificidad de primera entrada, contraevidencia, caso NRFI, mejor rival YRFI, clusters causales, falsificación de ambos lados y `what_would_change`.

Pisos iniciales de familias independientes: `CLEAR=3`, `NORMAL=5`, `DEEP=7`. Son pisos, no techos.

Auditor determinista de proceso: `KERNEL_PROCESS_AUDITOR_0.2`. Deriva sus controles desde la base y tiene prohibido votar NRFI/YRFI.

## Kernel 0.8 — doble estado: deporte vs ejecución

El error que Kernel 0.8 corrige es confundir una carencia técnica posterior con una conclusión deportiva.

**Eje deportivo:**

- `SPORTS_CANDIDATE` — `NRFI_LEAN` auditado con `ANALYSIS_COMPLETE + PROCESS PASS + DRIVE HASH MATCH`.
- `NO_PLAY` — rechazo deportivo para el producto NRFI; el `sports_verdict` original se conserva, por ejemplo `YRFI_LEAN`.
- `WATCHLIST` — investigación incompleta o información gobernante todavía insuficiente.
- `AUDIT_ONLY` — partido fuera de ventana pregame.

**Eje de ejecución:**

- `EXECUTABLE` — A8 emitió `APOSTAR` o `SOLO_SI_CUOTA` con autoridad real.
- `TECHNICAL_BLOCK` — existe `SPORTS_CANDIDATE`, pero A4/A6/A7 impiden ejecución real-money.
- `PENDING` — candidato deportivo cuya cadena técnica todavía no ha terminado.
- `NOT_APPLICABLE` — no existe candidato deportivo NRFI.
- `WATCHLIST` / `AUDIT_ONLY` — conservan su condición correspondiente.

Regla clave:

`SPORTS_CANDIDATE + TECHNICAL_BLOCK` es un estado válido.

Un `A4_ENGINE_NOT_INTEGRATED` **no puede** reescribir un candidato deportivo como `NO_PLAY`.

`eligible_count` en A7 significa únicamente **elegibilidad de ejecución**, nunca calidad deportiva.

## Reporte final obligatorio

Todo reporte final nuevo debe separar físicamente:

- `sports_candidate_count`;
- `execution_candidate_count`;
- `sports_no_play_count`;
- `sports_watchlist_count`;
- `sports_audit_only_count`;
- `technical_block_count`.

Además debe listar:

- las identidades exactas de `sports_candidates`;
- `game_statuses` para todos los juegos del RUN con `sports_status`, `execution_status` y `sports_verdict`.

Supabase valida esas identidades contra `public.nrfimetrica_game_dual_status`; la IA no puede inventar el conteo ni sustituir un candidato real por otro juego.

Si existen candidatos deportivos pero cero ejecutables, el reporte debe declarar:

`TECHNICAL_BLOCK_NOT_SPORTS_REJECTION`.

No puede presentar `0 elegibles` como si significara que la IA rechazó deportivamente toda la jornada.

## Flujo de certificación

La cadena contractual sigue intacta:

`A0 -> SPORTS_REASONING_SLATE -> A1 -> A2 -> A3 -> A4 -> A5 -> A6 -> A7 -> A8 -> PORTFOLIO -> FINAL_REPORT -> DRIVE VERIFIED -> CLOSE`.

A4 sigue siendo el dueño de la probabilidad RAW y no puede ser simulado. A5 integra `P0/P1/P2/P3+`. A6/A7/A8 siguen controlando auditoría independiente, calibración, prensa, mercado, edge/EV y ejecución.

Kernel 0.8 **no baja los controles de dinero real**. Solo impide que esos controles borren el juicio deportivo ya demostrado.

## Pruebas físicas de la reforma 0.8

La corrida histórica `NRFIM-MOTHER-20260819-99cf2c30`, antes reportada ambiguamente como `0 elegibles`, queda representada por la vista física así:

- 3 `SPORTS_CANDIDATE + TECHNICAL_BLOCK`: CWS@CHC, NYY@BAL, SEA@MIL.
- 6 `NO_PLAY` para el producto NRFI, preservando sus verdicts deportivos.
- 3 `WATCHLIST`.
- 3 `AUDIT_ONLY`.
- 0 `EXECUTABLE`.

Pruebas adversariales de Kernel 0.8:

- intentar declarar `sports_candidate_count=0` cuando la base deriva 3 -> **BLOQUEADO**;
- intentar insertar una identidad falsa dentro de `sports_candidates` -> **BLOQUEADO**.

## Estado real actual

- Documento Madre: **ACTIVO**.
- Agent 1.3 / Kernel 0.8: **ACTIVOS EN GITHUB Y SUPABASE**.
- Migraciones: **001–027 aplicadas en Supabase**.
- Clean Room: **ACTIVO**.
- Sports Reasoning chain: **ACTIVA**.
- Dual sports/execution status: **ACTIVO**.
- A4 `ACTIVE_TRUSTED`: **0**.
- A6 independent auditor `ACTIVE_TRUSTED`: **0**.
- A7 calibration `ACTIVE_TRUSTED`: **0**.
- `SYSTEM_STATE = TRADING_HALT_RESEARCH`.
- `REAL_MONEY_AUTHORITY = FALSE`.

El sistema puede producir y preservar juicios deportivos auditados aunque la ejecución real-money quede bloqueada. No puede fabricar probabilidades, calibraciones, edge, EV ni autoridad de apuesta inexistentes.
