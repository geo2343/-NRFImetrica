# @NRFImetrica Kernel

Kernel externo de `@NRFImetrica`, alineado al DOCUMENTO MADRE estadístico.

## Autoridad soberana

La autoridad activa ya no es el contrato resumido V2.1. Es el documento madre completo identificado por:

- `MOTHER_DOCUMENT_SHA256 = d16896eba602af272117a5c83b56245aa201979d394301781d424e705b3642d3`
- `MOTHER_DOCUMENT_LINES = 15570`
- `LATEST_SOVEREIGN_PATCH_WINS`
- parche soberano vigente: `A0-GOV.18 — REFORMA OPERATIVA SOBERANA V3`
- protocolo activo: `NRFIMETRICA_MOTHER_V3_AUTONOMOUS`

Estado técnico: `NRFIM-KERNEL-0.4-MOTHER-ALIGNED`.

## Arquitectura

- **Documento madre = constitución.** Define objeto, responsabilidades, precedencia, prohibiciones y hard gates.
- **ChatGPT = analista causal.** Investiga, interpreta, relaciona mecanismos, falsifica y explica. No fabrica probabilidades.
- **Kernel = camisa de fuerza operacional.** Controla fase, orden, evidencia, provenance, freeze, timestamps, SRA, auditoría, NRFI-Prensa, calibración, mercado y cierre.
- **A4 = dueño del RAW numérico.** Una probabilidad requiere ejecución real de motor identificable; la IA no lo sustituye.
- **A5 = integración conjunta.** Conserva/deriva distribución de primera entrada y contratos.
- **A6 = causalidad, falsificación y Sports Seal.** Incluye auditor realmente separado y SRA.
- **A7 = calibración, elegibilidad y contraste NRFI-Prensa.** Sin certificación no libera A8.
- **A8 = mercado, valor, cartera y ejecución.** Solo después del release de A7.
- **Supabase = estado técnico persistente y enforcement físico.**
- **Vercel = runtime HTTP.**
- **Drive/Notion = expediente documental**, no sustituto del Kernel.

## Adaptación del antiguo modo manual

El documento madre fue escrito para una operación donde el usuario podía autorizar manualmente A1, A2, A3, etc. Esa parte fue adaptada sin quitar responsabilidades deportivas:

`A0 sellado automáticamente -> A1 -> A2 -> A3 -> A4 -> A5 -> A6 -> A7 -> A8`

`MANUAL_PHASE_AUTHORIZATION_REQUIRED = FALSE`.

El Kernel habilita la fase siguiente únicamente cuando la anterior deja el handoff exigido. El usuario no tiene que escribir `adelante` entre fases. Un fallo local no paraliza automáticamente la jornada.

## A0

A0 se sella automáticamente por corrida con el hash exacto del documento madre. Si el hash/autoridad no coincide, ninguna fase madre puede persistirse.

## A1 — Integridad y freeze

A1 controla, entre otros:

- identidad inequívoca del juego;
- pitcher real de primera entrada, rol y mano;
- lineup y estado OFFICIAL/PROJECTED/etc.;
- catcher, umpire, parque, roof y weather con materialidad;
- scratches/lesiones/restricciones;
- unknowns y conflictos;
- `AS_OF`, `DATA_AVAILABLE_AT`, `INPUT_FREEZE_ID`;
- anti-leakage y market quarantine;
- SRA freeze;
- separación entre `RESEARCH_HANDOFF` y autoridad real-money.

Investigación puede continuar con inputs provisionales cuando el objeto siga siendo representable. Real-money requiere confirmaciones/freeze final conforme al documento madre.

## A2 — Baselines jerárquicos

A2 exige baselines regularizados, shrinkage, samples, platoon, dependency clusters, provenance, control de doble conteo, SRA bajo autoridad correcta y mercado en cuarentena. No puede inventar un combiner ni producir P(NRFI) por narrativa.

## A3 — Current Version + matchup

