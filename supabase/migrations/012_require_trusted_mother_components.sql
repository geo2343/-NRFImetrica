-- A string written by the LLM is not proof that a numeric engine, independent
-- auditor, or @NRFIprensa actually ran. Register and bind trusted executions.

create table if not exists public.numeric_engine_registry (
  engine_id text primary key,
  engine_version text not null,
  code_hash text not null,
  status text not null check (status in ('ACTIVE_TRUSTED','DIAGNOSTIC_TRUSTED','DISABLED')),
  notes text,
  registered_at timestamptz not null default now()
);
alter table public.numeric_engine_registry enable row level security;

create table if not exists public.numeric_engine_executions (
  execution_id text primary key,
  run_id text not null references public.runs(run_id) on delete cascade,
  game_id text not null,
  engine_id text not null references public.numeric_engine_registry(engine_id),
  model_version text not null,
  transition_version text not null,
  input_freeze_id text not null,
  executed_at timestamptz not null,
  input_hash text not null,
  output_hash text not null,
  output_payload jsonb not null,
  provenance_status text not null check (provenance_status in ('PASS','FAIL')),
  foreign key(run_id,game_id) references public.games(run_id,game_id) on delete cascade
);
alter table public.numeric_engine_executions enable row level security;

create table if not exists public.independent_auditor_registry (
  auditor_id text primary key,
  runtime_identity text not null,
  separation_class text not null,
  status text not null check (status in ('ACTIVE_TRUSTED','DIAGNOSTIC_TRUSTED','DISABLED')),
  registered_at timestamptz not null default now()
);
alter table public.independent_auditor_registry enable row level security;

create table if not exists public.independent_audit_executions (
  audit_execution_id text primary key,
  run_id text not null references public.runs(run_id) on delete cascade,
  game_id text not null,
  auditor_id text not null references public.independent_auditor_registry(auditor_id),
  primary_analyst_id text not null,
  executed_at timestamptz not null,
  input_hash text not null,
  output_hash text not null,
  status text not null check (status in ('PASS','CONDITIONED','FAIL')),
  payload jsonb not null default '{}'::jsonb,
  foreign key(run_id,game_id) references public.games(run_id,game_id) on delete cascade
);
alter table public.independent_audit_executions enable row level security;

create table if not exists public.nrfiprensa_packets (
  packet_id text primary key,
  run_id text not null references public.runs(run_id) on delete cascade,
  game_id text not null,
  source_agent text not null default '@NRFIprensa',
  generated_at timestamptz not null,
  content_hash text not null,
  status text not null check (status in ('VERIFIED','DIAGNOSTIC_VERIFIED','REJECTED')),
  payload jsonb not null default '{}'::jsonb,
  foreign key(run_id,game_id) references public.games(run_id,game_id) on delete cascade
);
alter table public.nrfiprensa_packets enable row level security;

update public.protocol_phase_catalog
set required_fields=case when not ('independent_audit.audit_execution_id'=any(required_fields)) then array_append(required_fields,'independent_audit.audit_execution_id') else required_fields end
where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and phase_id='A6_CAUSAL_FALSIFICATION_SPORTS_SEAL';

update public.protocol_phase_catalog
set required_fields=case when not ('nrfi_prensa.packet_hash'=any(required_fields)) then array_append(required_fields,'nrfi_prensa.packet_hash') else required_fields end
where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS';

create or replace function public.enforce_nrfimetrica_trusted_components()
returns trigger
language plpgsql
as $$
declare
  run_mode text;
  reg_status text;
  ex public.numeric_engine_executions%rowtype;
  audit_ex public.independent_audit_executions%rowtype;
  packet public.nrfiprensa_packets%rowtype;
  expected_status text;
