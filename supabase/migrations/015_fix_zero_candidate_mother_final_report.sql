-- A0-GOV.18 explicitly allows 0 candidates. The final report must therefore
-- accept an empty candidates array while still requiring all other report
-- blocks and exact slate/portfolio counts.

create or replace function public.enforce_nrfimetrica_run_stage()
returns trigger language plpgsql as $$
declare
  p text:='NRFIMETRICA_MOTHER_V3_AUTONOMOUS';
  total integer; covered integer; a1count integer; auditc integer; localc integer;
  eligible integer; resolved integer; researchc integer; candidates integer; arrn integer;
  c jsonb; gid text; line text; rankn integer; seen_ranks integer[]:='{}'; seen_games text[]:='{}'; cand jsonb;
  portfolio jsonb; a7stage jsonb;
begin
  if new.protocol_id<>p then return new; end if;
  if new.stage_id='A0_CONSTITUTION_SEALED' then
    if new.payload->>'mother_document_sha256'<>'d16896eba602af272117a5c83b56245aa201979d394301781d424e705b3642d3' then raise exception 'A0_MOTHER_HASH_MISMATCH' using errcode='23514'; end if;
    if lower(coalesce(new.payload->>'manual_phase_authorization_required','true')) not in ('false','0','no') then raise exception 'A0_AUTONOMOUS_ADAPTATION_NOT_ACTIVE' using errcode='23514'; end if;

  elsif new.stage_id='A1_SLATE_ROUTED' then
    select count(*) into total from public.games where run_id=new.run_id;
    select count(*) into a1count from public.games g where g.run_id=new.run_id and exists(select 1 from public.protocol_phase_state s where s.run_id=g.run_id and s.game_id=g.game_id and s.protocol_id=p and s.phase_id='A1_DATA_INTEGRITY_FREEZE');
    select count(*) into auditc from public.games where run_id=new.run_id and status='AUDIT_ONLY';
    select count(*) into localc from public.games where run_id=new.run_id and status='LOCAL_DATA_BLOCK';
    select count(*) into covered from public.games g where g.run_id=new.run_id and (
      g.status in ('AUDIT_ONLY','LOCAL_DATA_BLOCK')
      or exists(select 1 from public.protocol_phase_state s where s.run_id=g.run_id and s.game_id=g.game_id and s.protocol_id=p and s.phase_id='A1_DATA_INTEGRITY_FREEZE')
      or exists(select 1 from public.protocol_game_resolution r where r.run_id=g.run_id and r.game_id=g.game_id and r.protocol_id=p and r.terminal_phase='A1_DATA_INTEGRITY_FREEZE')
    );
    if covered<>total then raise exception 'A1_SLATE_NOT_FULLY_ROUTED:%/%',covered,total using errcode='23514'; end if;
    if coalesce((new.payload->>'total_games')::integer,-1)<>total or coalesce((new.payload->>'routed_games')::integer,-1)<>covered then raise exception 'A1_SLATE_COUNTS_MISMATCH' using errcode='23514'; end if;
    if coalesce((new.payload->>'a1_completed_count')::integer,-1)<>a1count or coalesce((new.payload->>'audit_only_count')::integer,-1)<>auditc or coalesce((new.payload->>'local_block_count')::integer,-1)<>localc then raise exception 'A1_SLATE_DETAIL_COUNTS_MISMATCH' using errcode='23514'; end if;

  elsif new.stage_id='A7_SLATE_ELIGIBILITY' then
    if not exists(select 1 from public.protocol_run_state x where x.run_id=new.run_id and x.protocol_id=p and x.stage_id='A1_SLATE_ROUTED' and x.status='COMPLETE') then raise exception 'A7_SLATE_REQUIRES_A1_SLATE_ROUTED' using errcode='23514'; end if;
    select count(*) into total from public.games where run_id=new.run_id;
    select count(*) into resolved from public.games g where g.run_id=new.run_id and (
      g.status in ('AUDIT_ONLY','LOCAL_DATA_BLOCK')
      or exists(select 1 from public.protocol_phase_state s where s.run_id=g.run_id and s.game_id=g.game_id and s.protocol_id=p and s.phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS')
      or exists(select 1 from public.protocol_game_resolution r where r.run_id=g.run_id and r.game_id=g.game_id and r.protocol_id=p)
    );
    if resolved<>total then raise exception 'A7_SLATE_HAS_UNRESOLVED_GAMES:%/%',resolved,total using errcode='23514'; end if;
    select count(*) into eligible from public.protocol_phase_state s where s.run_id=new.run_id and s.protocol_id=p and s.phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS' and upper(coalesce(s.payload->>'release_token',''))='ISSUED' and upper(coalesce(s.payload->>'absolute_eligibility','')) in ('A7_ELIGIBLE','A7_ELIGIBLE_CONDITIONED');
    select count(*) into researchc from public.protocol_game_resolution r where r.run_id=new.run_id and r.protocol_id=p and r.authority_level='RESEARCH_ONLY';
    if coalesce((new.payload->>'total_games')::integer,-1)<>total or coalesce((new.payload->>'resolved_games')::integer,-1)<>resolved or coalesce((new.payload->>'eligible_count')::integer,-1)<>eligible or coalesce((new.payload->>'research_only_count')::integer,-1)<>researchc then raise exception 'A7_SLATE_COUNTS_MISMATCH' using errcode='23514'; end if;

  elsif new.stage_id='A8_PORTFOLIO' then
    if not exists(select 1 from public.protocol_run_state x where x.run_id=new.run_id and x.protocol_id=p and x.stage_id='A7_SLATE_ELIGIBILITY' and x.status='COMPLETE') then raise exception 'A8_PORTFOLIO_REQUIRES_A7_SLATE_ELIGIBILITY' using errcode='23514'; end if;
    select count(*) into candidates from public.protocol_phase_state s where s.run_id=new.run_id and s.protocol_id=p and s.phase_id='A8_MARKET_VALUE_EXECUTION' and upper(coalesce(s.payload->>'final_verdict','')) in ('APOSTAR','SOLO_SI_CUOTA');
    if candidates>3 then raise exception 'PORTFOLIO_OVER_THREE_CANDIDATES' using errcode='23514'; end if;
    if coalesce((new.payload->>'candidate_count')::integer,-1)<>candidates then raise exception 'PORTFOLIO_CANDIDATE_COUNT_MISMATCH:%/%',(new.payload->>'candidate_count'),candidates using errcode='23514'; end if;
    if not (new.payload ? 'candidates') or jsonb_typeof(new.payload->'candidates')<>'array' then raise exception 'PORTFOLIO_CANDIDATE_INDEX_REQUIRED' using errcode='23514'; end if;
    arrn:=jsonb_array_length(new.payload->'candidates'); if arrn<>candidates then raise exception 'PORTFOLIO_CANDIDATE_INDEX_COUNT_MISMATCH' using errcode='23514'; end if;
    for c in select value from jsonb_array_elements(new.payload->'candidates') loop
      rankn:=(c->>'rank')::integer; gid:=c->>'game_id'; line:=upper(c->>'line');
      if rankn<1 or rankn>candidates or rankn=any(seen_ranks) then raise exception 'PORTFOLIO_RANK_INVALID_OR_DUPLICATE' using errcode='23514'; end if;
      if gid=any(seen_games) then raise exception 'PORTFOLIO_GAME_DUPLICATE:%',gid using errcode='23514'; end if;
      seen_ranks:=array_append(seen_ranks,rankn); seen_games:=array_append(seen_games,gid);
      select payload into cand from public.protocol_phase_state s where s.run_id=new.run_id and s.game_id=gid and s.protocol_id=p and s.phase_id='A8_MARKET_VALUE_EXECUTION';
      if not found or upper(coalesce(cand->>'final_verdict','')) not in ('APOSTAR','SOLO_SI_CUOTA') or upper(coalesce(cand->>'line_recommended',''))<>line then raise exception 'PORTFOLIO_CANDIDATE_NOT_BACKED_BY_A8:%',gid using errcode='23514'; end if;
    end loop;
    if candidates=0 then
      if not public.jsonb_path_nonempty(new.payload,'ticket_evaluations') then raise exception 'PORTFOLIO_TICKET_STATUS_REQUIRED' using errcode='23514'; end if;
    elsif candidates=1 then
      if upper(coalesce(new.payload #>> '{ticket_evaluations,status}',''))<>'NOT_APPLICABLE' then raise exception 'SINGLE_CANDIDATE_TICKETS_NOT_APPLICABLE' using errcode='23514'; end if;
    elsif candidates=2 then
      perform public.nrfim_validate_ticket(new.run_id,new.payload #> '{ticket_evaluations,double_primary}',2,false);
    elsif candidates=3 then
      perform public.nrfim_validate_ticket(new.run_id,new.payload #> '{ticket_evaluations,double_primary}',2,false);
      perform public.nrfim_validate_ticket(new.run_id,new.payload #> '{ticket_evaluations,double_secondary}',2,false);
      perform public.nrfim_validate_ticket(new.run_id,new.payload #> '{ticket_evaluations,double_alternative}',2,false);
      perform public.nrfim_validate_ticket(new.run_id,new.payload #> '{ticket_evaluations,triple_optional}',3,true);
    end if;

  elsif new.stage_id='FINAL_REPORT' then
    select payload into portfolio from public.protocol_run_state x where x.run_id=new.run_id and x.protocol_id=p and x.stage_id='A8_PORTFOLIO' and x.status='COMPLETE';
    select payload into a7stage from public.protocol_run_state x where x.run_id=new.run_id and x.protocol_id=p and x.stage_id='A7_SLATE_ELIGIBILITY' and x.status='COMPLETE';
    if portfolio is null then raise exception 'FINAL_REPORT_REQUIRES_A8_PORTFOLIO' using errcode='23514'; end if;
    foreach gid in array array['summary','tickets','final_verdict'] loop
      if not public.jsonb_path_nonempty(new.payload,gid) then raise exception 'FINAL_REPORT_REQUIRED_BLOCK_MISSING:%',gid using errcode='23514'; end if;
    end loop;
    if not (new.payload ? 'candidates') or jsonb_typeof(new.payload->'candidates')<>'array' then raise exception 'FINAL_REPORT_CANDIDATES_ARRAY_REQUIRED' using errcode='23514'; end if;
    candidates:=(portfolio->>'candidate_count')::integer;
    if jsonb_array_length(new.payload->'candidates')<>candidates then raise exception 'FINAL_REPORT_CANDIDATE_COUNT_MISMATCH' using errcode='23514'; end if;
    if new.payload->'tickets' is distinct from portfolio->'ticket_evaluations' then raise exception 'FINAL_REPORT_TICKETS_DO_NOT_MATCH_PORTFOLIO' using errcode='23514'; end if;
    if coalesce((new.payload #>> '{summary,total_games}')::integer,-1)<>coalesce((a7stage->>'total_games')::integer,-2)
       or coalesce((new.payload #>> '{summary,resolved_games}')::integer,-1)<>coalesce((a7stage->>'resolved_games')::integer,-2)
       or coalesce((new.payload #>> '{summary,candidate_count}')::integer,-1)<>candidates then
      raise exception 'FINAL_REPORT_SUMMARY_COUNTS_MISMATCH' using errcode='23514';
    end if;
    for c in select value from jsonb_array_elements(new.payload->'candidates') loop
      foreach gid in array array['rank','game_id','zero_run_thesis','p_nrfi_u0_5','p_exact1','p_exact2','p3plus','pre_press_verdict','nrfiprensa','contrast_effect','reformulated_verdict','line_recommended','current_price','minimum_acceptable_price','break_even','p_conservative','edge','ev','calibration_state','primary_reason','primary_risk','verdict'] loop
        if not public.jsonb_path_nonempty(c,gid) then raise exception 'FINAL_REPORT_CANDIDATE_FIELD_MISSING:%',gid using errcode='23514'; end if;
      end loop;
      select payload into cand from public.protocol_phase_state s where s.run_id=new.run_id and s.game_id=c->>'game_id' and s.protocol_id=p and s.phase_id='A8_MARKET_VALUE_EXECUTION';
      if not found then raise exception 'FINAL_REPORT_CANDIDATE_NOT_FOUND:%',c->>'game_id' using errcode='23514'; end if;
      if upper(c->>'line_recommended')<>upper(cand->>'line_recommended') then raise exception 'FINAL_REPORT_CANDIDATE_LINE_MISMATCH' using errcode='23514'; end if;
      if abs(public.nrfim_json_num(c,'p_nrfi_u0_5')-public.nrfim_json_num(cand,'probability.p0'))>0.000001 or abs(public.nrfim_json_num(c,'p_exact1')-public.nrfim_json_num(cand,'probability.p1'))>0.000001 or abs(public.nrfim_json_num(c,'p_exact2')-public.nrfim_json_num(cand,'probability.p2'))>0.000001 or abs(public.nrfim_json_num(c,'p3plus')-public.nrfim_json_num(cand,'probability.p3plus'))>0.000001 then raise exception 'FINAL_REPORT_PROBABILITY_MISMATCH:%',c->>'game_id' using errcode='23514'; end if;
    end loop;
    foreach gid in array array['pick_1','pick_2','pick_3','best_double','second_double','third_double','triple','motivo_central','riesgo_central','cuota_minima','decision_final'] loop
      if not public.jsonb_path_nonempty(new.payload->'final_verdict',gid) then raise exception 'FINAL_REPORT_FINAL_VERDICT_FIELD_MISSING:%',gid using errcode='23514'; end if;
    end loop;
    if candidates=0 and upper(coalesce(new.payload #>> '{final_verdict,decision_final}','')) not in ('NO_HAY_PICK','NO HAY PICK','NO_PICK','0 PICKS') then raise exception 'ZERO_CANDIDATE_FINAL_DECISION_MUST_SAY_NO_PICK' using errcode='23514'; end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_enforce_nrfimetrica_run_stage on public.protocol_run_state;
create trigger trg_enforce_nrfimetrica_run_stage before insert or update on public.protocol_run_state
for each row execute function public.enforce_nrfimetrica_run_stage();
