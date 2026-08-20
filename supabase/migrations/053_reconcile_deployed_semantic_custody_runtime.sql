-- 053 — RECONCILIATION MARKER FOR ALREADY-DEPLOYED SEMANTIC CUSTODY RUNTIME
-- The production database had the Agent 1.9 / Kernel 1.4 semantic-custody refactor
-- deployed before its repository migration artifact was committed. This migration is
-- intentionally fail-fast: it does NOT pretend to recreate an unknown historical
-- statement set. It asserts the required deployed objects so a fresh environment
-- cannot silently claim parity with production.
DO $$
BEGIN
  IF to_regprocedure('public.enforce_nrfimetrica_mother_lineage()') IS NULL
     OR to_regprocedure('public.enforce_nrfimetrica_mother_semantics()') IS NULL
     OR to_regprocedure('public.enforce_nrfimetrica_trusted_artifacts_v2()') IS NULL
     OR to_regclass('public.nrfimetrica_game_dual_status') IS NULL THEN
    RAISE EXCEPTION 'NRFIM_MIGRATION_053_REQUIRES_PREDEPLOYED_SEMANTIC_CUSTODY_BASELINE';
  END IF;
END $$;

-- Production provenance reference:
-- Supabase deployed migration name: harden_semantic_custody_and_adversarial_falsifiability
-- This marker exists to eliminate silent repository/database version skew.
