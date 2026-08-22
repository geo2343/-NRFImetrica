# KENDEL MLB — Production Architecture & Global Inventory Chain

Supabase project: `yejaollmavoudbxnbpll`

This directory records the cross-system architecture repair introduced on 2026-08-21. Sports-methodology Mother Documents remain authoritative for sports reasoning; this chain governs identity, execution proof, discovery, and inventory.

## Core distinction

`GLOBAL_AGENT_INVENTORY` answers: **what agents/systems/auditors physically exist?**

`KENDEL_COMPONENT_REGISTRY` answers: **which of those belong to KENDEL, and in what architectural state?**

`GLOBAL_EXISTENCE != KENDEL_MEMBERSHIP`.

## Applied production migrations

1. `kendel_constitution_v01_component_registry_and_dynamic_auditor`
   - Unified KENDEL component registry.
   - Multi-dimensional design/implementation/certification/runtime/authority/audit states.
   - Universal `kendel_execution_claims` K-EXEC proof ledger.
   - Auditor menu/resolution derived dynamically from component registry.
   - Generic architecture audit profile for DOCUMENT_ONLY/DRAFT objects.

2. `kendel_dynamic_auditor_preserve_depurnrfi_d_deep_profile`
   - Preserved the stronger dedicated Depuration NRFI D V1.1 baseline after the dynamic-auditor refactor.

3. `kendel_dynamic_auditor_selftest_ambiguity_fix`
   - Fixed PL/pgSQL `passed` output/column ambiguity found by fresh self-test.

4. `kendel_p0_core_rls_hardening`
   - Enabled RLS on central KENDEL registry/test surfaces and two Depuration D residual tables.

5. `investigadorglobal_nrfi_rls_hardening_01`
6. `investigadorglobal_nrfi_rls_hardening_02`
7. `investigadorglobal_nrfi_rls_hardening_03`
8. `investigadorglobal_nrfi_rls_hardening_04a`
9. `investigadorglobal_nrfi_rls_hardening_04b`
10. `investigadorglobal_nrfi_rls_hardening_04c`
11. `investigadorglobal_nrfi_rls_hardening_04d`
   - Enabled RLS across all ordinary `investigadorglobal_nrfi_*` tables.

12. `investigadorglobal_nrfi_rpc_hardening_01`
13. `investigadorglobal_nrfi_rpc_hardening_02`
   - Internal SECURITY DEFINER mutation RPCs restricted to `service_role`.

14. `kendel_core_rpc_hardening_01`
   - Restricted central suite-refresh and MLB dialogue append RPCs to `service_role`.

15. `global_agent_inventory_v01`
   - Added a registry above KENDEL for all observed agents, systems, auditors, candidates, legacy identities, and non-KENDEL identities.
   - Added KENDEL/non-KENDEL views.

16. `global_agent_inventory_identity_reconciliation_v02`
   - Corrected Depuration NRFI D to canonical chain membership.
   - Consolidated legacy/internal aliases (`@AnalistaaNRFI`, `@AnalistaDNRFI`, `@AnalistaFullunder`).
   - Added registered process/diagnostic auditors.

17. `global_agent_inventory_drive_and_authority_reconciliation_v03`
   - Added/updated `@AuditorSistema`, `EL OBSERVADOR`, Colaborador JRC, Colaborador Externo.
   - Bound `@NRFIprensa` to the physical `@NRFiPrensa` authority/runtime.
   - Corrected the `@AuditorKendelMLB` command authority document, which incorrectly pointed to the specialized `@AuditorDepuracionNRFI` manual.

## Fresh validation

Dynamic Auditor self-test after architecture and security changes: `12/12 PASS`.

Observed specialized current tests: `325`, failed: `0`.

Targeted security checks after hardening:
- InvestigadorGlobal NRFI ordinary tables without RLS: `0`
- Central targeted tables without RLS: `0`
- Targeted SECURITY DEFINER RPCs exposed to anon/authenticated: `0`
- Required service-role execution missing: `0`

K-EXEC negative test: a `PROVEN` execution claim without a proof hash was physically rejected with `K_EXEC_PROVEN_REQUIRES_PROOF_HASH`.

K-EXEC positive fixture with physical proof was accepted and cleaned up; residue `0`.

## Global inventory V0.1 cut

Current traced identities/components: `43`.

- KENDEL_CANONICAL: 14
- KENDEL_AUXILIARY: 5
- KENDEL_LEGACY: 6
- NON_KENDEL: 17
- UNCLASSIFIED: 1

Current existence states after reconciliation:
- RUNTIME_PRESENT: 18
- DOCUMENT_ONLY: 20
- EMPTY_PLACEHOLDER: 1
- Remaining items are STRUCTURED.

No run artifact is counted as an agent (`RUN_ARTIFACT = 0`).

The only canonical-name collision is intentional and unresolved: `KERNEL_PROCESS_AUDITOR` versions `0.2` and `0.3` are both physically registered ACTIVE. Inventory preserves both until version authority is resolved.

## Drive authorities

Global inventory report:
`INVENTARIO MAESTRO GLOBAL DE AGENTES Y SISTEMAS IA — V0.1`
Drive ID: `1qfO4ySFmjkuqSxP4hf4lY9UMY4ZVSnDqMUJFa6a2tYE`

KENDEL Constitution:
`05 — CONSTITUCIÓN ARQUITECTÓNICA KENDEL MLB — V0.1`
Drive ID: `15kNaeIWVXuqeeJUgnRX-sjK-DNSv3aV52Xl-Vc-DEi8`

The Constitution now explicitly states that global inventory and KENDEL membership are separate authorities.
