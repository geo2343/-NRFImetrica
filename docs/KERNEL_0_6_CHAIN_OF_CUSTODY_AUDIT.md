# @NRFImetrica — Kernel 0.6 Chain of Custody Audit

Date: 2026-08-19

## Canonical state

- System: `NRFIM MOTHER V3`
- Agent: `MOTHER-V3-AGENT-1.1`
- Kernel: `NRFIM-KERNEL-0.6-CHAIN-OF-CUSTODY`
- Sovereign protocol: `NRFIMETRICA_MOTHER_V3_AUTONOMOUS`
- Required process extension: `NRFIMETRICA_SPORTS_REASONING_PACKET_V2`
- Mother SHA-256: `d16896eba602af272117a5c83b56245aa201979d394301781d424e705b3642d3`
- Real-money authority: `FALSE`
- System state: `TRADING_HALT_RESEARCH`

## Why 0.6 exists

The first live Mother V3 invocation produced sports judgments for all 15 games but did not leave sufficient physical per-game provenance. The run had only global evidence, no per-game research packet, no tool trace, a zero tool-call counter, no Drive run dossier, and an invalid earlier AS_OF label relative to the actual evidence retrieval time.

Kernel 0.6 repairs the process proof without turning sports reasoning into a numerical score. The AI remains the causal analyst. The Kernel proves that the research actually occurred.

## New physical chain

`RESEARCH_TOOL_EVENT -> SOURCE_FAMILY -> EVIDENCE_ID + SNAPSHOT -> FACTUAL CLAIM -> SPORTS_REASONING_PACKET -> FREEZE/HASH -> DRIVE -> PROCESS AUDIT -> SPORTS_REASONING_SLATE`

Physical tables:

- `research_tool_events`
- `research_source_families`
- enhanced `evidence`
- `sports_reasoning_packets`
- `sports_reasoning_claims`
- `sports_process_audits`
- `sports_process_auditor_registry`
- `research_drive_artifacts`

## Deterministic rules

1. Sports evidence cannot exist without a real research tool event.
2. Research tool timestamps are DB-owned; caller timestamps cannot backdate an event.
3. Research tool calls increment `runs.tool_call_count` and create physical `trace_events`.
4. A factual claim requires at least one chain-verified `EVIDENCE_ID`.
5. Evidence must belong to the same run/game and have source family + snapshot hash.
6. Evidence not yet public at retrieval time is rejected.
7. Exact duplicate content cannot manufacture an independent family.
8. The same declared publisher/origin cannot manufacture a second family.
9. Independent-family floors are CLEAR=3, NORMAL=5, DEEP=7; they are floors, not automatic stop rules.
10. `ANALYSIS_COMPLETE` requires bilateral Top/Bottom first-inning analysis, NRFI thesis, best YRFI rival, strongest counterevidence, falsification of both sides, required dimensions and falsifiable change conditions.
11. Full-game data is only a proxy and requires an explicit first-inning causal justification.
12. Terminal packets freeze and hash. A causal change after freeze requires a new version linked by `previous_packet_hash`.
13. Every terminal packet must have a verified Drive artifact whose stored content hash matches `packet_hash` before the sports slate can seal.
14. The process auditor is deterministic `KERNEL_PROCESS_AUDITOR_0.2`; DB derives the checks and ignores caller-supplied audit truth values.
15. Process auditor authority is PROCESS ONLY; sports voting is forbidden.
16. `SPORTS_REASONING_SLATE` generates the exact `N/TOTAL ANALISIS_COMPLETOS`; the model cannot freewrite or round this statement.
17. Final report must match sports-slate counts.
18. A Mother V3 run cannot close without a verified Drive `FINAL_REPORT` artifact.

## Separation from A1–A8

The Sports Reasoning Packet proves the causal sports investigation. It does not certify a contract. A1–A8 remain the sovereign certification/execution flow.

Therefore:

- Missing A4/A7/A8 does not excuse skipping sports analysis.
- A strong sports judgment does not become an executable bet without A1–A8 authorization.
- An incomplete local game is reported as incomplete and does not stop the rest of the slate.

## Live adversarial proof

Diagnostic run: `DIAG-SR-CUSTODY-20260819-1022`.

Fourteen live attacks were exercised against Supabase and passed their expected physical result:

1. evidence without tool event blocked;
2. fake historical tool timestamp overridden by DB;
3. tool-call counter + trace creation proven;
4. future/unavailable evidence blocked;
5. factual claim without evidence blocked;
6. insufficient independent source families blocked;
7. exact duplicate content cannot create a new family;
8. same declared publisher/origin collapses to one family;
9. valid packet freezes and hashes;
10. Drive/process audit binds to packet hash;
11. fake auditor / caller audit booleans ignored and DB-derived;
12. post-freeze causal tampering blocked;
13. false sports-slate counts blocked;
14. run close without Drive final report blocked.

Result: `14/14 LIVE ADVERSARIAL CASES PASSED`.

## Honest limits

Kernel 0.6 does **not** automatically decide whether a baseball mechanism is good reasoning. That remains semantic/causal work of the analyst and process review must not become a hidden sports score.

The DB can physically collapse exact duplicate content and identical declared origins. Detecting non-identical articles that silently derive from the same underlying wire/feed still requires better provenance classification or semantic comparison; it is not claimed as solved deterministically.

The DB also cannot independently fetch Google Drive by itself. A Drive artifact is considered verified only after the authorized Drive integration performs readback and the integration records the matching hash. The database enforces the attestation and hash relationship; it does not pretend to be the Google Drive API.

Finally, Kernel 0.6 does not change the real-money halt. There are still no `ACTIVE_TRUSTED` A4 numeric engine, independent A6 auditor, or certified A7 calibration authority. This reform strengthens research fidelity and evidence custody; it does not fabricate those missing components.
