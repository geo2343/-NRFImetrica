-- Mirror of physically applied migration: enforce_user_facing_recommendation_authority
create table if not exists public.nrfimetrica_recommendation_log (
  recommendation_id uuid primary key default gen_random_uuid(),run_id text not null,game_id text not null,market text not null default 'NRFI',
  requested_action text not null check(requested_action in ('BET_APPROVED','BET_APPROVED_WITH_CONDITIONS','RESEARCH_CANDIDATE','DO_NOT_BET','REANALYSIS_REQUIRED')),
  source_channel text not null default 'ASSISTANT_USER_FACING',rationale text not null,created_at timestamptz not null default clock_timestamp()
);
create or replace function public.nrfim_enforce_recommendation_authority()
returns trigger language plpgsql as $$
declare a record;
begin
  select * into a from public.nrfimetrica_user_action where run_id=new.run_id and game_id=new.game_id;
  if not found then raise exception 'RECOMMENDATION_GAME_NOT_IN_USER_ACTION_VIEW:%/%',new.run_id,new.game_id using errcode='23514'; end if;
  if length(btrim(coalesce(new.rationale,'')))<30 then raise exception 'RECOMMENDATION_RATIONALE_TOO_THIN' using errcode='23514'; end if;
  if new.requested_action in ('BET_APPROVED','BET_APPROVED_WITH_CONDITIONS') and not a.bet_allowed then raise exception 'UNAUTHORIZED_BET_RECOMMENDATION_BLOCKED:%:SYSTEM_ACTION=%',new.game_id,a.user_action using errcode='23514'; end if;
  if new.requested_action='RESEARCH_CANDIDATE' and a.sports_status<>'SPORTS_CANDIDATE' then raise exception 'FALSE_RESEARCH_CANDIDATE_BLOCKED:%:SPORTS_STATUS=%',new.game_id,a.sports_status using errcode='23514'; end if;
  if new.requested_action='REANALYSIS_REQUIRED' and a.user_action<>'REANALYSIS_REQUIRED_DO_NOT_BET' then raise exception 'REANALYSIS_ACTION_STATE_MISMATCH:%:%',new.game_id,a.user_action using errcode='23514'; end if;
  return new;
end $$;
drop trigger if exists trg_nrfim_recommendation_authority on public.nrfimetrica_recommendation_log;
create trigger trg_nrfim_recommendation_authority before insert or update on public.nrfimetrica_recommendation_log for each row execute function public.nrfim_enforce_recommendation_authority();
