-- Kernel 0.9: sports judgment, process validation, and execution are three separate axes.
-- A process failure may block execution, but it may never erase a substantive sports verdict.

create or replace view public.nrfimetrica_game_dual_status as
with latest_packet as (
  select distinct on (s.run_id,s.game_id)
    s.run_id,s.game_id,s.packet_id,s.status as packet_status,s.sports_verdict,
    s.process_audit_status,s.packet_hash,s.drive_content_hash,s.drive_verified_at
  from public.sports_reasoning_packets s
  order by s.run_id,s.game_id,s.version desc
),
a8 as (
  select run_id,game_id,payload from public.protocol_phase_state
  where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and phase_id='A8_MARKET_VALUE_EXECUTION'
),
res as (
  select run_id,game_id,resolution_code,authority_level,reason
  from public.protocol_game_resolution
  where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS'
)
select
  g.run_id,g.game_id,g.status as game_status,lp.packet_id,lp.packet_status,lp.sports_verdict,lp.process_audit_status,
  (lp.drive_verified_at is not null and lp.drive_content_hash=lp.packet_hash) as drive_hash_verified,
  case
    when g.status='AUDIT_ONLY' then 'AUDIT_ONLY'
    when lp.sports_verdict='NRFI_LEAN' then 'SPORTS_CANDIDATE'
    when lp.sports_verdict in ('YRFI_LEAN','NO_PLAY','NEUTRAL') then 'NO_PLAY'
    else 'WATCHLIST'
  end as sports_status,
  case
    when upper(coalesce(a8.payload->>'final_verdict','')) in ('APOSTAR','SOLO_SI_CUOTA') then 'EXECUTABLE'
    when g.status='AUDIT_ONLY' then 'AUDIT_ONLY'
    when lp.sports_verdict='NRFI_LEAN' and res.resolution_code in (
      'A4_ENGINE_NOT_INTEGRATED','A4_TRUE_MODEL_FAILURE','A6_INDEPENDENT_AUDIT_UNAVAILABLE',
      'A7_NOT_ELIGIBLE','A7_RESEARCH_ONLY','A7_CALIBRATION_UNCERTIFIED','A7_MODEL_AUDIT_REQUIRED','A7_PRESS_UNAVAILABLE'
    ) then 'TECHNICAL_BLOCK'
    when lp.sports_verdict='NRFI_LEAN' and not (
      lp.packet_status='ANALYSIS_COMPLETE' and lp.process_audit_status='PASS'
      and lp.drive_verified_at is not null and lp.drive_content_hash=lp.packet_hash
    ) then 'PROCESS_BLOCK'
    when lp.sports_verdict='NRFI_LEAN' then 'PENDING'
    when lp.sports_verdict in ('YRFI_LEAN','NO_PLAY','NEUTRAL') then 'NOT_APPLICABLE'
    else 'WATCHLIST'
  end as execution_status,
  res.resolution_code as technical_resolution_code,
  res.reason as technical_resolution_reason,
  case
    when g.status='AUDIT_ONLY' then 'NOT_APPLICABLE'
    when lp.packet_id is null then 'MISSING'
    when lp.packet_status='ANALYSIS_COMPLETE' and lp.process_audit_status='PASS'
      and lp.drive_verified_at is not null and lp.drive_content_hash=lp.packet_hash then 'VERIFIED'
    when lp.packet_status='PROCESS_FAIL' or lp.process_audit_status='FAIL' then 'FAIL'
    when lp.process_audit_status='REVIEW' then 'REVIEW'
    when lp.drive_verified_at is null or lp.drive_content_hash is distinct from lp.packet_hash then 'UNVERIFIED'
    when lp.packet_status in ('RESEARCH_INCOMPLETE','INFORMATION_UNAVAILABLE','WITHDRAWN_POST_FREEZE') then 'INCOMPLETE'
    else 'PENDING'
  end as process_status
