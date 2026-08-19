# @NRFImetrica Kernel

Kernel externo de `@NRFImetrica`, alineado al **DOCUMENTO MADRE estadístico**.

## Autoridad soberana

La autoridad activa es el documento madre completo:

- `MOTHER_DOCUMENT_SHA256 = d16896eba602af272117a5c83b56245aa201979d394301781d424e705b3642d3`
- `MOTHER_DOCUMENT_LINES = 15570`
- `LATEST_SOVEREIGN_PATCH_WINS`
- parche soberano vigente: `A0-GOV.18 — REFORMA OPERATIVA SOBERANA V3`
- protocolo activo: `NRFIMETRICA_MOTHER_V3_AUTONOMOUS`
- Kernel activo: `NRFIM-KERNEL-0.5-MOTHER-ENFORCED`

El protocolo V2.1 anterior permanece solo como evidencia histórica y no tiene autoridad runtime.

## Arquitectura

- **Documento madre = constitución.** Define objeto, responsabilidades, precedencia, prohibiciones y hard gates.
- **ChatGPT = analista causal.** Investiga, interpreta, relaciona mecanismos, falsifica y explica. No fabrica probabilidades.
- **Kernel = camisa de fuerza operacional.** Controla fase, orden, evidencia, provenance, freeze, lineage, timestamps, SRA, auditoría independiente, NRFI-Prensa, calibración, mercado, cartera, tickets y cierre.
- **A4 = dueño del RAW numérico.** Una probabilidad requiere ejecución real de motor registrado; la IA no lo sustituye.
- **A5 = integración conjunta.** Conserva/deriva la distribución de carreras de primera entrada.
- **A6 = causalidad, falsificación y Sports Seal.** Incluye SRA y auditor independiente realmente separado.
- **A7 = calibración, elegibilidad y contraste NRFI-Prensa.** Sin certificación no libera A8.
- **A8 = mercado, valor, cartera, tickets y ejecución.** Solo después de release A7.
- **Supabase = estado técnico persistente + enforcement físico.**
- **Vercel = runtime HTTP.**
- **Drive/Notion = expediente documental**, no sustituto del Kernel.

## Adaptación del antiguo modo manual

El documento madre fue escrito para una operación donde el usuario podía autorizar manualmente A1, A2, A3, etc. Se conserva el contenido relevante, pero se elimina esa dependencia manual:

`A0 AUTO-SEAL -> A1 -> A2 -> A3 -> A4 -> A5 -> A6 -> A7 -> A8 -> PORTFOLIO -> FINAL REPORT`

`MANUAL_PHASE_AUTHORIZATION_REQUIRED = FALSE`.

El Kernel habilita la siguiente fase únicamente cuando la anterior deja el handoff exigido. El usuario no tiene que escribir `adelante` entre fases. Un fallo local puede cerrar/degradar solo ese partido mediante una resolución terminal verificable y la jornada continúa.

## Tres clases de reglas

El documento madre no fue convertido en 15,570 casillas. La adaptación separa:

1. **Hard gates físicos:** si fallan, no se avanza.
2. **Handoffs/outputs obligatorios:** la siguiente fase no puede inventar lo que la anterior debía producir.
3. **Doctrina de razonamiento:** gobierna cómo interpreta la IA y se audita en A6; no se convierte en score mecánico.

## A0 — Constitución

A0 se sella automáticamente por corrida con el hash exacto del documento madre. Un hash/autoridad incorrectos bloquean cualquier fase madre.

## A1 — Integridad, identidad y freeze

A1 controla, entre otros:

- identidad exacta del juego;
- pitcher real de primera entrada, rol y mano;
- lineup 1–9 y estado OFFICIAL/PROJECTED/etc.;
- catcher, umpire, parque, roof y weather con materialidad;
- scratches, lesiones y restricciones;
- unknowns y conflictos;
- `AS_OF`, `DATA_AVAILABLE_AT`, `INPUT_FREEZE_ID`;
- anti-leakage y market quarantine;
- SRA freeze;
- separación `RESEARCH_HANDOFF` / autoridad real-money.

Investigación puede continuar con inputs provisionales cuando el partido siga siendo representable. Autoridad real-money exige los requisitos finales del documento: pitchers confirmados, lineups oficiales, freeze final válido y demás hard gates.

## A2 — Baselines jerárquicos

A2 exige baselines regularizados, shrinkage, sample state, platoon, dependency clusters, provenance, control de doble conteo, SRA bajo autoridad correcta y mercado en cuarentena. No puede producir P(NRFI) por narrativa.

## A3 — Current Version + matchup

