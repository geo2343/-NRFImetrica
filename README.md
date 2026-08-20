# @NRFImetrica

Agente causal para primera entrada MLB gobernado por `MOTHER V3`.

## Autoridad activa

- `SYSTEM_VERSION = NRFIM MOTHER V3`
- `AGENT_VERSION = MOTHER-V3-AGENT-1.10`
- `KERNEL_VERSION = NRFIM-KERNEL-1.5-CALIBRATION-SEPARATION`
- `PROTOCOL_ID = NRFIMETRICA_MOTHER_V3_AUTONOMOUS`
- `MOTHER_DOCUMENT_SHA256 = d16896eba602af272117a5c83b56245aa201979d394301781d424e705b3642d3`
- `REAL_MONEY_AUTHORITY = FALSE`
- migraciones de repositorio requeridas hasta `056`

La IA decide deportivamente mediante razonamiento causal. El Kernel controla proceso, linaje, estados, evidencia y límites de autoridad; no suma métricas ni sustituye al analista.

## Principio soberano: calibrar el sistema != calibrar el partido

La probabilidad deportiva de un juego pertenece al juego actual:

`GAME_CAUSAL_P = A5_GAME_CAUSAL_ONLY`

No puede ser reemplazada por una frecuencia histórica, bin, score, banda, perfil estadístico ni grupo de partidos supuestamente equivalentes.

Reglas soberanas:

- `HISTORICAL_CALIBRATION SHALL NOT OVERRIDE GAME-SPECIFIC CAUSAL EVIDENCE`.
- Dos juegos no son equivalentes solo por compartir probabilidad, score, banda o perfil estadístico.
- La calibración histórica tiene `SPORTS_EFFECT=NONE`, `RANKING_EFFECT=NONE` y `PROBABILITY_EFFECT=NONE`.
- La calibración no crea ni elimina `SPORTS_CANDIDATE`.
- La calibración no modifica el ranking deportivo.
- La calibración no ajusta `GAME_CAUSAL_P`.
- Puede únicamente auditar la fiabilidad estructural del sistema y, si corresponde, `ALLOW / CONDITION / BLOCK` autoridad económica a nivel de sistema.

Documento soberano de la reforma en Drive:

`00A — ENMIENDA SOBERANA — CALIBRAR EL SISTEMA ≠ CALIBRAR EL PARTIDO — @NRFImetrica`

Drive ID: `1Z-nLDwL4eQIgMFFt8Gltsut6MrqhTW8x7pEf6ZB9jnE`

## Orden de análisis

`razonamiento causal individual → análisis bilateral → matchup secuencial → falsación adversarial → incertidumbre específica del partido → GAME_CAUSAL_P / Sports Seal → auditoría histórica externa del sistema`

La historia audita a `@NRFImetrica`; no obliga al juego de hoy a parecerse al promedio de ayer.

## Incertidumbre y robust edge

Se conserva `p_conservative` por compatibilidad de contrato, pero su significado es ahora exclusivamente:

`p_conservative = límite inferior de incertidumbre específica del partido`

Fuente obligatoria:

`GAME_SPECIFIC_STRESS_TEST_ONLY`

No puede proceder de calibración histórica. Puede reflejar lineup, scratches, velocidad/comando/release del abridor, estado físico, compatibilidad bateador-arsenal, BB/HBP, viento, roof, clima y otras perturbaciones causalmente propias del encuentro.

`ROBUST_EDGE = GAME_SPECIFIC_LOWER_BOUND - MARKET_BREAK_EVEN`

La historia no participa en ese lower bound.

## Auditoría histórica del sistema

Objetos físicos:

- `public.nrfimetrica_system_calibration_audits`
- `public.nrfimetrica_calibration_observations`

Puede utilizar Brier Score, Log Loss, reliability curve, calibration slope/intercept, walk-forward validation, sealed temporal holdout, baseline comparison, ablation, drift y diagnóstico de overconfidence/underconfidence. Son auditoría del sistema, no votos del partido.

