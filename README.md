# @NRFImetrica

Agente causal para primera entrada MLB gobernado por `MOTHER V3`.

## Autoridad vigente

- `SYSTEM_VERSION = NRFIM MOTHER V3`
- `AGENT_VERSION = MOTHER-V3-AGENT-1.11`
- `KERNEL_VERSION = NRFIM-KERNEL-1.6-PREANALYSIS-COGNITIVE-GUARD`
- `PROTOCOL_ID = NRFIMETRICA_MOTHER_V3_AUTONOMOUS`
- `MOTHER_DOCUMENT_SHA256 = 44edaa44707293115f8d129b8903c1d8f7dfa5f6bd79674de29cee01091228d8`
- `STATUS = ACTIVE`
- `REAL_MONEY_AUTHORITY = FALSE`
- migraciones requeridas hasta `068`.

La IA decide deportivamente mediante razonamiento causal. El Kernel controla proceso, linaje, estados, evidencia, temporalidad y límites de autoridad; no suma métricas ni sustituye al analista.

## A0P — información externa antes del análisis

`A0 → A0P_PRESS_INFORMATION_INTAKE → A1 → A2 → A3 → A4 → A5 → A6 → A7 → A8`

A0P prepara **solo el lado receptor de @NRFImetrica**. Esta arquitectura no modifica `@NRFIprensa`.

Si existe un paquete limpio de Prensa, entra únicamente como `INFORMATION_FOR_ANALYSIS` con:

- `SPORTS_AUTHORITY = NONE`
- `PROBABILITY_AUTHORITY = NONE`
- `RANKING_AUTHORITY = NONE`
- `MARKET_AUTHORITY = NONE`
- `CONCLUSION_AUTHORITY = NONE`

Si no existe paquete, A0P puede cerrar `SKIPPED_NOT_TRIGGERED` y Métrica continúa autónomamente. Cada item recibido necesita `MATERIALITY_QUESTION` y disposición explícita de Métrica. Un delta material obliga a reconstrucción causal desde la fase propietaria; nunca permite override externo del Sports Verdict.

## Constitución cognitiva

`THE PROTOCOL DEFINES THE FLOOR OF COVERAGE, NOT THE CEILING OF ANALYSIS.`

`COGNITIVE-1.0` exige representación provisional revisable, preguntas autónomas ante fricción material, análisis bilateral independiente, causal bottleneck por media entrada, compresión epistemológica, mejor rival respaldado, second-pass review, directional-bias check y semantic reclassification. Posibilidad no equivale a materialización e importancia no equivale a confianza.

## Calibrar el sistema != calibrar el partido

`GAME_CAUSAL_P = A5_GAME_CAUSAL_ONLY`.

`SYSTEM_RELIABILITY_AUDIT` puede detectar `RELIABLE`, `OVERCONFIDENT`, `UNDERCONFIDENT`, `MIXED`, `INSUFFICIENT_SAMPLE`, `DRIFT_DETECTED` o `NOT_AVAILABLE`, pero siempre mantiene:

- `SPORTS_EFFECT = NONE`
- `RANKING_EFFECT = NONE`
- `PROBABILITY_EFFECT = NONE`

La historia puede limitar autoridad económica del sistema mediante `ALLOW / CONDITION / BLOCK`; nunca cambia la probabilidad causal del juego. `p_conservative` procede únicamente de incertidumbre específica del partido mediante `GAME_SPECIFIC_STRESS_TEST`.

## A7 y A8

A7 = `SYSTEM RELIABILITY AUDIT + PRESS INTEGRATION AUDIT + ABSOLUTE ELIGIBILITY`.

A7 no reformula el Sports Verdict. `REANALYSIS_REQUIRED=TRUE` bloquea `RELEASE_TOKEN=ISSUED` hasta una nueva versión causal.

A8 abre mercado y valor por primera vez. La fuente histórica está prohibida como probabilidad del partido y el lower bound debe conservar linaje exacto desde `game_uncertainty`.

## Bilateralidad

`NRFI = TOP_1ST_NO_RUN AND BOTTOM_1ST_NO_RUN`.

No hay compensación entre medias entradas.

## Reproducibilidad y validación

Reforma versionada:

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

La duplicidad accidental del prefijo `062` fue eliminada. El hardening que contenía quedó canonizado en `067`; la secuencia activa vuelve a tener un único `062`.

Validación terminal vigente: `V16_POST_067_AUDIT = 12/12 PASS`. La prueba de la aserción A8 usada por producción quedó `4/4 PASS` y la batería adversarial corregida `5/5 PASS`. Seguridad: `SECURITY_DEFINER=0`, `MISSING_SAFE_SEARCH_PATH=0`, `CLIENT_EXECUTABLE_FUNCTIONS=0`; todas las tablas propias `nrfimetrica_%` tienen RLS y cero DML para `anon/authenticated`.

Cinco resultados históricos `HARNESS_ERROR/22P02` se conservaron por trazabilidad; cada uno tiene su prueba corregida equivalente `PASS` y no representa un fallo del Kernel. Durante la auditoría también se detectó una referencia A8 a una aserción faltante; fue corregida y la ruta real de producción se volvió a probar `4/4 PASS` antes de la activación final.

Notion se usa únicamente como fuente de consulta en esta reforma. `@NRFIprensa` no fue modificado: Métrica solo quedó preparada para recibir información futura sin heredar autoridad decisional.

**El partido se analiza. El sistema se calibra.**
