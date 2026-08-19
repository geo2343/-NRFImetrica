create or replace function public.freeze_terminal_sports_packet()
returns trigger language plpgsql as $$
begin
  if new.status in ('ANALYSIS_COMPLETE','RESEARCH_INCOMPLETE','INFORMATION_UNAVAILABLE','NOT_EXECUTABLE','WITHDRAWN_POST_FREEZE','PROCESS_FAIL') then
    if new.freeze_timestamp is null then new.freeze_timestamp:=clock_timestamp(); end if;
    if coalesce(new.packet_hash,'')='' then
      new.packet_hash:=public.nrfim_sha256_text((to_jsonb(new)-'packet_hash'-'drive_file_id'-'drive_content_hash'-'drive_verified_at'-'process_audit_status'-'process_audit_id'-'updated_at')::text);
    end if;
  end if;
  return new;
end $$;
drop trigger if exists trg_02_freeze_terminal_sports_packet on public.sports_reasoning_packets;
create trigger trg_02_freeze_terminal_sports_packet before insert or update on public.sports_reasoning_packets for each row execute function public.freeze_terminal_sports_packet();

create or replace function public.enforce_research_drive_artifact()
returns trigger language plpgsql as $$
declare p public.sports_reasoning_packets%rowtype; r jsonb; expected text;
begin
  new.verified_at:=clock_timestamp();
  if new.artifact_type='PACKET' then
    if new.packet_id is null then raise exception 'PACKET_DRIVE_ARTIFACT_REQUIRES_PACKET_ID' using errcode='23514'; end if;
    select * into p from public.sports_reasoning_packets where packet_id=new.packet_id;
    if not found or p.run_id<>new.run_id or p.game_id is distinct from new.game_id then raise exception 'PACKET_DRIVE_ARTIFACT_IDENTITY_MISMATCH' using errcode='23514'; end if;
    if coalesce(p.packet_hash,'')='' or new.content_hash<>p.packet_hash then raise exception 'PACKET_DRIVE_HASH_MISMATCH' using errcode='23514'; end if;
    update public.sports_reasoning_packets set drive_file_id=new.drive_file_id,drive_content_hash=new.content_hash,drive_verified_at=new.verified_at,updated_at=clock_timestamp() where packet_id=new.packet_id;
  elsif new.artifact_type='FINAL_REPORT' then
    select payload into r from public.protocol_run_state where run_id=new.run_id and protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and stage_id='FINAL_REPORT' and status='COMPLETE';
    if r is null then raise exception 'FINAL_REPORT_DRIVE_ARTIFACT_REQUIRES_FINAL_REPORT_STAGE' using errcode='23514'; end if;
    expected:=public.nrfim_sha256_text(r::text);
    if new.content_hash<>expected then raise exception 'FINAL_REPORT_DRIVE_HASH_MISMATCH' using errcode='23514'; end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_01_research_drive_artifact on public.research_drive_artifacts;
create trigger trg_01_research_drive_artifact before insert on public.research_drive_artifacts for each row execute function public.enforce_research_drive_artifact();

create or replace function public.enforce_sports_reasoning_run_stage()
returns trigger language plpgsql as $$
declare p text:='NRFIMETRICA_MOTHER_V3_AUTONOMOUS'; total integer; packeted integer; completec integer; incompletec integer; unavailablec integer; failc integer; exact_statement text;
begin
  if new.protocol_id<>p then return new; end if;
  if new.stage_id='SPORTS_REASONING_SLATE' then
    select count(*) into total from public.games where run_id=new.run_id;
    select count(*) into packeted from public.games g where g.run_id=new.run_id and exists(select 1 from public.sports_reasoning_packets s where s.run_id=g.run_id and s.game_id=g.game_id and s.version=(select max(x.version) from public.sports_reasoning_packets x where x.run_id=s.run_id and x.game_id=s.game_id) and s.status in ('ANALYSIS_COMPLETE','RESEARCH_INCOMPLETE','INFORMATION_UNAVAILABLE','NOT_EXECUTABLE','WITHDRAWN_POST_FREEZE','PROCESS_FAIL') and s.packet_hash is not null and s.drive_verified_at is not null and s.drive_content_hash=s.packet_hash);
    select count(*) into completec from public.games g where g.run_id=new.run_id and exists(select 1 from public.sports_reasoning_packets s where s.run_id=g.run_id and s.game_id=g.game_id and s.version=(select max(x.version) from public.sports_reasoning_packets x where x.run_id=s.run_id and x.game_id=s.game_id) and s.status='ANALYSIS_COMPLETE' and s.process_audit_status='PASS' and s.drive_verified_at is not null and s.drive_content_hash=s.packet_hash);
    select count(*) into incompletec from public.games g where g.run_id=new.run_id and exists(select 1 from public.sports_reasoning_packets s where s.run_id=g.run_id and s.game_id=g.game_id and s.version=(select max(x.version) from public.sports_reasoning_packets x where x.run_id=s.run_id and x.game_id=s.game_id) and s.status='RESEARCH_INCOMPLETE' and s.drive_verified_at is not null and s.drive_content_hash=s.packet_hash);
    select count(*) into unavailablec from public.games g where g.run_id=new.run_id and exists(select 1 from public.sports_reasoning_packets s where s.run_id=g.run_id and s.game_id=g.game_id and s.version=(select max(x.version) from public.sports_reasoning_packets x where x.run_id=s.run_id and x.game_id=s.game_id) and s.status in ('INFORMATION_UNAVAILABLE','NOT_EXECUTABLE','WITHDRAWN_POST_FREEZE') and s.drive_verified_at is not null and s.drive_content_hash=s.packet_hash);
    select count(*) into failc from public.games g where g.run_id=new.run_id and exists(select 1 from public.sports_reasoning_packets s where s.run_id=g.run_id and s.game_id=g.game_id and s.version=(select max(x.version) from public.sports_reasoning_packets x where x.run_id=s.run_id and x.game_id=s.game_id) and (s.status='PROCESS_FAIL' or s.process_audit_status='FAIL') and s.drive_verified_at is not null and s.drive_content_hash=s.packet_hash);
    if packeted<>total then raise exception 'SPORTS_REASONING_SLATE_MISSING_VERIFIED_PACKETS:%/%',packeted,total using errcode='23514'; end if;
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