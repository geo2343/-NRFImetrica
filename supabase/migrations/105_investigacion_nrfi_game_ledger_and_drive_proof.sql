create table if not exists public.investigacion_nrfi_games (
  daily_run_id text not null references public.investigacion_nrfi_runs(daily_run_id) on delete cascade,
  game_pk text not null,
  away_team text,
  home_team text,
  first_pitch_at timestamptz,
  final_status_text text not null,
  finalized_verified boolean not null check (finalized_verified = true),
  research_status text not null default 'PENDING' check (research_status in ('PENDING','PROCESSED','EXCLUDED')),
  exclusion_reason text,
  identity_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (daily_run_id,game_pk),
  check (research_status <> 'EXCLUDED' or nullif(exclusion_reason,'') is not null)
);

create or replace function public.investigacion_nrfi_sync_run_accounting(p_daily_run_id text)
returns public.investigacion_nrfi_runs
language plpgsql security definer set search_path=public as $$
declare out_run public.investigacion_nrfi_runs%rowtype;
begin
  update public.investigacion_nrfi_runs r set
    expected_finalized_count=(select count(*) from public.investigacion_nrfi_games g where g.daily_run_id=p_daily_run_id),
    processed_count=(select count(*) from public.investigacion_nrfi_games g where g.daily_run_id=p_daily_run_id and g.research_status='PROCESSED'),
    excluded_count=(select count(*) from public.investigacion_nrfi_games g where g.daily_run_id=p_daily_run_id and g.research_status='EXCLUDED')
  where r.daily_run_id=p_daily_run_id
  returning * into out_run;
  if out_run.daily_run_id is null then raise exception 'DAILY_RUN_NOT_FOUND'; end if;
  return out_run;
end;
$$;

create or replace function public.investigacion_nrfi_game_accounting_trigger()
returns trigger language plpgsql as $$
begin
  perform public.investigacion_nrfi_sync_run_accounting(coalesce(new.daily_run_id,old.daily_run_id));
  return coalesce(new,old);
end;
$$;

drop trigger if exists investigacion_nrfi_game_accounting_after_change on public.investigacion_nrfi_games;
create trigger investigacion_nrfi_game_accounting_after_change
after insert or update or delete on public.investigacion_nrfi_games
for each row execute function public.investigacion_nrfi_game_accounting_trigger();

create or replace function public.investigacion_nrfi_guard_phase_state()
returns trigger language plpgsql as $$
declare
  phase_rank integer; prior_missing integer;
  required_keys text[] := array['PHASE_ID','START_AS_OF','END_AS_OF','INPUT_OBJECTS','OPERATIONS_PERFORMED','OUTPUT_OBJECTS','SOURCES_OR_EVIDENCE','AUDITOR_RESULT','NEXT_PHASE'];
  expected_count integer; accounted_count integer; ledger_count integer;
