-- Mirror of physically applied migration: close_nrfi_zero_exit_bootstrap_ranking_and_add_postresult_learning

alter table public.numeric_engine_registry add column if not exists game_specific boolean not null default false;
alter table public.numeric_engine_registry add column if not exists sports_ranking_authority boolean not null default false;
alter table public.numeric_engine_registry add column if not exists economic_authority boolean not null default false;

update public.numeric_engine_registry
set game_specific=false,sports_ranking_authority=false,economic_authority=false,
    notes=case when engine_id='BOOTSTRAP-NUMERIC-ENGINE' then 'PRIOR_ONLY_NO_SPORTS_RANKING_NO_ECONOMIC_AUTHORITY. Same league-prior PMF for every game; research/calibration plumbing only.' else notes end
where engine_id in ('BOOTSTRAP-NUMERIC-ENGINE','DIAG-NUMERIC-ENGINE');

create or replace function public.enforce_numeric_engine_authority_flags()
returns trigger language plpgsql as $$
begin
  if new.sports_ranking_authority and not new.game_specific then raise exception 'NUMERIC_ENGINE_CANNOT_RANK_SPORTS_WITHOUT_GAME_SPECIFIC_MODEL:%',new.engine_id using errcode='23514'; end if;
  if new.economic_authority and (not new.game_specific or new.status<>'ACTIVE_TRUSTED') then raise exception 'NUMERIC_ENGINE_ECONOMIC_AUTHORITY_REQUIRES_GAME_SPECIFIC_ACTIVE_TRUSTED:%',new.engine_id using errcode='23514'; end if;
  return new;
end $$;

drop trigger if exists trg_numeric_engine_authority_flags on public.numeric_engine_registry;
create trigger trg_numeric_engine_authority_flags before insert or update on public.numeric_engine_registry for each row execute function public.enforce_numeric_engine_authority_flags();

create table if not exists public.nrfimetrica_postresult_audits (
  audit_id uuid primary key default gen_random_uuid(),run_id text not null,game_id text not null,market text not null default 'NRFI',pregame_user_action text,
  actual_first_inning_runs integer check(actual_first_inning_runs is null or actual_first_inning_runs>=0),outcome text not null check(outcome in ('WIN','LOSS','VOID','UNKNOWN')),
  classification text not null check(classification in ('LECTURA_CORRECTA_EJECUTADA','NO_PLAY_CORRECTO','FALSO_POSITIVO','FALSO_NEGATIVO','PROCESO_INCOMPLETO','DATO_CRITICO_FALLIDO','LOGICA_BILATERAL_FALLIDA','OVERRIDE_NO_AUTORIZADO')),
  failure_half text check(failure_half is null or failure_half in ('TOP_1ST','BOTTOM_1ST','BOTH','UNKNOWN')),
  root_causes jsonb not null default '[]'::jsonb,corrective_actions jsonb not null default '[]'::jsonb,outcome_used_as_sports_proof boolean not null default false,
  created_at timestamptz not null default clock_timestamp(),unique(run_id,game_id,market,classification)
);

create or replace function public.nrfim_validate_postresult_audit()
returns trigger language plpgsql as $$
begin
  if new.outcome_used_as_sports_proof then raise exception 'POSTRESULT_OUTCOME_CANNOT_BE_REUSED_AS_PREGAME_SPORTS_PROOF' using errcode='23514'; end if;
  if jsonb_typeof(new.root_causes)<>'array' or jsonb_array_length(new.root_causes)=0 then raise exception 'POSTRESULT_AUDIT_REQUIRES_ROOT_CAUSES' using errcode='23514'; end if;
  if jsonb_typeof(new.corrective_actions)<>'array' or jsonb_array_length(new.corrective_actions)=0 then raise exception 'POSTRESULT_AUDIT_REQUIRES_CORRECTIVE_ACTIONS' using errcode='23514'; end if;
  return new;
end $$;

drop trigger if exists trg_nrfim_validate_postresult_audit on public.nrfimetrica_postresult_audits;
create trigger trg_nrfim_validate_postresult_audit before insert or update on public.nrfimetrica_postresult_audits for each row execute function public.nrfim_validate_postresult_audit();

-- The physically applied version also replaced enforce_nrfimetrica_sports_shortlist so zero pool with WATCHLIST is INCOMPLETE_NOT_ZERO and every selected/excluded candidate must be BILATERAL-1.1 valid. The live Supabase function remains the source of truth for this mirrored migration.