from public.games g
left join latest_packet lp on lp.run_id=g.run_id and lp.game_id=g.game_id
left join a8 on a8.run_id=g.run_id and a8.game_id=g.game_id
left join res on res.run_id=g.run_id and res.game_id=g.game_id;

create or replace function public.enforce_nrfimetrica_dual_status_reporting()
returns trigger language plpgsql as $$
declare
  p text:='NRFIMETRICA_MOTHER_V3_AUTONOMOUS';
  sc integer; np integer; wl integer; ao integer; tb integer; pb integer; ex integer; total integer;
  pv integer; pf integer; pi integer; pr integer; pm integer;
  declared_sc integer; declared_ex integer; c jsonb; gid text; seen text[]:='{}'; actual_exec text; actual_verdict text; actual_process text;
  eid text; non_audit integer;
begin
  if new.protocol_id<>p then return new; end if;
  select count(*),
         count(*) filter(where sports_status='SPORTS_CANDIDATE'),
         count(*) filter(where sports_status='NO_PLAY'),
         count(*) filter(where sports_status='WATCHLIST'),
         count(*) filter(where sports_status='AUDIT_ONLY'),
         count(*) filter(where execution_status='TECHNICAL_BLOCK'),
         count(*) filter(where execution_status='PROCESS_BLOCK'),
         count(*) filter(where execution_status='EXECUTABLE'),
         count(*) filter(where process_status='VERIFIED'),
         count(*) filter(where process_status='FAIL'),
         count(*) filter(where process_status='INCOMPLETE'),
         count(*) filter(where process_status='REVIEW'),
         count(*) filter(where process_status='MISSING')
    into total,sc,np,wl,ao,tb,pb,ex,pv,pf,pi,pr,pm
  from public.nrfimetrica_game_dual_status where run_id=new.run_id;
  non_audit:=total-ao;

  if new.stage_id='A7_SLATE_ELIGIBILITY' then
    if not (new.payload ? 'sports_candidate_count') or not (new.payload ? 'sports_no_play_count')
       or not (new.payload ? 'sports_watchlist_count') or not (new.payload ? 'sports_audit_only_count')
       or not (new.payload ? 'technical_block_count') or not (new.payload ? 'process_block_count')
       or not (new.payload ? 'execution_eligible_count') then
      raise exception 'A7_TRI_STATUS_COUNTS_REQUIRED' using errcode='23514';
    end if;
    if (new.payload->>'sports_candidate_count')::integer<>sc
       or (new.payload->>'sports_no_play_count')::integer<>np
       or (new.payload->>'sports_watchlist_count')::integer<>wl
       or (new.payload->>'sports_audit_only_count')::integer<>ao
       or (new.payload->>'technical_block_count')::integer<>tb
       or (new.payload->>'process_block_count')::integer<>pb
       or (new.payload->>'execution_eligible_count')::integer<>ex then
      raise exception 'A7_TRI_STATUS_COUNTS_MISMATCH:SPORTS_CANDIDATE=% NO_PLAY=% WATCHLIST=% AUDIT_ONLY=% TECHNICAL_BLOCK=% PROCESS_BLOCK=% EXECUTABLE=%',sc,np,wl,ao,tb,pb,ex using errcode='23514';
    end if;
    if coalesce((new.payload->>'eligible_count')::integer,-1)<>ex then
      raise exception 'A7_ELIGIBLE_COUNT_IS_EXECUTION_ELIGIBILITY_ONLY:%/%',new.payload->>'eligible_count',ex using errcode='23514';
    end if;

  elsif new.stage_id='A8_PORTFOLIO' then
    if coalesce((new.payload->>'sports_candidate_count')::integer,-1)<>sc
       or coalesce((new.payload->>'technical_block_count')::integer,-1)<>tb
       or coalesce((new.payload->>'process_block_count')::integer,-1)<>pb then
      raise exception 'A8_MUST_PRESERVE_SPORTS_PROCESS_AND_EXECUTION_COUNTS:%/%/%',sc,tb,pb using errcode='23514';
    end if;

  elsif new.stage_id='FINAL_REPORT' then
    declared_sc:=coalesce((new.payload #>> '{summary,sports_candidate_count}')::integer,-1);
    declared_ex:=coalesce((new.payload #>> '{summary,execution_candidate_count}')::integer,-1);
    if declared_sc<>sc
       or coalesce((new.payload #>> '{summary,sports_no_play_count}')::integer,-1)<>np
       or coalesce((new.payload #>> '{summary,sports_watchlist_count}')::integer,-1)<>wl
       or coalesce((new.payload #>> '{summary,sports_audit_only_count}')::integer,-1)<>ao
       or coalesce((new.payload #>> '{summary,technical_block_count}')::integer,-1)<>tb
       or coalesce((new.payload #>> '{summary,process_block_count}')::integer,-1)<>pb
       or coalesce((new.payload #>> '{summary,process_verified_count}')::integer,-1)<>pv
       or coalesce((new.payload #>> '{summary,process_failed_count}')::integer,-1)<>pf
       or coalesce((new.payload #>> '{summary,process_incomplete_count}')::integer,-1)<>pi
       or declared_ex<>ex then raise exception 'FINAL_REPORT_TRI_STATUS_COUNTS_MISMATCH' using errcode='23514'; end if;

    if not (new.payload ? 'sports_candidates') or jsonb_typeof(new.payload->'sports_candidates')<>'array' then
      raise exception 'FINAL_REPORT_SPORTS_CANDIDATES_ARRAY_REQUIRED' using errcode='23514'; end if;
    if jsonb_array_length(new.payload->'sports_candidates')<>sc then
      raise exception 'FINAL_REPORT_SPORTS_CANDIDATE_ARRAY_COUNT_MISMATCH:%/%',jsonb_array_length(new.payload->'sports_candidates'),sc using errcode='23514'; end if;
    seen:='{}';
    for c in select value from jsonb_array_elements(new.payload->'sports_candidates') loop
      gid:=c->>'game_id';
      if coalesce(gid,'')='' or gid=any(seen) then raise exception 'FINAL_REPORT_SPORTS_CANDIDATE_ID_INVALID_OR_DUPLICATE:%',coalesce(gid,'NULL') using errcode='23514'; end if;
      select execution_status,sports_verdict,process_status into actual_exec,actual_verdict,actual_process
      from public.nrfimetrica_game_dual_status d where d.run_id=new.run_id and d.game_id=gid and d.sports_status='SPORTS_CANDIDATE';
      if not found then raise exception 'FINAL_REPORT_FALSE_SPORTS_CANDIDATE:%',gid using errcode='23514'; end if;
      if upper(coalesce(c->>'sports_status',''))<>'SPORTS_CANDIDATE' or upper(coalesce(c->>'execution_status',''))<>actual_exec
         or upper(coalesce(c->>'sports_verdict',''))<>actual_verdict or upper(coalesce(c->>'process_status',''))<>actual_process then
        raise exception 'FINAL_REPORT_SPORTS_CANDIDATE_STATE_MISMATCH:%',gid using errcode='23514'; end if;
      seen:=array_append(seen,gid);
    end loop;

    if not (new.payload ? 'game_statuses') or jsonb_typeof(new.payload->'game_statuses')<>'array' or jsonb_array_length(new.payload->'game_statuses')<>total then
      raise exception 'FINAL_REPORT_EXACT_GAME_STATUS_ARRAY_REQUIRED:%',total using errcode='23514'; end if;
    seen:='{}';
    for c in select value from jsonb_array_elements(new.payload->'game_statuses') loop
      gid:=c->>'game_id';
      if coalesce(gid,'')='' or gid=any(seen) then raise exception 'FINAL_REPORT_GAME_STATUS_ID_INVALID_OR_DUPLICATE:%',coalesce(gid,'NULL') using errcode='23514'; end if;
      if not exists(select 1 from public.nrfimetrica_game_dual_status d where d.run_id=new.run_id and d.game_id=gid
        and d.sports_status=upper(c->>'sports_status') and d.execution_status=upper(c->>'execution_status')
        and d.process_status=upper(c->>'process_status') and coalesce(d.sports_verdict,'')=coalesce(upper(c->>'sports_verdict'),'')) then
        raise exception 'FINAL_REPORT_GAME_TRI_STATUS_MISMATCH:%',gid using errcode='23514'; end if;
      seen:=array_append(seen,gid);
    end loop;

    if sc=0 then
      if non_audit=0 then
        if upper(coalesce(new.payload #>> '{final_verdict,sports_decision_status}',''))<>'NO_PREGAME_OPPORTUNITY' then
          raise exception 'ZERO_SPORTS_CANDIDATES_ALL_AUDIT_ONLY_MUST_SAY_NO_PREGAME_OPPORTUNITY' using errcode='23514'; end if;
      elsif wl>0 then
        if upper(coalesce(new.payload #>> '{final_verdict,sports_decision_status}',''))<>'INCOMPLETE_NOT_ZERO' then
          raise exception 'ZERO_SPORTS_CANDIDATES_WITH_WATCHLIST_IS_FORBIDDEN_AS_FINAL_ZERO:%',wl using errcode='23514'; end if;
      else
        if np<>non_audit then raise exception 'ZERO_SPORTS_CANDIDATES_NOT_FULLY_EXPLAINED_BY_SPORTS_REJECTIONS:%/%',np,non_audit using errcode='23514'; end if;
        if upper(coalesce(new.payload #>> '{final_verdict,sports_decision_status}',''))<>'ZERO_SPORTS_CANDIDATES_BY_DATA' then
          raise exception 'ZERO_SPORTS_CANDIDATES_REQUIRES_DATA_DRIVEN_STATUS' using errcode='23514'; end if;
        if not (new.payload ? 'zero_candidate_burden') or jsonb_typeof(new.payload->'zero_candidate_burden')<>'array'
           or jsonb_array_length(new.payload->'zero_candidate_burden')<>np then
          raise exception 'ZERO_SPORTS_CANDIDATES_REQUIRES_ONE_DATA_BURDEN_PER_NO_PLAY:%',np using errcode='23514'; end if;
        seen:='{}';
        for c in select value from jsonb_array_elements(new.payload->'zero_candidate_burden') loop
          gid:=c->>'game_id';
          if coalesce(gid,'')='' or gid=any(seen) then raise exception 'ZERO_CANDIDATE_BURDEN_GAME_INVALID_OR_DUPLICATE:%',coalesce(gid,'NULL') using errcode='23514'; end if;
          if not exists(select 1 from public.nrfimetrica_game_dual_status d where d.run_id=new.run_id and d.game_id=gid and d.sports_status='NO_PLAY') then
            raise exception 'ZERO_CANDIDATE_BURDEN_GAME_NOT_SPORTS_NO_PLAY:%',gid using errcode='23514'; end if;
          if length(trim(coalesce(c->>'data_reason','')))<30 or length(trim(coalesce(c->>'nrfi_case_rejected_because','')))<30
             or length(trim(coalesce(c->>'yrfi_or_no_play_mechanism','')))<30 or length(trim(coalesce(c->>'what_would_reverse','')))<20 then
            raise exception 'ZERO_CANDIDATE_BURDEN_ARGUMENT_TOO_THIN:%',gid using errcode='23514'; end if;
          if jsonb_typeof(coalesce(c->'evidence_ids','[]'::jsonb))<>'array' or jsonb_array_length(coalesce(c->'evidence_ids','[]'::jsonb))=0 then
            raise exception 'ZERO_CANDIDATE_BURDEN_EVIDENCE_REQUIRED:%',gid using errcode='23514'; end if;
          for eid in select jsonb_array_elements_text(c->'evidence_ids') loop
            if not exists(select 1 from public.evidence e where e.evidence_id=eid and e.run_id=new.run_id and e.game_id=gid and upper(coalesce(e.evidence_scope,''))='SPORTS_REASONING') then
              raise exception 'ZERO_CANDIDATE_BURDEN_EVIDENCE_INVALID:%:%',gid,eid using errcode='23514'; end if;
          end loop;
          seen:=array_append(seen,gid);
        end loop;
      end if;
    else
      if upper(coalesce(new.payload #>> '{final_verdict,sports_decision_status}','')) in ('ZERO_SPORTS_CANDIDATES_BY_DATA','INCOMPLETE_NOT_ZERO') then
        raise exception 'SPORTS_CANDIDATES_EXIST_ZERO_STATUS_FORBIDDEN:%',sc using errcode='23514'; end if;
    end if;

    if declared_sc>0 and declared_ex=0 then
      if upper(coalesce(new.payload #>> '{final_verdict,execution_status}','')) not in ('TECHNICAL_BLOCK','PROCESS_BLOCK','MIXED_BLOCK') then
        raise exception 'SPORTS_CANDIDATES_WITH_ZERO_EXECUTABLE_MUST_REPORT_BLOCK' using errcode='23514'; end if;
      if upper(coalesce(new.payload #>> '{final_verdict,decision_basis}',''))<>'BLOCK_NOT_SPORTS_REJECTION' then
        raise exception 'FINAL_REPORT_MUST_DISTINGUISH_BLOCK_FROM_SPORTS_REJECTION' using errcode='23514'; end if;
    end if;
  end if;
  return new;
end $$;

-- Legacy A8 zero means zero executable candidates, not zero sports candidates.
do $$
declare f text;
begin
  select pg_get_functiondef(p.oid) into f from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='enforce_nrfimetrica_run_stage';
  if f is null then raise exception 'RUN_STAGE_FUNCTION_NOT_FOUND'; end if;
  f:=replace(f,
    'if candidates=0 and upper(coalesce(new.payload #>> ''{final_verdict,decision_final}'','''')) not in (''NO_HAY_PICK'',''NO HAY PICK'',''NO_PICK'',''0 PICKS'') then raise exception ''ZERO_CANDIDATE_FINAL_DECISION_MUST_SAY_NO_PICK'' using errcode=''23514''; end if;',
    'if candidates=0 then select count(*) into eligible from public.nrfimetrica_game_dual_status d where d.run_id=new.run_id and d.sports_status=''SPORTS_CANDIDATE''; if eligible>0 then if upper(coalesce(new.payload #>> ''{final_verdict,decision_final}'','''')) not in (''TECHNICAL_BLOCK'',''PROCESS_BLOCK'',''MIXED_BLOCK'',''NO_EXECUTION'') then raise exception ''ZERO_EXECUTION_CANDIDATES_MUST_NOT_ERASE_SPORTS_CANDIDATES:%'',eligible using errcode=''23514''; end if; else if upper(coalesce(new.payload #>> ''{final_verdict,decision_final}'','''')) not in (''NO_SPORTS_CANDIDATE_BY_DATA'',''SPORTS_DECISION_INCOMPLETE'',''NO_PREGAME_OPPORTUNITY'') then raise exception ''ZERO_SPORTS_CANDIDATE_WORDING_MUST_BE_DATA_OR_INCOMPLETE'' using errcode=''23514''; end if; end if; end if;'
  );
  execute f;
end $$;

update public.agent_registry
set agent_version='MOTHER-V3-AGENT-1.4',kernel_version='NRFIM-KERNEL-0.9-CAUSAL-AUTHORITY',
    metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object(
      'sports_judgment_process_execution_three_axes',true,
      'process_failure_may_erase_sports_verdict',false,
      'zero_sports_candidates_may_be_caused_by_process',false,
      'zero_sports_candidates_requires_data_burden',true,
      'database_migrations_required_through',29)
where agent_id='@NRFImetrica';
update public.system_versions set kernel_version='NRFIM-KERNEL-0.9-CAUSAL-AUTHORITY' where system_version='NRFIM MOTHER V3';