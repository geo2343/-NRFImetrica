# @NRFImetrica

Agente causal para primera entrada MLB gobernado por `MOTHER V3`.

## Autoridad vigente

- `SYSTEM_VERSION = NRFIM MOTHER V3`
- `AGENT_VERSION = MOTHER-V3-AGENT-1.12`
- `KERNEL_VERSION = NRFIM-KERNEL-1.7-SELF-AUDIT-HARDENED`
- `PROTOCOL_ID = NRFIMETRICA_MOTHER_V3_AUTONOMOUS`
- `MOTHER_DOCUMENT_SHA256 = 799ccb5a483e7991f880ae7d49d2f191a98e292478ec64e76a55aa8250ec498b`
- `STATUS = DISABLED` mientras se ejecuta la auditoría terminal posterior a 071.
- `REAL_MONEY_AUTHORITY = FALSE`
- migraciones requeridas hasta `071`.

La IA decide deportivamente mediante razonamiento causal. El Kernel controla proceso, linaje, evidencia, temporalidad y límites de autoridad; no suma métricas ni sustituye al analista.

## A0P — información externa antes del análisis

`A0 → A0P_PRESS_INFORMATION_INTAKE → A1 → A2 → A3 → A4 → A5 → A6 → A7 → A8`

A0P prepara solo el lado receptor de `@NRFImetrica`; esta reforma no modifica `@NRFIprensa`. Un paquete externo entra únicamente como `INFORMATION_FOR_ANALYSIS` y mantiene `SPORTS/PROBABILITY/RANKING/MARKET/CONCLUSION_AUTHORITY = NONE`. Si no existe paquete, A0P puede quedar `SKIPPED_NOT_TRIGGERED` y Métrica continúa autónomamente.

Desde Kernel 1.7, `RECEIVED_VALIDATED` requiere provenance física mediante un `research_tool_event` receptor `KERNEL_ATTESTED`, mismo RUN/GAME y `response_hash = source_packet_hash`. Un `source_receipt` autoconsistente no basta. El productor solo puede declarar `EMPTY_PACKET`; la materialidad la decide Métrica.

## Constitución cognitiva

`THE PROTOCOL DEFINES THE FLOOR OF COVERAGE, NOT THE CEILING OF ANALYSIS.`

`COGNITIVE-1.0` exige representación provisional revisable, análisis bilateral independiente, causal bottleneck por media entrada, compresión epistemológica, búsqueda adversarial, second-pass review, directional-bias check y semantic reclassification. Si no existe rival YRFI suficientemente respaldado, se permite `NO_SUPPORTED_RIVAL` únicamente con búsqueda y evidencia documentadas; está prohibido inventar una ruta rival para llenar un campo.

## Calibrar el sistema != calibrar el partido

`GAME_CAUSAL_P` pertenece al partido y procede del motor causal del RUN actual. `SYSTEM_RELIABILITY_AUDIT` audita al sistema, no al juego.

Un estado `RELIABLE / OVERCONFIDENT / UNDERCONFIDENT / MIXED / INSUFFICIENT_SAMPLE / DRIFT_DETECTED` requiere una fila física sellada de `nrfimetrica_system_calibration_audits` para el mismo `MODEL_VERSION + TARGET_ID`. Sin audit válido, el único estado permitido es `NOT_AVAILABLE` con `ECONOMIC_EFFECT=BLOCK`. Siempre se exige `SPORTS_EFFECT=NONE`, `RANKING_EFFECT=NONE` y `PROBABILITY_EFFECT=NONE`.

## A7 y A8

A7 = `SYSTEM RELIABILITY AUDIT + PRESS INTEGRATION AUDIT + ABSOLUTE ELIGIBILITY`.

`PRESS_UNRESOLVED_COUNT > 0` obliga `REANALYSIS_REQUIRED=TRUE` y bloquea `RELEASE_TOKEN=ISSUED`. Un delta material reconstruye desde la fase causal propietaria; nunca produce override directo del Sports Verdict.

Kernel 1.7 aplica `TARGET FIREWALL`: la ejecutabilidad está certificada únicamente para `NRFI / U0.5`. U1.5 y U2.5 pueden estudiarse, pero no recibir `RELEASE / EXECUTION / APOSTAR` hasta disponer de certificación A7 target-specific separada.

A8 exige lineage exacto desde A7, proceso `PASS`, hash Drive/packet verificado, bilateralidad válida, lower bound específico del juego y coherencia entre `EXECUTION_AUTHORITY` y `FINAL_VERDICT`. Una etiqueta `APOSTAR` aislada no crea ejecutabilidad.

## Prohibición de probabilidad fabricada

Ninguna fase A0P–A8 puede introducir `ai_estimate`, `ai_probability`, `ai_nrfi_estimate` o `calibrated_probability` inventada. La IA interpreta la probabilidad; no la fabrica.

## Reproducibilidad

Secuencia principal de la reforma vigente:

- `059_nrfimetrica_preanalysis_press_intake_v16.sql`
- `060_nrfimetrica_cognitive_press_integration_v16.sql`
- `061_nrfimetrica_agent_1_11_kernel_1_6_authority_reconcile.sql`
- `062_nrfimetrica_a8_shared_assertion_layer.sql`
- `063_nrfimetrica_security_and_guard_dedup.sql`
- `064_nrfimetrica_a5_causal_language_alignment.sql`
- `065_nrfimetrica_v16_runtime_reconcile_exact.sql`
- `066_nrfimetrica_v16_activate_after_terminal_audit.sql`
- `067_nrfimetrica_v16_canonicalize_hardening_and_disable_for_reaudit.sql`
- `068_nrfimetrica_v16_activate_after_post067_reaudit.sql`
- `069_nrfimetrica_v17_self_audit_hardening.sql`
- `070_nrfimetrica_v17_unresolved_reanalysis_assertion.sql`
- `071_nrfimetrica_v17_lock_client_dml_views.sql`

La auditoría post-activación detectó dos brechas ejecutables y las registró como `GAP_CONFIRMED`, no como PASS. Después de 069/070, la batería adversarial específica quedó `12/12 PASS`. La auditoría terminal posterior a 071 permanece como requisito de activación.

Notion sigue siendo consulta solamente. `@NRFIprensa` no fue modificado.

**El partido se analiza. El sistema se calibra.**
