create or replace function public.enforce_nrfimetrica_dual_status_reporting()
returns trigger language plpgsql as $$
declare
  p text:='NRFIMETRICA_MOTHER_V3_AUTONOMOUS';
  sc integer; np integer; wl integer; ao integer; tb integer; ex integer; total integer;
  declared_sc integer; declared_ex integer; c jsonb; gid text; seen text[]:='{}'; actual_exec text; actual_verdict text;
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
    seen:='{}';
    for c in select value from jsonb_array_elements(new.payload->'sports_candidates') loop
      gid:=c->>'game_id';
      if coalesce(gid,'')='' or gid=any(seen) then raise exception 'FINAL_REPORT_SPORTS_CANDIDATE_ID_INVALID_OR_DUPLICATE:%',coalesce(gid,'NULL') using errcode='23514'; end if;
      select execution_status,sports_verdict into actual_exec,actual_verdict from public.nrfimetrica_game_dual_status d where d.run_id=new.run_id and d.game_id=gid and d.sports_status='SPORTS_CANDIDATE';
      if not found then raise exception 'FINAL_REPORT_FALSE_SPORTS_CANDIDATE:%',gid using errcode='23514'; end if;
      if upper(coalesce(c->>'sports_status',''))<>'SPORTS_CANDIDATE' or upper(coalesce(c->>'execution_status',''))<>actual_exec or upper(coalesce(c->>'sports_verdict',''))<>actual_verdict then
        raise exception 'FINAL_REPORT_SPORTS_CANDIDATE_STATE_MISMATCH:%',gid using errcode='23514';
      end if;
      seen:=array_append(seen,gid);
    end loop;
    if not (new.payload ? 'game_statuses') or jsonb_typeof(new.payload->'game_statuses')<>'array' or jsonb_array_length(new.payload->'game_statuses')<>total then
      raise exception 'FINAL_REPORT_EXACT_GAME_STATUS_ARRAY_REQUIRED:%',total using errcode='23514';
    end if;
    seen:='{}';
    for c in select value from jsonb_array_elements(new.payload->'game_statuses') loop
      gid:=c->>'game_id';
      if coalesce(gid,'')='' or gid=any(seen) then raise exception 'FINAL_REPORT_GAME_STATUS_ID_INVALID_OR_DUPLICATE:%',coalesce(gid,'NULL') using errcode='23514'; end if;
      if not exists(select 1 from public.nrfimetrica_game_dual_status d where d.run_id=new.run_id and d.game_id=gid and d.sports_status=upper(c->>'sports_status') and d.execution_status=upper(c->>'execution_status') and coalesce(d.sports_verdict,'')=coalesce(upper(c->>'sports_verdict'),'')) then
        raise exception 'FINAL_REPORT_GAME_DUAL_STATUS_MISMATCH:%',gid using errcode='23514';
      end if;
      seen:=array_append(seen,gid);
    end loop;
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

update public.agent_registry
set metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('dual_status_exact_identity_enforced',true,'final_report_all_game_statuses_required',true,'database_migrations_required_through',27)
where agent_id='@NRFImetrica';