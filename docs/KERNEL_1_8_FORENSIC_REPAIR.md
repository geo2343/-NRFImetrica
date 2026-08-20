# NRFIM-KERNEL-1.8-FORENSIC-REPAIR

Fecha: 2026-08-20

Origen: auditoría forense de `NRFIM-MOTHER-20260820-ead3b6f3`, veredicto `PROCESS_INVALID — CRITICAL`.

## Fallos raíz reparados

1. A0 dependía de un hash histórico hardcoded aunque `agent_registry` y `protocol_authority` compartían otro hash soberano vigente.
2. El bloqueo A0/A1–A8 impedía resolver A0P y, por dependencia indirecta, detenía también el razonamiento deportivo, aunque la doctrina exige separar SPORTS de certificación.
3. El reporte podía contener narrativa deportiva no respaldada por packet físico del RUN.
4. GitHub `kernel/core.py` declaraba una versión/hash distintos de la autoridad activa.
5. Persistía metadata histórica de un estado de refactor/disabled ya superado.

## Reparación

- A0 resuelve autoridad dinámicamente por igualdad `agent_registry.mother_document_sha256 == protocol_authority.document_sha256`.
- Un mismatch de esas dos autoridades bloquea.
- `A0_CONSTITUTION_SEALED` guarda snapshot de la autoridad activa.
- A0P puede resolverse como preanálisis deportivo sin A0 para no matar SPORTS reasoning.
- A1–A8 continúan bloqueados sin A0 válido.
- `SPORTS_REASONING_PACKET V2` conserva carga bilateral completa para todos los partidos, incluidos `NO_PLAY`.
- Se añadió manifest físico Drive obligatorio antes de `process_audit=PASS`.
- Se añadió snapshot de reporte derivado de DB y trigger que sustituye los estados narrativos por los estados físicos antes de `FINAL_REPORT`.
- Sin packet: `WATCHLIST / MISSING / DO_NOT_BET`.
- El firewall económico y la prohibición de probabilidad IA permanecen intactos.

## Retest físico V18_FORENSIC_PROCESS_REPAIR

12/12 PASS:

1. Hash soberano vigente resuelto.
2. A0 acepta hash vigente.
3. Hash histórico rechazado físicamente (`23514`).
4. Mismatch agent/protocol authority rechazado (`23514`).
5. SPORTS preanalysis permitido sin A0.
6. Certification chain continúa bloqueada sin A0.
7. Sin packet => WATCHLIST/MISSING/DO_NOT_BET.
8. Report snapshot reproduce ese estado físico.
9. Cero referencias al hash histórico en las dos funciones de enforcement afectadas.
10. Agent registry = ACTIVE 1.13 / Kernel 1.8 y metadata stale eliminada.
11. Gate de Drive artifact manifest activo.
12. Firewall económico preservado.

Los resultados están persistidos en `public.nrfimetrica_kernel_tests` con `test_suite='V18_FORENSIC_PROCESS_REPAIR'`.

## Protección histórica

`NRFIM-MOTHER-20260820-ead3b6f3` no fue reparado ni completado retroactivamente. Su hash de fila y sus conteos de fases/packets/evidence permanecieron iguales antes y después de la reparación. La migración aplica a nuevas invocaciones.

## Autoridad económica

La reparación no otorga autoridad de dinero real. Continúan siendo necesarios motor numérico game-specific `ACTIVE_TRUSTED`, auditor independiente `ACTIVE_TRUSTED`, auditoría certificada de confiabilidad, A7 release y A8 válido.
