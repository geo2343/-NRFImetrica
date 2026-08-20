# @NRFImetrica

Agente causal MLB de primera entrada gobernado por `MOTHER V3`.

## Estado vigente

- `SYSTEM_VERSION = NRFIM MOTHER V3`
- `AGENT_VERSION = MOTHER-V3-AGENT-1.12`
- `KERNEL_VERSION = NRFIM-KERNEL-1.7-SELF-AUDIT-HARDENED`
- `PROTOCOL_ID = NRFIMETRICA_MOTHER_V3_AUTONOMOUS`
- `MOTHER_DOCUMENT_SHA256 = 799ccb5a483e7991f880ae7d49d2f191a98e292478ec64e76a55aa8250ec498b`
- `STATUS = ACTIVE`
- `REAL_MONEY_AUTHORITY = FALSE`
- migraciones requeridas hasta `072`.
- `V17_SELF_AUDIT_POST_FIX = 12/12 PASS`.
- `V17_POST_071_TERMINAL_AUDIT = 20/20 PASS`.

La IA realiza el razonamiento deportivo causal. El Kernel controla orden, evidencia, lineage, temporalidad, seguridad y límites de autoridad; no convierte métricas en votos ni sustituye el razonamiento causal.

## Flujo

`A0 → A0P_PRESS_INFORMATION_INTAKE → A1 → A2 → A3 → A4 → A5 → A6 → A7 → A8`

A0P pertenece al lado receptor de `@NRFImetrica`. Esta reforma no modifica `@NRFIprensa`. Todo material externo entra como `INFORMATION_FOR_ANALYSIS` y conserva `SPORTS/PROBABILITY/RANKING/MARKET/CONCLUSION_AUTHORITY = NONE`. Si no existe material, A0P puede quedar `SKIPPED_NOT_TRIGGERED` y Métrica continúa autónomamente.

Un intake validado requiere provenance física mediante evento receptor `KERNEL_ATTESTED`, mismo RUN/GAME y hash coincidente. `EMPTY_PACKET` describe ausencia de items transferibles; la materialidad la decide Métrica.

`UNRESOLVED` obliga a reanálisis y bloquea la liberación económica hasta reconstruir la fase causal correspondiente.

## Calibración

`GAME_CAUSAL_P` pertenece al partido actual. `SYSTEM_RELIABILITY_AUDIT` audita el comportamiento histórico del sistema y no modifica la probabilidad, el ranking ni el Sports Verdict del juego.

Un estado de confiabilidad distinto de `NOT_AVAILABLE` requiere una auditoría física sellada para el mismo `MODEL_VERSION + TARGET_ID`. Sin auditoría válida, el estado es `NOT_AVAILABLE` con `ECONOMIC_EFFECT=BLOCK`.

## Contratos y adversarial

Kernel 1.7 certifica ejecutabilidad únicamente para `U0.5` hasta que U1.5/U2.5 reciban certificación target-specific independiente.

La búsqueda adversarial es obligatoria, pero no obliga a inventar un rival. `NO_SUPPORTED_RIVAL` es válido solo cuando la búsqueda y su evidencia quedan documentadas.

Ninguna fase A0P–A8 puede introducir probabilidades fabricadas por la IA.

## Seguridad y reproducibilidad

Las superficies finales son read-only para clientes; los helpers internos no son RPC de cliente; RLS permanece activo en las tablas propias.

Secuencia vigente de la reforma: migraciones `059` a `072`. Las correcciones principales de esta auditoría son:

- `069_nrfimetrica_v17_self_audit_hardening.sql`
- `070_nrfimetrica_v17_unresolved_reanalysis_assertion.sql`
- `071_nrfimetrica_v17_lock_client_dml_views.sql`
- `072_nrfimetrica_v17_activate_after_terminal_audit.sql`

Los dos defectos demostrados antes de la corrección permanecen registrados como `GAP_CONFIRMED / passed=false`; no fueron reescritos como PASS.

Notion continúa como consulta solamente. `@NRFIprensa` no fue modificado.

**EL PARTIDO SE ANALIZA. EL SISTEMA SE CALIBRA.**
