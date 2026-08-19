# @NRFImetrica

Agente causal para primera entrada MLB gobernado por `MOTHER V3`.

## Autoridad activa

- `SYSTEM_VERSION = NRFIM MOTHER V3`
- `AGENT_VERSION = MOTHER-V3-AGENT-1.4`
- `KERNEL_VERSION = NRFIM-KERNEL-0.9-CAUSAL-AUTHORITY`
- `PROTOCOL_ID = NRFIMETRICA_MOTHER_V3_AUTONOMOUS`
- `MOTHER_DOCUMENT_SHA256 = d16896eba602af272117a5c83b56245aa201979d394301781d424e705b3642d3`
- `REAL_MONEY_AUTHORITY = FALSE`
- migraciones activas requeridas hasta `030`

## Regla central

La IA decide deportivamente mediante **razonamiento causal**, no mediante suma de métricas ni conteos.

El sistema separa tres ejes:

1. `SPORTS_STATUS` — juicio deportivo.
2. `PROCESS_STATUS` — calidad/trazabilidad del proceso.
3. `EXECUTION_STATUS` — posibilidad de ejecutar una apuesta.

Un fallo de proceso puede bloquear ejecución. **No puede borrar ni modificar un juicio deportivo.**

## SPORTS_STATUS

- `SPORTS_CANDIDATE`: `NRFI_LEAN` sustentado por datos reales del mismo RUN/GAME.
- `NO_PLAY`: rechazo deportivo NRFI o mejor tesis `YRFI_LEAN` sustentada por datos.
- `WATCHLIST`: todavía no existe una conclusión deportiva suficientemente sustentada.
- `AUDIT_ONLY`: no existió ventana pregame válida.

`SPORTS_CANDIDATE` **no requiere** `PROCESS_AUDIT=PASS` ni Drive hash match. Esos controles pertenecen al proceso y a la ejecución.

## PROCESS_STATUS

`VERIFIED`, `FAIL`, `REVIEW`, `UNVERIFIED`, `INCOMPLETE`, `MISSING`, `PENDING`, `NOT_APPLICABLE`.

El auditor `KERNEL_PROCESS_AUDITOR_0.2` verifica cadena de custodia y calidad del proceso. Tiene prohibido votar NRFI/YRFI.

Los pisos `CLEAR=3 / NORMAL=5 / DEEP=7` permanecen como señal de calidad de proceso. **Ya no son hard gate para que la IA pueda registrar su juicio deportivo.**

También se retiraron mínimos arbitrarios de longitud de texto como criterio para permitir una conclusión deportiva.

## EXECUTION_STATUS

- `EXECUTABLE`
- `TECHNICAL_BLOCK`
- `PROCESS_BLOCK`
- `PENDING`
- `NOT_APPLICABLE`
- `WATCHLIST`
- `AUDIT_ONLY`

A4/A6/A7 pueden bloquear dinero real sin convertir un candidato en `NO_PLAY`.

## Carga causal mínima del análisis deportivo

Todo juicio completo debe estudiar:

- Top 1st y Bottom 1st;
- versión actual de ambos abridores;
- top order y matchup;
- caso central NRFI;
- mejor rival YRFI;
- contraevidencia más fuerte;
- clusters causales;
- factor dominante;
- falsificación de NRFI y YRFI;
- qué dato o cambio revertiría el juicio.

La lógica prohibida es:

`métrica A + métrica B + métrica C = pick/no pick`

La lógica esperada es:

`datos -> mecanismos -> rutas de anotación/supresión -> contradicciones -> falsificación -> juicio deportivo`

## Regla de cero candidatos

**Cero candidatos deportivos por proceso está prohibido.**

Un hash faltante, auditoría fallida, conteo de fuentes, A4 ausente, A6 ausente, A7 bloqueado o cualquier otro problema técnico no puede producir `0 SPORTS_CANDIDATE` como conclusión deportiva.

Si quedan partidos sin resolución deportiva, el reporte debe declarar:

`INCOMPLETE_NOT_ZERO`

Solo se permite:

`ZERO_SPORTS_CANDIDATES_BY_DATA`

cuando **todos los juegos no-auditados** son `NO_PLAY` deportivos y cada rechazo documenta:

- razón basada en datos;
- por qué fracasa la tesis NRFI;
- mecanismo YRFI/NO_PLAY dominante;
- qué revertiría la decisión;
- `EVIDENCE_ID` del mismo RUN/GAME.

## Clean Room

Cada invocación nueva requiere:

`RUN nuevo + INVOCATION_ID nuevo + documento Drive nuevo + fuentes nuevas + evidencia nueva + razonamiento nuevo`.

No se reutilizan reportes, packets ni conclusiones de corridas anteriores como evidencia deportiva.

## Research fallback

Los componentes `DIAGNOSTIC_TRUSTED` pueden apoyar investigación condicionada A4/A6 cuando exista ejecución física real. Eso **no** autoriza release A7 ni A8.

Dinero real sigue exigiendo los componentes y certificaciones `ACTIVE_TRUSTED` correspondientes.

## Estado físico actual

La corrida histórica `NRFIM-MOTHER-20260819-99cf2c30`, que llegó a presentarse como `0 elegibles`, bajo Kernel 0.9 deriva actualmente:

- `5 SPORTS_CANDIDATE + TECHNICAL_BLOCK`
- `7 NO_PLAY`
- `3 AUDIT_ONLY`
- `0 EXECUTABLE`

Eso demuestra la diferencia entre **candidato deportivo** y **apuesta ejecutable**.

## Archivos de la reforma

- `supabase/migrations/029_separate_sports_judgment_process_validation_and_execution.sql`
- `supabase/migrations/030_demetricize_sports_judgment_and_move_process_gates_to_audit.sql`
- `protocols/nrfimetrica_causal_authority_v09.json`
- `agents/nrfimetrica_mother_v3_agent.json`
- `kernel/core.py`

El objetivo de Kernel 0.9 es simple: **la IA piensa el deporte; el Kernel demuestra y controla el proceso; A4–A8 controlan ejecución. Ninguna de esas capas puede fingir que otra tomó su decisión.**
