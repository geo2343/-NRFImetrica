create or replace function public.enforce_sports_reasoning_run_stage()
returns trigger language plpgsql as $$
declare
  p text:='NRFIMETRICA_MOTHER_V3_AUTONOMOUS';
  total integer; packeted integer; completec integer; incompletec integer; unavailablec integer; failc integer; exact_statement text;
begin
  if new.protocol_id<>p then return new; end if;
  if new.stage_id='SPORTS_REASONING_SLATE' then
    select count(*) into total from public.games where run_id=new.run_id;
    select count(*) into packeted from public.games g where g.run_id=new.run_id and exists(
      select 1 from public.sports_reasoning_packets s where s.run_id=g.run_id and s.game_id=g.game_id
      and s.version=(select max(x.version) from public.sports_reasoning_packets x where x.run_id=s.run_id and x.game_id=s.game_id)
      and s.status in ('ANALYSIS_COMPLETE','RESEARCH_INCOMPLETE','INFORMATION_UNAVAILABLE','NOT_EXECUTABLE','WITHDRAWN_POST_FREEZE','PROCESS_FAIL')
    );
    select count(*) into completec from public.games g where g.run_id=new.run_id and exists(
      select 1 from public.sports_reasoning_packets s where s.run_id=g.run_id and s.game_id=g.game_id
      and s.version=(select max(x.version) from public.sports_reasoning_packets x where x.run_id=s.run_id and x.game_id=s.game_id)
      and s.status='ANALYSIS_COMPLETE' and s.process_audit_status='PASS' and s.drive_verified_at is not null and s.drive_content_hash=s.packet_hash
    );
    select count(*) into incompletec from public.games g where g.run_id=new.run_id and exists(
      select 1 from public.sports_reasoning_packets s where s.run_id=g.run_id and s.game_id=g.game_id
      and s.version=(select max(x.version) from public.sports_reasoning_packets x where x.run_id=s.run_id and x.game_id=s.game_id)
      and s.status='RESEARCH_INCOMPLETE'
    );
    select count(*) into unavailablec from public.games g where g.run_id=new.run_id and exists(
      select 1 from public.sports_reasoning_packets s where s.run_id=g.run_id and s.game_id=g.game_id
      and s.version=(select max(x.version) from public.sports_reasoning_packets x where x.run_id=s.run_id and x.game_id=s.game_id)
      and s.status in ('INFORMATION_UNAVAILABLE','NOT_EXECUTABLE','WITHDRAWN_POST_FREEZE')
    );
    select count(*) into failc from public.games g where g.run_id=new.run_id and exists(
      select 1 from public.sports_reasoning_packets s where s.run_id=g.run_id and s.game_id=g.game_id
      and s.version=(select max(x.version) from public.sports_reasoning_packets x where x.run_id=s.run_id and x.game_id=s.game_id)
      and (s.status='PROCESS_FAIL' or s.process_audit_status='FAIL')
    );
    if packeted<>total then raise exception 'SPORTS_REASONING_SLATE_MISSING_PACKETS:%/%',packeted,total using errcode='23514'; end if;
    if coalesce((new.payload->>'total_games')::integer,-1)<>total or coalesce((new.payload->>'terminal_packet_count')::integer,-1)<>packeted or coalesce((new.payload->>'analysis_complete_count')::integer,-1)<>completec or coalesce((new.payload->>'research_incomplete_count')::integer,-1)<>incompletec or coalesce((new.payload->>'information_unavailable_count')::integer,-1)<>unavailablec or coalesce((new.payload->>'process_fail_count')::integer,-1)<>failc then raise exception 'SPORTS_REASONING_SLATE_COUNTS_MISMATCH' using errcode='23514'; end if;
    exact_statement:=completec::text||'/'||total::text||' ANALISIS_COMPLETOS';
    if coalesce(new.payload->>'analysis_statement','')<>exact_statement then raise exception 'SPORTS_REASONING_STATEMENT_MUST_BE_KERNEL_EXACT:%',exact_statement using errcode='23514'; end if;
  elsif new.stage_id='FINAL_REPORT' then
    if not exists(select 1 from public.protocol_run_state x where x.run_id=new.run_id and x.protocol_id=p and x.stage_id='SPORTS_REASONING_SLATE' and x.status='COMPLETE') then raise exception 'FINAL_REPORT_REQUIRES_SPORTS_REASONING_SLATE' using errcode='23514'; end if;
    select count(*) into total from public.games where run_id=new.run_id;
    select (payload->>'analysis_complete_count')::integer,(payload->>'research_incomplete_count')::integer,(payload->>'information_unavailable_count')::integer,(payload->>'process_fail_count')::integer into completec,incompletec,unavailablec,failc from public.protocol_run_state where run_id=new.run_id and protocol_id=p and stage_id='SPORTS_REASONING_SLATE' and status='COMPLETE';
    if coalesce((new.payload #>> '{summary,sports_total_games}')::integer,-1)<>total or coalesce((new.payload #>> '{summary,sports_analysis_complete_count}')::integer,-1)<>completec or coalesce((new.payload #>> '{summary,sports_research_incomplete_count}')::integer,-1)<>incompletec or coalesce((new.payload #>> '{summary,sports_information_unavailable_count}')::integer,-1)<>unavailablec or coalesce((new.payload #>> '{summary,sports_process_fail_count}')::integer,-1)<>failc then raise exception 'FINAL_REPORT_SPORTS_REASONING_COUNTS_MISMATCH' using errcode='23514'; end if;
    exact_statement:=completec::text||'/'||total::text||' ANALISIS_COMPLETOS';
    if coalesce(new.payload #>> '{summary,sports_analysis_statement}','')<>exact_statement then raise exception 'FINAL_REPORT_SPORTS_STATEMENT_MUST_BE_KERNEL_EXACT:%',exact_statement using errcode='23514'; end if;
  end if;
  return new;
end $$;
drop trigger if exists trg_02_sports_reasoning_run_stage on public.protocol_run_state;
create trigger trg_02_sports_reasoning_run_stage before insert or update on public.protocol_run_state for each row execute function public.enforce_sports_reasoning_run_stage();

create or replace function public.enforce_sports_reasoning_before_run_close()
returns trigger language plpgsql as $$
declare total integer; terminalc integer;
begin
  if new.system_version<>'NRFIM MOTHER V3' or new.status<>'CLOSED' or old.status='CLOSED' then return new; end if;
  select count(*) into total from public.games where run_id=new.run_id;
  select count(*) into terminalc from public.games g where g.run_id=new.run_id and exists(
    select 1 from public.sports_reasoning_packets s where s.run_id=g.run_id and s.game_id=g.game_id
    and s.version=(select max(x.version) from public.sports_reasoning_packets x where x.run_id=s.run_id and x.game_id=s.game_id)
    and s.status in ('ANALYSIS_COMPLETE','RESEARCH_INCOMPLETE','INFORMATION_UNAVAILABLE','NOT_EXECUTABLE','WITHDRAWN_POST_FREEZE','PROCESS_FAIL')
  );
  if terminalc<>total then raise exception 'RUN_CLOSE_REQUIRES_ONE_TERMINAL_SPORTS_PACKET_PER_GAME:%/%',terminalc,total using errcode='23514'; end if;
  if not exists(select 1 from public.protocol_run_state x where x.run_id=new.run_id and x.protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and x.stage_id='SPORTS_REASONING_SLATE' and x.status='COMPLETE') then raise exception 'RUN_CLOSE_REQUIRES_SPORTS_REASONING_SLATE' using errcode='23514'; end if;
  if not exists(select 1 from public.research_drive_artifacts a where a.run_id=new.run_id and a.artifact_type='FINAL_REPORT' and a.immutable and a.verified_at is not null) then raise exception 'RUN_CLOSE_REQUIRES_VERIFIED_DRIVE_FINAL_REPORT' using errcode='23514'; end if;
  return new;
end $$;
drop trigger if exists trg_03_sports_reasoning_before_run_close on public.runs;
create trigger trg_03_sports_reasoning_before_run_close before update of status on public.runs for each row execute function public.enforce_sports_reasoning_before_run_close();

update public.system_versions set kernel_version='NRFIM-KERNEL-0.6-CHAIN-OF-CUSTODY' where system_version='NRFIM MOTHER V3';
update public.agent_registry set agent_version='MOTHER-V3-AGENT-1.1',kernel_version='NRFIM-KERNEL-0.6-CHAIN-OF-CUSTODY',metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('sports_reasoning_packet_version','2.0','research_chain_of_custody',true,'claim_evidence_map_required',true,'source_family_floor','CLEAR=3;NORMAL=5;DEEP=7','drive_hash_match_required',true,'sports_analysis_statement_kernel_generated',true,'semantic_auditor_authority','NO_SPORTS_VOTE'),updated_at=now() where agent_id='@NRFImetrica';