A3 actualiza el estado técnico actual de pitchers/hitters y matchup: arsenal, execution, location access, B1–B3, B4/B5 condicionales, failure modes de primera entrada, two-out extension, B4+ exposure, rutas de ruptura, dependencia y SRA. No puede fabricar ajustes probabilísticos.

## A4 — Motor numérico real

A4 solo existe operativamente cuando hay una ejecución registrada en:

- `numeric_engine_registry`
- `numeric_engine_executions`

El Kernel exige correspondencia física entre:

- `execution_id`;
- run y game;
- `model_version`;
- `transition_version`;
- `input_freeze_id`;
- timestamp;
- provenance;
- evidencia de herramienta numérica;
- P0/P1/P2/P3+ de Top y Bottom;
- conservación de masa y sanity checks.

Un `execution_id` escrito por la IA **no demuestra** que A4 ocurrió.

Una corrida `CONTROLLED_REAL` solo acepta un motor registrado como `ACTIVE_TRUSTED`. Los motores `DIAGNOSTIC_TRUSTED` sirven exclusivamente para pruebas.

## A5 — Integración conjunta

A5 debe conservar lineage con A4 y exige distribución conjunta:

- `P0`
- `P1`
- `P2`
- `P3+`

El Kernel valida físicamente:

- `P(U0.5) = P0`
- `P(U1.5) = P0 + P1`
- `P(U2.5) = P0 + P1 + P2`
- `P(YRFI) = 1 - P0`
- mismo contexto compartido;
- no doble ajuste;
- RAW != calibrado;
- mercado todavía ciego.

## A6 — Razonamiento, falsificación, SRA y auditoría

A6 exige caso central NRFI, mejor rival YRFI, mecanismos, mitad vulnerable, incertidumbre, breakpoints y falsificación de ambos lados.

Hard gates:

- `primary_analyst_id`;
- auditor distinto del analista;
- **ejecución real** en `independent_audit_executions`;
- auditor registrado en `independent_auditor_registry`;
- SRA obligatorio (`COMPLETE` o `DATA_UNAVAILABLE` justificado);
- Sports Seal market-blind;
- veredicto propio pre-prensa congelado y hasheado;
- frase exacta: `ESPERANDO RESULTADO DE NRFI-PRENSA`.

Un nombre de auditor diferente escrito en un campo no constituye independencia.

## A7 — Calibración, elegibilidad y NRFI-Prensa

El packet de `@NRFIprensa` debe existir físicamente en `nrfiprensa_packets`, pertenecer al mismo run/game, estar verificado, poseer hash válido y haber sido generado después del veredicto pre-prensa congelado y antes del contraste.

A7 registra coincidencias, discrepancias, nuevos datos, datos no verificados, riesgos omitidos, preguntas/respuestas e impacto causal. La prensa funciona como auditor/fuente/contraste; **no como voto**.

A7 también conserva lineage exacto con A1/A4/A5. La `RAW_P` de cero carreras debe venir de A5, no de una nueva opinión.

La calibración se controla **por contrato**:

- U0.5/NRFI;
- U1.5;
- U2.5.

Una línea no puede heredar silenciosamente la calibración de otra. Para emitir `RELEASE_TOKEN = ISSUED`, la tesis soberana de cero carreras debe estar certificada. Para ejecutar U1.5 o U2.5 en A8, ese contrato específico también debe tener cobertura/calibración certificada.

`A7_NOT_CERTIFIED -> A8_LOCKED`.

## A8 — Mercado, valor y ejecución

A8 exige release real de A7. El Kernel comprueba:

- línea exacta;
- precio real y timestamp;
- break-even;
- P conservadora procedente de la calibración del contrato seleccionado;
- edge;
- EV;
- precio mínimo aceptable;
- T-10;
- T-5 como revalidación rápida;
- freeze activo;
- starter y lineups oficiales;
- autoridad de ejecución.

No permite `APOSTAR` con edge/EV no positivos.

La selección nace de la **tesis de cero carreras**. U1.5/U2.5 no pueden utilizarse para rescatar un partido cuya tesis P0 era débil.

## Jornada completa y resoluciones terminales

El Kernel no obliga a rellenar fases falsas cuando una ruta legítimamente termina antes. Existe `protocol_game_resolution` para dejar trazado, por ejemplo:

- `A1_NOT_EXECUTABLE`
- `A1_GOVERNING_DATA_UNRESOLVED`
- `A4_ENGINE_NOT_INTEGRATED`
- `A4_TRUE_MODEL_FAILURE`
- `A6_INDEPENDENT_AUDIT_UNAVAILABLE`
- `A7_NOT_ELIGIBLE`
- `A7_CALIBRATION_UNCERTIFIED`
- `A7_PRESS_UNAVAILABLE`
- `AUDIT_ONLY`
- `LOCAL_DATA_BLOCK`