begin
  phase_rank := case new.phase_id when 'F1_FORENSIC_CAPTURE' then 1 when 'F2_DEEP_RECONSTRUCTION' then 2 when 'F3_FEATURE_FACTORY' then 3 when 'F4_HISTORICAL_PRESS_RELIABILITY' then 4 when 'F5_QUERYABLE_INTELLIGENCE' then 5 else 99 end;
  if public.investigacion_nrfi_payload_has_forbidden_keys(new.payload) then raise exception 'FORBIDDEN_PICK_OR_MARKET_OUTPUT'; end if;
  if new.status='COMPLETE' then
    if not (new.receipt ?& required_keys) then raise exception 'PHASE_EXECUTION_RECEIPT_INCOMPLETE'; end if;
    if coalesce(new.receipt->>'PHASE_ID','') <> new.phase_id then raise exception 'RECEIPT_PHASE_ID_MISMATCH'; end if;
    if new.phase_id='F1_FORENSIC_CAPTURE' then
      if nullif(new.payload#>>'{universe,expected_finalized_game_count}','') is null or nullif(new.payload#>>'{universe,accounted_game_count}','') is null or nullif(new.payload->>'identity_integrity','') is null or nullif(new.payload->>'temporal_lane_integrity','') is null then raise exception 'F1_REQUIRED_PAYLOAD_MISSING'; end if;
      expected_count := (new.payload#>>'{universe,expected_finalized_game_count}')::integer;
      accounted_count := (new.payload#>>'{universe,accounted_game_count}')::integer;
      select count(*) into ledger_count from public.investigacion_nrfi_games where daily_run_id=new.daily_run_id;
      if expected_count <> accounted_count then raise exception 'F1_UNIVERSE_NOT_FULLY_ACCOUNTED'; end if;
      if expected_count <> ledger_count then raise exception 'F1_UNIVERSE_COUNT_NOT_BOUND_TO_GAME_LEDGER'; end if;
    elsif new.phase_id='F2_DEEP_RECONSTRUCTION' then
      if nullif(new.payload#>>'{reconstruction,processed_game_count}','') is null or nullif(new.payload#>>'{reconstruction,first_inning_integrity}','') is null or coalesce((new.payload#>>'{reconstruction,exact_event_sequence_preserved}')::boolean,false) is not true then raise exception 'F2_RECONSTRUCTION_PAYLOAD_INVALID'; end if;
    elsif new.phase_id='F3_FEATURE_FACTORY' then
      if nullif(new.payload#>>'{feature_registry,version}','') is null or nullif(new.payload#>>'{feature_registry,lineage_status}','') is null or nullif(new.payload#>>'{feature_registry,coverage_state_status}','') is null then raise exception 'F3_FEATURE_REGISTRY_PAYLOAD_INVALID'; end if;
    elsif new.phase_id='F4_HISTORICAL_PRESS_RELIABILITY' then
      if nullif(new.payload#>>'{reliability,status}','') is null or nullif(new.payload->>'human_information_lane_status','') is null or nullif(new.payload->>'mechanism_sequence_integrity','') is null then raise exception 'F4_RELIABILITY_PRESS_PAYLOAD_INVALID'; end if;
    elsif new.phase_id='F5_QUERYABLE_INTELLIGENCE' then
      if nullif(new.payload#>>'{query_engine,status}','') is null or nullif(new.payload#>>'{query_engine,as_of_future_game_count}','') is null or (new.payload#>>'{query_engine,as_of_future_game_count}')::integer <> 0 or nullif(new.payload#>>'{evidence_packet,status}','') is null then raise exception 'F5_QUERY_ENGINE_OR_AS_OF_INVALID'; end if;
    end if;
  end if;
  if phase_rank>1 then
    select count(*) into prior_missing from (values (1,'F1_FORENSIC_CAPTURE'),(2,'F2_DEEP_RECONSTRUCTION'),(3,'F3_FEATURE_FACTORY'),(4,'F4_HISTORICAL_PRESS_RELIABILITY'),(5,'F5_QUERYABLE_INTELLIGENCE')) as p(rank,pid)
    where p.rank<phase_rank and not exists(select 1 from public.investigacion_nrfi_phase_state s where s.daily_run_id=new.daily_run_id and s.phase_id=p.pid and s.status='COMPLETE');
    if prior_missing>0 then raise exception 'PREREQUISITES_INCOMPLETE'; end if;
  end if;
  return new;
end;
$$;

create or replace function public.investigacion_nrfi_guard_drive_append()
returns trigger language plpgsql as $$
declare run_volume text; active_doc text; volume_status text; readback_tool text; readback_run text; readback_doc text; readback_text_hash text;
begin
  select volume_id into run_volume from public.investigacion_nrfi_runs where daily_run_id=new.daily_run_id;
  if run_volume is distinct from new.volume_id then raise exception 'DRIVE_APPEND_VOLUME_MISMATCH'; end if;
  select drive_document_id,status into active_doc,volume_status from public.investigacion_nrfi_volumes where volume_id=new.volume_id;
  if active_doc is distinct from new.drive_document_id then raise exception 'DRIVE_APPEND_DOCUMENT_MISMATCH'; end if;
  if volume_status <> 'OPEN' then raise exception 'NORMAL_APPEND_TO_CLOSED_VOLUME_FORBIDDEN'; end if;
  if new.verified then
    if new.post_append_hash is null or new.readback_hash is null or new.readback_tool_event_id is null then raise exception 'DRIVE_READBACK_PROOF_REQUIRED'; end if;
    if new.post_append_hash is distinct from new.readback_hash then raise exception 'DRIVE_READBACK_HASH_MISMATCH'; end if;
    select tool_name,daily_run_id,metadata->>'drive_document_id',metadata->>'document_text_hash'
      into readback_tool,readback_run,readback_doc,readback_text_hash
      from public.investigacion_nrfi_tool_events where event_id=new.readback_tool_event_id;
    if readback_run is distinct from new.daily_run_id then raise exception 'DRIVE_READBACK_EVENT_WRONG_RUN'; end if;
    if readback_tool not in ('Google_Drive.get_document_text','Google_Drive.fetch','Google_Drive.find_document_text_range') then raise exception 'DRIVE_READBACK_REQUIRES_GOOGLE_DRIVE_TOOL_EVENT'; end if;
    if readback_doc is distinct from new.drive_document_id then raise exception 'DRIVE_READBACK_EVENT_WRONG_DOCUMENT'; end if;
    if readback_text_hash is distinct from new.readback_hash then raise exception 'DRIVE_READBACK_EVENT_HASH_MISMATCH'; end if;
  end if;
  return new;
end;
$$;

create or replace function public.investigacion_nrfi_derive_audit(p_daily_run_id text)
returns public.investigacion_nrfi_audits language plpgsql security definer set search_path=public as $$
declare
  r public.investigacion_nrfi_runs%rowtype;
  out_row public.investigacion_nrfi_audits%rowtype;
  completed text[]; missing text[]; temporal_ok boolean; trace_ok boolean; drive_ok boolean; universe_ok boolean;
  ledger_expected integer; ledger_processed integer; ledger_excluded integer; ledger_pending integer;
begin
  perform public.investigacion_nrfi_sync_run_accounting(p_daily_run_id);
  select * into r from public.investigacion_nrfi_runs where daily_run_id=p_daily_run_id;
  if not found then raise exception 'DAILY_RUN_NOT_FOUND'; end if;
  select count(*),count(*) filter(where research_status='PROCESSED'),count(*) filter(where research_status='EXCLUDED'),count(*) filter(where research_status='PENDING')
    into ledger_expected,ledger_processed,ledger_excluded,ledger_pending
    from public.investigacion_nrfi_games where daily_run_id=p_daily_run_id;
  select coalesce(array_agg(phase_id order by phase_id),'{}'::text[]) into completed from public.investigacion_nrfi_phase_state where daily_run_id=p_daily_run_id and status='COMPLETE';
  select coalesce(array_agg(pid),'{}'::text[]) into missing from unnest(array['F1_FORENSIC_CAPTURE','F2_DEEP_RECONSTRUCTION','F3_FEATURE_FACTORY','F4_HISTORICAL_PRESS_RELIABILITY','F5_QUERYABLE_INTELLIGENCE']) pid where not (pid=any(completed));
  universe_ok := ledger_pending=0 and ledger_expected=ledger_processed+ledger_excluded and r.expected_finalized_count=ledger_expected and r.processed_count=ledger_processed and r.excluded_count=ledger_excluded;
  select not exists(select 1 from public.investigacion_nrfi_evidence e where e.daily_run_id=p_daily_run_id and e.temporal_lane='PREGAME_EVIDENCE' and (e.available_at is null or e.first_pitch_at is null or e.available_at>=e.first_pitch_at)) into temporal_ok;
  select case when ledger_expected=0 then true else exists(select 1 from public.investigacion_nrfi_evidence e where e.daily_run_id=p_daily_run_id) and not exists(select 1 from public.investigacion_nrfi_evidence e left join public.investigacion_nrfi_tool_events t on t.event_id=e.tool_event_id left join public.investigacion_nrfi_source_families f on f.source_family_id=e.source_family_id where e.daily_run_id=p_daily_run_id and (t.event_id is null or f.source_family_id is null)) end into trace_ok;
  select exists(select 1 from public.investigacion_nrfi_drive_appends d where d.daily_run_id=p_daily_run_id and d.verified=true) into drive_ok;
  insert into public.investigacion_nrfi_audits(daily_run_id,phases_expected,phases_executed,mandatory_phases_not_run,universe_accounting_pass,temporal_integrity_pass,evidence_trace_pass,drive_append_pass,audit_status,details,derived_at)
  values(p_daily_run_id,5,cardinality(completed),missing,universe_ok,temporal_ok,trace_ok,drive_ok,case when cardinality(missing)=0 and universe_ok and temporal_ok and trace_ok and drive_ok then 'PASS' else 'FAIL' end,jsonb_build_object('ledger_expected',ledger_expected,'ledger_processed',ledger_processed,'ledger_excluded',ledger_excluded,'ledger_pending',ledger_pending,'agent_id','@investigacionNRFI'),now())
  on conflict(daily_run_id) do update set phases_executed=excluded.phases_executed,mandatory_phases_not_run=excluded.mandatory_phases_not_run,universe_accounting_pass=excluded.universe_accounting_pass,temporal_integrity_pass=excluded.temporal_integrity_pass,evidence_trace_pass=excluded.evidence_trace_pass,drive_append_pass=excluded.drive_append_pass,audit_status=excluded.audit_status,details=excluded.details,derived_at=excluded.derived_at returning * into out_row;
  return out_row;
end;
$$;