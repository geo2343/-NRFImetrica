-- @NRFImetrica Agent 1.11 / Kernel 1.6
-- Final hardening after adversarial regression.
-- Scope: @NRFImetrica only. Does not modify @NRFIprensa or Notion.

-- 1) Canonical causal-lineage assertions used by production guards.
create or replace function public.nrfimetrica_assert_a7_game_causal_lineage_v16(a7 jsonb,a5 jsonb)
returns void language plpgsql immutable set search_path=public,extensions,pg_temp as $$
declare p0 numeric; p1 numeric; p2 numeric;
begin
  p0:=public.nrfim_json_num(a5,'contracts.p_u0_5');
  p1:=public.nrfim_json_num(a5,'contracts.p_u1_5');
  p2:=public.nrfim_json_num(a5,'contracts.p_u2_5');
  if abs(public.nrfim_json_num(a7,'game_causal_p')-p0)>0.000001 then raise exception 'A7_GAME_CAUSAL_P_NOT_FROM_A5' using errcode='23514'; end if;
  if upper(coalesce(a7->>'game_probability_source',''))<>'A5_GAME_CAUSAL_ONLY' or upper(coalesce(a7->>'eligibility_basis',''))<>'GAME_CAUSAL_ONLY' then raise exception 'A7_GAME_PROBABILITY_AND_ELIGIBILITY_MUST_BE_CAUSAL_ONLY' using errcode='23514'; end if;
  if lower(coalesce(a7 #>> '{game_uncertainty,historical_calibration_used}','true')) not in ('false','0','no') then raise exception 'A7_GAME_UNCERTAINTY_CANNOT_USE_HISTORICAL_CALIBRATION' using errcode='23514'; end if;
  if upper(coalesce(a7 #>> '{game_uncertainty,u0_5,source}',''))<>'GAME_SPECIFIC_STRESS_TEST' or upper(coalesce(a7 #>> '{game_uncertainty,u1_5,source}',''))<>'GAME_SPECIFIC_STRESS_TEST' or upper(coalesce(a7 #>> '{game_uncertainty,u2_5,source}',''))<>'GAME_SPECIFIC_STRESS_TEST' then raise exception 'A7_CONSERVATIVE_BOUNDS_MUST_BE_GAME_SPECIFIC' using errcode='23514'; end if;
  if public.nrfim_json_num(a7,'game_uncertainty.u0_5.lower_bound')>p0 or public.nrfim_json_num(a7,'game_uncertainty.u1_5.lower_bound')>p1 or public.nrfim_json_num(a7,'game_uncertainty.u2_5.lower_bound')>p2 then raise exception 'A7_GAME_UNCERTAINTY_LOWER_BOUND_ABOVE_CENTRAL' using errcode='23514'; end if;
end; $$;

create or replace function public.nrfimetrica_assert_a8_lineage_v16(a8 jsonb,a7 jsonb)
returns void language plpgsql immutable set search_path=public,extensions,pg_temp as $$
declare line_key text; lb numeric; break_even numeric; decodds numeric; edge numeric; ev numeric;
begin
  if upper(coalesce(a7 #>> '{system_reliability,economic_effect}',''))='BLOCK' then raise exception 'A8_SYSTEM_RELIABILITY_BLOCKS_ECONOMIC_EXECUTION' using errcode='23514'; end if;
  if upper(coalesce(a8 #>> '{system_reliability,status}','')) is distinct from upper(coalesce(a7 #>> '{system_reliability,status}','')) then raise exception 'A8_SYSTEM_RELIABILITY_STATUS_LINEAGE_MISMATCH' using errcode='23514'; end if;
  if upper(coalesce(a8 #>> '{system_reliability,economic_effect}','')) is distinct from upper(coalesce(a7 #>> '{system_reliability,economic_effect}','')) then raise exception 'A8_SYSTEM_RELIABILITY_EFFECT_LINEAGE_MISMATCH' using errcode='23514'; end if;
  if lower(coalesce(a7 #>> '{press_integration,reanalysis_required}','false')) in ('true','1','yes') then raise exception 'A8_BLOCKED_PENDING_CAUSAL_REANALYSIS' using errcode='23514'; end if;
  line_key:=case upper(coalesce(a8->>'line_recommended','')) when 'NRFI' then 'u0_5' when 'U0.5' then 'u0_5' when 'U1.5' then 'u1_5' when 'U2.5' then 'u2_5' else null end;
  if line_key is null then raise exception 'A8_LINE_INVALID' using errcode='23514'; end if;
  if upper(coalesce(a8 #>> '{market,p_conservative_source}',''))<>'GAME_SPECIFIC_UNCERTAINTY_ONLY' then raise exception 'A8_P_CONSERVATIVE_SOURCE_MUST_BE_GAME_SPECIFIC' using errcode='23514'; end if;
  lb:=public.nrfim_json_num(a7,'game_uncertainty.'||line_key||'.lower_bound');
  if abs(public.nrfim_json_num(a8,'market.p_conservative')-lb)>0.000001 then raise exception 'A8_P_CONSERVATIVE_NOT_FROM_GAME_SPECIFIC_UNCERTAINTY' using errcode='23514'; end if;
  if abs(public.nrfim_json_num(a8,'game_specific_lower_bound')-lb)>0.000001 then raise exception 'A8_GAME_SPECIFIC_LOWER_BOUND_LINEAGE_MISMATCH' using errcode='23514'; end if;
  if a8 ? 'calibrated_p' or a8 ? 'historical_adjusted_p' then raise exception 'A8_HISTORICAL_GAME_PROBABILITY_OVERRIDE_FORBIDDEN' using errcode='23514'; end if;
  break_even:=public.nrfim_json_num(a8,'market.break_even'); decodds:=(a8 #>> '{market,decimal_odds}')::numeric; edge:=(a8 #>> '{market,edge}')::numeric; ev:=(a8 #>> '{market,ev}')::numeric;
  if decodds<=1 or abs(edge-(lb-break_even))>0.000001 or abs(ev-(lb*decodds-1))>0.000001 then raise exception 'A8_ROBUST_EDGE_MATH_FAIL' using errcode='23514'; end if;
end; $$;

create or replace function public.nrfimetrica_assert_a8_game_specific_execution_v16(a8 jsonb,a7 jsonb)
returns void language plpgsql immutable set search_path=public,extensions,pg_temp as $$
begin
  if upper(coalesce(a7->>'release_token',''))<>'ISSUED' or upper(coalesce(a8->>'a7_release_token',''))<>'ISSUED' then raise exception 'A8_RELEASE_BLOCKED' using errcode='23514'; end if;
  perform public.nrfimetrica_assert_a8_lineage_v16(a8,a7);
end; $$;

-- 2) Dormant V1.5 press/calibration guard cannot be accidentally reattached.
create or replace function public.nrfim_enforce_calibration_separation_v15()
returns trigger language plpgsql set search_path=public,extensions,pg_temp as $$
begin
  raise exception 'NRFIM_LEGACY_V15_CALIBRATION_PRESS_GUARD_DISABLED_USE_KERNEL_1_6' using errcode='23514';
end; $$;

-- 3) Future resolution codes cannot terminate a game because Prensa is unavailable or because a historical game-calibration certificate is absent.
create or replace function public.enforce_nrfimetrica_game_resolution()
returns trigger language plpgsql set search_path=public,extensions,pg_temp as $$
declare p text:='NRFIMETRICA_MOTHER_V3_AUTONOMOUS'; e text; gstatus text; start_at timestamptz; a7 jsonb;
begin
  if new.protocol_id<>p then return new; end if;
  if length(btrim(new.reason))<20 then raise exception 'RESOLUTION_REASON_TOO_SHORT' using errcode='23514'; end if;
  if length(btrim(new.materiality))<8 then raise exception 'RESOLUTION_MATERIALITY_REQUIRED' using errcode='23514'; end if;
  if length(btrim(new.what_would_resolve))<10 then raise exception 'RESOLUTION_REVERSAL_CONDITION_REQUIRED' using errcode='23514'; end if;
  if new.resolution_code not in ('A1_HOLD','A1_NOT_EXECUTABLE','A1_EXCLUDED','A1_GOVERNING_DATA_UNRESOLVED','A4_ENGINE_NOT_INTEGRATED','A4_TRUE_MODEL_FAILURE','A6_INDEPENDENT_AUDIT_UNAVAILABLE','A7_NOT_ELIGIBLE','A7_RESEARCH_ONLY','A7_MODEL_AUDIT_REQUIRED','A7_SYSTEM_RELIABILITY_BLOCK','A7_PRESS_INTEGRATION_UNRESOLVED','AUDIT_ONLY','LOCAL_DATA_BLOCK') then raise exception 'RESOLUTION_CODE_INVALID:%',new.resolution_code using errcode='23514'; end if;
  foreach e in array new.evidence_ids loop if not exists(select 1 from public.evidence x where x.evidence_id=e and x.run_id=new.run_id and (x.game_id is null or x.game_id=new.game_id) and coalesce(x.data_available_at,x.retrieved_at)<=new.created_at) then raise exception 'RESOLUTION_EVIDENCE_NOT_REAL_OR_TEMPORALLY_INVALID:%',e using errcode='23514'; end if; end loop;
  if new.recovery_issue_id is not null and not exists(select 1 from public.recoveries r where r.run_id=new.run_id and r.issue_id=new.recovery_issue_id and (r.game_id is null or r.game_id=new.game_id)) then raise exception 'RESOLUTION_RECOVERY_NOT_FOUND:%',new.recovery_issue_id using errcode='23514'; end if;
  if new.resolution_code='A1_GOVERNING_DATA_UNRESOLVED' and new.recovery_issue_id is null then raise exception 'A1_UNRESOLVED_GOVERNING_DATA_REQUIRES_RECOVERY' using errcode='23514'; end if;
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
  if new.resolution_code in ('A7_NOT_ELIGIBLE','A7_RESEARCH_ONLY','A7_MODEL_AUDIT_REQUIRED','A7_SYSTEM_RELIABILITY_BLOCK','A7_PRESS_INTEGRATION_UNRESOLVED') then
    select payload into a7 from public.protocol_phase_state s where s.run_id=new.run_id and s.game_id=new.game_id and s.protocol_id=p and s.phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS';
    if a7 is null then raise exception 'A7_RESOLUTION_REQUIRES_A7_STATE' using errcode='23514'; end if;
  end if;
  if new.resolution_code='A7_SYSTEM_RELIABILITY_BLOCK' and upper(coalesce(a7 #>> '{system_reliability,economic_effect}',''))<>'BLOCK' then raise exception 'A7_SYSTEM_RELIABILITY_BLOCK_REQUIRES_BLOCK_STATE' using errcode='23514'; end if;
  if new.resolution_code='A7_PRESS_INTEGRATION_UNRESOLVED' and lower(coalesce(a7 #>> '{press_integration,reanalysis_required}','false')) not in ('true','1','yes') then raise exception 'A7_PRESS_INTEGRATION_RESOLUTION_REQUIRES_REANALYSIS_STATE' using errcode='23514'; end if;
  return new;
end; $$;

-- 4) Remove direct post-seal Prensa dependencies from trusted-component guards.
create or replace function public.enforce_nrfimetrica_trusted_components()
returns trigger language plpgsql set search_path=public,extensions,pg_temp as $$
declare run_mode text; reg_status text; ex public.numeric_engine_executions%rowtype; audit_ex public.independent_audit_executions%rowtype; a4_status text; audit_status text;
begin
  if new.protocol_id<>'NRFIMETRICA_MOTHER_V3_AUTONOMOUS' then return new; end if;
  select mode into run_mode from public.runs where run_id=new.run_id;
  if new.phase_id='A4_NUMERIC_STATE_ENGINE' then
    select e.* into ex from public.numeric_engine_executions e where e.execution_id=new.payload #>> '{numeric_engine,execution_id}' limit 1;
    if not found or ex.run_id<>new.run_id or ex.game_id<>new.game_id or ex.provenance_status<>'PASS' then raise exception 'A4_TRUSTED_NUMERIC_EXECUTION_REQUIRED' using errcode='23514'; end if;
    select status into reg_status from public.numeric_engine_registry where engine_id=ex.engine_id; a4_status:=upper(coalesce(new.payload->>'a4_numeric_provenance_status',''));
    if run_mode='DIAGNOSTIC' then if reg_status not in ('DIAGNOSTIC_TRUSTED','ACTIVE_TRUSTED') then raise exception 'A4_NUMERIC_ENGINE_NOT_TRUSTED_FOR_DIAGNOSTIC:%',coalesce(reg_status,'NONE') using errcode='23514'; end if;
    elsif a4_status in ('A4_RESEARCH_READY_FULL','A4_RESEARCH_READY_REDUCED','A4_RESEARCH_READY_BOOTSTRAP','A4_RESEARCH_READY_HIGH_UNCERTAINTY') then if reg_status not in ('DIAGNOSTIC_TRUSTED','ACTIVE_TRUSTED') then raise exception 'A4_RESEARCH_ENGINE_NOT_TRUSTED:%',coalesce(reg_status,'NONE') using errcode='23514'; end if;
    else if reg_status is distinct from 'ACTIVE_TRUSTED' then raise exception 'A4_NUMERIC_ENGINE_NOT_ACTIVE_TRUSTED_FOR_EXECUTION:%',coalesce(reg_status,'NONE') using errcode='23514'; end if; end if;
    if ex.model_version is distinct from new.payload #>> '{numeric_engine,model_version}' or ex.transition_version is distinct from new.payload #>> '{numeric_engine,transition_version}' or ex.input_freeze_id is distinct from new.payload #>> '{numeric_engine,input_freeze_id}' then raise exception 'A4_TRUSTED_EXECUTION_METADATA_MISMATCH' using errcode='23514'; end if;
    if ex.executed_at>new.submitted_at then raise exception 'A4_NUMERIC_EXECUTION_FROM_FUTURE' using errcode='23514'; end if;
  elsif new.phase_id='A6_CAUSAL_FALSIFICATION_SPORTS_SEAL' then
    select a.* into audit_ex from public.independent_audit_executions a where a.audit_execution_id=new.payload #>> '{independent_audit,audit_execution_id}' limit 1;
    if not found or audit_ex.run_id<>new.run_id or audit_ex.game_id<>new.game_id then raise exception 'A6_TRUSTED_INDEPENDENT_AUDIT_EXECUTION_REQUIRED' using errcode='23514'; end if;
    select status into reg_status from public.independent_auditor_registry where auditor_id=audit_ex.auditor_id; audit_status:=upper(coalesce(new.payload #>> '{independent_audit,status}',''));
    if run_mode='DIAGNOSTIC' then if reg_status not in ('DIAGNOSTIC_TRUSTED','ACTIVE_TRUSTED') then raise exception 'A6_AUDITOR_NOT_TRUSTED_FOR_DIAGNOSTIC:%',coalesce(reg_status,'NONE') using errcode='23514'; end if;
    elsif audit_status='CONDITIONED' then if reg_status not in ('DIAGNOSTIC_TRUSTED','ACTIVE_TRUSTED') then raise exception 'A6_RESEARCH_AUDITOR_NOT_TRUSTED:%',coalesce(reg_status,'NONE') using errcode='23514'; end if;
    else if reg_status is distinct from 'ACTIVE_TRUSTED' then raise exception 'A6_AUDITOR_NOT_ACTIVE_TRUSTED_FOR_PASS:%',coalesce(reg_status,'NONE') using errcode='23514'; end if; end if;
    if audit_ex.auditor_id is distinct from new.payload #>> '{independent_audit,auditor_id}' or audit_ex.primary_analyst_id is distinct from new.payload->>'primary_analyst_id' or audit_ex.status not in ('PASS','CONDITIONED') then raise exception 'A6_TRUSTED_AUDIT_METADATA_MISMATCH' using errcode='23514'; end if;
    if audit_ex.executed_at>new.submitted_at then raise exception 'A6_AUDIT_EXECUTION_FROM_FUTURE' using errcode='23514'; end if;
  end if;
  return new;
end; $$;

-- 5) RLS + internal RPC lockdown for NRFImetrica-owned surfaces.
alter table public.nrfimetrica_postresult_audits enable row level security;
alter table public.nrfimetrica_recommendation_log enable row level security;
do $$ declare r record; begin
  for r in select c.oid::regclass::text as obj from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and c.relname like 'nrfimetrica_%' loop
    execute format('revoke all privileges on table %s from public, anon, authenticated',r.obj);
    execute format('grant select,insert,update,delete on table %s to service_role',r.obj);
  end loop;
end $$;
do $$ declare r record; begin
  for r in select p.oid::regprocedure::text as sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and (p.proname like 'nrfimetrica_%' or p.proname like 'nrfim_%' or p.proname like 'enforce_nrfimetrica_%' or p.proname in ('enforce_sports_reasoning_packet','freeze_terminal_sports_packet')) loop
    execute format('alter function %s set search_path = public, extensions, pg_temp',r.sig);
    execute format('revoke execute on function %s from public, anon, authenticated',r.sig);
    execute format('grant execute on function %s to service_role',r.sig);
  end loop;
end $$;

-- Explicit grants after function recreation.
revoke execute on function public.nrfimetrica_assert_a7_game_causal_lineage_v16(jsonb,jsonb) from public,anon,authenticated;
revoke execute on function public.nrfimetrica_assert_a8_lineage_v16(jsonb,jsonb) from public,anon,authenticated;
revoke execute on function public.nrfimetrica_assert_a8_game_specific_execution_v16(jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.nrfimetrica_assert_a7_game_causal_lineage_v16(jsonb,jsonb) to service_role;
grant execute on function public.nrfimetrica_assert_a8_lineage_v16(jsonb,jsonb) to service_role;
grant execute on function public.nrfimetrica_assert_a8_game_specific_execution_v16(jsonb,jsonb) to service_role;
