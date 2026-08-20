# @NRFImetrica

Agente causal para primera entrada MLB gobernado por `MOTHER V3`.

## Autoridad activa

- `SYSTEM_VERSION = NRFIM MOTHER V3`
- `AGENT_VERSION = MOTHER-V3-AGENT-1.10`
- `KERNEL_VERSION = NRFIM-KERNEL-1.5-CALIBRATION-SEPARATION`
- `PROTOCOL_ID = NRFIMETRICA_MOTHER_V3_AUTONOMOUS`
- `MOTHER_DOCUMENT_SHA256 = 391fbdfdf78965f9454307267f7e3d048abc7ccb4329e29870ad58aeabcb55f1`
- `REAL_MONEY_AUTHORITY = FALSE`
- migraciones de repositorio requeridas hasta `058`

La IA decide deportivamente mediante razonamiento causal. El Kernel controla proceso, linaje, estados, evidencia y límites de autoridad; no suma métricas ni sustituye al analista.

## Principio soberano: calibrar el sistema != calibrar el partido

`GAME_CAUSAL_P = A5_GAME_CAUSAL_ONLY`

La probabilidad deportiva de un juego no puede ser reemplazada por una frecuencia histórica, bin, score, banda, perfil estadístico ni grupo de partidos supuestamente equivalentes.

Reglas soberanas:

- `HISTORICAL_CALIBRATION SHALL NOT OVERRIDE GAME-SPECIFIC CAUSAL EVIDENCE`.
- Dos juegos no son equivalentes solo por compartir probabilidad, score, banda o perfil estadístico.
- La calibración histórica tiene `SPORTS_EFFECT=NONE`, `RANKING_EFFECT=NONE` y `PROBABILITY_EFFECT=NONE`.
- La calibración no crea ni elimina `SPORTS_CANDIDATE`.
- La calibración no modifica ranking deportivo ni `GAME_CAUSAL_P`.
- Solo puede auditar la fiabilidad estructural del sistema y, si corresponde, `ALLOW / CONDITION / BLOCK` autoridad económica a nivel de sistema.

Documento soberano complementario:

`00A — ENMIENDA SOBERANA — CALIBRAR EL SISTEMA ≠ CALIBRAR EL PARTIDO — @NRFImetrica`

Drive ID: `1Z-nLDwL4eQIgMFFt8Gltsut6MrqhTW8x7pEf6ZB9jnE`

## Orden de análisis

`razonamiento causal individual → análisis bilateral → matchup secuencial → falsación adversarial → incertidumbre específica del partido → GAME_CAUSAL_P / Sports Seal → auditoría histórica externa del sistema`

La historia audita a `@NRFImetrica`; no obliga al juego de hoy a parecerse al promedio de ayer.

## Incertidumbre y robust edge

`p_conservative` se conserva por compatibilidad contractual, pero ahora significa exclusivamente:

`p_conservative = límite inferior de incertidumbre específica del partido`

Fuente obligatoria: `GAME_SPECIFIC_STRESS_TEST_ONLY`.

Puede reflejar lineup, scratches, velocidad/comando/release, estado físico, compatibilidad bateador-arsenal, BB/HBP, viento, roof, clima y otras perturbaciones causalmente propias del juego actual.

`ROBUST_EDGE = GAME_SPECIFIC_LOWER_BOUND - MARKET_BREAK_EVEN`

La historia no participa en ese lower bound.

## Auditoría histórica del sistema

Objetos físicos:

- `public.nrfimetrica_system_calibration_audits`
- `public.nrfimetrica_calibration_observations`

Puede utilizar Brier Score, Log Loss, reliability curve, calibration slope/intercept, walk-forward validation, sealed temporal holdout, baseline comparison, ablation, drift y diagnóstico de overconfidence/underconfidence. Son auditoría del sistema, no votos del partido.

La calibración será jerárquica/contextual cuando la muestra lo permita. No existe calibración universal con derecho a homologar partidos heterogéneos.

## Enforcement

A7: `public.nrfim_enforce_calibration_separation_v15()`.

Exige `game_probability_source=A5_GAME_CAUSAL_ONLY`, `eligibility_basis=GAME_CAUSAL_ONLY`, `calibration_role=SYSTEM_AUDIT_ONLY`, cero autoridad deportiva/ranking/probabilidad de la calibración, `historical_calibration_used=false` y lower bounds derivados de `GAME_SPECIFIC_STRESS_TEST`.

A8: `public.nrfim_assert_game_specific_conservative_probability()` más el trigger `public.nrfim_a8_game_specific_uncertainty_guard()`.

Exige `market.p_conservative_source=GAME_SPECIFIC_UNCERTAINTY_ONLY`, igualdad exacta con el lower bound del juego y bloquea `historical_adjusted_p` y equivalentes.

## Pruebas adversariales ejecutadas

- A7 limpio `SYSTEM_AUDIT_ONLY` → `ACCEPTED`.
- `contract_calibration.u0_5.calibrated_p` → bloqueado.
- certificación con `sports_authority=true` → bloqueada.
- auditoría histórica intentando efecto deportivo → bloqueada.
- A8 lower bound actual + fuente actual → `ACCEPTED`.
- A8 fuente histórica → bloqueada.
- A8 valor distinto al stress-test lower bound → bloqueado.
- A8 `historical_adjusted_p` → bloqueado.

No existía ningún A7 histórico con `release_token=ISSUED`; la regla A8 se validó sobre la función de aserción que ejecuta el trigger real, sin fabricar una corrida económica histórica inexistente.

## Bilateralidad y clean room

NRFI continúa siendo `TOP_1ST_NO_RUN AND BOTTOM_1ST_NO_RUN`, sin compensación entre medias entradas. Cada invocación nueva exige `RUN nuevo + INVOCATION_ID nuevo + documento Drive nuevo + fuentes nuevas + evidencia nueva + razonamiento nuevo`.

## Migraciones recientes

- `053_reconcile_deployed_semantic_custody_runtime.sql`
- `054_calibrate_system_not_game.sql`
- `055_fix_calibration_separation_digest_search_path.sql`
- `056_enforce_a8_game_specific_uncertainty_only.sql`
- `057_refresh_mother_authority_hash_after_calibration_amendment.sql`
- `058_seal_mother_hash_refresh_and_reactivate.sql`

La 057 desactiva de forma preventiva mientras el nuevo Documento Madre espera readback externo. La 058, ejecutada después del readback SHA-256, actualiza guards/autoridades vivas y reactiva el agente. Los hashes de RUNs y evidencias históricos permanecen intactos.

**El partido se analiza. El sistema se calibra.**