La calibración debe ser jerárquica/contextual cuando la muestra lo permita. No existe calibración universal con derecho a homologar partidos heterogéneos.

## Bilateralidad NRFI

NRFI continúa siendo:

`TOP_1ST_NO_RUN AND BOTTOM_1ST_NO_RUN`

No existe compensación entre medias entradas. La primera entrada se estudia como secuencia causal: abridor actual, arsenal/command, top order, B1-B4, platoon/matchup, tráfico, poder, parque/entorno y rutas concretas de materialización.

## SPORTS_STATUS

- `SPORTS_CANDIDATE`
- `NO_PLAY`
- `WATCHLIST`
- `AUDIT_ONLY`

Un problema de proceso, calibración o ejecución puede bloquear dinero real, pero no puede fabricar ni borrar retrospectivamente el juicio deportivo.

## Shortlist

El pool bruto no es la conclusión final. El sistema discrimina causalmente hasta dos candidatos principales y un tercero opcional excepcional. No se usa score aditivo para decidir la shortlist.

## Clean Room

Cada invocación nueva exige:

`RUN nuevo + INVOCATION_ID nuevo + documento Drive nuevo + fuentes nuevas + evidencia nueva + razonamiento nuevo`

No se reutilizan conclusiones deportivas previas como evidencia del juego actual.

## Enforcement

A7 está gobernado por:

`public.nrfim_enforce_calibration_separation_v15()`

Exige `game_probability_source=A5_GAME_CAUSAL_ONLY`, `eligibility_basis=GAME_CAUSAL_ONLY`, `calibration_role=SYSTEM_AUDIT_ONLY`, cero autoridad deportiva/ranking/probabilidad de la calibración, `historical_calibration_used=false` y lower bounds del `GAME_SPECIFIC_STRESS_TEST`.

A8 tiene además una segunda barrera independiente:

`public.nrfim_assert_game_specific_conservative_probability()`

Exige `market.p_conservative_source=GAME_SPECIFIC_UNCERTAINTY_ONLY`, igualdad exacta con el lower bound del juego y bloquea cualquier `historical_adjusted_p` o equivalente.

## Pruebas adversariales ejecutadas

- A7 limpio `SYSTEM_AUDIT_ONLY` → `ACCEPTED`.
- `contract_calibration.u0_5.calibrated_p` → bloqueado con `A7_HISTORICAL_GAME_PROBABILITY_OVERRIDE_FORBIDDEN`.
- certificación con `sports_authority=true` → bloqueada con `NRFIM_CALIBRATION_MUST_BE_SYSTEM_AUDIT_ONLY`.
- auditoría histórica intentando efecto deportivo → bloqueada por constraint.
- A8 lower bound actual + fuente actual → `ACCEPTED`.
- A8 fuente `HISTORICAL_CALIBRATION` → bloqueada con `A8_P_CONSERVATIVE_SOURCE_MUST_BE_GAME_SPECIFIC`.
- A8 valor distinto al stress-test lower bound → bloqueado con `A8_P_CONSERVATIVE_NOT_FROM_GAME_SPECIFIC_UNCERTAINTY`.
- A8 `historical_adjusted_p` → bloqueado con `A8_HISTORICAL_GAME_PROBABILITY_OVERRIDE_FORBIDDEN`.

No existía ningún A7 histórico con `release_token=ISSUED`; por eso la validación de la regla A8 se hizo sobre la función de aserción que ejecuta el trigger real, sin fabricar una corrida económica histórica inexistente.

## Migraciones recientes

- `053_reconcile_deployed_semantic_custody_runtime.sql`: marcador fail-fast de la divergencia histórica GitHub/Supabase.
- `054_calibrate_system_not_game.sql`: separación física entre partido y auditoría histórica.
- `055_fix_calibration_separation_digest_search_path.sql`: corrección del search path descubierta adversarialmente.
- `056_enforce_a8_game_specific_uncertainty_only.sql`: aserción independiente de que A8 usa exclusivamente incertidumbre del juego actual.

**El partido se analiza. El sistema se calibra.**
