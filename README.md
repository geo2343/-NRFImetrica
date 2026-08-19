# @NRFImetrica

Agente causal para primera entrada MLB gobernado por `MOTHER V3`.

## Autoridad activa

- `SYSTEM_VERSION = NRFIM MOTHER V3`
- `AGENT_VERSION = MOTHER-V3-AGENT-1.5`
- `KERNEL_VERSION = NRFIM-KERNEL-1.0-SELECTIVE-CONCLUSION`
- `PROTOCOL_ID = NRFIMETRICA_MOTHER_V3_AUTONOMOUS`
- `MOTHER_DOCUMENT_SHA256 = d16896eba602af272117a5c83b56245aa201979d394301781d424e705b3642d3`
- `REAL_MONEY_AUTHORITY = FALSE`
- migraciones activas requeridas hasta `032`

## Regla central

La IA decide deportivamente mediante razonamiento causal, no mediante suma de métricas ni conteos. El sistema separa `SPORTS_STATUS`, `PROCESS_STATUS` y `EXECUTION_STATUS`; un fallo de proceso o de autoridad puede bloquear ejecución, pero no puede borrar ni modificar el juicio deportivo.

## SPORTS_STATUS

- `SPORTS_CANDIDATE`: `NRFI_LEAN` sustentado por datos reales del mismo RUN/GAME.
- `NO_PLAY`: rechazo deportivo NRFI o mejor tesis `YRFI_LEAN` sustentada por datos.
- `WATCHLIST`: todavía no existe una conclusión deportiva suficientemente sustentada.
- `AUDIT_ONLY`: no existió ventana pregame válida.

`SPORTS_CANDIDATE` no requiere `PROCESS_AUDIT=PASS` ni Drive hash match. Esos controles pertenecen al proceso y a la ejecución.

## PROCESS_STATUS

`VERIFIED`, `FAIL`, `REVIEW`, `UNVERIFIED`, `INCOMPLETE`, `MISSING`, `PENDING`, `NOT_APPLICABLE`.

El auditor `KERNEL_PROCESS_AUDITOR_0.2` verifica cadena de custodia y calidad del proceso. Tiene prohibido votar NRFI/YRFI. Los pisos `CLEAR=3 / NORMAL=5 / DEEP=7` son señal de calidad de proceso, no selector deportivo.

## EXECUTION_STATUS

`EXECUTABLE`, `TECHNICAL_BLOCK`, `PROCESS_BLOCK`, `PENDING`, `NOT_APPLICABLE`, `WATCHLIST`, `AUDIT_ONLY`.

A4/A6/A7 pueden bloquear dinero real sin convertir un candidato en `NO_PLAY`.

## Kernel 1.0 — conclusión selectiva

El pool bruto de `SPORTS_CANDIDATE` no es la conclusión final.

Si existen al menos dos candidatos deportivos, la IA debe producir exactamente:

1. **Candidato principal #1**.
2. **Candidato principal #2**.
3. **Tercero opcional**, solamente si tiene una justificación excepcional para acompañar a los dos primeros.

La salida final nunca puede contener cuatro o más candidatos deportivos.

El Kernel no escoge mediante score. La IA debe comparar causalmente todo el pool. Para cada uno de los dos principales debe documentar:

- argumento central;
- mecanismo dominante de supresión de carrera;
- riesgo contrario más fuerte;
- por qué la tesis sobrevive ese riesgo;
- por qué queda por encima del siguiente candidato;
- `EVIDENCE_ID` del mismo RUN/GAME.

El tercero, si existe, debe explicar adicionalmente:

- por qué merece entrar;
- por qué no desplaza a ninguno de los dos principales.

Todo `SPORTS_CANDIDATE` que quede fuera debe registrar:

- `why_not_top_two`;
- `material_weakness_vs_selected`.

Así, tener cinco candidatos en la fase de investigación puede ser correcto; entregar cinco como conclusión no lo es.

Si el pool tiene un solo candidato, el sistema devuelve uno y marca `INSUFFICIENT_POTABLE_SHORTLIST`; no fabrica un segundo débil. Si no existe ninguno, aplica la regla estricta `ZERO_SPORTS_CANDIDATES_BY_DATA`.

Objeto físico: `public.nrfimetrica_sports_shortlists`.

## Carga causal mínima del análisis deportivo

Todo juicio completo debe estudiar Top 1st y Bottom 1st, versión actual de ambos abridores, top order y matchup, caso central NRFI, mejor rival YRFI, contraevidencia más fuerte, clusters causales, factor dominante, falsificación de NRFI y YRFI y qué dato o cambio revertiría el juicio.

Lógica prohibida:

`métrica A + métrica B + métrica C = pick/no pick`

Lógica esperada:

`datos -> mecanismos -> rutas de anotación/supresión -> contradicciones -> falsificación -> juicio -> comparación relativa -> shortlist final`

## Regla de cero candidatos

Cero candidatos deportivos por proceso está prohibido. Un hash faltante, auditoría fallida, conteo de fuentes, A4 ausente, A6 ausente, A7 bloqueado o cualquier otro problema técnico no puede producir `0 SPORTS_CANDIDATE` como conclusión deportiva.

Si quedan partidos sin resolución deportiva, el reporte debe declarar `INCOMPLETE_NOT_ZERO`. Solo se permite `ZERO_SPORTS_CANDIDATES_BY_DATA` cuando todos los juegos no-auditados son `NO_PLAY` deportivos con carga causal y evidencia del RUN actual.

## Clean Room

Cada invocación nueva requiere:

`RUN nuevo + INVOCATION_ID nuevo + documento Drive nuevo + fuentes nuevas + evidencia nueva + razonamiento nuevo`.

No se reutilizan reportes, packets ni conclusiones de corridas anteriores como evidencia deportiva.

## Research fallback

Los componentes `DIAGNOSTIC_TRUSTED` pueden apoyar investigación condicionada A4/A6 cuando exista ejecución física real. Eso no autoriza release A7 ni A8. Dinero real sigue exigiendo los componentes y certificaciones `ACTIVE_TRUSTED` correspondientes.

## Pruebas físicas de Kernel 1.0

Sobre el pool histórico de cinco `SPORTS_CANDIDATE`:

- intentar persistir cuatro candidatos finales -> `SHORTLIST_REQUIRES_EXACTLY_TWO_PRIMARY_CANDIDATES` -> BLOQUEADO;
- estructura `2 principales + 1 tercero opcional` con evidencia, comparación causal y razones para excluir los dos restantes -> ACEPTADA en transacción de prueba y revertida, sin alterar la corrida histórica.

Durante la primera prueba válida se detectó una ambigüedad SQL en la variable `evidence_id`; la transacción fue rechazada íntegra. La migración 032 corrigió el defecto y la prueba se repitió satisfactoriamente.

## Archivos de la reforma

- `supabase/migrations/029_separate_sports_judgment_process_validation_and_execution.sql`
- `supabase/migrations/030_demetricize_sports_judgment_and_move_process_gates_to_audit.sql`
- `supabase/migrations/031_enforce_two_primary_sports_shortlist_with_optional_third.sql`
- `supabase/migrations/032_fix_sports_shortlist_evidence_variable_ambiguity.sql`
- `protocols/nrfimetrica_causal_authority_v09.json`
- `agents/nrfimetrica_mother_v3_agent.json`
- `kernel/core.py`

Objetivo de Kernel 1.0: **la IA puede encontrar varios candidatos durante el análisis, pero debe terminar discriminando de verdad: dos principales potables y, como máximo, un tercero excepcional, todos defendidos con argumentos deportivos comparativos.**
