-- @NRFImetrica Agent 1.11 / Kernel 1.6
-- Canonicalizes hardening that had been split across live hotfixes and a duplicate 062 file.
-- Scope: @NRFImetrica only. Does not modify @NRFIprensa or Notion.

update public.agent_registry
set status='DISABLED',
    metadata=(coalesce(metadata,'{}'::jsonb)-'database_migrations_required_through'-'github_migrations_through'-'github_parity_state'-'terminal_validation_state'-'refactor_state')
      || jsonb_build_object(
        'database_migrations_required_through',67,
        'github_migrations_through',67,
        'github_parity_state','MIGRATION_067_CANONICALIZED_PENDING_REAUDIT',
        'terminal_validation_state','POST_067_AUDIT_PENDING',
        'refactor_state','DISABLED_FOR_POST_067_REAUDIT',
        'notion_role','CONSULTATION_ONLY_NO_WRITE_AUTHORITY',
        'nrfiprensa_write_scope','NONE',
        'receiver_side_only',true
      ),
    updated_at=now()
where agent_id='@NRFImetrica';

create or replace function public.enforce_nrfimetrica_game_resolution()
returns trigger
language plpgsql
set search_path=public,extensions,pg_temp
as $$
declare
  p text:='NRFIMETRICA_MOTHER_V3_AUTONOMOUS';
  e text; gstatus text; start_at timestamptz; a7 jsonb;
begin
  if new.protocol_id<>p then return new; end if;
  if length(btrim(new.reason))<20 then raise exception 'RESOLUTION_REASON_TOO_SHORT' using errcode='23514'; end if;
  if length(btrim(new.materiality))<8 then raise exception 'RESOLUTION_MATERIALITY_REQUIRED' using errcode='23514'; end if;
  if length(btrim(new.what_would_resolve))<10 then raise exception 'RESOLUTION_REVERSAL_CONDITION_REQUIRED' using errcode='23514'; end if;
  if new.resolution_code not in (
    'A1_HOLD','A1_NOT_EXECUTABLE','A1_EXCLUDED','A1_GOVERNING_DATA_UNRESOLVED',
    'A4_ENGINE_NOT_INTEGRATED','A4_TRUE_MODEL_FAILURE',
    'A6_INDEPENDENT_AUDIT_UNAVAILABLE',
    'A7_NOT_ELIGIBLE','A7_RESEARCH_ONLY','A7_MODEL_AUDIT_REQUIRED','A7_SYSTEM_RELIABILITY_BLOCK','A7_PRESS_INTEGRATION_UNRESOLVED',
    'AUDIT_ONLY','LOCAL_DATA_BLOCK'
  ) then raise exception 'RESOLUTION_CODE_INVALID:%',new.resolution_code using errcode='23514'; end if;
  foreach e in array new.evidence_ids loop
    if not exists(select 1 from public.evidence x where x.evidence_id=e and x.run_id=new.run_id and (x.game_id is null or x.game_id=new.game_id) and coalesce(x.data_available_at,x.retrieved_at)<=new.created_at) then raise exception 'RESOLUTION_EVIDENCE_NOT_REAL_OR_TEMPORALLY_INVALID:%',e using errcode='23514'; end if;
  end loop;
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
end;
$$;

create or replace function public.enforce_nrfimetrica_trusted_components()
returns trigger
language plpgsql
set search_path=public,extensions,pg_temp
as $$
declare
  run_mode text; reg_status text;
  ex public.numeric_engine_executions%rowtype;
  audit_ex public.independent_audit_executions%rowtype;
  a4_status text; audit_status text;
