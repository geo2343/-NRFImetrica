# @NRFImetrica Kernel

Kernel externo para `@NRFImetrica` V2.1.

## Arquitectura activa

- **ChatGPT = cerebro deportivo.** Comprende, relaciona, interpreta, compara mecanismos NRFI/YRFI, reconsidera y decide.
- **Kernel = camisa de fuerza operacional.** Controla orden, obligaciones, evidencia, cutoff, trazabilidad, Recovery, estados y cierre; no decide por score.
- **Validator = desafío de soporte.** Comprueba afirmaciones, contradicciones, independencia causal, evidencia y cutoff antes de la reconsideración final.
- **Vercel = runtime HTTP.**
- **Supabase = estado técnico persistente mínimo.** Runs, juegos, evidencia, trazas, Recovery, gates y decisiones; no sustituye el expediente documental.
- **Google Drive/Notion = expediente documental permanente** cuando corresponda.

Estado técnico: `NRFIM-KERNEL-0.3-PROTOCOL-GATED / CONTROLLED_REAL_RUNTIME`.

## Flujo obligatorio

`DATOS REALES -> KERNEL REGISTRA -> CHATGPT RAZONA -> VALIDATOR DESAFIA -> CHATGPT RECONSIDERA -> KERNEL CERTIFICA -> ARCHIVO DOCUMENTAL`

El Kernel **no** usa `métrica A + puntos -> score -> apostar`.

## Motor de protocolo declarativo

Archivo activo: `protocols/nrfimetrica_v21_ai_analyst.json`.

El motor soporta requisitos configurables por fase:

- `prerequisites`: impide saltar fases;
- `required_fields`: campos obligatorios;
- `min_source_calls`: por ejemplo, si una fase exige 30 fuentes, `29/30 = BLOQUEADO`;
- `required_documents`: por ejemplo T100;
- `required_phrases`: exige una frase literal cuando el protocolo la requiera;
- `min_evidence_ids`: evidencia mínima real;
- `conditional`: una fase adaptativa solo puede omitirse como `SKIPPED_NOT_TRIGGERED` con motivo explícito;
- `max_items`: limita elementos como incertidumbres gobernantes o breakpoints.

Las fuentes que cuentan deben tener `source_ref`, `evidence_id` único y `retrieved_at`. Un número escrito por la IA no cuenta como consulta real.

## Gates deportivos activos para decisiones competitivas

Antes de permitir `NRFI_CANDIDATE` o `NRFI_REJECTED`, deben estar cerrados:

1. `TRIAGE`
2. `BILATERAL_FIRST_INNING_ANALYSIS`
3. `MATERIAL_CONTEXT` o skip justificado si no fue material
4. `RED_TEAM` o skip justificado si no hubo trigger
5. `SYNTHESIS`
6. `VALIDATOR_CHALLENGE`
7. `RECONSIDERATION`

Supabase tiene un trigger físico: aunque alguien intente insertar una decisión saltándose el API, la base la rechaza si faltan gates o si la decisión no coincide con `RECONSIDERATION.final_decision`.

## Inteligencia de la IA

Las métricas son evidencia, no votos. Varias métricas correlacionadas pueden describir un solo mecanismo. Una sola vulnerabilidad puede dominar si existe una ruta concreta de materialización.

La síntesis debe distinguir:

- `CENTRAL_NRFI_CASE`;
- `BEST_YRFI_RIVAL`;
- rutas de materialización de ambos lados;
- evidencia decisiva;
- datos redundantes o engañosos;
- riesgo principal;
- máximo una incertidumbre gobernante;
- hasta dos breakpoints;
- qué cambiaría la decisión.

## Estimación de IA vs probabilidad calibrada

La IA puede expresar una síntesis como:

- `AI_ESTIMATE = MODERATELY_FAVORABLE`; o
- `AI_NRFI_ESTIMATE ≈ 68%` con `kind = AI_JUDGMENT_UNCALIBRATED`.

Eso **no** se guarda como `raw_p_nrfi`, no se presenta como probabilidad calibrada y no habilita edge, EV ni dinero real. `raw_p_nrfi` permanece reservado para una herramienta numérica identificable y calibrada si algún día existe.

## Controles técnicos ya implementados

- jornada MLB congelada con IDs, horarios y cutoff;
- partidos iniciados -> `AUDIT_ONLY`;
- fallo local no detiene la jornada;
- una sola Recovery material por `ISSUE_ID`;
- evidencia con hashes y timestamps;
- cadena `prev_event_hash -> event_hash`;
- gates persistentes por partido;
- decisión competitiva bloqueada si faltan obligaciones;
- rechazo competitivo exige caso NRFI, rival YRFI, factor decisivo, materialidad y cambio concreto que alteraría el veredicto;
- cierre de jornada incompleta bloqueado.

## Pruebas adversariales

- decisión antes de completar gates: **RECHAZADA**;
- decisión después de completar todos los gates: **ACEPTADA**;
- segunda Recovery del mismo `ISSUE_ID`: **RECHAZADA**;
- probabilidad numérica no autorizada: **RECHAZADA**;
- rechazo competitivo vacío: **RECHAZADO**;
- suite incluye pruebas explícitas `29/30`, T100, frase obligatoria, prerequisitos y estimación IA no calibrada.

Estado de autorización: `REAL_MONEY_AUTHORITY = FALSE`.
