create or replace function public.investigacion_nrfi_payload_has_forbidden_keys(p jsonb)
returns boolean language sql immutable as $$
  select coalesce(p::text ~* '"(pick|stake|ev|sportsbook|odds|bet_recommendation|authoritative_nrfi_probability|metric_score_decision)"\s*:', false);
$$;

create or replace function public.investigacion_nrfi_guard_run_volume()
returns trigger language plpgsql as $$
declare v public.investigacion_nrfi_volumes%rowtype;
begin
  select * into v from public.investigacion_nrfi_volumes where volume_id=new.volume_id;
  if not found then raise exception 'ACTIVE_VOLUME_NOT_FOUND'; end if;
  if v.status <> 'OPEN' then raise exception 'DAILY_RUN_REQUIRES_OPEN_VOLUME'; end if;
  if v.capacity_state = 'ROLLOVER_REQUIRED' then raise exception 'ACTIVE_VOLUME_ROLLOVER_REQUIRED_USER_AUTHORIZATION_NEEDED'; end if;
  if new.run_type <> 'ORIGINAL' and new.parent_run_id is null then raise exception 'PARENT_RUN_REQUIRED_FOR_NON_ORIGINAL'; end if;
  return new;
end;
$$;

drop trigger if exists investigacion_nrfi_run_volume_guard on public.investigacion_nrfi_runs;
create trigger investigacion_nrfi_run_volume_guard
before insert or update of volume_id,run_type,parent_run_id on public.investigacion_nrfi_runs
for each row execute function public.investigacion_nrfi_guard_run_volume();

create or replace function public.investigacion_nrfi_guard_phase_state()
returns trigger language plpgsql as $$
declare
  phase_rank integer;
  prior_missing integer;
  required_keys text[] := array['PHASE_ID','START_AS_OF','END_AS_OF','INPUT_OBJECTS','OPERATIONS_PERFORMED','OUTPUT_OBJECTS','SOURCES_OR_EVIDENCE','AUDITOR_RESULT','NEXT_PHASE'];
  expected_count integer;
  accounted_count integer;
begin
  phase_rank := case new.phase_id
    when 'F1_FORENSIC_CAPTURE' then 1
    when 'F2_DEEP_RECONSTRUCTION' then 2
    when 'F3_FEATURE_FACTORY' then 3
    when 'F4_HISTORICAL_PRESS_RELIABILITY' then 4
    when 'F5_QUERYABLE_INTELLIGENCE' then 5
    else 99 end;

  if public.investigacion_nrfi_payload_has_forbidden_keys(new.payload) then
    raise exception 'FORBIDDEN_PICK_OR_MARKET_OUTPUT';
  end if;

  if new.status = 'COMPLETE' then
    if not (new.receipt ?& required_keys) then raise exception 'PHASE_EXECUTION_RECEIPT_INCOMPLETE'; end if;
    if coalesce(new.receipt->>'PHASE_ID','') <> new.phase_id then raise exception 'RECEIPT_PHASE_ID_MISMATCH'; end if;

    if new.phase_id='F1_FORENSIC_CAPTURE' then
      if nullif(new.payload#>>'{universe,expected_finalized_game_count}','') is null
         or nullif(new.payload#>>'{universe,accounted_game_count}','') is null
         or nullif(new.payload->>'identity_integrity','') is null
         or nullif(new.payload->>'temporal_lane_integrity','') is null then
        raise exception 'F1_REQUIRED_PAYLOAD_MISSING';
      end if;
      expected_count := (new.payload#>>'{universe,expected_finalized_game_count}')::integer;
      accounted_count := (new.payload#>>'{universe,accounted_game_count}')::integer;
      if expected_count <> accounted_count then raise exception 'F1_UNIVERSE_NOT_FULLY_ACCOUNTED'; end if;
    elsif new.phase_id='F2_DEEP_RECONSTRUCTION' then
      if nullif(new.payload#>>'{reconstruction,processed_game_count}','') is null
         or nullif(new.payload#>>'{reconstruction,first_inning_integrity}','') is null
         or coalesce((new.payload#>>'{reconstruction,exact_event_sequence_preserved}')::boolean,false) is not true then
        raise exception 'F2_RECONSTRUCTION_PAYLOAD_INVALID';
      end if;
    elsif new.phase_id='F3_FEATURE_FACTORY' then
      if nullif(new.payload#>>'{feature_registry,version}','') is null
         or nullif(new.payload#>>'{feature_registry,lineage_status}','') is null
         or nullif(new.payload#>>'{feature_registry,coverage_state_status}','') is null then
        raise exception 'F3_FEATURE_REGISTRY_PAYLOAD_INVALID';
      end if;
    elsif new.phase_id='F4_HISTORICAL_PRESS_RELIABILITY' then
      if nullif(new.payload#>>'{reliability,status}','') is null
         or nullif(new.payload->>'human_information_lane_status','') is null
         or nullif(new.payload->>'mechanism_sequence_integrity','') is null then
        raise exception 'F4_RELIABILITY_PRESS_PAYLOAD_INVALID';
      end if;
    elsif new.phase_id='F5_QUERYABLE_INTELLIGENCE' then
      if nullif(new.payload#>>'{query_engine,status}','') is null
         or nullif(new.payload#>>'{query_engine,as_of_future_game_count}','') is null
         or (new.payload#>>'{query_engine,as_of_future_game_count}')::integer <> 0
         or nullif(new.payload#>>'{evidence_packet,status}','') is null then
        raise exception 'F5_QUERY_ENGINE_OR_AS_OF_INVALID';
      end if;
    end if;
  end if;

  if phase_rank > 1 then
    select count(*) into prior_missing
    from (values
      (1,'F1_FORENSIC_CAPTURE'),(2,'F2_DEEP_RECONSTRUCTION'),(3,'F3_FEATURE_FACTORY'),
      (4,'F4_HISTORICAL_PRESS_RELIABILITY'),(5,'F5_QUERYABLE_INTELLIGENCE')
    ) as p(rank,pid)
    where p.rank < phase_rank
      and not exists (
        select 1 from public.investigacion_nrfi_phase_state s
        where s.daily_run_id=new.daily_run_id and s.phase_id=p.pid and s.status='COMPLETE'
      );
    if prior_missing > 0 then raise exception 'PREREQUISITES_INCOMPLETE'; end if;
  end if;
  return new;
end;
$$;

create or replace function public.investigacion_nrfi_guard_drive_append()
returns trigger language plpgsql as $$
declare run_volume text; active_doc text; volume_status text;
begin
  select volume_id into run_volume from public.investigacion_nrfi_runs where daily_run_id=new.daily_run_id;
  if run_volume is distinct from new.volume_id then raise exception 'DRIVE_APPEND_VOLUME_MISMATCH'; end if;
  select drive_document_id,status into active_doc,volume_status from public.investigacion_nrfi_volumes where volume_id=new.volume_id;
  if active_doc is distinct from new.drive_document_id then raise exception 'DRIVE_APPEND_DOCUMENT_MISMATCH'; end if;
  if volume_status <> 'OPEN' then raise exception 'NORMAL_APPEND_TO_CLOSED_VOLUME_FORBIDDEN'; end if;
  if new.verified then
    if new.post_append_hash is null or new.readback_hash is null or new.readback_tool_event_id is null then raise exception 'DRIVE_READBACK_PROOF_REQUIRED'; end if;
    if new.post_append_hash is distinct from new.readback_hash then raise exception 'DRIVE_READBACK_HASH_MISMATCH'; end if;
  end if;
  return new;
end;
$$;