begin
  if new.protocol_id<>'NRFIMETRICA_MOTHER_V3_AUTONOMOUS' then return new; end if;
  select mode into run_mode from public.runs where run_id=new.run_id;
  if new.phase_id='A4_NUMERIC_STATE_ENGINE' then
    select e.* into ex from public.numeric_engine_executions e where e.execution_id=new.payload #>> '{numeric_engine,execution_id}' limit 1;
    if not found or ex.run_id<>new.run_id or ex.game_id<>new.game_id or ex.provenance_status<>'PASS' then raise exception 'A4_TRUSTED_NUMERIC_EXECUTION_REQUIRED' using errcode='23514'; end if;
    select status into reg_status from public.numeric_engine_registry where engine_id=ex.engine_id;
    a4_status:=upper(coalesce(new.payload->>'a4_numeric_provenance_status',''));
    if run_mode='DIAGNOSTIC' then
      if reg_status not in ('DIAGNOSTIC_TRUSTED','ACTIVE_TRUSTED') then raise exception 'A4_NUMERIC_ENGINE_NOT_TRUSTED_FOR_DIAGNOSTIC:%',coalesce(reg_status,'NONE') using errcode='23514'; end if;
    elsif a4_status in ('A4_RESEARCH_READY_FULL','A4_RESEARCH_READY_REDUCED','A4_RESEARCH_READY_BOOTSTRAP','A4_RESEARCH_READY_HIGH_UNCERTAINTY') then
      if reg_status not in ('DIAGNOSTIC_TRUSTED','ACTIVE_TRUSTED') then raise exception 'A4_RESEARCH_ENGINE_NOT_TRUSTED:%',coalesce(reg_status,'NONE') using errcode='23514'; end if;
    else
      if reg_status is distinct from 'ACTIVE_TRUSTED' then raise exception 'A4_NUMERIC_ENGINE_NOT_ACTIVE_TRUSTED_FOR_EXECUTION:%',coalesce(reg_status,'NONE') using errcode='23514'; end if;
    end if;
    if ex.model_version is distinct from new.payload #>> '{numeric_engine,model_version}' or ex.transition_version is distinct from new.payload #>> '{numeric_engine,transition_version}' or ex.input_freeze_id is distinct from new.payload #>> '{numeric_engine,input_freeze_id}' then raise exception 'A4_TRUSTED_EXECUTION_METADATA_MISMATCH' using errcode='23514'; end if;
    if ex.executed_at>new.submitted_at then raise exception 'A4_NUMERIC_EXECUTION_FROM_FUTURE' using errcode='23514'; end if;
  elsif new.phase_id='A6_CAUSAL_FALSIFICATION_SPORTS_SEAL' then
    select a.* into audit_ex from public.independent_audit_executions a where a.audit_execution_id=new.payload #>> '{independent_audit,audit_execution_id}' limit 1;
    if not found or audit_ex.run_id<>new.run_id or audit_ex.game_id<>new.game_id then raise exception 'A6_TRUSTED_INDEPENDENT_AUDIT_EXECUTION_REQUIRED' using errcode='23514'; end if;
    select status into reg_status from public.independent_auditor_registry where auditor_id=audit_ex.auditor_id;
    audit_status:=upper(coalesce(new.payload #>> '{independent_audit,status}',''));
    if run_mode='DIAGNOSTIC' then
      if reg_status not in ('DIAGNOSTIC_TRUSTED','ACTIVE_TRUSTED') then raise exception 'A6_AUDITOR_NOT_TRUSTED_FOR_DIAGNOSTIC:%',coalesce(reg_status,'NONE') using errcode='23514'; end if;
    elsif audit_status='CONDITIONED' then
      if reg_status not in ('DIAGNOSTIC_TRUSTED','ACTIVE_TRUSTED') then raise exception 'A6_RESEARCH_AUDITOR_NOT_TRUSTED:%',coalesce(reg_status,'NONE') using errcode='23514'; end if;
    else
      if reg_status is distinct from 'ACTIVE_TRUSTED' then raise exception 'A6_AUDITOR_NOT_ACTIVE_TRUSTED_FOR_PASS:%',coalesce(reg_status,'NONE') using errcode='23514'; end if;
    end if;
    if audit_ex.auditor_id is distinct from new.payload #>> '{independent_audit,auditor_id}' or audit_ex.primary_analyst_id is distinct from new.payload->>'primary_analyst_id' or audit_ex.status not in ('PASS','CONDITIONED') then raise exception 'A6_TRUSTED_AUDIT_METADATA_MISMATCH' using errcode='23514'; end if;
    if audit_ex.executed_at>new.submitted_at then raise exception 'A6_AUDIT_EXECUTION_FROM_FUTURE' using errcode='23514'; end if;
  end if;
  return new;
end;
$$;

create or replace function public.enforce_nrfimetrica_trusted_artifacts_v2()
returns trigger
language plpgsql
set search_path=public,extensions,pg_temp
as $$
declare
  p text:='NRFIMETRICA_MOTHER_V3_AUTONOMOUS';
  run_mode text; ex public.numeric_engine_executions%rowtype; aud public.independent_audit_executions%rowtype;
  sra public.sra_packets%rowtype; offer public.market_offers%rowtype; t5 public.t5_revalidations%rowtype; a5 jsonb;
  eid text; market_odds numeric; market_asof timestamptz;
begin
  if new.protocol_id<>p then return new; end if;
  select mode into run_mode from public.runs where run_id=new.run_id;
  if new.phase_id='A4_NUMERIC_STATE_ENGINE' then
    select * into ex from public.numeric_engine_executions where execution_id=new.payload #>> '{numeric_engine,execution_id}';
    if not found then raise exception 'A4_TRUSTED_NUMERIC_EXECUTION_REQUIRED' using errcode='23514'; end if;
    if ex.output_hash<>encode(digest(ex.output_payload::text,'sha256'),'hex') then raise exception 'A4_NUMERIC_OUTPUT_HASH_INVALID' using errcode='23514'; end if;
    if ex.output_payload->'top' is distinct from new.payload->'top' or ex.output_payload->'bottom' is distinct from new.payload->'bottom' then raise exception 'A4_PHASE_OUTPUT_DIFFERS_FROM_ENGINE_OUTPUT' using errcode='23514'; end if;
  elsif new.phase_id='A6_CAUSAL_FALSIFICATION_SPORTS_SEAL' then
    select * into aud from public.independent_audit_executions where audit_execution_id=new.payload #>> '{independent_audit,audit_execution_id}';
    if not found then raise exception 'A6_TRUSTED_INDEPENDENT_AUDIT_EXECUTION_REQUIRED' using errcode='23514'; end if;
    if aud.output_hash<>encode(digest(aud.payload::text,'sha256'),'hex') then raise exception 'A6_AUDIT_OUTPUT_HASH_INVALID' using errcode='23514'; end if;
    if coalesce(aud.payload->>'central_case','') is distinct from coalesce(new.payload #>> '{independent_audit,central_case}','') or coalesce(aud.payload->>'best_yrfi_rival','') is distinct from coalesce(new.payload #>> '{independent_audit,best_yrfi_rival}','') or coalesce(aud.payload->>'divergence_class','') is distinct from coalesce(new.payload #>> '{independent_audit,divergence_class}','') or upper(coalesce(aud.payload->>'status','')) is distinct from upper(coalesce(new.payload #>> '{independent_audit,status}','')) then raise exception 'A6_PHASE_AUDIT_DIFFERS_FROM_AUDITOR_OUTPUT' using errcode='23514'; end if;
    select * into sra from public.sra_packets where packet_id=new.payload #>> '{sra,packet_id}';
    if not found or sra.run_id<>new.run_id or sra.game_id<>new.game_id then raise exception 'A6_SRA_PACKET_REQUIRED' using errcode='23514'; end if;
    if sra.content_hash<>encode(digest(sra.payload::text,'sha256'),'hex') or sra.content_hash is distinct from new.payload #>> '{sra,packet_hash}' then raise exception 'A6_SRA_PACKET_HASH_MISMATCH' using errcode='23514'; end if;
    if run_mode='DIAGNOSTIC' then
      if sra.status<>'DIAGNOSTIC_COMPLETE' then raise exception 'A6_SRA_NOT_DIAGNOSTIC_COMPLETE' using errcode='23514'; end if;
    else
      if sra.status not in ('COMPLETE','DATA_UNAVAILABLE') then raise exception 'A6_SRA_NOT_COMPLETE' using errcode='23514'; end if;
    end if;
    if sra.generated_at>new.submitted_at then raise exception 'A6_SRA_PACKET_FROM_FUTURE' using errcode='23514'; end if;
    if coalesce(sra.payload->>'team_packet_status','') is distinct from coalesce(new.payload #>> '{sra,team_packet_status}','') or coalesce(sra.payload->>'b1_b4_packet_status','') is distinct from coalesce(new.payload #>> '{sra,b1_b4_packet_status}','') then raise exception 'A6_PHASE_SRA_DIFFERS_FROM_PACKET' using errcode='23514'; end if;
  elsif new.phase_id='A8_MARKET_VALUE_EXECUTION' then
    select payload into a5 from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=p and phase_id='A5_JOINT_INTEGRATION';
    if new.payload->'probability' is distinct from a5->'joint' then raise exception 'A8_DISPLAYED_DISTRIBUTION_NOT_FROM_A5' using errcode='23514'; end if;
    select * into offer from public.market_offers where offer_id=new.payload #>> '{market,offer_id}';
    if not found or offer.run_id<>new.run_id or offer.game_id<>new.game_id then raise exception 'A8_VERIFIED_MARKET_OFFER_REQUIRED' using errcode='23514'; end if;
    if run_mode='DIAGNOSTIC' then
      if offer.status<>'DIAGNOSTIC_VERIFIED' then raise exception 'A8_MARKET_OFFER_NOT_DIAGNOSTIC_VERIFIED' using errcode='23514'; end if;
    else
      if offer.status<>'VERIFIED' then raise exception 'A8_MARKET_OFFER_NOT_VERIFIED' using errcode='23514'; end if;
    end if;
    begin market_odds:=(new.payload #>> '{market,decimal_odds}')::numeric; market_asof:=(new.payload #>> '{market,as_of}')::timestamptz; exception when others then raise exception 'A8_MARKET_OFFER_FIELDS_INVALID' using errcode='23514'; end;
    if offer.sportsbook is distinct from new.payload #>> '{market,sportsbook}' or offer.line_exact is distinct from new.payload #>> '{market,line_exact}' or offer.price_exact is distinct from new.payload #>> '{market,price_exact}' or abs(offer.decimal_odds-market_odds)>0.000001 then raise exception 'A8_MARKET_FIELDS_DIFFER_FROM_VERIFIED_OFFER' using errcode='23514'; end if;
    if market_asof is distinct from offer.retrieved_at then raise exception 'A8_MARKET_ASOF_DIFFERS_FROM_VERIFIED_OFFER' using errcode='23514'; end if;
    if abs(public.nrfim_json_num(new.payload,'market.break_even')-(1/offer.decimal_odds))>0.000001 then raise exception 'A8_BREAK_EVEN_NOT_FROM_VERIFIED_PRICE' using errcode='23514'; end if;
    if offer.retrieved_at>new.submitted_at then raise exception 'A8_MARKET_OFFER_FROM_FUTURE' using errcode='23514'; end if;
    if not exists(select 1 from public.evidence e where e.evidence_id=offer.evidence_id and e.run_id=new.run_id and (e.game_id is null or e.game_id=new.game_id) and coalesce(e.data_available_at,e.retrieved_at)<=offer.retrieved_at and (coalesce(e.source_ref,'')='' or e.source_ref=offer.source_ref)) then raise exception 'A8_MARKET_OFFER_EVIDENCE_INVALID' using errcode='23514'; end if;
    select * into t5 from public.t5_revalidations where revalidation_id=new.payload #>> '{t5,revalidation_id}';
    if not found or t5.run_id<>new.run_id or t5.game_id<>new.game_id or t5.offer_id<>offer.offer_id then raise exception 'A8_T5_VERIFIED_RECORD_REQUIRED' using errcode='23514'; end if;
    if run_mode='DIAGNOSTIC' then
      if t5.status<>'DIAGNOSTIC_VERIFIED' then raise exception 'A8_T5_NOT_DIAGNOSTIC_VERIFIED' using errcode='23514'; end if;
    else
      if t5.status<>'VERIFIED' then raise exception 'A8_T5_NOT_VERIFIED' using errcode='23514'; end if;
    end if;
    if t5.material_change then raise exception 'A8_T5_MATERIAL_CHANGE_FULL_RECOMPUTE_REQUIRED' using errcode='23514'; end if;
    if not t5.starter_confirmed or not t5.official_lineup_verified then raise exception 'A8_T5_STARTER_OR_LINEUP_NOT_VERIFIED' using errcode='23514'; end if;
    if t5.active_freeze_id is distinct from new.payload #>> '{t5,active_freeze_id}' or t5.as_of is distinct from (new.payload #>> '{t5,as_of}')::timestamptz or t5.line_exact is distinct from new.payload #>> '{t5,line_exact}' or t5.price_exact is distinct from new.payload #>> '{t5,price_exact}' or abs(t5.break_even-public.nrfim_json_num(new.payload,'t5.break_even'))>0.000001 then raise exception 'A8_T5_FIELDS_DIFFER_FROM_VERIFIED_RECORD' using errcode='23514'; end if;
    foreach eid in array t5.evidence_ids loop
      if not exists(select 1 from public.evidence e where e.evidence_id=eid and e.run_id=new.run_id and (e.game_id is null or e.game_id=new.game_id) and coalesce(e.data_available_at,e.retrieved_at)<=t5.as_of) then raise exception 'A8_T5_EVIDENCE_INVALID:%',eid using errcode='23514'; end if;
    end loop;
    if lower(coalesce(new.payload #>> '{t5,material_change}','false')) not in ('false','0','no') or upper(coalesce(new.payload #>> '{t5,recompute_status}','')) not in ('NOT_REQUIRED','PASS') then raise exception 'A8_T5_RECOMPUTE_STATE_INVALID' using errcode='23514'; end if;
  end if;
  return new;
end;
$$;

alter table public.nrfimetrica_postresult_audits enable row level security;
alter table public.nrfimetrica_recommendation_log enable row level security;

do $$ declare r record; begin
  for r in select c.oid::regclass::text as obj from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and c.relname like 'nrfimetrica_%' loop
    execute format('revoke all privileges on table %s from public, anon, authenticated',r.obj);
    execute format('grant select,insert,update,delete on table %s to service_role',r.obj);
  end loop;
  for r in select p.oid::regprocedure::text as sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and (p.proname like 'nrfimetrica_%' or p.proname like 'nrfim_%' or p.proname like 'enforce_nrfimetrica_%' or p.proname in ('enforce_sports_reasoning_packet','freeze_terminal_sports_packet')) loop
    execute format('alter function %s set search_path = public, extensions, pg_temp',r.sig);
    execute format('revoke execute on function %s from public, anon, authenticated',r.sig);
    execute format('grant execute on function %s to service_role',r.sig);
  end loop;
end $$;
