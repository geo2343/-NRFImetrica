# @NRFImetrica Kernel

Kernel externo para `@NRFImetrica` V2.1.

Arquitectura mínima:

- GitHub: código y versionado.
- Vercel: servidor HTTP del Kernel.
- Supabase: ledger persistente de runs, games, evidence, trace, recoveries, decisions y audit events.
- ChatGPT/LLM: razonamiento causal y síntesis.
- Google Drive: informes/documentación; no es el runtime.

Estado actual: `FOUNDATION_REAL_RUNTIME_BUILDING`.

Reglas duras:

- Scope exclusivo `NRFI_ONLY`.
- No inventar P(NRFI), edge, EV ni autorización real-money.
- Máximo un Recovery material por `ISSUE_ID`.
- Un fallo local no detiene la jornada.
- El LLM no puede auto-certificar ejecución.
- Evidencia real = tool call/output/timestamp/hash persistido.
- Rechazo competitivo exige mejor caso NRFI, mejor rival YRFI, factor decisivo, materialidad y qué cambiaría la decisión.

El Alpha.1 archivado no se reactiva como producción porque usaba mocks y una política de Recovery incompatible con V2.1.
