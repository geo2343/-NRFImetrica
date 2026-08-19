# @NRFImetrica

Agente técnico-estadístico y causal para primera entrada MLB, gobernado por el **DOCUMENTO MADRE MOTHER V3** y protegido por un Kernel externo.

## Autoridad activa

- `SYSTEM_VERSION = NRFIM MOTHER V3`
- `AGENT_VERSION = MOTHER-V3-AGENT-1.1`
- `KERNEL_VERSION = NRFIM-KERNEL-0.6-CHAIN-OF-CUSTODY`
- `PROTOCOL_ID = NRFIMETRICA_MOTHER_V3_AUTONOMOUS`
- extensión obligatoria: `NRFIMETRICA_SPORTS_REASONING_PACKET_V2`
- `MOTHER_DOCUMENT_SHA256 = d16896eba602af272117a5c83b56245aa201979d394301781d424e705b3642d3`
- `LATEST_SOVEREIGN_PATCH_WINS`
- parche vigente: `A0-GOV.18 — REFORMA OPERATIVA SOBERANA V3`
- `MANUAL_PHASE_AUTHORIZATION_REQUIRED = FALSE`
- `SYSTEM_STATE = TRADING_HALT_RESEARCH`
- `REAL_MONEY_AUTHORITY = FALSE`

V2.1/V1.x se conservan exclusivamente como histórico y no tienen autoridad runtime.

## Arquitectura

- **Documento Madre = constitución.** Define objeto, doctrina, obligaciones, precedencia y hard gates.
- **ChatGPT/IA = analista causal.** Investiga, interpreta mecanismos, compara NRFI contra la mejor tesis YRFI, falsifica y toma posición. No fabrica probabilidades.
- **Kernel = enforcement + cadena de custodia.** No decide el partido mediante un score; demuestra que el trabajo ocurrió y bloquea atajos.
- **Supabase = estado técnico persistente y enforcement físico.**
- **Drive = expediente humano-legible, snapshots y hashes verificados.**
- **Vercel = runtime HTTP.**
- **@NRFIprensa = agente separado.** Se integra después del freeze técnico conforme A6/A7; no funciona como voto.

## Separación soberana: juicio deportivo vs certificación

Dos objetos distintos:

1. **Juicio causal deportivo.** Debe realizarse para cada partido aunque posteriormente A4/A7/A8 estén bloqueadas.
2. **Certificación A1–A8.** Decide si el juicio puede convertirse en contrato/mercado ejecutable.

Por tanto:

`BUEN JUICIO DEPORTIVO != APUESTA CERTIFICADA`

`FALTA DE CERTIFICACION != AUSENCIA DE ANALISIS DEPORTIVO`

La ausencia de motor, calibración, mercado o lineup oficial no autoriza a la IA a dejar de pensar. Tampoco autoriza a fingir una fase que no ocurrió.

## SPORTS_REASONING_PACKET V2 — cadena de custodia

Cada juego registrado debe tener su propio packet. La cadena física es:

`RESEARCH_TOOL_EVENT -> SOURCE_FAMILY -> EVIDENCE_ID + SNAPSHOT -> FACTUAL CLAIM -> CAUSAL ANALYSIS -> FALSIFICATION -> SPORTS VERDICT -> PACKET FREEZE/HASH -> DRIVE -> PROCESS AUDIT -> SPORTS_REASONING_SLATE`

### Tool calls y evidencia

- Cada búsqueda/open/fetch/query material se registra en `research_tool_events`.
- El timestamp del tool call lo escribe la base, no la IA.
- Cada tool call incrementa `runs.tool_call_count` y crea `trace_events`.
- Evidencia deportiva sin tool event real es rechazada.
- Cada afirmación factual requiere uno o más `EVIDENCE_ID` del mismo run/game.
- Cada evidencia requiere `SOURCE_FAMILY_ID`, snapshot y hash.
- Dato disponible después de su supuesta consulta es rechazado.

### Familias independientes

No se cuentan URLs como votos independientes.

- contenido exactamente duplicado no puede crear una familia nueva;
- mismo publisher/origen declarado debe colapsar en una sola familia;
- piso inicial adaptativo: `CLEAR=3`, `NORMAL=5`, `DEEP=7`;
- el piso no es un techo: contradicción material exige continuar investigando.

La detección determinista de sindicación no idéntica todavía depende de mejor clasificación de provenance/semantic similarity; no se declara resuelta por completo.

### Cobertura causal obligatoria

Todo `ANALYSIS_COMPLETE` exige:

- `TOP_1ST`;
- `BOTTOM_1ST`;
- `STARTER_CURRENT_FORM`;
- `TOP_ORDER_MATCHUP`;
- `FIRST_INNING_SPECIFIC`;
- `COUNTEREVIDENCE`;
- `CENTRAL_NRFI_CASE`;
- `BEST_YRFI_RIVAL`;
- `STRONGEST_COUNTEREVIDENCE`;
- `CAUSAL_CLUSTERS`;
- falsificación real contra NRFI y contra YRFI;
- `WHAT_WOULD_CHANGE_THE_DECISION` falsable;
- razón verificable de parada de investigación.

`NO_PLAY` y `RESEARCH_ONLY` tienen la misma carga de investigación que un positivo. `UNKNOWN` no se convierte en riesgo por defecto; requiere ruta causal material.

Datos full-game solo pueden utilizarse como proxy con explicación explícita de por qué afectan la primera entrada.

### Integridad temporal y versionado