A3 actualiza el estado técnico actual del pitcher/hitters y el matchup: arsenal, execution, location access, B1–B3, B4/B5 condicionales, failure modes de primera entrada, two-out extension, B4+ exposure, rutas de ruptura, dependencia y SRA. Tiene prohibido fabricar ajustes numéricos.

## A4 — Motor numérico

A4 debe demostrar una ejecución numérica real e identificable. El Kernel exige:

- `execution_id`;
- `model_version`;
- `engine_mode` y `model_tier`;
- `transition_version`;
- freeze/as-of;
- provenance y transformación A3->A4;
- evidencia física de herramienta numérica con el mismo `execution_id`;
- P(0), P(1), P(2), P(3+) para Top y Bottom;
- cada distribución suma 1;
- mass conservation y sanity checks;
- incertidumbre, sensibilidad y fragilidad.

**Estado actual:** el motor numérico real aún no está integrado. Por diseño, una corrida madre no puede fingir A4 con números escritos por ChatGPT.

## A5 — Integración conjunta

El Kernel exige distribución conjunta `P0/P1/P2/P3+` y valida físicamente:

- `P(U0.5) = P0`;
- `P(U1.5) = P0 + P1`;
- `P(U2.5) = P0 + P1 + P2`;
- `P(YRFI) = 1 - P0`;
- mismo contexto compartido;
- no doble ajuste;
- RAW no se presenta como calibrado;
- mercado todavía ciego.

## A6 — Razonamiento, falsificación, SRA y auditoría

A6 exige caso central NRFI, mejor rival YRFI, mecanismos, mitad débil, incertidumbre, breakpoints y falsificación de ambos lados.

Hard gates adicionales:

- auditor independiente con identidad distinta del analista principal;
- SRA obligatorio (`COMPLETE` o `DATA_UNAVAILABLE` justificado);
- Sports Seal market-blind;
- veredicto propio pre-prensa congelado y hasheado;
- frase exacta: `ESPERANDO RESULTADO DE NRFI-PRENSA`.

La prensa no vota. Se contrasta después contra un veredicto ya congelado.

## A7 — Calibración, elegibilidad y NRFI-Prensa

A7 vincula el packet de `@NRFIprensa` al hash del veredicto pre-prensa de A6 y obliga a registrar coincidencias, discrepancias, datos nuevos/no verificados, riesgos omitidos, preguntas/respuestas e impacto causal.

`RELEASE_TOKEN = ISSUED` solo puede existir cuando pasan los hard gates upstream y la calibración/OOS/provenance/región/elegibilidad exigidas. En caso contrario:

`A7_NOT_CERTIFIED -> A8_LOCKED`.

## A8 — Mercado, valor y ejecución

A8 exige release real de A7 antes de revelar/usar el mercado para ejecución. Comprueba matemáticamente break-even, P conservadora, edge y EV; no permite `APOSTAR` con edge/EV no positivos.

Además:

- distribución P0/P1/P2/P3+ visible;
- máximo 3 candidatos ejecutables por jornada;
- 0 candidatos es válido;
- el candidato nace de la tesis de cero carreras;
- U1.5, cuando se use, debe explicar que el partido fue seleccionado por su fortaleza para cero carreras;
- veredicto emitido antes de T-10;
- T-5 se usa para revalidación rápida, no para rehacer todo el análisis;
- starter y lineups deben seguir confirmados para autoridad de ejecución.

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
- no ocultar contradicciones;
- narrativa elegante != probabilidad.

## Estado real actual

- Documento madre convertido en autoridad versionada: **sí**.
- A0 automático y A1→A8 gates persistentes: **sí**.
- Enforcement DB además del API: **sí**.
- IA inventando probabilidad: **bloqueado**.
- Motor numérico A4 real: **NO INTEGRADO**.
- Calibración OOS certificada A7: **NO CERTIFICADA**.
- `SYSTEM_STATE = TRADING_HALT_RESEARCH`.
- `REAL_MONEY_AUTHORITY = FALSE`.

Por tanto, el Kernel ya puede impedir atajos contra el documento madre, pero no se declarará sistema real-money completo hasta que existan y se validen el motor A4 y la calibración A7.
