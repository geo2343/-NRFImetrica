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

Final production objects use the dedicated `fullunder_` prefix and are separate from `mlb_v2_*` / `@AnalistaaNRFI` state.

## Final enforced invariants

- one bound Pregame MLB game per run;
- constitutive target, versions and Mother hash immutable;
- target-binding hash derived by Postgres;
- strict F1→F8 state machine;
- 889 active requirement containers, bound to their active phase;
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
- required final artifacts: `FULL_UNDER_PREGAME_EVIDENCE_DOSSIER`, `ANALYST_HANDOFF_BRIEF`, `MASTER_RESEARCH_REPORT`;
- artifact identity immutable and final artifacts immutable after handoff;
- each final artifact requires readback hash equality;
- `ANALYST_HANDOFF_BRIEF` must satisfy `FULLUNDER-HANDOFF-FORMAT-1.1`;
- the handoff brief must account for all 20 canonical F8 sections;
- minimum visual structure: 20 headings, 15 tables/structured boxes and 20 bold anchors;
- visual hierarchy and structure readback must both PASS;
- the structure receipt is immutable and its `structure_hash` is part of the final handoff hash;
- plain-text/unstructured handoff is therefore not eligible for `READY_FOR_ANALYST`;
- handoff role, game, target, Mother, artifact types and cryptographic handoff hash are enforced;
- `READY_FOR_ANALYST` and `COMPLETED` are derived only from valid handoff;
- audit fixtures may be purged only through a SECURITY DEFINER cleanup function after `audit_fixture=true` verification.

## Physical validation

Supabase adversarial/positive suite after the visual-contract upgrade: `54/54 PASS`, `0 FAIL`.

Specific v1.1 tests:
- handoff without structure receipt → REJECT;
- incomplete 20-section inventory → REJECT;
- insufficient table structure → REJECT;
- complete structural receipt → ACCEPT;
- full F1→F8→structured handoff → `COMPLETED / READY_FOR_ANALYST`.

Audit fixture residue after the test: `0`.

Official Drive handoff template: `1BJPRwLNbHr9i1LKANUWD1LfRPq0OfECyijUFZ0wAOyw`; physical readback found the 20 canonical F8 blocks as heading structure and 21 real tables.

Edge Function: `investigarfullunder-kernel`, runtime version `2`, Kernel `FULLUNDER-EDGE-KERNEL-1.1`, JWT required, deployed hash `d893cb50007ea966b31cbf01d354f6925f80c569a3b75a7cb20575453fb8beea`.
