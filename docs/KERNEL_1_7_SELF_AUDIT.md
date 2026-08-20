# @NRFImetrica — Kernel 1.7 Self-Audit

Fecha: 2026-08-20

## Identidad auditada

- System: `NRFIM MOTHER V3`
- Agent: `MOTHER-V3-AGENT-1.12`
- Kernel: `NRFIM-KERNEL-1.7-SELF-AUDIT-HARDENED`
- Protocol: `NRFIMETRICA_MOTHER_V3_AUTONOMOUS`
- Mother SHA256: `799ccb5a483e7991f880ae7d49d2f191a98e292478ec64e76a55aa8250ec498b`
- Real-money authority: `false`

## Hallazgos reales de la auditoría

La revisión adversarial posterior a la activación anterior encontró brechas ejecutables, no simples diferencias documentales:

1. A7 podía aceptar una declaración de `SYSTEM_RELIABILITY` sin lineage físico a una auditoría histórica sellada.
2. A8 podía aceptar incoherencias entre `A7_ELIGIBILITY_STATUS`, `EXECUTION_AUTHORITY` y el veredicto económico.
3. La vista de acción al usuario necesitaba un cierre fail-closed explícito sobre process audit, Drive hash, bilateralidad, A7 y A8.
4. Un `source_receipt` autoconsistente podía presentarse como verificación sin un evento receptor kernel-attested.
5. Un item Press `UNRESOLVED` no forzaba suficientemente reanálisis antes de release.
6. U1.5/U2.5 podían aproximarse a ejecución sin certificación target-specific propia.
7. La falsación podía forzar la fabricación de un rival YRFI para llenar el campo.
8. La auditoría de autoridad Press debía comprobar los cinco ejes: sports, probability, ranking, market y conclusion.
9. Persistía una superficie DML innecesaria para `anon/authenticated` sobre las vistas finales, detectada por la auditoría terminal post-070.

## Evidencia de que los huecos existían

Antes de corregir se ejecutaron dos ataques que atravesaron el Kernel. Se conservaron en `nrfimetrica_kernel_tests` bajo `V16_SELF_AUDIT_PRE_FIX` como `GAP_CONFIRMED` con `passed=false`:

- `a8_inconsistent_eligibility_and_execution_authority_gap`
- `a7_unbacked_system_reliability_gap`

No fueron reescritos ni convertidos en PASS después de la corrección.

## Correcciones

- `069_nrfimetrica_v17_self_audit_hardening.sql`
- `070_nrfimetrica_v17_unresolved_reanalysis_assertion.sql`
- `071_nrfimetrica_v17_lock_client_dml_views.sql`

Entre otras medidas:

- provenance física del intake A0P mediante evento receptor kernel-attested;
- `EMPTY_PACKET` sustituye la pretensión del productor de decidir materialidad;
- `UNRESOLVED` implica reanálisis y bloquea release;
- `SYSTEM_RELIABILITY` exige auditoría física por `MODEL_VERSION + TARGET_ID`, o `NOT_AVAILABLE/BLOCK`;
- U0.5 es el único target económicamente certificado por esta versión; U1.5/U2.5 quedan research-only hasta certificación propia;
- A8 exige lineage, proceso PASS, Drive hash, bilateralidad, T-10 y coherencia entre autoridad y veredicto;
- `NO_SUPPORTED_RIVAL` es válido únicamente después de búsqueda adversarial documentada con evidencia;
- probabilidad fabricada por IA queda prohibida globalmente;
- user action es fail-closed;
- vistas finales son read-only para `anon/authenticated`.

## Regresión adversarial

Suite `V17_SELF_AUDIT_POST_FIX`: `12/12 PASS`.

Incluye ataques contra elegibilidad A8, system reliability inventada, Press unresolved, release con reanálisis, target U1.5 sin certificación, autoridad económica inconsistente, receipt autoconsistente sin kernel event, probabilidad IA y rival adversarial fabricado.

## Auditoría terminal post-071

Suite `V17_POST_071_TERMINAL_AUDIT`: `20/20 PASS`, `0 FAIL`.

La suite cubre:

- identidad y hash de registry/system_versions/protocol_authority;
- migraciones 069–071 en Supabase;
- 12/12 adversarial;
- preservación de los dos GAP_CONFIRMED;
- RLS de tablas propias;
- cero DML cliente sobre superficies `nrfimetrica_%`;
- cero `SECURITY DEFINER` relevante;
- `search_path` seguro;
- cero RPC interno ejecutable por `anon/authenticated`;
- triggers v1.7 activos;
- contratos A7/A8 vigentes;
- user-action fail-closed;
- códigos legacy prohibidos prospectivamente;
- cero RUN abiertos;
- hash externo del Documento Madre;
- paridad de GitHub hasta 071 y readback de README/manifest.

## Límites de autoridad

`@NRFIprensa` no fue modificado por esta reforma. Notion no fue modificado. La reforma es del lado receptor de `@NRFImetrica`.

La activación del agente no concede autoridad económica automática. `REAL_MONEY_AUTHORITY=false` permanece. Además, sin `SYSTEM_RELIABILITY_AUDIT` válido para el target, A7 debe producir `NOT_AVAILABLE/BLOCK`; no se fabricará una auditoría para abrir dinero real.

## Doctrina vigente

`EL PARTIDO SE ANALIZA. EL SISTEMA SE CALIBRA.`

La calibración histórica audita al sistema y nunca sustituye, reajusta ni domina la evidencia causal del partido actual.
