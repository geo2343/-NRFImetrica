# @NRFiPrensa — SO-MEDIA NRFI V0.2 — Physical Research Kernel Audit

## Authority

- Agent: `@NRFiPrensa`
- Agent version: `V0.2-AGENT-1.0`
- Protocol: `SO_MEDIA_NRFI_V02`
- Kernel: `NRFIPRENSA-KERNEL-0.1-RESEARCH-CUSTODY`
- Sovereign document SHA-256: `a6ed0be85ea66750dbea7e3deafe717675433a78d141f0656688421e15dacbac`
- State: `RESEARCH_ONLY_TRADING_HALT`
- Real-money authority: `false`

## Architecture boundary

The AI performs causal interpretation. The Kernel proves process, lineage, freshness and hard gates. Press discovery, factual verification, metric verification, NRFI materiality, independent F8 representation and F9 confrontation remain distinct objects.

Shared infrastructure with `@NRFImetrica` is intentional: same Supabase project and GitHub repository, separate `nrfiprensa_` namespace and separate agent/protocol authority. This allows F9 to verify a real `sports_reasoning_packets` record without copying conclusions into F8.

## Adversarial suite

A disposable diagnostic run was created and deleted. Final residual diagnostic runs: `0`.

| Test | Result | Physical behavior |
|---|---|---|
| F8 without bilateral F7-Q / Red Team | PASS | blocked with `NRFIPRENSA_F8_REQUIRES_BILATERAL_F7Q` |
| Final Pregame Seal PASS without F7-Q | PASS | blocked with `NRFIPRENSA_FINAL_PASS_REQUIRES_TWO_COMPLETE_F7Q_HALVES` |
| F9 before F8 frozen | PASS | blocked with `NRFIPRENSA_F9_REQUIRES_F8_FROZEN` |
| Evidence retrieved after first pitch | PASS | blocked with `NRFIPRENSA_LIVE_EVIDENCE_CONTAMINATION_FORBIDDEN` |
| `SO_MEDIA_STRONG_NRFI` while RESEARCH ONLY | PASS | blocked with `NRFIPRENSA_STRONG_DISABLED_WHILE_RESEARCH_ONLY` |
| REVIEW_PRIORITY without Final Seal PASS | PASS | blocked with `NRFIPRENSA_REVIEW_PRIORITY_REQUIRES_FINAL_PREGAME_SEAL_PASS` |
| PACK-I containing odds | PASS | blocked with `NRFIPRENSA_PACK_I_CLEAN_ROOM_CONTAMINATION` |
| Close run without F10 disposition for every game | PASS | blocked with `NRFIPRENSA_CLOSE_REQUIRES_F10_DISPOSITION_FOR_ALL_GAMES` |
| Fourth transfer candidate | PASS | blocked with `NRFIPRENSA_MAX_THREE_TRANSFER_CANDIDATES` |

## Bug found during adversarial testing

The first combined test exposed a PostgreSQL three-valued-logic issue: `seal <> 'PASS'` does not evaluate to true when `seal` is NULL. A missing seal could therefore bypass a naïve negative comparison. The same class of issue was reviewed for starter state and Red Team state.

Migration `037_fix_nrfiprensa_null_gate_semantics.sql` changed these gates to fail closed with explicit `COALESCE` checks. The full adversarial suite was rerun after the correction and passed.

## Non-negotiable research-only rules

- `HOLD_DYNAMIC = NO BET`.
- `REVIEW_PRIORITY != PICK`.
- `TRANSFER != PICK`.
- F8 freezes before any JRC conclusion is allowed into F9.
- `PACK-I` excludes picks, consensus, odds, line movement, shortlist, JRC conclusion and SO-MEDIA ranking.
- Current roster/BvP cannot masquerade as official B1–B5.
- Q5 CONTACT DAMAGE, Q6 ONE-SWING RISK and Q11 no-walk run paths cannot be omitted from a favorable clean representation.
- No Live data may reconstruct a pregame thesis after first pitch.
- No P(NRFI), edge, EV, stake or execution authority may be fabricated inside SO-MEDIA.

## Deployment truth

This audit proves the Supabase enforcement and GitHub source state. It does **not** claim a standalone Vercel deployment. A real full-slate sporting execution has not yet been used as proof of production readiness. The next validation object is a fresh clean-room MLB slate run in research-only mode.
