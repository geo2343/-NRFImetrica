# @Investigarfullunder — production migration chain

Canonical Supabase project: `yejaollmavoudbxnbpll` (`nrfimetrica-kernel`).

Mother SHA-256: `18da7c034b9c2ff156b063ac1a12cc7f62b556c0bec55832d79a70c9246ab4de`.

Production migrations, in physical order:

1. `20260821012749 investigarfullunder_kernel_v1_schema`
2. `20260821013110 investigarfullunder_kernel_v1_hardening`
3. `20260821013223 investigarfullunder_kernel_v1_binding_and_handoff_integrity`
4. `20260821013303 investigarfullunder_kernel_v1_decision_boundary_precision`
5. `20260821013403 investigarfullunder_kernel_v1_requirement_phase_binding`
6. `20260821013530 investigarfullunder_kernel_v1_audit_cleanup_safety`
7. `20260821015523 investigarfullunder_handoff_visual_contract_v11`
8. `ifu_exhaustive_report_close_runtime_gaps`
9. `ifu_exhaustive_report_register_patch_state`

Final production objects use the dedicated `fullunder_` prefix and are separate from `mlb_v2_*` / `@AnalistaaNRFI` state.

## Final enforced invariants

- one bound Pregame MLB game per run;
- constitutive target, versions and Mother hash immutable;
- target-binding hash derived by Postgres;
- strict F1→F8 state machine;
- 889 active requirement containers, bound to their active phase;
- every requirement now requires its own `fullunder_requirement_execution_detail` record;
- each detail requires specific `result_text`, non-empty `data_payload`, physical `evidence_refs` and `output_refs`;
- generic reusable coverage language is rejected physically;
- unresolved requirement details require recorded recovery attempts;
- requirement evidence refs must resolve to physical evidence IDs from the same run and phase;
- requirement detail rows can only be written through the Kernel command bus action `SET_REQUIREMENT_DETAILS`;
- direct writes to the requirement-detail table remain forbidden;
- phase close is blocked unless the detailed requirement audit passes for that phase;
- `SATISFIED` requires a physical evidence/output reference;
- no `NOT_EXECUTED` requirement at phase close;
- recursive market contamination guard;
- recursive sports-decision contamination guard;
- no phase receipt after first pitch;
- source temporal firewall uses `available_at/published_at/updated_at/as_of/retrieved_at`;
- F2/F3 require B1–B9 first sweep, selective second sweep, B6–B9 omission check, starter current version, batter×pitch matrix, bullpen reconstruction and previous-game reconstruction;
- F4 context cannot become a sports conclusion;
- F5 preserves raw data and enforces comparability;
- F6 cannot ignore triggered autonomous questions;
- F7 allows documented legitimate pending but forbids ignored recoverable pending;
- F8 requires neutral signals, attention map, tensions and analyst questions;
- phase receipts immutable;
- event hash chain;
- required final artifacts: `FULL_UNDER_PREGAME_EVIDENCE_DOSSIER`, `ANALYST_HANDOFF_BRIEF`, `MASTER_RESEARCH_REPORT`, `FULL_REQUIREMENT_EXECUTION_APPENDIX`;
- the exhaustive appendix is generated from the detailed execution ledger, written to Drive, read back, and hash-matched before handoff;
- each final artifact requires readback hash equality;
- `ANALYST_HANDOFF_BRIEF` must satisfy `FULLUNDER-HANDOFF-FORMAT-1.1`;
- the handoff brief must account for all 20 canonical F8 sections;
- minimum visual structure: 20 headings, 15 tables/structured boxes and 20 bold anchors;
- visual hierarchy and structure readback must both PASS;
- the structure receipt is immutable and its `structure_hash` is part of the final handoff hash;
- plain-text/unstructured handoff is not eligible for `READY_FOR_ANALYST`;
- handoff role, game, target, Mother, artifact types and cryptographic handoff hash are enforced;
- `READY_FOR_ANALYST` and `COMPLETED` now have an independent canonical invariant: they are rejected unless all 889 detailed requirement records pass, all F1→F8 watchdogs pass, the exhaustive appendix passes readback/hash verification and a valid handoff exists;
- audit fixtures may be purged only through a SECURITY DEFINER cleanup function after `audit_fixture=true` verification.

## IFU-EXHAUSTIVE-REPORT-1.0 repair

A real CHC@SEA run exposed a semantic-depth failure: the old run had `889/889` requirement states but only a small evidence set and no individual execution-detail records. That allowed an over-compressed report to appear complete.

The repaired Kernel is `FULLUNDER-RESEARCH-KERNEL-1.2.1-EXHAUSTIVE-COVERAGE`.

The legacy CHC@SEA run `58739976-4be5-47bb-9e21-06715facf0ff` was physically changed from `COMPLETED / ready_for_analyst=true` to `INVALIDATED_REQUIREMENT_REBUILD / false` because its detailed audit is `0/889`.

Source migration for the hardening is tracked in `supabase/investigarfullunder/IFU_EXHAUSTIVE_REPORT_1_0.sql`.

## Physical validation

Original Supabase adversarial/positive suite after the visual-contract upgrade: `54/54 PASS`, `0 FAIL`.

IFU-EXHAUSTIVE-REPORT-1.0 patch tests:
- legal command-bus detail write with physical tool/source/evidence lineage → PASS;
- generic reusable requirement detail → REJECT with `FULLUNDER_REQUIREMENT_DETAIL_GENERIC_TEXT_FORBIDDEN`;
- direct requirement-detail table write → REJECT with `FULLUNDER_REQUIREMENT_DETAIL_DIRECT_WRITE_FORBIDDEN`;
- premature F1 close at `0/93` detailed requirements → REJECT with `FULLUNDER_REQUIREMENT_DETAIL_AUDIT_FAILED`;
- attempt to restore invalid CHC@SEA to READY at `0/889` → REJECT with `FULLUNDER_READY_REQUIREMENT_DETAIL_INCOMPLETE`.

All synthetic patch tests used rollback fixtures; fixture residue: `0`.

Operational certification remains deliberately disabled until a fresh real MLB run completes under the exhaustive standard.

Official Drive handoff template: `1BJPRwLNbHr9i1LKANUWD1LfRPq0OfECyijUFZ0wAOyw`.

Edge Function: `investigarfullunder-kernel`, runtime version `3`, JWT required. The Edge remains a command-bus gateway; the exhaustive coverage enforcement is implemented in the Supabase control plane.
