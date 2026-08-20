-- BILATERAL-1.2
-- Applied physically in Supabase on 2026-08-19.
-- Purpose: preserve TOP_AND_BOTTOM independent approval while removing the incorrect
-- requirement that one isolated first-inning statistic/evidence annotation act as a hard gate.
-- The first-inning split remains a DESCRIPTIVE CHECK inside the causal set.

-- Canonical runtime objects changed by this migration:
--   public.nrfim_latest_bilateral_nrfi_valid(text,text)
--   public.nrfim_enforce_bilateral_conjunction()
--   public.nrfiprensa_latest_bilateral_valid(text,text)
--   public.nrfiprensa_enforce_half_independence()
--   public.nrfimetrica_game_dual_status
--   public.agent_registry (@NRFImetrica)
--   public.nrfiprensa_authority (@NRFiPrensa)
--   public.system_audit_adapter_checks
--   public.system_auditor_authority

-- Sovereign invariants:
-- 1. NRFI = TOP_1ST_NO_RUN AND BOTTOM_1ST_NO_RUN.
-- 2. NRFI_LEAN / positive press view requires TOP=NRFI_HALF_PASS AND BOTTOM=NRFI_HALF_PASS.
-- 3. ACCEPTABLE / UNCERTAIN / FAIL is never PASS.
-- 4. No cross-half compensation.
-- 5. Each half requires its own current-run/current-game evidence and complete causal dimensions:
--    pitcher, opposing top order, splits, BB, HR/contact damage, traffic, first-inning descriptive check,
--    current form/version, matchup, material run path, data quality, rationale and uncertainty.
-- 6. No single metric may create or kill a candidate.
-- 7. @NRFiPrensa still requires official B1-B5, Q1-Q12, OSR, no-walk run paths and F7-R Red Team.
-- 8. A6/A7/A8/shortlist/user-facing authority remain downstream of the bilateral validator.

update public.agent_registry
set agent_version='MOTHER-V3-AGENT-1.8',
    kernel_version='NRFIM-KERNEL-1.3-BILATERAL-1.2-CAUSAL-GATE',
    metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object(
      'bilateral_rule_version','BILATERAL-1.2',
      'first_inning_specific_role','DESCRIPTIVE_CHECK_NOT_SOLE_GATE',
      'single_metric_may_block_sports_candidate',false,
      'bilateral_independent_half_approval_required',true,
      'no_compensation_between_halves',true,
      'database_migrations_required_through',52),
    updated_at=clock_timestamp()
where agent_id='@NRFImetrica';

update public.nrfiprensa_authority
set agent_version='V0.2-AGENT-1.3',
    kernel_version='NRFIPRENSA-KERNEL-0.4-BILATERAL-1.2-CAUSAL-GATE',
    metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object(
      'bilateral_rule_version','BILATERAL-1.2',
      'first_inning_specific_role','DESCRIPTIVE_CHECK_NOT_SOLE_GATE',
      'single_metric_may_block_positive_nrfi',false,
      'f7q_universal_per_half_required',true,
      'osr_required',true,
      'no_walk_run_paths_required',true,
      'red_team_required',true,
      'database_migrations_required_through',52),
    updated_at=clock_timestamp()
where agent_id='@NRFiPrensa';

-- Full CREATE OR REPLACE definitions are the canonical Supabase migration body and are
-- mirrored by the active protocol/agent manifests. This file records the authority and
-- reproducibility contract for migration 052 without rewriting historical packets.
