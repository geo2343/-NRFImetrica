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
- handoff role, game, target, Mother, artifact types and cryptographic handoff hash are enforced;
- `READY_FOR_ANALYST` and `COMPLETED` are derived only from valid handoff;
- audit fixtures may be purged only through a SECURITY DEFINER cleanup function after `audit_fixture=true` verification.

## Physical validation

Supabase adversarial/positive suite: `49/49 PASS`, `0 FAIL`, audit fixture residue `0` before GitHub certification.

Edge Function: `investigarfullunder-kernel`, runtime version `1`, Kernel `FULLUNDER-EDGE-KERNEL-1.0`, JWT required, deployed hash `22548ca8f7e4d2b45d141d713738868b093e779fc7a113fbbed140469a337143`.
