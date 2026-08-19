-- Defense-in-depth: protocol phases cannot be persisted out of order.

create table if not exists public.protocol_phase_prerequisites (
  protocol_id text not null,
  phase_id text not null,
  prerequisite_phase_id text not null,
  primary key(protocol_id, phase_id, prerequisite_phase_id)
);

alter table public.protocol_phase_prerequisites enable row level security;

insert into public.protocol_phase_prerequisites(protocol_id, phase_id, prerequisite_phase_id) values
  ('NRFIMETRICA_V21_AI_ANALYST','BILATERAL_FIRST_INNING_ANALYSIS','TRIAGE'),
  ('NRFIMETRICA_V21_AI_ANALYST','MATERIAL_CONTEXT','BILATERAL_FIRST_INNING_ANALYSIS'),
  ('NRFIMETRICA_V21_AI_ANALYST','RED_TEAM','BILATERAL_FIRST_INNING_ANALYSIS'),
  ('NRFIMETRICA_V21_AI_ANALYST','SYNTHESIS','BILATERAL_FIRST_INNING_ANALYSIS'),
  ('NRFIMETRICA_V21_AI_ANALYST','SYNTHESIS','MATERIAL_CONTEXT'),
  ('NRFIMETRICA_V21_AI_ANALYST','SYNTHESIS','RED_TEAM'),
  ('NRFIMETRICA_V21_AI_ANALYST','VALIDATOR_CHALLENGE','SYNTHESIS'),
  ('NRFIMETRICA_V21_AI_ANALYST','RECONSIDERATION','VALIDATOR_CHALLENGE')
on conflict do nothing;

create or replace function public.enforce_nrfimetrica_phase_order()
returns trigger
language plpgsql
as $$
declare
  missing_count integer;
begin
  select count(*) into missing_count
  from public.protocol_phase_prerequisites p
  where p.protocol_id = new.protocol_id
    and p.phase_id = new.phase_id
    and not exists (
      select 1
      from public.protocol_phase_state s
      where s.run_id = new.run_id
        and s.game_id = new.game_id
        and s.protocol_id = new.protocol_id
        and s.phase_id = p.prerequisite_phase_id
        and s.status in ('COMPLETE','SKIPPED_NOT_TRIGGERED')
    );

  if missing_count > 0 then
    raise exception 'PHASE_PREREQUISITES_INCOMPLETE:%:%', new.phase_id, missing_count
      using errcode = '23514';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_nrfimetrica_phase_order on public.protocol_phase_state;
create trigger trg_enforce_nrfimetrica_phase_order
before insert or update on public.protocol_phase_state
for each row execute function public.enforce_nrfimetrica_phase_order();
