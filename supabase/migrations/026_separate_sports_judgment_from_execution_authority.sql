create or replace view public.nrfimetrica_game_dual_status as
with latest_packet as (
  select distinct on (s.run_id,s.game_id)
    s.run_id,s.game_id,s.packet_id,s.status as packet_status,s.sports_verdict,
    s.process_audit_status,s.packet_hash,s.drive_content_hash,s.drive_verified_at
  from public.sports_reasoning_packets s
  order by s.run_id,s.game_id,s.version desc
), a8 as (
  select run_id,game_id,payload
  from public.protocol_phase_state
  where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS'
    and phase_id='A8_MARKET_VALUE_EXECUTION'
), res as (
  select run_id,game_id,resolution_code,authority_level,reason
  from public.protocol_game_resolution
  where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS'
)
select
  g.run_id,g.game_id,g.status as game_status,
  lp.packet_id,lp.packet_status,lp.sports_verdict,lp.process_audit_status,
  (lp.drive_verified_at is not null and lp.drive_content_hash=lp.packet_hash) as drive_hash_verified,
  case
    when g.status='AUDIT_ONLY' or lp.packet_status='NOT_EXECUTABLE' then 'AUDIT_ONLY'
    when lp.packet_status in ('RESEARCH_INCOMPLETE','INFORMATION_UNAVAILABLE','WITHDRAWN_POST_FREEZE','PROCESS_FAIL') then 'WATCHLIST'
    when lp.packet_status='ANALYSIS_COMPLETE' and lp.process_audit_status='PASS'
         and lp.drive_verified_at is not null and lp.drive_content_hash=lp.packet_hash
         and lp.sports_verdict='NRFI_LEAN' then 'SPORTS_CANDIDATE'
    when lp.packet_status='ANALYSIS_COMPLETE' and lp.process_audit_status='PASS'
         and lp.drive_verified_at is not null and lp.drive_content_hash=lp.packet_hash
         and lp.sports_verdict in ('YRFI_LEAN','NO_PLAY','NEUTRAL') then 'NO_PLAY'
    else 'WATCHLIST'
  end as sports_status,
  case
    when upper(coalesce(a8.payload->>'final_verdict','')) in ('APOSTAR','SOLO_SI_CUOTA') then 'EXECUTABLE'
    when lp.packet_status='ANALYSIS_COMPLETE' and lp.process_audit_status='PASS'
         and lp.drive_verified_at is not null and lp.drive_content_hash=lp.packet_hash
         and lp.sports_verdict='NRFI_LEAN'
         and res.resolution_code in ('A4_ENGINE_NOT_INTEGRATED','A4_TRUE_MODEL_FAILURE','A6_INDEPENDENT_AUDIT_UNAVAILABLE','A7_NOT_ELIGIBLE','A7_RESEARCH_ONLY','A7_CALIBRATION_UNCERTIFIED','A7_MODEL_AUDIT_REQUIRED','A7_PRESS_UNAVAILABLE') then 'TECHNICAL_BLOCK'
    when g.status='AUDIT_ONLY' or lp.packet_status='NOT_EXECUTABLE' then 'AUDIT_ONLY'
    when lp.packet_status in ('RESEARCH_INCOMPLETE','INFORMATION_UNAVAILABLE','WITHDRAWN_POST_FREEZE','PROCESS_FAIL') then 'WATCHLIST'
    when lp.packet_status='ANALYSIS_COMPLETE' and lp.process_audit_status='PASS'
         and lp.drive_verified_at is not null and lp.drive_content_hash=lp.packet_hash
         and lp.sports_verdict in ('YRFI_LEAN','NO_PLAY','NEUTRAL') then 'NOT_APPLICABLE'
    when lp.packet_status='ANALYSIS_COMPLETE' and lp.process_audit_status='PASS'
         and lp.drive_verified_at is not null and lp.drive_content_hash=lp.packet_hash
         and lp.sports_verdict='NRFI_LEAN' then 'PENDING'
    else 'WATCHLIST'
  end as execution_status,
  res.resolution_code as technical_resolution_code,
  res.reason as technical_resolution_reason
from public.games g
left join latest_packet lp on lp.run_id=g.run_id and lp.game_id=g.game_id
left join a8 on a8.run_id=g.run_id and a8.game_id=g.game_id
left join res on res.run_id=g.run_id and res.game_id=g.game_id;

create or replace function public.enforce_nrfimetrica_dual_status_reporting()
returns trigger language plpgsql as $$
declare
  p text:='NRFIMETRICA_MOTHER_V3_AUTONOMOUS';
  sc integer; np integer; wl integer; ao integer; tb integer; ex integer; total integer;
  declared_sc integer; declared_ex integer;
