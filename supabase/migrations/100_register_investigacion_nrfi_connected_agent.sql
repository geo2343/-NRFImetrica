-- @investigacionNRFI — connected historical research kernel v0.1
create extension if not exists pgcrypto;

create table if not exists public.investigacion_nrfi_volumes (
  volume_id text primary key,
  sequence_no integer not null unique check (sequence_no >= 1),
  status text not null default 'OPEN' check (status in ('OPEN','CLOSED')),
  drive_document_id text not null,
  drive_document_url text not null,
  character_count integer not null default 0 check (character_count >= 0),
  capacity_state text not null default 'HEALTHY' check (capacity_state in ('HEALTHY','WATCH','NEAR_LIMIT','ROLLOVER_REQUIRED')),
  rollover_authorized boolean not null default false,
  previous_volume_id text references public.investigacion_nrfi_volumes(volume_id),
  created_at timestamptz not null default now(),
  closed_at timestamptz
);

create unique index if not exists investigacion_nrfi_one_open_volume_idx
  on public.investigacion_nrfi_volumes ((status)) where status = 'OPEN';

create table if not exists public.investigacion_nrfi_runs (
  daily_run_id text primary key,
  agent_id text not null default '@investigacionNRFI' check (agent_id = '@investigacionNRFI'),
  protocol_id text not null default 'INVESTIGACION_NRFI_HISTORICAL_V1' check (protocol_id = 'INVESTIGACION_NRFI_HISTORICAL_V1'),
  system_version text not null default 'INVESTIGACION-NRFI-HISTORICAL-V1.0',
  kernel_version text not null default 'INVESTIGACION-NRFI-KERNEL-0.1-CONNECTED',
  run_date date not null,
  run_type text not null default 'ORIGINAL' check (run_type in ('ORIGINAL','AMENDMENT','REVALIDATION')),
  parent_run_id text references public.investigacion_nrfi_runs(daily_run_id),
  volume_id text not null references public.investigacion_nrfi_volumes(volume_id),
  status text not null default 'OPEN' check (status in ('OPEN','IN_PROGRESS','INCOMPLETE_REPAIR_REQUIRED','COMPLETE','FAILED')),
  expected_finalized_count integer not null default 0 check (expected_finalized_count >= 0),
  processed_count integer not null default 0 check (processed_count >= 0),
  excluded_count integer not null default 0 check (excluded_count >= 0),
  drive_append_verified boolean not null default false,
  core_mission_complete boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  closed_at timestamptz
);

create unique index if not exists investigacion_nrfi_one_original_date_idx
  on public.investigacion_nrfi_runs (run_date) where run_type = 'ORIGINAL';

create table if not exists public.investigacion_nrfi_tool_events (
  event_id text primary key,
  daily_run_id text not null references public.investigacion_nrfi_runs(daily_run_id) on delete cascade,
  game_pk text,
  tool_name text not null,
  source_ref text,
  invoked_at timestamptz not null default now(),
  completed_at timestamptz,
  input_hash text,
  output_hash text,
  metadata jsonb not null default '{}'::jsonb
);

