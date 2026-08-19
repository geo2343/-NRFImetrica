# @NRFImetrica — KERNEL 0.5 MOTHER ENFORCEMENT AUDIT

## Authority

- Mother document SHA-256: `d16896eba602af272117a5c83b56245aa201979d394301781d424e705b3642d3`
- Mother document lines: `15570`
- Active protocol: `NRFIMETRICA_MOTHER_V3_AUTONOMOUS`
- Active Kernel: `NRFIM-KERNEL-0.5-MOTHER-ENFORCED`
- Precedence: `LATEST_SOVEREIGN_PATCH_WINS`
- Latest sovereign reform: `A0-GOV.18 — REFORMA OPERATIVA SOBERANA V3`

## Manual-to-autonomous adaptation

The original user-authorized phase progression has been replaced by automatic gate progression:

`A0 AUTO-SEAL -> A1 -> A2 -> A3 -> A4 -> A5 -> A6 -> A7 -> A8 -> PORTFOLIO -> FINAL_REPORT`

The removal of manual user authorization does not remove phase responsibilities. A later phase cannot fabricate a missing upstream output.

## Enforcement layers

### A0

- Exact mother-document hash required.
- Manual authorization flag must remain false in autonomous runtime.

### A1

- Full game identity and scheduled-start continuity.
- First-inning pitcher identity/role/hand.
- Lineup state and 1–9 representation.
- Freeze, as-of, DATA_AVAILABLE_AT, anti-leakage.
- Market quarantine.
- Research handoff separated from real-money authority.
- Official lineup/final freeze required for real-money path.

### A2

- Hierarchical/regularized baselines.
- Shrinkage and sample state.
- Dependency clusters / double-count control.
- Provenance.
- Market blindness.

### A3

- Current Version and matchup representation.
- Arsenal/execution/location access.
- B1–B3 plus B4/B5 conditional exposure.
- Failure modes, two-out extension, B4+ exposure.
- No numeric fabrication.

### A4

- Numeric output can only come from a registered physical execution.
- `CONTROLLED_REAL` requires `ACTIVE_TRUSTED` engine.
- Execution metadata must match run/game/model/transition/freeze.
- Persisted output hash must validate.
- Phase Top/Bottom distributions must exactly match physical engine output.
- Probability mass and state sanity enforced.

### A5

- A4 execution lineage required.
- Joint `P0/P1/P2/P3+` required.
- `P(U0.5)=P0`.
- `P(U1.5)=P0+P1`.
- `P(U2.5)=P0+P1+P2`.
- `P(YRFI)=1-P0`.
- RAW remains distinct from calibrated probability.

### A6

- Causal case and strongest rival.
- Independent audit cannot be the primary analyst.
- Audit must have a physical execution and trusted registered auditor.
- Audit phase summary must match physical auditor output.
- SRA packet is physical and hash-bound.
- Frozen pre-press verdict required.
- Sports Seal remains market-blind.
- Required wait marker: `ESPERANDO RESULTADO DE NRFI-PRENSA`.

### A7

- Must preserve A1/A4/A5 lineage.
- Core target is the zero-run thesis (`U0.5/NRFI`).
- NRFI-Prensa packet must be physical, verified, temporally valid and hash-bound.
- Phase press facts must match packet facts; press is not a vote.
- Contract-specific calibration certification is required for any contract marked certified.
- Diagnostic calibration cannot authorize a controlled-real run.
- `A7_NOT_CERTIFIED -> A8_LOCKED`.

### A8

- A7 release and absolute eligibility required.
- Displayed `P0/P1/P2/P3+` must be the A5 distribution.
- Selected line must have its own valid calibration authority.
- `P_CONSERVATIVE` must come from selected-contract calibration.
- Market offer must be a physical verified offer with evidence.
- Break-even is derived from the verified offered price.
- T-5 revalidation must be physical and verified.
- Material T-5 change forces full recompute; it cannot be manually waived.
- Starter and official lineup must remain verified.
- Edge/EV mathematics enforced.
- Nonpositive edge/EV cannot produce `APOSTAR`.
- U1.5/U2.5 cannot rescue a weak zero-run thesis.

## Slate and terminal resolution

A game may terminate honestly without filling false downstream phases. `protocol_game_resolution` records material terminal states such as:

- A1 unresolved/non-executable;
- A4 engine not integrated / true model failure;
- A6 independent auditor unavailable;
- A7 not eligible / research only / calibration uncertified / press unavailable;
- AUDIT_ONLY / LOCAL_DATA_BLOCK.

Every terminal resolution requires a specific reason, materiality, what would resolve it, and real evidence/Recovery when applicable.

The slate cannot close while a registered game remains unresolved.

## Portfolio and tickets

- 0–3 candidates allowed.
- Candidate identity is `GAME + LINE`.
- No fourth candidate.
- With 2–3 candidates, tickets are separately evaluated economic objects.
- Ticket price must be real/offered.
- Joint probability, break-even, edge, EV and dependence/correlation must be audited.
- A parlay does not create value merely by combining individually acceptable selections.

## Final report

The mother FINAL_REPORT must match:

- resolved slate counts;
- A8 candidate identities;
- A5/A8 probabilities;
- prices/value fields;
- ticket evaluations;
- final verdict.

Zero candidates is a legitimate final state and may close as `NO_HAY_PICK`.

## Physical adversarial validation performed

The database physically rejected attempts to:

- enter A1 without A0;
- use a false mother-document hash;
- grant real-money authority to projected lineups;
- fabricate an AI probability;
- skip A1 and enter A2;
- use an A4 phase without real numeric execution;
- use a diagnostic engine in a CONTROLLED_REAL run;
- alter A4 probability mass/contract derivation;
- self-certify the independent audit;
- omit SRA;
- alter SRA hash;
- alter the phase audit after citing a physical auditor execution;
- alter A4 outputs after citing a physical numeric execution;
- use future/unbound source calls;
- alter press content after citing a physical NRFI-Prensa packet;
- issue A7 release without certification;
- enter A8 without A7 release;
- submit inconsistent portfolio counts;
- close a mother run without mother FINAL_REPORT.

A CONTROLLED_REAL diagnostic behavior test reached A1–A3, found no `ACTIVE_TRUSTED` A4 engine, created no fake A4 phase, resolved as `A4_ENGINE_NOT_INTEGRATED`, produced 0 picks and closed with `NO_HAY_PICK`.

## Current authority state

Intentionally blocked:

- `ACTIVE_TRUSTED` numeric engines: 0.
- `ACTIVE_TRUSTED` independent auditors: 0.
- `ACTIVE_TRUSTED` calibration certifications: 0.
- real-money authorization: false.
- system state: `TRADING_HALT_RESEARCH`.

The Kernel enforcement architecture is in place. A real-money route remains unavailable until the missing external components are genuinely integrated, registered, validated and certified; no narrative or manually filled identifier can substitute for them.
