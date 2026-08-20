-- @investigacionNRFI v1.2 — denominator hardening
-- official_slate_count comes from the official MLB schedule freeze and is never recomputed from ledger rows.

alter table public.investigacion_nrfi_runs
  add column if not exists ledger_game_count integer not null default 0;

create or replace function public.investigacion_nrfi_sync_run_accounting(p_daily_run_id text)
returns public.investigacion_nrfi_runs
language plpgsql
security definer
set search_path to 'public','extensions'
as $$
declare out_run public.investigacion_nrfi_runs%rowtype;
begin
  update public.investigacion_nrfi_runs r set
    expected_finalized_count=(select count(*) from public.investigacion_nrfi_games g where g.daily_run_id=p_daily_run_id and g.official_slate_member=true),
    ledger_game_count=(select count(*) from public.investigacion_nrfi_games g where g.daily_run_id=p_daily_run_id and g.official_slate_member=true),
    finalized_game_count=(select count(*) from public.investigacion_nrfi_games g where g.daily_run_id=p_daily_run_id and g.official_slate_member=true and g.finalized_verified=true),
    nonfinal_game_count=(select count(*) from public.investigacion_nrfi_games g where g.daily_run_id=p_daily_run_id and g.official_slate_member=true and g.finalized_verified=false),
    processed_count=(select count(*) from public.investigacion_nrfi_games g where g.daily_run_id=p_daily_run_id and g.official_slate_member=true and g.research_status='PROCESSED'),
    excluded_count=(select count(*) from public.investigacion_nrfi_games g where g.daily_run_id=p_daily_run_id and g.official_slate_member=true and g.research_status='EXCLUDED'),
    slate_complete=(
      r.official_slate_count > 0
      and r.official_slate_count=(select count(*) from public.investigacion_nrfi_games g where g.daily_run_id=p_daily_run_id and g.official_slate_member=true)
      and not exists(select 1 from public.investigacion_nrfi_games g where g.daily_run_id=p_daily_run_id and g.official_slate_member=true and g.research_status='PENDING')
      and not exists(select 1 from public.investigacion_nrfi_games g where g.daily_run_id=p_daily_run_id and g.official_slate_member=true and g.research_status<>'EXCLUDED' and g.finalized_verified=false)
    )
  where r.daily_run_id=p_daily_run_id returning * into out_run;
  if out_run.daily_run_id is null then raise exception 'DAILY_RUN_NOT_FOUND'; end if;
  return out_run;
end;
$$;

update public.investigacion_nrfi_runs r
set official_slate_count = case
      when official_slate_count=0 then (select count(*) from public.investigacion_nrfi_games g where g.daily_run_id=r.daily_run_id and g.official_slate_member=true)
      else official_slate_count end,
    metadata = coalesce(metadata,'{}'::jsonb) || case
      when official_slate_count=0 then jsonb_build_object('legacy_official_slate_count_backfilled_from_existing_ledger',true)
      else '{}'::jsonb end;

select public.investigacion_nrfi_sync_run_accounting(daily_run_id)
from public.investigacion_nrfi_runs;

revoke execute on function public.investigacion_nrfi_sync_run_accounting(text) from public, anon, authenticated;
grant execute on function public.investigacion_nrfi_sync_run_accounting(text) to service_role;