create table if not exists public.investigacion_nrfi_source_families (
  source_family_id text primary key,
  canonical_origin text not null,
  publisher text,
  family_hash text not null unique,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.investigacion_nrfi_evidence (
  evidence_id text primary key,
  daily_run_id text not null references public.investigacion_nrfi_runs(daily_run_id) on delete cascade,
  game_pk text,
  phase_id text check (phase_id in ('F1_FORENSIC_CAPTURE','F2_DEEP_RECONSTRUCTION','F3_FEATURE_FACTORY','F4_HISTORICAL_PRESS_RELIABILITY','F5_QUERYABLE_INTELLIGENCE')),
  tool_event_id text not null references public.investigacion_nrfi_tool_events(event_id),
  source_family_id text not null references public.investigacion_nrfi_source_families(source_family_id),
  source_url text,
  temporal_lane text not null check (temporal_lane in ('PREGAME_EVIDENCE','POSTGAME_EXPLANATORY_EVIDENCE','NOT_APPLICABLE')),
  epistemic_lane text not null check (epistemic_lane in ('OBSERVED','DERIVED','HUMAN_INFORMATION')),
  retrieved_at timestamptz not null,
  available_at timestamptz,
  first_pitch_at timestamptz,
  event_time timestamptz,
  payload_hash text not null,
  snapshot_hash text not null,
  data_coverage_state text not null default 'AVAILABLE',
  object_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.investigacion_nrfi_phase_state (
  daily_run_id text not null references public.investigacion_nrfi_runs(daily_run_id) on delete cascade,
  phase_id text not null check (phase_id in ('F1_FORENSIC_CAPTURE','F2_DEEP_RECONSTRUCTION','F3_FEATURE_FACTORY','F4_HISTORICAL_PRESS_RELIABILITY','F5_QUERYABLE_INTELLIGENCE')),
  status text not null check (status in ('COMPLETE','FAILED','INCOMPLETE')),
  started_at timestamptz not null,
  ended_at timestamptz,
  payload jsonb not null default '{}'::jsonb,
  receipt jsonb not null default '{}'::jsonb,
  auditor_result text,
  submitted_at timestamptz not null default now(),
  primary key (daily_run_id, phase_id)
);

create table if not exists public.investigacion_nrfi_trace (
  event_id text primary key,
  daily_run_id text not null references public.investigacion_nrfi_runs(daily_run_id) on delete cascade,
  phase_id text,
  event_type text not null,
  occurred_at timestamptz not null default now(),
  prev_event_hash text,
  event_hash text not null unique,
  input_hash text,
  output_hash text,
  details jsonb not null default '{}'::jsonb
);

create table if not exists public.investigacion_nrfi_drive_appends (
  daily_run_id text primary key references public.investigacion_nrfi_runs(daily_run_id) on delete cascade,
  volume_id text not null references public.investigacion_nrfi_volumes(volume_id),
  drive_document_id text not null,
  block_marker text not null,
  pre_append_hash text,
  post_append_hash text,
  readback_hash text,
  readback_tool_event_id text references public.investigacion_nrfi_tool_events(event_id),
  character_count_before integer check (character_count_before >= 0),
  character_count_after integer check (character_count_after >= 0),
  verified boolean not null default false,
  appended_at timestamptz not null default now()
);

create table if not exists public.investigacion_nrfi_audits (
  daily_run_id text primary key references public.investigacion_nrfi_runs(daily_run_id) on delete cascade,
  phases_expected integer not null default 5,
  phases_executed integer not null default 0,
  mandatory_phases_not_run text[] not null default '{}'::text[],
  universe_accounting_pass boolean not null default false,
  temporal_integrity_pass boolean not null default false,
  evidence_trace_pass boolean not null default false,
  drive_append_pass boolean not null default false,
  audit_status text not null check (audit_status in ('PASS','FAIL')),
  details jsonb not null default '{}'::jsonb,
  derived_at timestamptz not null default now()
);

create or replace function public.investigacion_nrfi_capacity_state(p_chars integer)
returns text language sql immutable as $$
  select case
    when p_chars < 700000 then 'HEALTHY'
    when p_chars < 800000 then 'WATCH'
    when p_chars < 900000 then 'NEAR_LIMIT'
    else 'ROLLOVER_REQUIRED'
  end;
$$;

create or replace function public.investigacion_nrfi_guard_volume_creation()
returns trigger language plpgsql as $$
declare
  prev public.investigacion_nrfi_volumes%rowtype;
begin
  if new.sequence_no = 1 then
    if new.previous_volume_id is not null then
      raise exception 'VOL1_CANNOT_HAVE_PREVIOUS_VOLUME';
    end if;
    return new;
  end if;

  select * into prev
  from public.investigacion_nrfi_volumes
  where sequence_no = new.sequence_no - 1;

  if not found then
    raise exception 'PREVIOUS_VOLUME_NOT_FOUND';
  end if;
  if prev.status <> 'CLOSED' then
    raise exception 'PREVIOUS_VOLUME_NOT_CLOSED';
  end if;
  if prev.capacity_state <> 'ROLLOVER_REQUIRED' then
    raise exception 'PREVIOUS_VOLUME_NOT_ROLLOVER_REQUIRED';
  end if;
  if prev.rollover_authorized is not true then
    raise exception 'ROLLOVER_REQUIRES_EXPLICIT_USER_AUTHORIZATION';
  end if;
  if new.previous_volume_id is distinct from prev.volume_id then
    raise exception 'PREVIOUS_VOLUME_ID_MISMATCH';
  end if;
  return new;
end;
$$;

drop trigger if exists investigacion_nrfi_volume_creation_guard on public.investigacion_nrfi_volumes;
create trigger investigacion_nrfi_volume_creation_guard
before insert on public.investigacion_nrfi_volumes
for each row execute function public.investigacion_nrfi_guard_volume_creation();

create or replace function public.investigacion_nrfi_guard_evidence_temporality()
returns trigger language plpgsql as $$
begin
  if new.temporal_lane = 'PREGAME_EVIDENCE' then
    if new.available_at is null or new.first_pitch_at is null then
      raise exception 'PREGAME_TIMESTAMPS_REQUIRED';
    end if;
    if new.available_at >= new.first_pitch_at then
      raise exception 'POSTGAME_OR_LATE_EVIDENCE_CANNOT_BE_PREGAME';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists investigacion_nrfi_evidence_temporal_guard on public.investigacion_nrfi_evidence;
create trigger investigacion_nrfi_evidence_temporal_guard
before insert or update on public.investigacion_nrfi_evidence
for each row execute function public.investigacion_nrfi_guard_evidence_temporality();

create or replace function public.investigacion_nrfi_guard_phase_state()
returns trigger language plpgsql as $$
declare
  phase_rank integer;
  prior_missing integer;
  required_keys text[] := array['PHASE_ID','START_AS_OF','END_AS_OF','INPUT_OBJECTS','OPERATIONS_PERFORMED','OUTPUT_OBJECTS','SOURCES_OR_EVIDENCE','AUDITOR_RESULT','NEXT_PHASE'];
begin
  phase_rank := case new.phase_id
    when 'F1_FORENSIC_CAPTURE' then 1
    when 'F2_DEEP_RECONSTRUCTION' then 2
    when 'F3_FEATURE_FACTORY' then 3
    when 'F4_HISTORICAL_PRESS_RELIABILITY' then 4
    when 'F5_QUERYABLE_INTELLIGENCE' then 5
    else 99 end;

  if new.status = 'COMPLETE' then
    if not (new.receipt ?& required_keys) then
      raise exception 'PHASE_EXECUTION_RECEIPT_INCOMPLETE';
    end if;
    if coalesce(new.receipt->>'PHASE_ID','') <> new.phase_id then
      raise exception 'RECEIPT_PHASE_ID_MISMATCH';
    end if;
  end if;

  if phase_rank > 1 then
    select count(*) into prior_missing
    from (values
      (1,'F1_FORENSIC_CAPTURE'),
      (2,'F2_DEEP_RECONSTRUCTION'),
      (3,'F3_FEATURE_FACTORY'),
      (4,'F4_HISTORICAL_PRESS_RELIABILITY'),
      (5,'F5_QUERYABLE_INTELLIGENCE')
    ) as p(rank, pid)
    where p.rank < phase_rank
      and not exists (
        select 1 from public.investigacion_nrfi_phase_state s
        where s.daily_run_id = new.daily_run_id
          and s.phase_id = p.pid
          and s.status = 'COMPLETE'
      );
    if prior_missing > 0 then
      raise exception 'PREREQUISITES_INCOMPLETE';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists investigacion_nrfi_phase_state_guard on public.investigacion_nrfi_phase_state;
create trigger investigacion_nrfi_phase_state_guard
before insert or update on public.investigacion_nrfi_phase_state
for each row execute function public.investigacion_nrfi_guard_phase_state();

create or replace function public.investigacion_nrfi_guard_drive_append()
returns trigger language plpgsql as $$
declare
  run_volume text;
  active_doc text;
begin
  select volume_id into run_volume
  from public.investigacion_nrfi_runs where daily_run_id = new.daily_run_id;
  if run_volume is distinct from new.volume_id then
    raise exception 'DRIVE_APPEND_VOLUME_MISMATCH';
  end if;

  select drive_document_id into active_doc
  from public.investigacion_nrfi_volumes where volume_id = new.volume_id;
  if active_doc is distinct from new.drive_document_id then
    raise exception 'DRIVE_APPEND_DOCUMENT_MISMATCH';
  end if;

  if new.verified then
    if new.post_append_hash is null or new.readback_hash is null or new.readback_tool_event_id is null then
      raise exception 'DRIVE_READBACK_PROOF_REQUIRED';
    end if;
    if new.post_append_hash is distinct from new.readback_hash then
      raise exception 'DRIVE_READBACK_HASH_MISMATCH';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists investigacion_nrfi_drive_append_guard on public.investigacion_nrfi_drive_appends;
create trigger investigacion_nrfi_drive_append_guard
before insert or update on public.investigacion_nrfi_drive_appends
for each row execute function public.investigacion_nrfi_guard_drive_append();

create or replace function public.investigacion_nrfi_trace_hash_guard()
returns trigger language plpgsql as $$
declare
  latest_hash text;
begin
  select t.event_hash into latest_hash
  from public.investigacion_nrfi_trace t
  where t.daily_run_id = new.daily_run_id
  order by t.occurred_at desc, t.event_id desc
  limit 1;

  new.prev_event_hash := latest_hash;
  new.event_hash := encode(digest(convert_to(
    concat_ws('|', new.event_id, new.daily_run_id, coalesce(new.phase_id,''), new.event_type,
      new.occurred_at::text, coalesce(latest_hash,''), coalesce(new.input_hash,''),
      coalesce(new.output_hash,''), new.details::text), 'UTF8'), 'sha256'), 'hex');
  return new;
end;
$$;

drop trigger if exists investigacion_nrfi_trace_hash_trigger on public.investigacion_nrfi_trace;
create trigger investigacion_nrfi_trace_hash_trigger
before insert on public.investigacion_nrfi_trace
for each row execute function public.investigacion_nrfi_trace_hash_guard();

create or replace function public.investigacion_nrfi_derive_audit(p_daily_run_id text)
returns public.investigacion_nrfi_audits
language plpgsql security definer set search_path = public as $$
declare
  r public.investigacion_nrfi_runs%rowtype;
  out_row public.investigacion_nrfi_audits%rowtype;
  completed text[];
  missing text[];
  temporal_ok boolean;
  trace_ok boolean;
  drive_ok boolean;
  universe_ok boolean;
begin
  select * into r from public.investigacion_nrfi_runs where daily_run_id = p_daily_run_id;
  if not found then raise exception 'DAILY_RUN_NOT_FOUND'; end if;

  select coalesce(array_agg(phase_id order by phase_id), '{}'::text[])
  into completed
  from public.investigacion_nrfi_phase_state
  where daily_run_id = p_daily_run_id and status = 'COMPLETE';

  select coalesce(array_agg(pid), '{}'::text[])
  into missing
  from unnest(array['F1_FORENSIC_CAPTURE','F2_DEEP_RECONSTRUCTION','F3_FEATURE_FACTORY','F4_HISTORICAL_PRESS_RELIABILITY','F5_QUERYABLE_INTELLIGENCE']) pid
  where not (pid = any(completed));

  universe_ok := r.expected_finalized_count = r.processed_count + r.excluded_count;

  select not exists (
    select 1 from public.investigacion_nrfi_evidence e
    where e.daily_run_id = p_daily_run_id
      and e.temporal_lane = 'PREGAME_EVIDENCE'
      and (e.available_at is null or e.first_pitch_at is null or e.available_at >= e.first_pitch_at)
  ) into temporal_ok;

  select case
    when r.expected_finalized_count = 0 then true
    else exists (select 1 from public.investigacion_nrfi_evidence e where e.daily_run_id = p_daily_run_id)
         and not exists (
           select 1 from public.investigacion_nrfi_evidence e
           left join public.investigacion_nrfi_tool_events t on t.event_id = e.tool_event_id
           left join public.investigacion_nrfi_source_families f on f.source_family_id = e.source_family_id
           where e.daily_run_id = p_daily_run_id and (t.event_id is null or f.source_family_id is null)
         )
  end into trace_ok;

  select exists (
    select 1 from public.investigacion_nrfi_drive_appends d
    where d.daily_run_id = p_daily_run_id and d.verified = true
  ) into drive_ok;

  insert into public.investigacion_nrfi_audits(
    daily_run_id, phases_expected, phases_executed, mandatory_phases_not_run,
    universe_accounting_pass, temporal_integrity_pass, evidence_trace_pass,
    drive_append_pass, audit_status, details, derived_at
  ) values (
    p_daily_run_id, 5, cardinality(completed), missing,
    universe_ok, temporal_ok, trace_ok, drive_ok,
    case when cardinality(missing)=0 and universe_ok and temporal_ok and trace_ok and drive_ok then 'PASS' else 'FAIL' end,
    jsonb_build_object('agent_id','@investigacionNRFI','protocol_id','INVESTIGACION_NRFI_HISTORICAL_V1'), now()
  )
  on conflict (daily_run_id) do update set
    phases_executed = excluded.phases_executed,
    mandatory_phases_not_run = excluded.mandatory_phases_not_run,
    universe_accounting_pass = excluded.universe_accounting_pass,
    temporal_integrity_pass = excluded.temporal_integrity_pass,
    evidence_trace_pass = excluded.evidence_trace_pass,
    drive_append_pass = excluded.drive_append_pass,
    audit_status = excluded.audit_status,
    details = excluded.details,
    derived_at = excluded.derived_at
  returning * into out_row;

  return out_row;
end;
$$;

create or replace function public.investigacion_nrfi_close_daily_run(p_daily_run_id text)
returns public.investigacion_nrfi_runs
language plpgsql security definer set search_path = public as $$
declare
  a public.investigacion_nrfi_audits%rowtype;
  out_run public.investigacion_nrfi_runs%rowtype;
begin
  a := public.investigacion_nrfi_derive_audit(p_daily_run_id);
  if a.audit_status <> 'PASS' then
    update public.investigacion_nrfi_runs
      set status='INCOMPLETE_REPAIR_REQUIRED', core_mission_complete=false
      where daily_run_id=p_daily_run_id
      returning * into out_run;
    return out_run;
  end if;

  update public.investigacion_nrfi_runs
    set status='COMPLETE', core_mission_complete=true, drive_append_verified=true, closed_at=now()
    where daily_run_id=p_daily_run_id
    returning * into out_run;
  return out_run;
end;
$$;

create or replace function public.investigacion_nrfi_authorize_rollover(p_volume_id text)
returns public.investigacion_nrfi_volumes
language plpgsql security definer set search_path = public as $$
declare
  out_volume public.investigacion_nrfi_volumes%rowtype;
begin
  select * into out_volume from public.investigacion_nrfi_volumes where volume_id=p_volume_id;
  if not found then raise exception 'VOLUME_NOT_FOUND'; end if;
  if out_volume.status <> 'CLOSED' then raise exception 'VOLUME_MUST_BE_CLOSED'; end if;
  if out_volume.capacity_state <> 'ROLLOVER_REQUIRED' then raise exception 'ROLLOVER_NOT_REQUIRED'; end if;
  update public.investigacion_nrfi_volumes set rollover_authorized=true where volume_id=p_volume_id returning * into out_volume;
  return out_volume;
end;
$$;

insert into public.investigacion_nrfi_volumes(
  volume_id, sequence_no, status, drive_document_id, drive_document_url,
  character_count, capacity_state, rollover_authorized
) values (
  'INVESTIGACIONNRFI-VOL-01', 1, 'OPEN',
  '12PSuZwQKxb4oFiEqaH4fB8twnS74KhiPDUHMGpso6Us',
  'https://docs.google.com/document/d/12PSuZwQKxb4oFiEqaH4fB8twnS74KhiPDUHMGpso6Us/edit?usp=drivesdk',
  0, 'HEALTHY', false
) on conflict (volume_id) do update set
  drive_document_id=excluded.drive_document_id,
  drive_document_url=excluded.drive_document_url;

insert into public.agent_registry(
  agent_id, agent_version, status, protocol_id, system_version, kernel_version,
  mother_document_sha256, manifest_path, activation_aliases,
  manual_phase_authorization_required, auto_advance, drive_root_folder_id,
  drive_execution_folder_id, drive_authority_folder_id, real_money_authority,
  metadata, updated_at
) values (
  '@investigacionNRFI', 'INVESTIGACION-NRFI-AGENT-1.0', 'ACTIVE',
  'INVESTIGACION_NRFI_HISTORICAL_V1', 'INVESTIGACION-NRFI-HISTORICAL-V1.0',
  'INVESTIGACION-NRFI-KERNEL-0.1-CONNECTED',
  'faaf79e94729a129ed790ee7cd9d90872c602cfdc3756769e5f6e415b25d89fd',
  'agents/investigacion_nrfi_agent.json', array['@investigacionNRFI'],
  false, true, '1jsuemCCNiDZlVOVNTgdLw67vUDTzhLkE',
  '11x0d6ugvfq4NRFvu39Eac-8IUvAjC3I4', '1H1aHTlKc38WewaOw3VNduaxhMj7tnqgZ', false,
  jsonb_build_object(
    'mother_document_id','1Hqj6s11F2dEf_UUeto38rP90f5Q5eemnBi0B0PWnQuY',
    'active_volume_id','INVESTIGACIONNRFI-VOL-01',
    'active_volume_doc_id','12PSuZwQKxb4oFiEqaH4fB8twnS74KhiPDUHMGpso6Us',
    'single_living_report',true,
    'new_volume_requires_user_authorization',true,
    'real_money_authority',false
  ), now()
) on conflict (agent_id) do update set
  agent_version=excluded.agent_version,
  status=excluded.status,
  protocol_id=excluded.protocol_id,
  system_version=excluded.system_version,
  kernel_version=excluded.kernel_version,
  mother_document_sha256=excluded.mother_document_sha256,
  manifest_path=excluded.manifest_path,
  activation_aliases=excluded.activation_aliases,
  manual_phase_authorization_required=excluded.manual_phase_authorization_required,
  auto_advance=excluded.auto_advance,
  drive_root_folder_id=excluded.drive_root_folder_id,
  drive_execution_folder_id=excluded.drive_execution_folder_id,
  drive_authority_folder_id=excluded.drive_authority_folder_id,
  real_money_authority=excluded.real_money_authority,
  metadata=excluded.metadata,
  updated_at=now();

insert into public.protocol_authority(
  protocol_id, authority_name, document_sha256, document_lines, precedence_rule,
  latest_sovereign_patch, manual_phase_authorization_required, active, created_at
) values (
  'INVESTIGACION_NRFI_HISTORICAL_V1',
  '@investigacionNRFI DOCUMENTO MADRE V1.0',
  'faaf79e94729a129ed790ee7cd9d90872c602cfdc3756769e5f6e415b25d89fd',
  84,
  'MOTHER_DOCUMENT_FIRST',
  'CONNECTED-KERNEL-BOOTSTRAP-1',
  false,
  true,
  now()
) on conflict (protocol_id) do update set
  authority_name=excluded.authority_name,
  document_sha256=excluded.document_sha256,
  document_lines=excluded.document_lines,
  precedence_rule=excluded.precedence_rule,
  latest_sovereign_patch=excluded.latest_sovereign_patch,
  manual_phase_authorization_required=excluded.manual_phase_authorization_required,
  active=true;

insert into public.system_versions(system_version, contract_doc_id, kernel_version, model_version, calibration_status)
values (
  'INVESTIGACION-NRFI-HISTORICAL-V1.0',
  '1Hqj6s11F2dEf_UUeto38rP90f5Q5eemnBi0B0PWnQuY',
  'INVESTIGACION-NRFI-KERNEL-0.1-CONNECTED',
  'NOT_APPLICABLE',
  'NOT_APPLICABLE'
)
on conflict (system_version) do update set
  contract_doc_id=excluded.contract_doc_id,
  kernel_version=excluded.kernel_version,
  model_version=excluded.model_version,
  calibration_status=excluded.calibration_status;
