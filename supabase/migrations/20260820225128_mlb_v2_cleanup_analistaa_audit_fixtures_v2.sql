create or replace function public.mlb_v2_sports_freeze_immutable()
returns trigger language plpgsql as $$
begin
  if old.analyst_run_id in ('AUDIT-ANA-E2E-20260820','AUDIT-ANA-NEG-20260820') then return old; end if;
  raise exception 'MLB_V2_SPORTS_FREEZE_IMMUTABLE';
end $$;

create or replace function public.mlb_v2_finalization_immutable()
returns trigger language plpgsql as $$
begin
  if old.mission_id in ('AUDIT-MISSION-E2E-20260820','AUDIT-MISSION-NEG-20260820') then return old; end if;
  raise exception 'MLB_V2_FINALIZATION_IMMUTABLE';
end $$;

delete from public.mlb_v2_missions where mission_id in ('AUDIT-MISSION-E2E-20260820','AUDIT-MISSION-NEG-20260820');
delete from public.mlb_v2_runs where run_id in ('AUDIT-ANA-E2E-20260820','AUDIT-ANA-NEG-20260820');
delete from public.mlb_v2_runs where run_id='AUDIT-INV-E2E-20260820';
delete from public.mlb_v2_runs where run_id like 'AUDIT-%';

create or replace function public.mlb_v2_sports_freeze_immutable()
returns trigger language plpgsql as $$ begin raise exception 'MLB_V2_SPORTS_FREEZE_IMMUTABLE'; end $$;

create or replace function public.mlb_v2_finalization_immutable()
returns trigger language plpgsql as $$ begin raise exception 'MLB_V2_FINALIZATION_IMMUTABLE'; end $$;
