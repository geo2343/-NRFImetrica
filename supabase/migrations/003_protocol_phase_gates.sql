-- Operational protocol state for @NRFImetrica.
-- This stores only technical execution/gate state, not the documentary case file.

create table if not exists public.protocol_phase_state (
  id uuid primary key default gen_random_uuid(),
  run_id text not null references public.runs(run_id) on delete cascade,
  game_id text not null,
  protocol_id text not null,
  phase_id text not null,
  status text not null check (status in ('COMPLETE','SKIPPED_NOT_TRIGGERED')),
  payload jsonb not null default '{}'::jsonb,
  evidence_ids text[] not null default '{}',
  source_calls jsonb not null default '[]'::jsonb,
  documents_analyzed text[] not null default '{}',
  output_text text not null default '',
  skip_reason text,
  requirement_check jsonb not null default '{}'::jsonb,
  submitted_at timestamptz not null default now(),
  unique(run_id, game_id, phase_id),
  foreign key (run_id, game_id) references public.games(run_id, game_id) on delete cascade
);

create index if not exists idx_protocol_phase_run_game
  on public.protocol_phase_state(run_id, game_id);

alter table public.protocol_phase_state enable row level security;

create table if not exists public.protocol_decision_gates (
  protocol_id text not null,
  decision text not null,
  phase_id text not null,
  primary key(protocol_id, decision, phase_id)
);

alter table public.protocol_decision_gates enable row level security;

insert into public.protocol_decision_gates(protocol_id, decision, phase_id) values
  ('NRFIMETRICA_V21_AI_ANALYST','NRFI_CANDIDATE','TRIAGE'),
  ('NRFIMETRICA_V21_AI_ANALYST','NRFI_CANDIDATE','BILATERAL_FIRST_INNING_ANALYSIS'),
  ('NRFIMETRICA_V21_AI_ANALYST','NRFI_CANDIDATE','MATERIAL_CONTEXT'),
  ('NRFIMETRICA_V21_AI_ANALYST','NRFI_CANDIDATE','RED_TEAM'),
  ('NRFIMETRICA_V21_AI_ANALYST','NRFI_CANDIDATE','SYNTHESIS'),
  ('NRFIMETRICA_V21_AI_ANALYST','NRFI_CANDIDATE','VALIDATOR_CHALLENGE'),
  ('NRFIMETRICA_V21_AI_ANALYST','NRFI_CANDIDATE','RECONSIDERATION'),
  ('NRFIMETRICA_V21_AI_ANALYST','NRFI_REJECTED','TRIAGE'),
  ('NRFIMETRICA_V21_AI_ANALYST','NRFI_REJECTED','BILATERAL_FIRST_INNING_ANALYSIS'),
  ('NRFIMETRICA_V21_AI_ANALYST','NRFI_REJECTED','MATERIAL_CONTEXT'),
  ('NRFIMETRICA_V21_AI_ANALYST','NRFI_REJECTED','RED_TEAM'),
  ('NRFIMETRICA_V21_AI_ANALYST','NRFI_REJECTED','SYNTHESIS'),
  ('NRFIMETRICA_V21_AI_ANALYST','NRFI_REJECTED','VALIDATOR_CHALLENGE'),
  ('NRFIMETRICA_V21_AI_ANALYST','NRFI_REJECTED','RECONSIDERATION')
on conflict do nothing;

create or replace function public.enforce_nrfimetrica_protocol_before_decision()
returns trigger
language plpgsql
as $$
declare
  v_protocol text := 'NRFIMETRICA_V21_AI_ANALYST';
  v_required integer;
  v_completed integer;
begin
  if new.decision not in ('NRFI_CANDIDATE','NRFI_REJECTED') then
    return new;
  end if;

  select count(*) into v_required
  from public.protocol_decision_gates
  where protocol_id = v_protocol
    and decision = new.decision;

  select count(*) into v_completed
  from public.protocol_decision_gates g
  join public.protocol_phase_state s
    on s.protocol_id = g.protocol_id
   and s.phase_id = g.phase_id
   and s.run_id = new.run_id
   and s.game_id = new.game_id
   and s.status in ('COMPLETE','SKIPPED_NOT_TRIGGERED')
  where g.protocol_id = v_protocol
    and g.decision = new.decision;

  if v_completed <> v_required then
    raise exception 'PROTOCOL_GATES_INCOMPLETE:%/%', v_completed, v_required
      using errcode = '23514';
  end if;

  if not exists (
    select 1
    from public.protocol_phase_state s
    where s.run_id = new.run_id
      and s.game_id = new.game_id
      and s.phase_id = 'RECONSIDERATION'
      and s.status = 'COMPLETE'
      and s.payload->>'final_decision' = new.decision
  ) then
    raise exception 'FINAL_DECISION_DOES_NOT_MATCH_RECONSIDERATION'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_nrfimetrica_protocol_before_decision on public.decisions;
create trigger trg_enforce_nrfimetrica_protocol_before_decision
before insert or update on public.decisions
for each row execute function public.enforce_nrfimetrica_protocol_before_decision();