- `RETRIEVED_AT` es Kernel-owned.
- `AS_OF` efectivo se calcula desde la evidencia realmente utilizada.
- backdating y future leakage están prohibidos.
- todo packet terminal queda congelado y hasheado;
- cambiar razonamiento después del freeze requiere una nueva versión enlazada a `previous_packet_hash`;
- la versión anterior permanece intacta.

### Drive

Cada packet terminal debe existir en Drive y su hash debe coincidir con `packet_hash` antes de sellar la jornada deportiva.

Estructura esperada:

```text
YYYY-MM-DD — RUN_ID/
  00 — JORNADA Y FREEZE/
  PARTIDO — AWAY@HOME/
    00 — SPORTS_REASONING_PACKET/
      packet_vN
      sources/
      snapshots/
      claim_evidence_map
      trace_log
    A1/
    A2/
    A3/
    A4 o RESOLUCIÓN TERMINAL/
    A5/
    A6/
    A7/
    A8/
  90 — AUDITORÍA/
  99 — REPORTE FINAL
```

El `FINAL_REPORT` también debe quedar registrado como artifact Drive verificado antes del cierre del run.

## Auditor de proceso

Auditor determinista activo: `KERNEL_PROCESS_AUDITOR_0.2`.

No confía en booleans enviados por la IA. Supabase deriva físicamente:

- `structural_pass`;
- `temporal_pass`;
- `evidence_pass`;
- `falsification_pass`;
- `independence_pass`;
- correspondencia packet/Drive.

El auditor puede marcar `PASS`, `FAIL` o `REVIEW`, pero **tiene prohibido votar NRFI/YRFI**. La decisión deportiva sigue perteneciendo al analista causal.

## Verdad de jornada

Estados terminales deportivos:

- `ANALYSIS_COMPLETE`
- `RESEARCH_INCOMPLETE`
- `INFORMATION_UNAVAILABLE`
- `NOT_EXECUTABLE`
- `WITHDRAWN_POST_FREEZE`
- `PROCESS_FAIL`

La frase `N/TOTAL ANALISIS_COMPLETOS` es generada por Kernel. Solo cuenta el último packet de cada partido que tenga:

`ANALYSIS_COMPLETE + PROCESS_AUDIT PASS + DRIVE HASH MATCH`.

Si hay 14 completos y 1 incompleto, el sistema declara `14/15 ANALISIS_COMPLETOS`; jamás lo redondea a 15/15. El incompleto local no detiene los demás juegos.

## Flujo de certificación A1–A8

La cadena de custodia deportiva no sustituye el protocolo contractual:

`A0 AUTO-SEAL -> SPORTS_REASONING_SLATE -> A1 -> A2 -> A3 -> A4 -> A5 -> A6 -> A7 -> A8 -> PORTFOLIO -> FINAL_REPORT -> DRIVE VERIFIED -> CLOSE`

- **A1:** identidad, pitchers, lineups, catcher/umpire/contexto, temporal integrity, freeze y market quarantine.
- **A2:** baselines jerárquicos, shrinkage, dependency clusters y double-count control.
- **A3:** versión actual + matchup y rutas reales de supresión/ruptura.
- **A4:** motor numérico real; la IA no puede sustituirlo.
- **A5:** distribución conjunta `P0/P1/P2/P3+` y contratos derivados.
- **A6:** falsificación causal, SRA, auditor independiente, Sports Seal y freeze pre-prensa.
- **A7:** calibración/eligibilidad y contraste con packet real de `@NRFIprensa`.
- **A8:** mercado, precio, break-even, edge/EV autorizados, T-10/T-5 y ejecución.

Candidatos permitidos por jornada: `0–3`; tres es máximo, nunca obligación. U1.5/U2.5 no rescatan una tesis P0 débil.

## Pruebas adversariales Kernel 0.6

Suite live en Supabase: `DIAG-SR-CUSTODY-20260819-1022`.

Resultado: **14/14 ataques físicos bloqueados o derivados correctamente**, incluyendo:

- evidencia sin tool call;
- timestamp falso;
- tool call sin contador/trace;
- dato futuro;
- claim factual sin evidencia;
- piso de familias insuficiente;
- contenido duplicado como familia nueva;
- mismo origen declarado como familia nueva;
- packet sin freeze/hash;
- Drive/auditoría sin vínculo de hash;
- auditor falso/booleans falsos;
- tampering post-freeze;
- conteo falso de jornada;
- cierre sin FINAL_REPORT de Drive.

Ver `tests/research_chain_adversarial_cases.json` y `docs/KERNEL_0_6_CHAIN_OF_CUSTODY_AUDIT.md`.

## Estado real actual

- Documento Madre: **ACTIVO**.
- Agent 1.1 / Kernel 0.6: **ACTIVOS EN GITHUB Y SUPABASE**.
- Migraciones: **001–024 aplicadas en Supabase**.
- Sports Reasoning chain: **ACTIVA**.
- A4 `ACTIVE_TRUSTED`: **0**.
- A6 independent auditor `ACTIVE_TRUSTED`: **0**.
- A7 calibration `ACTIVE_TRUSTED`: **0**.
- `SYSTEM_STATE = TRADING_HALT_RESEARCH`.
- `REAL_MONEY_AUTHORITY = FALSE`.

El Kernel 0.6 garantiza la demostrabilidad física del proceso de investigación; no inventa los componentes soberanos que todavía faltan para real-money y no sustituye el razonamiento causal de la IA con una suma mecánica.
