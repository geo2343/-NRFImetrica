# @AnalistaDepuracionRNFI_D — production migration chain

Production Supabase project: `yejaollmavoudbxnbpll` (`nrfimetrica-kernel`).

Canonical source:
- Drive document: `1ZsPlc2tOSzRH4_XQB0IpzwLGTQxeGASsjy8Cbzy3HLM`
- SHA-256: `121f80c4569de1f87c438f96fbd48364a1756afee17a38f3f1f33698a67caea9`
- Source lines: 18,569
- Binding source subsections: 1,057

Applied production migrations, in order:
1. `depurnrfi_d_tables_v1`
2. `depurnrfi_d_guards_and_hashes_v1`
3. `depurnrfi_d_state_machine_v1`
4. `depurnrfi_d_manual_dialogue_v1`
5. `depurnrfi_d_drive_readback_gate_v1`

## Phase contract

`F1 → F2 → F3 → F4 → F5 → F6 → F7 → F8 → F9 → D1 → D2 → F10 → F11 → REPORT_D → PRE_DIALOGUE_FREEZE → DIALOGUE`

Requirement counts:
- F1 27
- F2 69
- F3 80
- F4 124
- F5 145
- F6 144
- F7 152
- F8 85
- F9 93
- D1 19
- D2 20
- F10 54
- F11 45
- total 1,057

## Runtime tables

- `depurnrfi_d_agent_registry`
- `depurnrfi_d_phase_catalog`
- `depurnrfi_d_requirement_catalog`
- `depurnrfi_d_runs`
- `depurnrfi_d_requirement_state`
- `depurnrfi_d_phase_receipts`
- `depurnrfi_d_artifacts`
- `depurnrfi_d_pre_dialogue_reports`
- `depurnrfi_d_dialogue_turns`
- `depurnrfi_d_dialogue_closings`
- `depurnrfi_d_events`
- `depurnrfi_d_kernel_test_results`

## Kernel RPCs

- `depurnrfi_d_create_run`
- `depurnrfi_d_submit_phase`
- `depurnrfi_d_register_artifact`
- `depurnrfi_d_mark_artifact_readback`
- `depurnrfi_d_commit_pre_dialogue_report`
- `depurnrfi_d_grant_user_authorization` — external service-role control plane only; NOT exposed by the agent Edge runtime
- `depurnrfi_d_commit_dialogue_turn_authorized`
- `depurnrfi_d_commit_dialogue_closing_authorized`
- `depurnrfi_d_get_state`

## Dialogue invariant

The autonomous run ends only after a complete `FINAL_DEPURATION_REPORT_D` has been persisted, Drive-readback verified, hashed and frozen. From there the state is `STOP_WAITING_USER_AUTHORIZATION`.

Every D dialogue intervention consumes exactly one explicit external user authorization. The same authorization cannot be reused. The Edge function deliberately refuses `grant_user_authorization`. After each D response, `auto_continue=false` and the state returns to `STOP_WAITING_USER_AUTHORIZATION`, so the user can copy the full response to the other AI. D closes its own participation first; A retains final system-closing authority.

## Production audit

Physical adversarial/E2E suite executed in production: `DDEP-T01` through `DDEP-T19`.
Observed result at certification build time: 19/19 PASS; audit fixture residue = 0.
