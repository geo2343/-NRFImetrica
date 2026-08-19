-- Whole-slate, terminal-resolution, portfolio/ticket, and final-report enforcement
-- for @NRFImetrica mother protocol.

create table if not exists public.protocol_game_resolution (
  id uuid primary key default gen_random_uuid(),
  run_id text not null references public.runs(run_id) on delete cascade,
  game_id text not null,
  protocol_id text not null,
  terminal_phase text not null,
  resolution_code text not null,
  authority_level text not null check (authority_level in ('RESEARCH_ONLY','NON_EXECUTABLE','AUDIT_ONLY')),
  reason text not null,
  materiality text not null,
  what_would_resolve text not null,
  recovery_issue_id text,
  evidence_ids text[] not null default '{}',
  created_at timestamptz not null default now(),
  unique(run_id,game_id,protocol_id),
  foreign key(run_id,game_id) references public.games(run_id,game_id) on delete cascade
);
alter table public.protocol_game_resolution enable row level security;

create or replace function public.enforce_nrfimetrica_game_resolution()
returns trigger language plpgsql as $$
declare
  p text:='NRFIMETRICA_MOTHER_V3_AUTONOMOUS';
  e text; gstatus text; start_at timestamptz;
begin
  if new.protocol_id<>p then return new; end if;
  if length(btrim(new.reason))<20 then raise exception 'RESOLUTION_REASON_TOO_SHORT' using errcode='23514'; end if;
  if length(btrim(new.materiality))<8 then raise exception 'RESOLUTION_MATERIALITY_REQUIRED' using errcode='23514'; end if;
  if length(btrim(new.what_would_resolve))<10 then raise exception 'RESOLUTION_REVERSAL_CONDITION_REQUIRED' using errcode='23514'; end if;
  if new.resolution_code not in (
    'A1_HOLD','A1_NOT_EXECUTABLE','A1_EXCLUDED','A1_GOVERNING_DATA_UNRESOLVED',
    'A4_ENGINE_NOT_INTEGRATED','A4_TRUE_MODEL_FAILURE',
    'A6_INDEPENDENT_AUDIT_UNAVAILABLE',
    'A7_NOT_ELIGIBLE','A7_RESEARCH_ONLY','A7_CALIBRATION_UNCERTIFIED','A7_MODEL_AUDIT_REQUIRED','A7_PRESS_UNAVAILABLE',
    'AUDIT_ONLY','LOCAL_DATA_BLOCK'
  ) then raise exception 'RESOLUTION_CODE_INVALID:%',new.resolution_code using errcode='23514'; end if;

  foreach e in array new.evidence_ids loop
    if not exists(select 1 from public.evidence x where x.evidence_id=e and x.run_id=new.run_id and (x.game_id is null or x.game_id=new.game_id) and coalesce(x.data_available_at,x.retrieved_at)<=new.created_at) then
      raise exception 'RESOLUTION_EVIDENCE_NOT_REAL_OR_TEMPORALLY_INVALID:%',e using errcode='23514';
    end if;
  end loop;

  if new.recovery_issue_id is not null and not exists(select 1 from public.recoveries r where r.run_id=new.run_id and r.issue_id=new.recovery_issue_id and (r.game_id is null or r.game_id=new.game_id)) then
    raise exception 'RESOLUTION_RECOVERY_NOT_FOUND:%',new.recovery_issue_id using errcode='23514';
  end if;
  if new.resolution_code='A1_GOVERNING_DATA_UNRESOLVED' and new.recovery_issue_id is null then
    raise exception 'A1_UNRESOLVED_GOVERNING_DATA_REQUIRES_RECOVERY' using errcode='23514';
  end if;

  select status,scheduled_start into gstatus,start_at from public.games where run_id=new.run_id and game_id=new.game_id;
  if new.resolution_code='AUDIT_ONLY' and gstatus<>'AUDIT_ONLY' then raise exception 'AUDIT_ONLY_RESOLUTION_STATUS_MISMATCH' using errcode='23514'; end if;
  if new.resolution_code='LOCAL_DATA_BLOCK' and gstatus<>'LOCAL_DATA_BLOCK' then raise exception 'LOCAL_BLOCK_RESOLUTION_STATUS_MISMATCH' using errcode='23514'; end if;
  if new.resolution_code='A4_ENGINE_NOT_INTEGRATED' then
    if new.terminal_phase<>'A4_NUMERIC_STATE_ENGINE' then raise exception 'A4_ENGINE_BLOCK_PHASE_MISMATCH' using errcode='23514'; end if;
    if not exists(select 1 from public.protocol_phase_state s where s.run_id=new.run_id and s.game_id=new.game_id and s.protocol_id=p and s.phase_id='A3_CURRENT_VERSION_MATCHUP') then raise exception 'A4_ENGINE_BLOCK_REQUIRES_A3' using errcode='23514'; end if;
    if exists(select 1 from public.numeric_engine_registry where status='ACTIVE_TRUSTED') then raise exception 'A4_ENGINE_NOT_INTEGRATED_CANNOT_BE_USED_WHEN_TRUSTED_ENGINE_EXISTS' using errcode='23514'; end if;
  end if;
  if new.resolution_code='A6_INDEPENDENT_AUDIT_UNAVAILABLE' then
    if not exists(select 1 from public.protocol_phase_state s where s.run_id=new.run_id and s.game_id=new.game_id and s.protocol_id=p and s.phase_id='A5_JOINT_INTEGRATION') then raise exception 'A6_AUDIT_BLOCK_REQUIRES_A5' using errcode='23514'; end if;
    if exists(select 1 from public.independent_auditor_registry where status='ACTIVE_TRUSTED') then raise exception 'A6_AUDITOR_UNAVAILABLE_CANNOT_BE_USED_WHEN_TRUSTED_AUDITOR_EXISTS' using errcode='23514'; end if;
  end if;
  if new.resolution_code in ('A7_NOT_ELIGIBLE','A7_RESEARCH_ONLY','A7_CALIBRATION_UNCERTIFIED','A7_MODEL_AUDIT_REQUIRED') then
    if not exists(select 1 from public.protocol_phase_state s where s.run_id=new.run_id and s.game_id=new.game_id and s.protocol_id=p and s.phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS') then raise exception 'A7_RESOLUTION_REQUIRES_A7_STATE' using errcode='23514'; end if;
  end if;
  if new.resolution_code='A7_PRESS_UNAVAILABLE' then
    if start_at is not null and new.created_at < start_at-interval '10 minutes' then raise exception 'A7_PRESS_UNAVAILABLE_CANNOT_TERMINATE_BEFORE_T10' using errcode='23514'; end if;
    if exists(select 1 from public.nrfiprensa_packets n where n.run_id=new.run_id and n.game_id=new.game_id and n.status='VERIFIED') then raise exception 'A7_PRESS_UNAVAILABLE_FALSE_WHEN_VERIFIED_PACKET_EXISTS' using errcode='23514'; end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_enforce_nrfimetrica_game_resolution on public.protocol_game_resolution;
create trigger trg_enforce_nrfimetrica_game_resolution before insert or update on public.protocol_game_resolution
for each row execute function public.enforce_nrfimetrica_game_resolution();

create or replace function public.nrfim_validate_ticket(p_run text, ticket jsonb, expected_size integer, allow_not_recommended boolean)
returns void language plpgsql as $$
declare
  st text; sels jsonb; sel jsonb; n integer; seen text[]:='{}'; gid text; line text; cand jsonb;
  product_p numeric:=1; pbase numeric; pcons numeric; odds numeric; be numeric; edge numeric; ev numeric;
  corr text; method text; verdict text;
begin
  st:=upper(coalesce(ticket->>'status',''));
  if st='NOT_RECOMMENDED' and allow_not_recommended then
    if length(btrim(coalesce(ticket->>'reason','')))<12 then raise exception 'TICKET_NOT_RECOMMENDED_REQUIRES_REASON' using errcode='23514'; end if;
    return;
  end if;
  if st<>'EVALUATED' then raise exception 'TICKET_MUST_BE_EVALUATED' using errcode='23514'; end if;
  sels:=ticket->'selections';
  if jsonb_typeof(sels)<>'array' then raise exception 'TICKET_SELECTIONS_MUST_BE_ARRAY' using errcode='23514'; end if;
  n:=jsonb_array_length(sels); if n<>expected_size then raise exception 'TICKET_SELECTION_COUNT_MISMATCH:%/%',n,expected_size using errcode='23514'; end if;
  for sel in select value from jsonb_array_elements(sels) loop
    gid:=btrim(coalesce(sel->>'game_id','')); line:=upper(btrim(coalesce(sel->>'line','')));
    if gid='' or line='' then raise exception 'TICKET_COMPONENT_IDENTITY_MISSING' using errcode='23514'; end if;
    if gid=any(seen) then raise exception 'TICKET_DUPLICATE_COMPONENT:%',gid using errcode='23514'; end if; seen:=array_append(seen,gid);
    select payload into cand from public.protocol_phase_state s where s.run_id=p_run and s.game_id=gid and s.protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and s.phase_id='A8_MARKET_VALUE_EXECUTION';
    if not found or upper(coalesce(cand->>'final_verdict','')) not in ('APOSTAR','SOLO_SI_CUOTA') then raise exception 'TICKET_COMPONENT_NOT_APPROVED:%',gid using errcode='23514'; end if;
    if upper(coalesce(cand->>'line_recommended',''))<>line then raise exception 'TICKET_COMPONENT_LINE_MISMATCH:%',gid using errcode='23514'; end if;
    product_p:=product_p*public.nrfim_json_num(cand,'market.p_conservative');
  end loop;
  if lower(coalesce(ticket->>'price_is_real_offered','false')) not in ('true','1','yes') then raise exception 'TICKET_REQUIRES_REAL_OFFERED_PRICE' using errcode='23514'; end if;
  if length(btrim(coalesce(ticket->>'price_source','')))<2 or length(btrim(coalesce(ticket->>'price_as_of','')))<8 then raise exception 'TICKET_PRICE_PROVENANCE_REQUIRED' using errcode='23514'; end if;
  odds:=(ticket->>'decimal_odds')::numeric; if odds<=1 then raise exception 'TICKET_DECIMAL_ODDS_INVALID' using errcode='23514'; end if;
  pbase:=public.nrfim_json_num(ticket,'p_joint_base'); pcons:=public.nrfim_json_num(ticket,'p_joint_conservative');
  be:=public.nrfim_json_num(ticket,'break_even'); edge:=(ticket->>'edge')::numeric; ev:=(ticket->>'ev')::numeric;
  if abs(be-(1/odds))>0.000001 then raise exception 'TICKET_BREAK_EVEN_MATH_FAIL' using errcode='23514'; end if;
  if abs(edge-(pcons-be))>0.000001 then raise exception 'TICKET_EDGE_MATH_FAIL' using errcode='23514'; end if;
  if abs(ev-(pcons*odds-1))>0.000001 then raise exception 'TICKET_EV_MATH_FAIL' using errcode='23514'; end if;
  corr:=upper(coalesce(ticket->>'correlation_status','')); method:=upper(coalesce(ticket->>'joint_method',''));
  if corr='INDEPENDENT_JUSTIFIED' then
    if abs(pbase-product_p)>0.000001 then raise exception 'TICKET_INDEPENDENT_PRODUCT_MATH_FAIL' using errcode='23514'; end if;
  elsif corr='MATERIAL_DEPENDENCE' then
    if method not in ('JOINT_SIMULATION','CONSERVATIVE_ADJUSTMENT') then raise exception 'TICKET_DEPENDENCE_REQUIRES_JOINT_METHOD' using errcode='23514'; end if;
    if not public.jsonb_path_nonempty(ticket,'joint_evidence') then raise exception 'TICKET_DEPENDENCE_REQUIRES_EVIDENCE' using errcode='23514'; end if;
  else raise exception 'TICKET_CORRELATION_STATUS_INVALID' using errcode='23514'; end if;
  verdict:=upper(coalesce(ticket->>'verdict',''));
  if verdict='APOSTAR' and (edge<=0 or ev<=0) then raise exception 'TICKET_NONPOSITIVE_EDGE_OR_EV_NO_BET' using errcode='23514'; end if;
  if verdict not in ('APOSTAR','NO_APOSTAR','SOLO_SI_CUOTA') then raise exception 'TICKET_VERDICT_INVALID' using errcode='23514'; end if;
end $$;

create or replace function public.enforce_nrfimetrica_run_stage()
returns trigger language plpgsql as $$
declare
  p text:='NRFIMETRICA_MOTHER_V3_AUTONOMOUS';
  total integer; covered integer; a1count integer; auditc integer; localc integer;
  eligible integer; resolved integer; researchc integer; candidates integer; arrn integer;
  c jsonb; gid text; line text; rankn integer; seen_ranks integer[]:='{}'; seen_games text[]:='{}'; cand jsonb;
  portfolio jsonb;
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
    if portfolio is null then raise exception 'FINAL_REPORT_REQUIRES_A8_PORTFOLIO' using errcode='23514'; end if;
    foreach gid in array array['summary','candidates','tickets','final_verdict'] loop
      if not public.jsonb_path_nonempty(new.payload,gid) then raise exception 'FINAL_REPORT_REQUIRED_BLOCK_MISSING:%',gid using errcode='23514'; end if;
    end loop;
    candidates:=(portfolio->>'candidate_count')::integer;
    if jsonb_typeof(new.payload->'candidates')<>'array' or jsonb_array_length(new.payload->'candidates')<>candidates then raise exception 'FINAL_REPORT_CANDIDATE_COUNT_MISMATCH' using errcode='23514'; end if;
    if new.payload->'tickets' is distinct from portfolio->'ticket_evaluations' then raise exception 'FINAL_REPORT_TICKETS_DO_NOT_MATCH_PORTFOLIO' using errcode='23514'; end if;
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

create or replace function public.require_final_report_before_close()
returns trigger language plpgsql as $$
begin
  if new.status='CLOSED' and old.status is distinct from 'CLOSED' and coalesce(new.mode,'')<>'DIAGNOSTIC' then
    if new.system_version='NRFIM MOTHER V3' then
      if not exists(select 1 from public.protocol_run_state rs where rs.run_id=new.run_id and rs.protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and rs.stage_id='FINAL_REPORT' and rs.status='COMPLETE') then
        raise exception 'MOTHER_FINAL_REPORT_GATE_INCOMPLETE' using errcode='23514';
      end if;
    elsif not exists(select 1 from public.run_report_state r where r.run_id=new.run_id and r.status='COMPLETE') then
      raise exception 'FINAL_REPORT_GATE_INCOMPLETE' using errcode='23514';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_require_final_report_before_close on public.runs;
create trigger trg_require_final_report_before_close before update on public.runs
for each row execute function public.require_final_report_before_close();
