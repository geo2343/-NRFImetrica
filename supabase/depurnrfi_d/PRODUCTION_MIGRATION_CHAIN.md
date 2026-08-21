# @AnalistaDepuracionRNFI_D — production migration / certification chain

Current agent: `ANALISTADEPURACIONRNFI-D-AGENT-1.1`  
Current control plane: `ANALISTADEPURACIONRNFI-D-KERNEL-1.1.1`  
Supabase project: `yejaollmavoudbxnbpll` (`nrfimetrica-kernel`)  
Edge: `analista-depuracion-nrfi-d-kernel`, runtime version 3, JWT required.

## Canonical source

- Drive source document: `1ZsPlc2tOSzRH4_XQB0IpzwLGTQxeGASsjy8Cbzy3HLM`
- Canonical exported-text SHA-256: `c46dc9a945d37e3e53e2a6e3879045c6c7de38b25ea5f92894fded5cbaff857b`
- Binding subsections: 1,057
- Literal source locators materialized: 1,057/1,057
- Placeholder requirement titles remaining: 0

Counts: F1=27, F2=69, F3=80, F4=124, F5=145, F6=144, F7=152, F8=85, F9=93, D1=19, D2=20, F10=54, F11=45.

## Sovereign route

`F1 → F2 → F3 → F4 → F5 → F6 → F7 → F8 → F9 → D1 → D2 → F10 → F11 → REPORT_D → PRE_DIALOGUE_FREEZE → DIALOGUE`

F10 is the first final selection authority and may leave 0–4 candidates. F11 produces dossiers, never bets. After REPORT_D the agent stops. Each D dialogue response consumes one new explicit user authorization. D closes its participation first; A retains final system-close authority.

## Applied production migrations

Base V1.0:
1. `depurnrfi_d_tables_v1`
2. `depurnrfi_d_guards_and_hashes_v1`
3. `depurnrfi_d_state_machine_v1`
4. `depurnrfi_d_manual_dialogue_v1`
5. `depurnrfi_d_drive_readback_gate_v1`

V1.1 hardening and operability:
6. `depurnrfi_d_v11_evidence_e1_foundation`
7. `depurnrfi_d_v11_operational_rpcs`
8. `depurnrfi_d_v11_report_dialogue_authorization`
9. `depurnrfi_d_v11_command_bus_and_plan`
10. `depurnrfi_d_v11_edge_actor_boundary`
11. `kendel_auditor_depurnrfi_d_v11_profile`
12. `depurnrfi_d_v11_semantic_anti_bypass_hardening`
13. `depurnrfi_d_v11_adversarial_suite`
14. `kendel_refresh_depurnrfi_d_v11_suite`
15. `depurnrfi_d_v11_literal_catalog_schema`
16. `depurnrfi_d_v11_literal_catalog_chunk_01`
17. `depurnrfi_d_v11_literal_locator_01`
18. `depurnrfi_d_v11_literal_locator_02`
19. `depurnrfi_d_v11_literal_catalog_materializer`
20. `depurnrfi_d_v11_literal_catalog_materializer_v2`
21. `depurnrfi_d_v11_literal_catalog_hard_gate`
22. `depurnrfi_d_v11_structural_smoke_builder`
23. `depurnrfi_d_v11_real_drive_smoke_commit`
24. `kendel_refresh_depurnrfi_d_v11_include_cert_smoke`
25. `depurnrfi_d_v11_security_boundary_final`
26. `depurnrfi_d_v11_service_role_least_privilege`
27. `depurnrfi_d_v11_version_alignment_final`

The authoritative applied order is Supabase migration history. This document mirrors it for code review and reconstruction. `schema_contract.sql` is the fail-closed post-migration verifier.

## Reproducible canonical catalog

The repository includes `tools/materialize_depurnrfi_d_catalog.py`. Given a text export of the canonical Drive document, it:
- verifies the exact source SHA-256;
- parses all F1/F2/F3A…F9A/D1/D2/F10/F11 headings;
- verifies the exact per-phase counts and 1,057 total;
- records title and exact source line range;
- emits JSON suitable for `depurnrfi_d_materialize_literal_catalog_v11`.

The source text itself is not copied into GitHub. Reconstruction therefore requires a fresh export of the canonical Drive document whose SHA matches the pinned source fingerprint.

## V1.1 control plane

The reasoning plane is ChatGPT. The Supabase Kernel is `CONTROL_PLANE_ONLY` and enforces input identity, requirement attestations, evidence/tool-event lineage, E1 receipts, state_version, idempotency, phase legality, causal integrity, F10 max-four, real Drive proof, report freeze and user-authorized dialogue.

Direct PostgREST access is fail-closed:
- every `depurnrfi_d_*` table has RLS;
- `anon` direct RPC count = 0;
- `authenticated` direct RPC count = 0;
- legacy `depurnrfi_d_submit_phase` has no service-role EXECUTE;
- service-role Edge allowlist contains only six operational surfaces: create run, bind actor, assert actor, command bus, execution plan and state read.

## Physical certification evidence

Current suite: `DEPURNRFI-D-CURRENT-1.1` = **21/21 PASS, 0 FAIL**.

It contains 15 adversarial V1.1 tests plus certification tests for:
- literal catalog 1,057/1,057;
- full structural F1→F11 traversal with 13 E1 phase receipts;
- real Google Drive document/revision/readback/hash;
- one authorization → exactly one D response;
- D closes first / A retains system close;
- direct-access least-privilege security boundary.

Real Drive smoke artifact:
- file ID `1Xu9Dgf6PCfktUMVbr3pqsGGGnvMKGcrSe6V0CsOPuTE`
- revision `2`
- exported-text SHA-256 `d46ea2d72cdd0f2b8033023d8d6bc0f0444bc81cbfa88a49aa50eb3ff316271b`

The smoke fixture was removed from runtime state after evidence capture: run/auth/tool-event/evidence residue = 0.

Kendel dedicated baseline after final hardening: **10/10 PASS** against the correct `FULL_MLB_SLATE` profile, with D1=19, D2=20 and the V1.0 bypass observed as revoked.

The structural smoke certifies process operability, not sports predictive quality. Sports-analysis quality is evaluated on real MLB runs without changing the operational readiness of the control plane.