begin
  if new.protocol_id<>'NRFIMETRICA_MOTHER_V3_AUTONOMOUS' then return new; end if;
  select mode into run_mode from public.runs where run_id=new.run_id;
  expected_status:=case when run_mode='DIAGNOSTIC' then 'DIAGNOSTIC_TRUSTED' else 'ACTIVE_TRUSTED' end;

  if new.phase_id='A4_NUMERIC_STATE_ENGINE' then
    select e.* into ex from public.numeric_engine_executions e where e.execution_id=new.payload #>> '{numeric_engine,execution_id}' limit 1;
    if not found or ex.run_id<>new.run_id or ex.game_id<>new.game_id or ex.provenance_status<>'PASS' then
      raise exception 'A4_TRUSTED_NUMERIC_EXECUTION_REQUIRED' using errcode='23514';
    end if;
    select status into reg_status from public.numeric_engine_registry where engine_id=ex.engine_id;
    if reg_status is distinct from expected_status then
      raise exception 'A4_NUMERIC_ENGINE_NOT_TRUSTED_FOR_RUN_MODE:%/%',coalesce(reg_status,'NONE'),expected_status using errcode='23514';
    end if;
    if ex.model_version is distinct from new.payload #>> '{numeric_engine,model_version}'
       or ex.transition_version is distinct from new.payload #>> '{numeric_engine,transition_version}'
       or ex.input_freeze_id is distinct from new.payload #>> '{numeric_engine,input_freeze_id}' then
      raise exception 'A4_TRUSTED_EXECUTION_METADATA_MISMATCH' using errcode='23514';
    end if;
    if ex.executed_at>new.submitted_at then raise exception 'A4_NUMERIC_EXECUTION_FROM_FUTURE' using errcode='23514'; end if;

  elsif new.phase_id='A6_CAUSAL_FALSIFICATION_SPORTS_SEAL' then
    select a.* into audit_ex from public.independent_audit_executions a where a.audit_execution_id=new.payload #>> '{independent_audit,audit_execution_id}' limit 1;
    if not found or audit_ex.run_id<>new.run_id or audit_ex.game_id<>new.game_id then
      raise exception 'A6_TRUSTED_INDEPENDENT_AUDIT_EXECUTION_REQUIRED' using errcode='23514';
    end if;
    select status into reg_status from public.independent_auditor_registry where auditor_id=audit_ex.auditor_id;
    if reg_status is distinct from expected_status then
      raise exception 'A6_AUDITOR_NOT_TRUSTED_FOR_RUN_MODE:%/%',coalesce(reg_status,'NONE'),expected_status using errcode='23514';
    end if;
    if audit_ex.auditor_id is distinct from new.payload #>> '{independent_audit,auditor_id}'
       or audit_ex.primary_analyst_id is distinct from new.payload->>'primary_analyst_id'
       or audit_ex.status not in ('PASS','CONDITIONED') then
      raise exception 'A6_TRUSTED_AUDIT_METADATA_MISMATCH' using errcode='23514';
    end if;
    if audit_ex.executed_at>new.submitted_at then raise exception 'A6_AUDIT_EXECUTION_FROM_FUTURE' using errcode='23514'; end if;

  elsif new.phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS' then
    select n.* into packet from public.nrfiprensa_packets n where n.packet_id=new.payload #>> '{nrfi_prensa,packet_id}' limit 1;
    if not found or packet.run_id<>new.run_id or packet.game_id<>new.game_id or packet.source_agent<>'@NRFIprensa' then
      raise exception 'A7_TRUSTED_NRFIPRENSA_PACKET_REQUIRED' using errcode='23514';
    end if;
    if run_mode='DIAGNOSTIC' then
      if packet.status<>'DIAGNOSTIC_VERIFIED' then raise exception 'A7_NRFIPRENSA_PACKET_NOT_DIAGNOSTIC_VERIFIED' using errcode='23514'; end if;
    else
      if packet.status<>'VERIFIED' then raise exception 'A7_NRFIPRENSA_PACKET_NOT_VERIFIED' using errcode='23514'; end if;
    end if;
    if packet.content_hash is distinct from new.payload #>> '{nrfi_prensa,packet_hash}' then
      raise exception 'A7_NRFIPRENSA_PACKET_HASH_MISMATCH' using errcode='23514';
    end if;
    if packet.generated_at>new.submitted_at then raise exception 'A7_NRFIPRENSA_PACKET_FROM_FUTURE' using errcode='23514'; end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_02_nrfimetrica_trusted_components on public.protocol_phase_state;
create trigger trg_02_nrfimetrica_trusted_components
before insert or update on public.protocol_phase_state
for each row execute function public.enforce_nrfimetrica_trusted_components();

-- Production intentionally starts with no ACTIVE_TRUSTED numeric engine,
-- independent auditor, or verified press packet. Therefore controlled-real
-- runs cannot fake A4/A6/A7 until those components are genuinely integrated.