Una resolución exige causa, materialidad, condición que la resolvería y evidencia/Recovery cuando corresponda. Un partido terminal no paraliza automáticamente los demás.

Los gates de jornada son:

`A1_SLATE_ROUTED -> A7_SLATE_ELIGIBILITY -> A8_PORTFOLIO -> FINAL_REPORT`

No se puede declarar completa la jornada dejando partidos sin resolver.

## Cartera y tickets

La reforma soberana permite **0–3 candidatos**, nunca un cuarto. Calidad absoluta precede al ranking.

Cada candidato está definido por `GAME + LINE`, no solo por partido.

Con 2–3 candidatos, los tickets/combinadas se evalúan como objetos económicos independientes. El Kernel exige:

- componentes ya aprobados individualmente;
- precio real ofrecido y fuente;
- P conjunta;
- break-even;
- edge;
- EV;
- auditoría de correlación/dependencia;
- método conjunto cuando exista dependencia material.

Una combinada no crea valor. Con 3 candidatos se evalúan las tres dobles y la triple opcional; eso no significa ejecutarlas automáticamente.

## Reporte final

El reporte madre solo puede cerrarse después de la cartera. Debe coincidir con el estado real del slate, candidatos, tickets y probabilidades A8.

Una jornada de **0 candidatos es válida** y puede cerrar con `NO_HAY_PICK`. El Kernel fue probado físicamente con esa ruta.

Para `NRFIM MOTHER V3`, el antiguo `run_report_state` V2.1 no puede utilizarse como bypass del reporte madre.

## SRA

SRA es transversal y obligatorio en pregame. Su omisión silenciosa produce `SRA_GATE_NOT_EXECUTED`. Hasta demostrar valor incremental OOS, su autoridad permanece secundaria/candidate y no puede convertirse en voto o ajuste probabilístico narrativo.

## Prohibiciones constitucionales preservadas

Entre otras:

- métrica != mecanismo;
- varias métricas dependientes != varios votos;
- tráfico != carrera;
- posibilidad != materialización;
- ruta corta != ruta probable;
- First-Inning ERA/rachas/BvP pequeño no gobiernan;
- una mitad fuerte no oculta la otra;
- no Full-Game bullpen para justificar primera entrada;
- no market contamination antes de A8;
- no información futura;
- unknown != safe y unknown != danger;
- no forzar número de picks;
- no cuarto candidato;
- no ocultar contradicciones;
- narrativa elegante != probabilidad.

## Pruebas físicas realizadas

En Supabase se verificó, entre otras cosas, que se bloquean:

- A1 sin A0;
- hash de documento madre falso;
- autoridad real-money con lineup proyectado;
- probabilidad inventada por IA;
- A2 saltando A1;
- A4 sin ejecución numérica evidenciada;
- A4 con motor diagnóstico dentro de una corrida CONTROLLED_REAL;
- masa probabilística incorrecta;
- derivación contractual A5 incorrecta;
- autoauditoría A6;
- SRA omitido;
- packet de prensa futuro/no ligado al veredicto congelado;
- release A7 sin certificación;
- A8 sin release;
- conteos de cartera inconsistentes;
- cierre de corrida madre sin FINAL_REPORT.

También se demostró físicamente que una jornada válida con **0 candidatos** puede completar `FINAL_REPORT` y cerrar.

## Estado real actual

- Documento madre como autoridad versionada: **SÍ**.
- A0 automático: **SÍ**.
- A1→A8 con gates físicos: **SÍ**.
- Jornada/cartera/reporte final madre: **SÍ**.
- Evidencia/source calls/lineage/freeze: **SÍ**.
- IA fabricando probabilidad: **BLOQUEADA**.
- Motor A4 `ACTIVE_TRUSTED`: **0 / NO INTEGRADO**.
- Auditor independiente `ACTIVE_TRUSTED`: **0 / NO INTEGRADO**.
- Bridge real verificado de `@NRFIprensa`: **NO INTEGRADO**.
- Calibración OOS certificada A7: **NO CERTIFICADA**.
- `SYSTEM_STATE = TRADING_HALT_RESEARCH`.
- `REAL_MONEY_AUTHORITY = FALSE`.

El Kernel ya impide atajos contra el documento madre. Lo que falta para una ruta real-money no es más documentación ni más campos: son los componentes reales que el propio documento exige —motor numérico A4, auditor verdaderamente independiente, bridge verificable con NRFI-Prensa y calibración A7 fuera de muestra— y deberán demostrar su validez antes de recibir autoridad.
