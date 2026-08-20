# @NRFImetrica

Agente causal para primera entrada MLB gobernado por `MOTHER V3`.

## Autoridad vigente en validación

- `SYSTEM_VERSION = NRFIM MOTHER V3`
- `AGENT_VERSION = MOTHER-V3-AGENT-1.10`
- `KERNEL_VERSION = NRFIM-KERNEL-1.5-CALIBRATION-SEPARATION`
- `PROTOCOL_ID = NRFIMETRICA_MOTHER_V3_AUTONOMOUS`
- `MOTHER_DOCUMENT_SHA256 = d16896eba602af272117a5c83b56245aa201979d394301781d424e705b3642d3`
- `REAL_MONEY_AUTHORITY = FALSE`
- migraciones de repositorio requeridas hasta `055`

La IA decide deportivamente mediante razonamiento causal. El Kernel controla proceso, linaje, estados, evidencia y límites de autoridad; no suma métricas ni sustituye al analista.

## Principio nuevo: calibrar el sistema != calibrar el partido

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

La arquitectura queda:

`razonamiento causal individual → análisis bilateral → matchup secuencial → falsación adversarial → incertidumbre específica del partido → GAME_CAUSAL_P / Sports Seal → auditoría histórica externa del sistema`

La historia audita a `@NRFImetrica`; no obliga al juego de hoy a parecerse al promedio de ayer.

## Incertidumbre y robust edge

Se conserva el campo `p_conservative` por compatibilidad de contrato, pero su significado cambia de forma soberana:

`p_conservative = límite inferior de incertidumbre específica del partido`

Fuente obligatoria:

`GAME_SPECIFIC_STRESS_TEST_ONLY`

No puede proceder de calibración histórica. Puede reflejar perturbaciones plausibles del juego actual: lineup, scratches, velocidad/comando/release del abridor, estado físico, compatibilidad bateador-arsenal, BB/HBP, viento, roof, clima y otros cambios causalmente propios del encuentro.

Por tanto:

`ROBUST_EDGE = GAME_SPECIFIC_LOWER_BOUND - MARKET_BREAK_EVEN`

La historia no participa en ese límite.

## Auditoría histórica del sistema

Objetos físicos nuevos:

- `public.nrfimetrica_system_calibration_audits`
- `public.nrfimetrica_calibration_observations`

La auditoría puede utilizar, fuera del núcleo deportivo individual:

- Brier Score;
- Log Loss;
- reliability curve;
- calibration slope/intercept;
- walk-forward validation;
- sealed temporal holdout;
- baseline comparison;
- ablation;
- drift;
- diagnóstico de overconfidence / underconfidence.

La calibración debe ser jerárquica/contextual cuando la muestra lo permita. No existe calibración universal con derecho a homologar partidos heterogéneos.

## Bilateralidad NRFI

NRFI continúa siendo una conjunción:

`TOP_1ST_NO_RUN AND BOTTOM_1ST_NO_RUN`

No existe compensación entre medias entradas. Un abridor dominante no puede borrar una ruta material de carrera en la otra mitad.

La primera entrada se estudia como secuencia causal: abridor actual, arsenal/command, top order, B1-B4, platoon y matchup, tráfico, poder, parque/entorno y rutas concretas de materialización.

## SPORTS_STATUS

- `SPORTS_CANDIDATE`
- `NO_PLAY`
- `WATCHLIST`
- `AUDIT_ONLY`

Un problema de proceso, calibración o ejecución puede bloquear dinero real, pero no puede fabricar ni borrar retrospectivamente el juicio deportivo.

## Shortlist

El pool bruto no es la conclusión final. El sistema discrimina causalmente hasta:

1. candidato principal #1;
2. candidato principal #2;
3. tercero opcional únicamente si existe justificación excepcional.

No se usa score aditivo para decidir la shortlist.

## Clean Room

Cada invocación nueva exige:

`RUN nuevo + INVOCATION_ID nuevo + documento Drive nuevo + fuentes nuevas + evidencia nueva + razonamiento nuevo`

No se reutilizan conclusiones deportivas previas como evidencia del juego actual.

## Enforcement de calibración

Función activa:

`public.nrfim_enforce_calibration_separation_v15()`

A7 exige:

- `game_probability_source=A5_GAME_CAUSAL_ONLY`;
- `eligibility_basis=GAME_CAUSAL_ONLY`;
- `calibration_role=SYSTEM_AUDIT_ONLY`;
- cero autoridad deportiva/ranking/probabilidad de la calibración;
- `historical_calibration_used=false` en incertidumbre del juego;
- límites conservadores derivados de `GAME_SPECIFIC_STRESS_TEST`.

A8 exige:

- `market.p_conservative_source=GAME_SPECIFIC_UNCERTAINTY_ONLY`;
- igualdad exacta con el lower bound específico del juego generado en A7;
- robust edge/EV derivados de ese lower bound;
- bloqueo explícito de `calibrated_p` o `historical_adjusted_p` como probabilidad del partido.

## Pruebas adversariales ejecutadas

- A7 limpio con calibración `SYSTEM_AUDIT_ONLY` → `ACCEPTED`.
- introducir `contract_calibration.u0_5.calibrated_p` → `A7_HISTORICAL_GAME_PROBABILITY_OVERRIDE_FORBIDDEN`.
- intentar otorgar `sports_authority=true` a una certificación → `NRFIM_CALIBRATION_MUST_BE_SYSTEM_AUDIT_ONLY`.
- intentar que una auditoría histórica produzca efecto deportivo → bloqueado por constraint de base de datos.

No existía ningún A7 histórico con `release_token=ISSUED`, por lo que la prueba de A8 se mantiene separada de cualquier falsa afirmación de una certificación económica histórica inexistente.

## Migraciones recientes

- `053_reconcile_deployed_semantic_custody_runtime.sql`: marcador fail-fast para eliminar la divergencia histórica GitHub/Supabase sin fingir que reconstruye statements que no estaban versionados.
- `054_calibrate_system_not_game.sql`: separación física entre análisis del partido y auditoría histórica del sistema.
- `055_fix_calibration_separation_digest_search_path.sql`: corrección del search path de `digest` descubierta por prueba adversarial.

La doctrina final es simple:

**El partido se analiza. El sistema se calibra.**