begin
  if new.protocol_id<>p then return new; end if;

  select count(*),
         count(*) filter(where sports_status='SPORTS_CANDIDATE'),
         count(*) filter(where sports_status='NO_PLAY'),
         count(*) filter(where sports_status='WATCHLIST'),
         count(*) filter(where sports_status='AUDIT_ONLY'),
         count(*) filter(where execution_status='TECHNICAL_BLOCK'),
         count(*) filter(where execution_status='EXECUTABLE')
    into total,sc,np,wl,ao,tb,ex
  from public.nrfimetrica_game_dual_status
  where run_id=new.run_id;

  if new.stage_id='A7_SLATE_ELIGIBILITY' then
    if not (new.payload ? 'sports_candidate_count')
       or not (new.payload ? 'sports_no_play_count')
       or not (new.payload ? 'sports_watchlist_count')
       or not (new.payload ? 'sports_audit_only_count')
       or not (new.payload ? 'technical_block_count')
       or not (new.payload ? 'execution_eligible_count') then
      raise exception 'A7_DUAL_STATUS_COUNTS_REQUIRED' using errcode='23514';
    end if;
    if (new.payload->>'sports_candidate_count')::integer<>sc
       or (new.payload->>'sports_no_play_count')::integer<>np
       or (new.payload->>'sports_watchlist_count')::integer<>wl
       or (new.payload->>'sports_audit_only_count')::integer<>ao
       or (new.payload->>'technical_block_count')::integer<>tb
       or (new.payload->>'execution_eligible_count')::integer<>ex then
      raise exception 'A7_DUAL_STATUS_COUNTS_MISMATCH:SPORTS_CANDIDATE=% NO_PLAY=% WATCHLIST=% AUDIT_ONLY=% TECHNICAL_BLOCK=% EXECUTABLE=%',sc,np,wl,ao,tb,ex using errcode='23514';
    end if;
    if coalesce((new.payload->>'eligible_count')::integer,-1)<>ex then
      raise exception 'A7_ELIGIBLE_COUNT_IS_EXECUTION_ELIGIBILITY_ONLY:%/%',new.payload->>'eligible_count',ex using errcode='23514';
    end if;

  elsif new.stage_id='A8_PORTFOLIO' then
    if coalesce((new.payload->>'sports_candidate_count')::integer,-1)<>sc
       or coalesce((new.payload->>'technical_block_count')::integer,-1)<>tb then
      raise exception 'A8_MUST_PRESERVE_SPORTS_CANDIDATE_AND_TECHNICAL_BLOCK_COUNTS:%/%',sc,tb using errcode='23514';
    end if;

  elsif new.stage_id='FINAL_REPORT' then
    declared_sc:=coalesce((new.payload #>> '{summary,sports_candidate_count}')::integer,-1);
    declared_ex:=coalesce((new.payload #>> '{summary,execution_candidate_count}')::integer,-1);
    if declared_sc<>sc
       or coalesce((new.payload #>> '{summary,sports_no_play_count}')::integer,-1)<>np
       or coalesce((new.payload #>> '{summary,sports_watchlist_count}')::integer,-1)<>wl
       or coalesce((new.payload #>> '{summary,sports_audit_only_count}')::integer,-1)<>ao
       or coalesce((new.payload #>> '{summary,technical_block_count}')::integer,-1)<>tb
       or declared_ex<>ex then
      raise exception 'FINAL_REPORT_DUAL_STATUS_COUNTS_MISMATCH' using errcode='23514';
    end if;
    if not (new.payload ? 'sports_candidates') or jsonb_typeof(new.payload->'sports_candidates')<>'array' then
      raise exception 'FINAL_REPORT_SPORTS_CANDIDATES_ARRAY_REQUIRED' using errcode='23514';
    end if;
    if jsonb_array_length(new.payload->'sports_candidates')<>sc then
      raise exception 'FINAL_REPORT_SPORTS_CANDIDATE_ARRAY_COUNT_MISMATCH:%/%',jsonb_array_length(new.payload->'sports_candidates'),sc using errcode='23514';
    end if;
    if declared_sc>0 and declared_ex=0 then
      if upper(coalesce(new.payload #>> '{final_verdict,execution_status}',''))<>'TECHNICAL_BLOCK' then
        raise exception 'SPORTS_CANDIDATES_WITH_ZERO_EXECUTABLE_MUST_REPORT_TECHNICAL_BLOCK' using errcode='23514';
      end if;
      if upper(coalesce(new.payload #>> '{final_verdict,decision_basis}',''))<>'TECHNICAL_BLOCK_NOT_SPORTS_REJECTION' then
        raise exception 'FINAL_REPORT_MUST_DISTINGUISH_TECHNICAL_BLOCK_FROM_SPORTS_REJECTION' using errcode='23514';
      end if;
    end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_03_nrfimetrica_dual_status_reporting on public.protocol_run_state;
create trigger trg_03_nrfimetrica_dual_status_reporting
before insert or update on public.protocol_run_state
for each row execute function public.enforce_nrfimetrica_dual_status_reporting();

update public.agent_registry
set agent_version='MOTHER-V3-AGENT-1.3',
    kernel_version='NRFIM-KERNEL-0.8-DUAL-STATUS',
    metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object(
      'sports_execution_dual_status',true,
      'sports_candidate_survives_technical_block',true,
      'a4_block_is_not_sports_no_play',true,
      'required_statuses',jsonb_build_array('SPORTS_CANDIDATE','EXECUTABLE','WATCHLIST','NO_PLAY','TECHNICAL_BLOCK'),
      'database_migrations_required_through',26)
where agent_id='@NRFImetrica';

update public.system_versions
set kernel_version='NRFIM-KERNEL-0.8-DUAL-STATUS'
where system_version='NRFIM MOTHER V3';