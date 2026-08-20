# @NRFImetrica

Agente causal para primera entrada MLB gobernado por `MOTHER V3`.

## Autoridad en validación

- `SYSTEM_VERSION = NRFIM MOTHER V3`
- `AGENT_VERSION = MOTHER-V3-AGENT-1.11`
- `KERNEL_VERSION = NRFIM-KERNEL-1.6-PREANALYSIS-COGNITIVE-GUARD`
- `PROTOCOL_ID = NRFIMETRICA_MOTHER_V3_AUTONOMOUS`
- `MOTHER_DOCUMENT_SHA256 = 44edaa44707293115f8d129b8903c1d8f7dfa5f6bd79674de29cee01091228d8`
- `STATUS = DISABLED` hasta cerrar la regresión y auditoría final.
- `REAL_MONEY_AUTHORITY = FALSE`
- migraciones de repositorio requeridas hasta `061` antes de la activación final.

La IA decide deportivamente mediante razonamiento causal. El Kernel controla proceso, linaje, estados, evidencia, temporalidad y límites de autoridad; no suma métricas ni sustituye al analista.

## A0P — reporte externo antes del análisis

`A0 → A0P_PRESS_INFORMATION_INTAKE → A1 → A2 → A3 → A4 → A5 → A6 → A7 → A8`

A0P prepara **solo el lado receptor de @NRFImetrica**. Esta arquitectura no modifica `@NRFIprensa`.

Si existe un paquete limpio de Prensa, entra únicamente como `INFORMATION_FOR_ANALYSIS` con:

- `SPORTS_AUTHORITY = NONE`
- `PROBABILITY_AUTHORITY = NONE`
- `RANKING_AUTHORITY = NONE`
- `MARKET_AUTHORITY = NONE`
- `CONCLUSION_AUTHORITY = NONE`

Si no existe paquete, A0P puede cerrar `SKIPPED_NOT_TRIGGERED` y Métrica continúa autónomamente.

Picks, odds, consenso, ranking, probabilidad externa, edge/EV, recomendaciones y veredictos externos quedan fuera del intake limpio. Cada item debe formular una `MATERIALITY_QUESTION` y terminar con una disposición explícita de Métrica. Un delta material obliga a reconstrucción causal desde la fase propietaria; nunca permite override externo del Sports Verdict.

## Constitución cognitiva

`THE PROTOCOL DEFINES THE FLOOR OF COVERAGE, NOT THE CEILING OF ANALYSIS.`

El contrato `COGNITIVE-1.0` exige:

- representación provisional y revisable;
- preguntas autónomas ante fricción material;
- TOP 1ST y BOTTOM 1ST analizados independientemente;
- causal bottleneck por media entrada;
- compresión epistemológica de métricas correlacionadas;
- mejor rival YRFI respaldado, no colección ilimitada de miedos;
- second-pass review;
- directional-bias check sin fabricar balance artificial;
- semantic reclassification cuando cambia el significado de evidencia anterior;
- posibilidad != materialización;
- importancia != confianza.

## Calibrar el sistema != calibrar el partido

`GAME_CAUSAL_P = A5_GAME_CAUSAL_ONLY`.

La historia no reemplaza la probabilidad del juego. `SYSTEM_RELIABILITY_AUDIT` puede detectar `RELIABLE`, `OVERCONFIDENT`, `UNDERCONFIDENT`, `MIXED`, `INSUFFICIENT_SAMPLE`, `DRIFT_DETECTED` o `NOT_AVAILABLE`, pero siempre mantiene:

- `SPORTS_EFFECT = NONE`
- `RANKING_EFFECT = NONE`
- `PROBABILITY_EFFECT = NONE`

Su único efecto permitido sobre ejecución es `ALLOW / CONDITION / BLOCK` a nivel de confiabilidad del sistema.

`p_conservative` significa el límite inferior de incertidumbre específica del juego y su fuente obligatoria es `GAME_SPECIFIC_STRESS_TEST_ONLY`. Dos juegos no se consideran equivalentes por compartir probabilidad, score, banda o perfil estadístico.

## A7 y A8

A7 es ahora `SYSTEM RELIABILITY AUDIT + PRESS INTEGRATION AUDIT + ABSOLUTE ELIGIBILITY`.

A7 no ve precio y no reformula el Sports Verdict. `REANALYSIS_REQUIRED=TRUE` bloquea `RELEASE_TOKEN=ISSUED` hasta una nueva versión causal del análisis.

A8 abre el mercado por primera vez y utiliza `GAME_SPECIFIC_LOWER_BOUND` para robust edge. La fuente histórica está prohibida como probabilidad del partido.

## Bilateralidad

NRFI continúa siendo:

`TOP_1ST_NO_RUN AND BOTTOM_1ST_NO_RUN`

No hay compensación entre medias entradas. Una mitad excelente nunca compensa una mitad que no pasa su análisis causal.

## Reproducibilidad

Migraciones nuevas:

- `059_nrfimetrica_preanalysis_press_intake_v16.sql`
- `060_nrfimetrica_cognitive_press_integration_v16.sql`
- `061_nrfimetrica_agent_1_11_kernel_1_6_authority_reconcile.sql`

El Documento Madre, Supabase y GitHub deben compartir exactamente la identidad 1.11/1.6 y SHA-256 antes de activación. Notion se usa únicamente como fuente de consulta y no forma parte de las superficies autorizadas de escritura de esta reforma.

**El partido se analiza. El sistema se calibra.**
