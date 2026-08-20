-- @investigacionNRFI v1.2 — full-slate compatibility hardening
-- The old ledger admitted only finalized rows. Full-slate mode must retain scheduled/suspended/postponed members too.

alter table public.investigacion_nrfi_games
  drop constraint if exists investigacion_nrfi_games_finalized_verified_check;

alter table public.investigacion_nrfi_games
  add constraint investigacion_nrfi_games_processed_requires_final_check
  check (research_status <> 'PROCESSED' or finalized_verified = true);

update public.agent_registry
set metadata=coalesce(metadata,'{}'::jsonb) || jsonb_build_object(
  'nonfinal_slate_members_allowed',true,
  'processed_requires_final_db_constraint',true
), updated_at=now()
where agent_id='@investigacionNRFI';
