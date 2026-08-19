# @NRFImetrica Kernel

Kernel externo para `@NRFImetrica` V2.1.

Arquitectura activa:

- GitHub: código y versionado.
- Vercel: servidor HTTP del Kernel; deployments del commit actual reportados `success`.
- Supabase: ledger persistente de runs, games, evidence, trace, recoveries, decisions y audit events.
- ChatGPT/LLM: razonamiento causal y síntesis.
- Google Drive: informes/documentación; no es el runtime.

Estado técnico: `NRFIM-KERNEL-0.2 / CONTROLLED_REAL_RUNTIME`.

Capacidades implementadas:

- `GET /health`: comprueba configuración y alcance real de Supabase.
- `GET /mlb/schedule/{YYYY-MM-DD}`: sonda del proveedor MLB.
- `POST /runs/sync-mlb`: obtiene la jornada MLB, congela universo, registra juegos, evidencia y trace automática.
- `POST /evidence`: persistencia de evidencia con hash.
- `POST /recoveries`: máximo una Recovery por `ISSUE_ID`, reforzada por constraint físico en Supabase.
- `POST /trace`: cadena automática `prev_event_hash -> event_hash`.
- `POST /decisions`: valida carga probatoria de candidatos/rechazos y bloquea probabilidades no autorizadas.
- `POST /runs/{run_id}/close`: impide cerrar jornadas con juegos pregame sin decisión.
- `GET /runs/{run_id}/snapshot`: reconstruye run, juegos, decisiones, recoveries y trazas.

Pruebas realizadas:

- Ledger Supabase real: PASS.
- Cadena de hashes: PASS.
- Segunda Recovery del mismo `ISSUE_ID`: rechazada por constraint físico, PASS.
- RLS habilitado sin políticas públicas deliberadamente: backend-only.
- CI incluye pruebas unitarias y sonda live del proveedor oficial MLB Stats API.

Reglas duras:

- Scope exclusivo `NRFI_ONLY`.
- No inventar P(NRFI), edge, EV ni autorización real-money.
- `NUMERIC_ENGINE_STATUS = NOT_INTEGRATED` hasta que exista un motor identificable, versionado y validado.
- `MODEL_STATUS = NOT_INTEGRATED` y `CALIBRATION_STATUS = NOT_CERTIFIED` hasta validación posterior.
- Máximo un Recovery material por `ISSUE_ID`.
- Un fallo local no detiene la jornada.
- Evidencia de ejecución = llamada real, salida, timestamp y hash persistido; no receipts narrativos.
- Rechazo competitivo exige caso NRFI, mejor rival YRFI, factor decisivo, materialidad y condición concreta que cambiaría la decisión.
- Cero candidatos solo es válido después de procesar realmente la jornada completa.

El Alpha.1 archivado no se reactiva como producción porque usaba mocks y una política de Recovery incompatible con V2.1.

Estado de autorización: `REAL_MONEY_AUTHORITY = FALSE`.
