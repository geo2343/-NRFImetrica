-- @NRFImetrica only. Agent remains DISABLED until post-migration audit passes.

update public.agent_registry
set status='DISABLED',
    agent_version='MOTHER-V3-AGENT-1.12',
    kernel_version='NRFIM-KERNEL-1.7-SELF-AUDIT-HARDENED',
    mother_document_sha256='799ccb5a483e7991f880ae7d49d2f191a98e292478ec64e76a55aa8250ec498b',
    metadata=(coalesce(metadata,'{}'::jsonb)
      -'database_migrations_required_through'-'github_migrations_through'-'terminal_validation_state'-'github_parity_state'-'refactor_state')
      || jsonb_build_object(
        'database_migrations_required_through',69,
        'github_migrations_through',68,
        'terminal_validation_state','V17_SELF_AUDIT_PENDING',
        'github_parity_state','DB_069_PENDING_GITHUB',
        'refactor_state','DISABLED_FOR_V17_SELF_AUDIT',
        'mother_export_sha256','799ccb5a483e7991f880ae7d49d2f191a98e292478ec64e76a55aa8250ec498b',
        'press_intake_provenance','KERNEL_ATTESTED_RECEIVER_EVENT_REQUIRED',
        'press_unresolved_release_policy','BLOCK_AND_REANALYZE',
        'system_reliability_lineage','PHYSICAL_AUDIT_ROW_REQUIRED_OR_NOT_AVAILABLE_BLOCK',
        'execution_target_firewall','U0.5_ONLY_UNTIL_TARGET_SPECIFIC_CERTIFICATION',
        'user_action_fail_closed',true,
        'best_supported_rival_may_be_none_if_search_documented',true,
        'post_activation_audit_state','CORRECTION_APPLIED_PENDING_RETEST'
      ),
    updated_at=clock_timestamp()
where agent_id='@NRFImetrica';

update public.system_versions
set kernel_version='NRFIM-KERNEL-1.7-SELF-AUDIT-HARDENED',
    contract_doc_id='MOTHER_SHA256:799ccb5a483e7991f880ae7d49d2f191a98e292478ec64e76a55aa8250ec498b',
    calibration_status='SYSTEM_AUDIT_ONLY_NO_GAME_OVERRIDE'
where system_version='NRFIM MOTHER V3';

update public.protocol_authority
set document_sha256='799ccb5a483e7991f880ae7d49d2f191a98e292478ec64e76a55aa8250ec498b',
    document_lines=18610,
    precedence_rule='V17_SELF_AUDIT_HARDENING_PLUS_PREANALYSIS_PRESS_PLUS_CALIBRATE_SYSTEM_NOT_GAME',
    latest_sovereign_patch='POST_ACTIVATION_SELF_AUDIT_HARDENING — 2026-08-20',
    active=true
where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS';

alter table public.nrfimetrica_press_intakes rename column no_material_delta to empty_packet;
alter table public.nrfimetrica_press_intakes add column source_event_id text;
alter table public.nrfimetrica_press_intakes
  add constraint nrfimetrica_press_intakes_source_event_fkey foreign key(source_event_id) references public.research_tool_events(event_id);

create or replace function public.nrfimetrica_enforce_press_intake()
returns trigger
language plpgsql
set search_path=public,extensions,pg_temp
as $$
declare
  start_at timestamptz;
  ev public.research_tool_events%rowtype;
  forbidden text[]:=array[
    'external_picks','picks','consensus','odds','line_movement','movement','review_priority','shortlist',
    'jrc','jrc_status','so_media_status','f8_conclusion','candidate_rank','p_nrfi','model_probability','edge','ev','stake',
    'bet_amount','final_pick','nrfi_materiality','materiality_answer','press_verdict','best_press_nrfi_case',
    'best_press_yrfi_case','press_vulnerable_half','press_breakpoints','external_analyst_arguments','recommendation',
    'ranking','priority','reformulated_verdict','contrast_effect','coincidences','omitted_risks',
    'ai_estimate','ai_probability','ai_nrfi_estimate','calibrated_probability'
  ];
begin
  if tg_op='INSERT' and coalesce(new.intake_id,'')='' then new.intake_id:='PINT-'||replace(gen_random_uuid()::text,'-',''); end if;
  select scheduled_start into start_at from public.games where run_id=new.run_id and game_id=new.game_id;
  if start_at is null then raise exception 'PRESS_INTAKE_GAME_NOT_REGISTERED' using errcode='23514'; end if;
  if new.received_at>clock_timestamp()+interval '1 minute' then raise exception 'PRESS_INTAKE_FROM_FUTURE' using errcode='23514'; end if;
  if new.received_at>=start_at then raise exception 'PRESS_INTAKE_LIVE_CONTAMINATION_FORBIDDEN' using errcode='23514'; end if;
  if jsonb_typeof(new.payload)<>'object' then raise exception 'PRESS_INTAKE_PAYLOAD_OBJECT_REQUIRED' using errcode='23514'; end if;
  new.content_hash:=public.nrfim_sha256_text(new.payload::text);
  if public.nrfim_json_has_key_recursive(new.payload,forbidden) then
    new.contamination_status:='FAIL';
    if new.status='RECEIVED_VALIDATED' then raise exception 'PRESS_INTAKE_INTERPRETIVE_OR_MARKET_CONTAMINATION' using errcode='23514'; end if;
    new.status:='REJECTED_CONTAMINATION';
  end if;
  if new.status='RECEIVED_VALIDATED' then
    if new.provenance_status<>'VERIFIED_SOURCE_PACKET' then raise exception 'PRESS_INTAKE_VALIDATED_REQUIRES_VERIFIED_SOURCE_PACKET' using errcode='23514'; end if;
    if new.contamination_status<>'PASS' then raise exception 'PRESS_INTAKE_VALIDATED_REQUIRES_CONTAMINATION_PASS' using errcode='23514'; end if;
    if coalesce(new.source_event_id,'')='' then raise exception 'PRESS_INTAKE_VALIDATED_REQUIRES_KERNEL_ATTESTED_SOURCE_EVENT' using errcode='23514'; end if;
    select * into ev from public.research_tool_events where event_id=new.source_event_id;
    if not found or ev.run_id<>new.run_id or ev.game_id is distinct from new.game_id then raise exception 'PRESS_INTAKE_SOURCE_EVENT_IDENTITY_MISMATCH' using errcode='23514'; end if;
    if not ev.kernel_attested or ev.retrieval_mode not in ('KERNEL_SERVER_FETCH','KERNEL_PROVIDER_FETCH') then raise exception 'PRESS_INTAKE_SOURCE_EVENT_NOT_KERNEL_ATTESTED' using errcode='23514'; end if;
    if coalesce(ev.response_hash,'')<>new.source_packet_hash then raise exception 'PRESS_INTAKE_SOURCE_EVENT_HASH_MISMATCH' using errcode='23514'; end if;
    if ev.occurred_at>new.received_at or ev.occurred_at>=start_at then raise exception 'PRESS_INTAKE_SOURCE_EVENT_TEMPORAL_INVALID' using errcode='23514'; end if;
    if new.source_receipt='{}'::jsonb then raise exception 'PRESS_INTAKE_VALIDATED_REQUIRES_SOURCE_RECEIPT' using errcode='23514'; end if;
    if coalesce(new.source_receipt->>'source_packet_hash','')<>new.source_packet_hash then raise exception 'PRESS_INTAKE_SOURCE_RECEIPT_HASH_MISMATCH' using errcode='23514'; end if;
    if coalesce(new.source_receipt->>'parsed_payload_hash','')<>new.content_hash then raise exception 'PRESS_INTAKE_PARSED_PAYLOAD_HASH_MISMATCH' using errcode='23514'; end if;
  end if;
  return new;
end;
$$;

create or replace function public.nrfimetrica_enforce_press_intake_phase()
returns trigger
language plpgsql
set search_path=public,extensions,pg_temp
as $$
declare i public.nrfimetrica_press_intakes%rowtype; cnt integer;
begin
  if new.protocol_id<>'NRFIMETRICA_MOTHER_V3_AUTONOMOUS' or new.phase_id<>'A0P_PRESS_INFORMATION_INTAKE' then return new; end if;
  if new.status='SKIPPED_NOT_TRIGGERED' then
    if lower(coalesce(new.payload->>'press_packet_available','false')) not in ('false','0','no') then raise exception 'A0P_SKIP_REQUIRES_PRESS_PACKET_UNAVAILABLE' using errcode='23514'; end if;
    return new;
  end if;
  if new.status<>'COMPLETE' then raise exception 'A0P_MUST_COMPLETE_OR_SKIP_NOT_TRIGGERED' using errcode='23514'; end if;
  if lower(coalesce(new.payload->>'press_packet_available','false')) not in ('true','1','yes') then raise exception 'A0P_COMPLETE_REQUIRES_PRESS_PACKET_AVAILABLE' using errcode='23514'; end if;
  select * into i from public.nrfimetrica_press_intakes where intake_id=new.payload->>'intake_id';
  if not found or i.run_id<>new.run_id or i.game_id<>new.game_id then raise exception 'A0P_INTAKE_IDENTITY_MISMATCH' using errcode='23514'; end if;
  if i.status<>'RECEIVED_VALIDATED' or i.contamination_status<>'PASS' or i.provenance_status<>'VERIFIED_SOURCE_PACKET' then raise exception 'A0P_REQUIRES_VALIDATED_CLEAN_VERIFIED_INTAKE' using errcode='23514'; end if;
  if i.information_role<>'INFORMATION_FOR_ANALYSIS' or i.sports_authority<>'NONE' or i.probability_authority<>'NONE' or i.ranking_authority<>'NONE' or i.market_authority<>'NONE' or i.conclusion_authority<>'NONE' then raise exception 'A0P_PRESS_INPUT_HAS_FORBIDDEN_AUTHORITY' using errcode='23514'; end if;
  if new.payload->>'intake_status' is distinct from i.status or new.payload->>'information_role' is distinct from i.information_role or new.payload->>'sports_authority' is distinct from i.sports_authority or new.payload->>'probability_authority' is distinct from i.probability_authority or new.payload->>'ranking_authority' is distinct from i.ranking_authority or new.payload->>'market_authority' is distinct from i.market_authority or new.payload->>'conclusion_authority' is distinct from i.conclusion_authority or new.payload->>'contamination_status' is distinct from i.contamination_status then raise exception 'A0P_PHASE_FIELDS_DIFFER_FROM_INTAKE' using errcode='23514'; end if;
  select count(*) into cnt from public.nrfimetrica_press_items where intake_id=i.intake_id;
  if i.empty_packet and cnt<>0 then raise exception 'A0P_EMPTY_PACKET_CANNOT_HAVE_ITEMS' using errcode='23514'; end if;
  if not i.empty_packet and cnt=0 then raise exception 'A0P_NONEMPTY_PACKET_REQUIRES_ITEMS' using errcode='23514'; end if;
  return new;
end;
$$;

create or replace function public.nrfimetrica_no_ai_probability_v17()
returns trigger
language plpgsql
set search_path=public,pg_temp
as $$
begin
  if new.protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and public.nrfim_json_has_key_recursive(new.payload,array['ai_estimate','ai_probability','ai_nrfi_estimate','calibrated_probability']) then
    raise exception 'NRFIMETRICA_AI_PROBABILITY_FABRICATION_FORBIDDEN' using errcode='23514';
  end if;
  return new;
end;
$$;
drop trigger if exists trg_000_nrfimetrica_no_ai_probability_v17 on public.protocol_phase_state;
create trigger trg_000_nrfimetrica_no_ai_probability_v17 before insert or update on public.protocol_phase_state for each row execute function public.nrfimetrica_no_ai_probability_v17();

create or replace function public.enforce_nrfimetrica_mother_source_truth()
returns trigger
language plpgsql
set search_path=public,extensions,pg_temp
as $$
declare x jsonb; eid text; sref text; rt timestamptz; evid public.evidence%rowtype;
begin
  if new.protocol_id<>'NRFIMETRICA_MOTHER_V3_AUTONOMOUS' then return new; end if;
  for x in select value from jsonb_array_elements(coalesce(new.source_calls,'[]'::jsonb)) loop
    eid:=btrim(coalesce(x->>'evidence_id','')); sref:=btrim(coalesce(x->>'source_ref',''));
    if eid='' then raise exception 'MOTHER_SOURCE_CALL_WITHOUT_EVIDENCE_ID' using errcode='23514'; end if;
    if not (eid=any(new.evidence_ids)) then raise exception 'MOTHER_SOURCE_CALL_EVIDENCE_NOT_BOUND_TO_PHASE:%',eid using errcode='23514'; end if;
    begin rt:=(x->>'retrieved_at')::timestamptz; exception when others then raise exception 'MOTHER_SOURCE_CALL_RETRIEVED_AT_INVALID:%',eid using errcode='23514'; end;
    if rt>new.submitted_at then raise exception 'MOTHER_SOURCE_CALL_FROM_FUTURE:%',eid using errcode='23514'; end if;
    select * into evid from public.evidence e where e.evidence_id=eid and e.run_id=new.run_id and (e.game_id is null or e.game_id=new.game_id) limit 1;
    if not found then raise exception 'MOTHER_SOURCE_CALL_EVIDENCE_NOT_FOUND:%',eid using errcode='23514'; end if;
    if coalesce(evid.data_available_at,evid.retrieved_at)>new.submitted_at then raise exception 'MOTHER_SOURCE_CALL_EVIDENCE_NOT_YET_AVAILABLE:%',eid using errcode='23514'; end if;
    if sref<>'' and coalesce(evid.source_ref,'')<>'' and sref<>evid.source_ref then raise exception 'MOTHER_SOURCE_REF_MISMATCH:%',eid using errcode='23514'; end if;
  end loop;
  return new;
end;
$$;

alter table public.nrfimetrica_system_calibration_audits add column audit_hash text not null default '';
alter table public.nrfimetrica_system_calibration_audits add column sealed_at timestamptz;

create or replace function public.nrfimetrica_system_audit_guard_v17()
returns trigger
language plpgsql
set search_path=public,extensions,pg_temp
as $$
begin
  if tg_op in ('UPDATE','DELETE') and old.sealed_at is not null then raise exception 'SYSTEM_RELIABILITY_AUDIT_IMMUTABLE_AFTER_SEAL' using errcode='23514'; end if;
  if tg_op='DELETE' then return old; end if;
  if new.status in ('PASS','CONDITIONED') and new.sample_size<=0 then raise exception 'SYSTEM_RELIABILITY_AUDIT_CERTIFYING_STATUS_REQUIRES_OBSERVATIONS' using errcode='23514'; end if;
  if new.status not in ('PASS','CONDITIONED') and new.economic_effect<>'BLOCK' then raise exception 'SYSTEM_RELIABILITY_NONCERTIFYING_AUDIT_MUST_BLOCK_ECONOMIC_AUTHORITY' using errcode='23514'; end if;
  if new.sports_effect<>'NONE' or new.ranking_effect<>'NONE' or new.probability_effect<>'NONE' or new.historical_override_allowed or new.universal_game_equivalence_allowed then raise exception 'SYSTEM_RELIABILITY_AUDIT_FORBIDDEN_GAME_AUTHORITY' using errcode='23514'; end if;
  new.sealed_at:=clock_timestamp();
  new.audit_hash:=public.nrfim_sha256_text(jsonb_build_object('audit_id',new.audit_id,'model_version',new.model_version,'target_id',new.target_id,'evaluation_start',new.evaluation_start,'evaluation_end',new.evaluation_end,'sample_size',new.sample_size,'methodology',new.methodology,'context_scope',new.context_scope,'metrics',new.metrics,'baseline_comparison',new.baseline_comparison,'ablation_summary',new.ablation_summary,'confidence_behavior',new.confidence_behavior,'drift_status',new.drift_status,'economic_effect',new.economic_effect,'sports_effect',new.sports_effect,'ranking_effect',new.ranking_effect,'probability_effect',new.probability_effect,'status',new.status)::text);
  return new;
end;
$$;
drop trigger if exists trg_nrfimetrica_system_audit_guard_v17 on public.nrfimetrica_system_calibration_audits;
create trigger trg_nrfimetrica_system_audit_guard_v17 before insert or update or delete on public.nrfimetrica_system_calibration_audits for each row execute function public.nrfimetrica_system_audit_guard_v17();

create or replace function public.nrfimetrica_assert_system_reliability_lineage_v17(a7 jsonb)
returns void
language plpgsql
stable
set search_path=public,pg_temp
as $$
declare aid text; a public.nrfimetrica_system_calibration_audits%rowtype; expected_status text;
begin
  aid:=upper(btrim(coalesce(a7 #>> '{system_reliability,audit_id}','NONE')));
  if aid in ('','NONE','N/A','NA') then
    if upper(coalesce(a7 #>> '{system_reliability,status}',''))<>'NOT_AVAILABLE' or upper(coalesce(a7 #>> '{system_reliability,economic_effect}',''))<>'BLOCK' then raise exception 'A7_NO_SYSTEM_AUDIT_REQUIRES_NOT_AVAILABLE_BLOCK' using errcode='23514'; end if;
    return;
  end if;
  select * into a from public.nrfimetrica_system_calibration_audits where audit_id::text=lower(aid);
  if not found then raise exception 'A7_SYSTEM_RELIABILITY_AUDIT_NOT_FOUND:%',aid using errcode='23514'; end if;
  if a.model_version is distinct from a7->>'model_version' or a.target_id is distinct from a7->>'target_id' then raise exception 'A7_SYSTEM_RELIABILITY_AUDIT_MODEL_TARGET_MISMATCH' using errcode='23514'; end if;
  if a.sports_effect<>'NONE' or a.ranking_effect<>'NONE' or a.probability_effect<>'NONE' or a.historical_override_allowed or a.universal_game_equivalence_allowed then raise exception 'A7_SYSTEM_RELIABILITY_AUDIT_HAS_FORBIDDEN_GAME_AUTHORITY' using errcode='23514'; end if;
  expected_status:=case when a.status not in ('PASS','CONDITIONED','INSUFFICIENT_SAMPLE') then 'NOT_AVAILABLE' when a.drift_status='DRIFT_DETECTED' then 'DRIFT_DETECTED' when a.status='INSUFFICIENT_SAMPLE' or a.confidence_behavior='INSUFFICIENT_SAMPLE' then 'INSUFFICIENT_SAMPLE' when a.confidence_behavior in ('RELIABLE','OVERCONFIDENT','UNDERCONFIDENT','MIXED') then a.confidence_behavior else 'NOT_AVAILABLE' end;
  if upper(coalesce(a7 #>> '{system_reliability,status}',''))<>expected_status then raise exception 'A7_SYSTEM_RELIABILITY_STATUS_NOT_DERIVED_FROM_AUDIT:%/%',coalesce(a7 #>> '{system_reliability,status}',''),expected_status using errcode='23514'; end if;
  if upper(coalesce(a7 #>> '{system_reliability,economic_effect}',''))<>a.economic_effect then raise exception 'A7_SYSTEM_RELIABILITY_ECONOMIC_EFFECT_NOT_FROM_AUDIT' using errcode='23514'; end if;
  if expected_status='NOT_AVAILABLE' and a.economic_effect<>'BLOCK' then raise exception 'A7_NONVALID_SYSTEM_AUDIT_MUST_BLOCK' using errcode='23514'; end if;
end;
$$;

create or replace function public.nrfimetrica_assert_a7_game_causal_lineage_v16(a7 jsonb,a5 jsonb)
returns void
language plpgsql
immutable
set search_path=public,pg_temp
as $$
declare central numeric; target text;
begin
  target:=upper(coalesce(a7->>'target_id',''));
  central:=case target when 'U0.5' then public.nrfim_json_num(a5,'contracts.p_u0_5') when 'U1.5' then public.nrfim_json_num(a5,'contracts.p_u1_5') when 'U2.5' then public.nrfim_json_num(a5,'contracts.p_u2_5') else null end;
  if central is null then raise exception 'A7_TARGET_ID_INVALID:%',target using errcode='23514'; end if;
  if abs(public.nrfim_json_num(a7,'game_causal_p')-central)>0.000001 then raise exception 'A7_GAME_CAUSAL_P_NOT_FROM_A5_TARGET' using errcode='23514'; end if;
  if upper(coalesce(a7->>'game_probability_source',''))<>'A5_GAME_CAUSAL_ONLY' or upper(coalesce(a7->>'eligibility_basis',''))<>'GAME_CAUSAL_ONLY' then raise exception 'A7_GAME_PROBABILITY_AND_ELIGIBILITY_MUST_BE_CAUSAL_ONLY' using errcode='23514'; end if;
  if lower(coalesce(a7 #>> '{game_uncertainty,historical_calibration_used}','true')) not in ('false','0','no') then raise exception 'A7_GAME_UNCERTAINTY_CANNOT_USE_HISTORICAL_CALIBRATION' using errcode='23514'; end if;
  if upper(coalesce(a7 #>> '{game_uncertainty,u0_5,source}',''))<>'GAME_SPECIFIC_STRESS_TEST' or upper(coalesce(a7 #>> '{game_uncertainty,u1_5,source}',''))<>'GAME_SPECIFIC_STRESS_TEST' or upper(coalesce(a7 #>> '{game_uncertainty,u2_5,source}',''))<>'GAME_SPECIFIC_STRESS_TEST' then raise exception 'A7_CONSERVATIVE_BOUNDS_MUST_BE_GAME_SPECIFIC' using errcode='23514'; end if;
  if public.nrfim_json_num(a7,'game_uncertainty.u0_5.lower_bound')>public.nrfim_json_num(a5,'contracts.p_u0_5') or public.nrfim_json_num(a7,'game_uncertainty.u1_5.lower_bound')>public.nrfim_json_num(a5,'contracts.p_u1_5') or public.nrfim_json_num(a7,'game_uncertainty.u2_5.lower_bound')>public.nrfim_json_num(a5,'contracts.p_u2_5') then raise exception 'A7_GAME_UNCERTAINTY_LOWER_BOUND_ABOVE_CENTRAL' using errcode='23514'; end if;
end;
$$;

create or replace function public.nrfimetrica_assert_a7_no_external_override_v16(a7 jsonb)
returns void
language plpgsql
immutable
set search_path=public,pg_temp
as $$
begin
  if upper(coalesce(a7->>'calibration_role',''))<>'SYSTEM_AUDIT_ONLY' then raise exception 'A7_CALIBRATION_ROLE_MUST_BE_SYSTEM_AUDIT_ONLY' using errcode='23514'; end if;
  if lower(coalesce(a7->>'calibration_game_override','true')) not in ('false','0','no') or lower(coalesce(a7->>'calibration_sports_authority','true')) not in ('false','0','no') or lower(coalesce(a7->>'calibration_ranking_authority','true')) not in ('false','0','no') then raise exception 'A7_HISTORICAL_CALIBRATION_HAS_FORBIDDEN_GAME_AUTHORITY' using errcode='23514'; end if;
  if upper(coalesce(a7 #>> '{system_reliability,sports_effect}',''))<>'NONE' or upper(coalesce(a7 #>> '{system_reliability,ranking_effect}',''))<>'NONE' or upper(coalesce(a7 #>> '{system_reliability,probability_effect}',''))<>'NONE' then raise exception 'A7_SYSTEM_CALIBRATION_CANNOT_CHANGE_GAME_SPORTS_OR_PROBABILITY' using errcode='23514'; end if;
  if upper(coalesce(a7 #>> '{press_integration,sports_effect}',''))<>'NONE' or upper(coalesce(a7 #>> '{press_integration,probability_effect}',''))<>'NONE' or upper(coalesce(a7 #>> '{press_integration,ranking_effect}',''))<>'NONE' or upper(coalesce(a7 #>> '{press_integration,market_effect}',''))<>'NONE' or upper(coalesce(a7 #>> '{press_integration,conclusion_effect}',''))<>'NONE' then raise exception 'A7_PRESS_INTEGRATION_HAS_FORBIDDEN_DIRECT_EFFECT' using errcode='23514'; end if;
  if upper(coalesce(a7->>'sports_verdict_effect',''))<>'NONE' then raise exception 'A7_CANNOT_REFORMULATE_SPORTS_VERDICT' using errcode='23514'; end if;
  if a7 ? 'reformulated_verdict' or a7 ? 'contrast_effect' or a7 ? 'calibrated_p' or a7 ? 'historical_adjusted_p' then raise exception 'A7_EXTERNAL_OR_HISTORICAL_GAME_OVERRIDE_FORBIDDEN' using errcode='23514'; end if;
end;
$$;

update public.protocol_phase_catalog
set required_fields=array['model_version','engine_mode','model_tier','target_id','game_causal_p','total_uncertainty','sports_stability','absolute_eligibility','input_freeze_id','a4_execution_id','calibration_role','calibration_game_override','calibration_sports_authority','calibration_ranking_authority','game_probability_source','eligibility_basis','system_reliability.audit_id','system_reliability.status','system_reliability.economic_effect','system_reliability.sports_effect','system_reliability.ranking_effect','system_reliability.probability_effect','game_uncertainty.u0_5.lower_bound','game_uncertainty.u0_5.source','game_uncertainty.u1_5.lower_bound','game_uncertainty.u1_5.source','game_uncertainty.u2_5.lower_bound','game_uncertainty.u2_5.source','game_uncertainty.historical_calibration_used','press_integration.a0p_status','press_integration.intake_id','press_integration.disposition_complete','press_integration.sports_effect','press_integration.probability_effect','press_integration.ranking_effect','press_integration.market_effect','press_integration.conclusion_effect','press_integration.reanalysis_required','press_integration.unresolved_count','sports_verdict_hash','sports_verdict_reference','sports_verdict_effect','hard_gates','release_token','phase_result']
where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS';

create or replace function public.nrfimetrica_a7_press_integration_guard_v16()
returns trigger
language plpgsql
set search_path=public,extensions,pg_temp
as $$
declare p text:='NRFIMETRICA_MOTHER_V3_AUTONOMOUS'; a1 jsonb; a4 jsonb; a5 jsonb; a6 jsonb; a0p public.protocol_phase_state%rowtype; intake public.nrfimetrica_press_intakes%rowtype; sp public.sports_reasoning_packets%rowtype; item_count integer:=0; disposition_count integer:=0; unresolved integer:=0; rel_status text; econ_effect text; target text;
begin
  if new.protocol_id<>p or new.phase_id<>'A7_CALIBRATION_ELIGIBILITY_PRESS' then return new; end if;
  perform public.nrfimetrica_assert_a7_no_external_override_v16(new.payload);
  perform public.nrfimetrica_assert_press_reanalysis_gate_v16(new.payload);
  select payload into a1 from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=p and phase_id='A1_DATA_INTEGRITY_FREEZE';
  select payload into a4 from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=p and phase_id='A4_NUMERIC_STATE_ENGINE';
  select payload into a5 from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=p and phase_id='A5_JOINT_INTEGRATION';
  select payload into a6 from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=p and phase_id='A6_CAUSAL_FALSIFICATION_SPORTS_SEAL';
  if a1 is null or a4 is null or a5 is null or a6 is null then raise exception 'A7_CAUSAL_LINEAGE_INCOMPLETE' using errcode='23514'; end if;
  if new.payload->>'input_freeze_id' is distinct from a1->>'input_freeze_id' then raise exception 'A7_FREEZE_LINEAGE_MISMATCH' using errcode='23514'; end if;
  if new.payload->>'a4_execution_id' is distinct from a4 #>> '{numeric_engine,execution_id}' then raise exception 'A7_A4_EXECUTION_LINEAGE_MISMATCH' using errcode='23514'; end if;
  perform public.nrfimetrica_assert_a7_game_causal_lineage_v16(new.payload,a5);
  perform public.nrfimetrica_assert_system_reliability_lineage_v17(new.payload);
  rel_status:=upper(coalesce(new.payload #>> '{system_reliability,status}','')); econ_effect:=upper(coalesce(new.payload #>> '{system_reliability,economic_effect}','')); target:=upper(coalesce(new.payload->>'target_id',''));
  if rel_status not in ('RELIABLE','OVERCONFIDENT','UNDERCONFIDENT','MIXED','INSUFFICIENT_SAMPLE','DRIFT_DETECTED','NOT_AVAILABLE') then raise exception 'A7_SYSTEM_RELIABILITY_STATUS_INVALID' using errcode='23514'; end if;
  if econ_effect not in ('ALLOW','CONDITION','BLOCK') then raise exception 'A7_SYSTEM_RELIABILITY_ECONOMIC_EFFECT_INVALID' using errcode='23514'; end if;
  if rel_status in ('NOT_AVAILABLE','DRIFT_DETECTED') and econ_effect<>'BLOCK' then raise exception 'A7_SYSTEM_RELIABILITY_MUST_BLOCK_ECONOMIC_AUTHORITY:%',rel_status using errcode='23514'; end if;
  if new.payload->>'sports_verdict_hash' is distinct from a6 #>> '{sports_verdict,hash}' then raise exception 'A7_SPORTS_VERDICT_HASH_MISMATCH' using errcode='23514'; end if;
  select * into a0p from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=p and phase_id='A0P_PRESS_INFORMATION_INTAKE' order by submitted_at desc limit 1;
  if not found then raise exception 'A7_REQUIRES_A0P_RESOLVED' using errcode='23514'; end if;
  if upper(coalesce(new.payload #>> '{press_integration,a0p_status}',''))<>a0p.status then raise exception 'A7_A0P_STATUS_MISMATCH' using errcode='23514'; end if;
  select * into sp from public.sports_reasoning_packets where run_id=new.run_id and game_id=new.game_id and status='ANALYSIS_COMPLETE' order by version desc limit 1;
  if not found then raise exception 'A7_REQUIRES_COMPLETED_SPORTS_REASONING_PACKET' using errcode='23514'; end if;
  if a0p.status='COMPLETE' then
    select * into intake from public.nrfimetrica_press_intakes where intake_id=a0p.payload->>'intake_id';
    if not found then raise exception 'A7_PRESS_INTAKE_NOT_FOUND' using errcode='23514'; end if;
    if new.payload #>> '{press_integration,intake_id}' is distinct from intake.intake_id or sp.press_intake_id is distinct from intake.intake_id then raise exception 'A7_PRESS_INTAKE_LINEAGE_MISMATCH' using errcode='23514'; end if;
    select count(*) into item_count from public.nrfimetrica_press_items where intake_id=intake.intake_id;
    select count(*) into disposition_count from public.nrfimetrica_press_item_dispositions where intake_id=intake.intake_id and sports_packet_id=sp.packet_id;
    select count(*) into unresolved from public.nrfimetrica_press_item_dispositions where intake_id=intake.intake_id and sports_packet_id=sp.packet_id and disposition='UNRESOLVED';
    if item_count<>disposition_count then raise exception 'A7_PRESS_DISPOSITIONS_INCOMPLETE:%/%',disposition_count,item_count using errcode='23514'; end if;
    if coalesce((new.payload #>> '{press_integration,unresolved_count}')::integer,-1)<>unresolved then raise exception 'A7_PRESS_UNRESOLVED_COUNT_MISMATCH' using errcode='23514'; end if;
    if lower(coalesce(new.payload #>> '{press_integration,disposition_complete}','false')) not in ('true','1','yes') then raise exception 'A7_PRESS_DISPOSITION_COMPLETE_REQUIRED' using errcode='23514'; end if;
    if unresolved>0 and lower(coalesce(new.payload #>> '{press_integration,reanalysis_required}','false')) not in ('true','1','yes') then raise exception 'A7_UNRESOLVED_PRESS_ITEM_REQUIRES_REANALYSIS' using errcode='23514'; end if;
  else
    if nullif(new.payload #>> '{press_integration,intake_id}','') is not null then raise exception 'A7_SKIPPED_A0P_CANNOT_HAVE_INTAKE_ID' using errcode='23514'; end if;
    if coalesce((new.payload #>> '{press_integration,unresolved_count}')::integer,-1)<>0 then raise exception 'A7_SKIPPED_A0P_UNRESOLVED_MUST_BE_ZERO' using errcode='23514'; end if;
  end if;
  if upper(coalesce(new.payload->>'release_token',''))='ISSUED' then
    if target<>'U0.5' then raise exception 'A7_TARGET_SPECIFIC_EXECUTION_CERTIFICATION_REQUIRED:%',target using errcode='23514'; end if;
    if upper(coalesce(new.payload->>'absolute_eligibility','')) not in ('A7_ELIGIBLE','A7_ELIGIBLE_CONDITIONED') then raise exception 'A7_RELEASE_REQUIRES_GAME_CAUSAL_ELIGIBILITY' using errcode='23514'; end if;
    if econ_effect='BLOCK' then raise exception 'A7_RELEASE_BLOCKED_BY_SYSTEM_RELIABILITY_AUDIT' using errcode='23514'; end if;
    if lower(coalesce(new.payload #>> '{press_integration,reanalysis_required}','false')) in ('true','1','yes') or coalesce((new.payload #>> '{press_integration,unresolved_count}')::integer,0)>0 then raise exception 'A7_RELEASE_BLOCKED_PENDING_PRESS_REANALYSIS' using errcode='23514'; end if;
    if sp.process_audit_status<>'PASS' or sp.drive_verified_at is null or sp.drive_content_hash is distinct from sp.packet_hash then raise exception 'A7_RELEASE_REQUIRES_VERIFIED_PROCESS_AND_DRIVE_HASH' using errcode='23514'; end if;
    if not public.nrfim_latest_bilateral_nrfi_valid(new.run_id,new.game_id) then raise exception 'A7_RELEASE_REQUIRES_BILATERAL_CAUSAL_PROOF' using errcode='23514'; end if;
  elsif upper(coalesce(new.payload->>'release_token','')) not in ('NOT_ISSUED','BLOCKED','N/A','NA') then raise exception 'A7_RELEASE_TOKEN_INVALID' using errcode='23514'; end if;
  return new;
end;
$$;

create or replace function public.nrfim_validate_materialization_path(obj jsonb)
returns boolean
language plpgsql
immutable
set search_path=public,pg_temp
as $$
declare p jsonb; steps jsonb; pt text;
begin
  if jsonb_typeof(obj)<>'object' then return false; end if;
  if lower(coalesce(obj->>'supported_rival','true')) in ('false','0','no') and upper(coalesce(obj->>'rival_status',''))='NO_SUPPORTED_RIVAL' then
    if length(trim(coalesce(obj->>'search_summary','')))<8 or length(trim(coalesce(obj->>'why_none_competitive','')))<8 then return false; end if;
    if jsonb_typeof(coalesce(obj->'evidence_ids','[]'::jsonb))<>'array' or jsonb_array_length(coalesce(obj->'evidence_ids','[]'::jsonb))=0 then return false; end if;
    return true;
  end if;
  if lower(coalesce(obj->>'supported_rival','true')) not in ('true','1','yes') then return false; end if;
  p:=obj->'materialization_path'; if jsonb_typeof(p)<>'object' then return false; end if;
  if upper(coalesce(p->>'half','')) not in ('TOP_1ST','BOTTOM_1ST') then return false; end if;
  pt:=upper(coalesce(p->>'path_type','')); if pt not in ('FREE_TRAFFIC_CHAIN','ONE_SWING','EXTRA_BASE_CHAIN','CONTACT_CLUSTER','ERROR_ADVANCEMENT','OTHER_SPECIFIC') then return false; end if;
  if length(trim(coalesce(p->>'vulnerability_activator','')))<4 then return false; end if;
  if jsonb_typeof(coalesce(p->'evidence_ids','[]'::jsonb))<>'array' or jsonb_array_length(coalesce(p->'evidence_ids','[]'::jsonb))=0 then return false; end if;
  steps:=coalesce(p->'steps','[]'::jsonb); if jsonb_typeof(steps)<>'array' or jsonb_array_length(steps)=0 then return false; end if;
  if pt='ONE_SWING' then if length(trim(coalesce(p->>'batter_or_profile','')))<2 or length(trim(coalesce(p->>'pitch_or_zone_vulnerability','')))<2 then return false; end if; elsif jsonb_array_length(steps)<2 then return false; end if;
  if exists(select 1 from jsonb_array_elements(steps) s where jsonb_typeof(s)<>'object' or length(trim(coalesce(s->>'event','')))<2 or length(trim(coalesce(s->>'actor_or_profile','')))<2) then return false; end if;
  return true;
end;
$$;

create or replace function public.nrfimetrica_cognitive_packet_guard_v16()
returns trigger
language plpgsql
set search_path=public,extensions,pg_temp
as $$
declare pstate public.protocol_phase_state%rowtype; intake public.nrfimetrica_press_intakes%rowtype; item_count integer:=0; disposition_count integer:=0; x jsonb; topb integer:=0; botb integer:=0; eid text; rid text; rival_evidence jsonb;
begin
  if new.protocol_id<>'NRFIMETRICA_MOTHER_V3_AUTONOMOUS' or new.status<>'ANALYSIS_COMPLETE' then return new; end if;
  if upper(coalesce(new.cognitive_contract_version,''))<>'COGNITIVE-1.0' then raise exception 'COGNITIVE_CONTRACT_V1_REQUIRED' using errcode='23514'; end if;
  select * into pstate from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=new.protocol_id and phase_id='A0P_PRESS_INFORMATION_INTAKE' order by submitted_at desc limit 1;
  if not found or pstate.status not in ('COMPLETE','SKIPPED_NOT_TRIGGERED') then raise exception 'COGNITIVE_PACKET_REQUIRES_A0P_RESOLVED' using errcode='23514'; end if;
  if pstate.status='COMPLETE' then
    select * into intake from public.nrfimetrica_press_intakes where intake_id=pstate.payload->>'intake_id';
    if not found or intake.status<>'RECEIVED_VALIDATED' or intake.contamination_status<>'PASS' then raise exception 'COGNITIVE_PACKET_PRESS_INTAKE_NOT_VALIDATED' using errcode='23514'; end if;
    if new.press_intake_id is distinct from intake.intake_id then raise exception 'COGNITIVE_PACKET_PRESS_INTAKE_LINEAGE_MISMATCH' using errcode='23514'; end if;
    select count(*) into item_count from public.nrfimetrica_press_items where intake_id=intake.intake_id;
    select count(*) into disposition_count from public.nrfimetrica_press_item_dispositions where intake_id=intake.intake_id and sports_packet_id=new.packet_id;
    if item_count<>disposition_count then raise exception 'PRESS_ITEMS_REQUIRE_EXPLICIT_METRICA_DISPOSITION:%/%',disposition_count,item_count using errcode='23514'; end if;
    if upper(coalesce(new.press_disposition_summary->>'sports_authority',''))<>'NONE' or upper(coalesce(new.press_disposition_summary->>'probability_authority',''))<>'NONE' or upper(coalesce(new.press_disposition_summary->>'ranking_authority',''))<>'NONE' or upper(coalesce(new.press_disposition_summary->>'market_authority',''))<>'NONE' or upper(coalesce(new.press_disposition_summary->>'conclusion_authority',''))<>'NONE' then raise exception 'PRESS_DISPOSITION_SUMMARY_FORBIDDEN_AUTHORITY' using errcode='23514'; end if;
  else
    if new.press_intake_id is not null then raise exception 'A0P_SKIPPED_PACKET_CANNOT_BIND_PRESS_INTAKE' using errcode='23514'; end if;
  end if;
  if jsonb_typeof(new.provisional_representation)<>'object' or length(btrim(coalesce(new.provisional_representation->>'representation_class','')))<4 or length(btrim(coalesce(new.provisional_representation->>'working_hypothesis','')))<8 or upper(coalesce(new.provisional_representation->>'revision_status',''))<>'REVISABLE' then raise exception 'PROVISIONAL_REPRESENTATION_REQUIRED_AND_REVISABLE' using errcode='23514'; end if;
  if lower(coalesce(new.provisional_representation->>'inherited_press_conclusion','true')) not in ('false','0','no') then raise exception 'PROVISIONAL_REPRESENTATION_CANNOT_INHERIT_PRESS_CONCLUSION' using errcode='23514'; end if;
  if jsonb_typeof(new.autonomous_questions)<>'array' then raise exception 'AUTONOMOUS_QUESTIONS_ARRAY_REQUIRED' using errcode='23514'; end if;
  if exists(select 1 from jsonb_array_elements(new.autonomous_questions) q where length(btrim(coalesce(q->>'question','')))<8 or upper(coalesce(q->>'status','')) not in ('ANSWERED','OPEN_NON_GOVERNING','NOT_TRIGGERED')) then raise exception 'AUTONOMOUS_QUESTION_INVALID' using errcode='23514'; end if;
  if jsonb_typeof(new.causal_bottlenecks)<>'array' then raise exception 'CAUSAL_BOTTLENECKS_ARRAY_REQUIRED' using errcode='23514'; end if;
  for x in select value from jsonb_array_elements(new.causal_bottlenecks) loop
    if upper(coalesce(x->>'half',''))='TOP_1ST' then topb:=topb+1; elsif upper(coalesce(x->>'half',''))='BOTTOM_1ST' then botb:=botb+1; else raise exception 'CAUSAL_BOTTLENECK_HALF_INVALID' using errcode='23514'; end if;
    if length(btrim(coalesce(x->>'bottleneck','')))<5 or length(btrim(coalesce(x->>'what_breaks_it','')))<5 then raise exception 'CAUSAL_BOTTLENECK_CONTENT_REQUIRED' using errcode='23514'; end if;
    if jsonb_typeof(coalesce(x->'evidence_ids','[]'::jsonb))<>'array' or jsonb_array_length(coalesce(x->'evidence_ids','[]'::jsonb))=0 then raise exception 'CAUSAL_BOTTLENECK_EVIDENCE_REQUIRED' using errcode='23514'; end if;
    for eid in select jsonb_array_elements_text(x->'evidence_ids') loop if not eid=any(coalesce(new.evidence_ids,'{}')) then raise exception 'CAUSAL_BOTTLENECK_EVIDENCE_OUTSIDE_PACKET:%',eid using errcode='23514'; end if; end loop;
  end loop;
  if topb=0 or botb=0 then raise exception 'CAUSAL_BOTTLENECKS_MUST_COVER_BOTH_HALVES' using errcode='23514'; end if;
  if jsonb_typeof(new.second_pass_review)<>'object' or upper(coalesce(new.second_pass_review->>'status','')) not in ('PASS','CONDITIONED') then raise exception 'SECOND_PASS_REVIEW_REQUIRED' using errcode='23514'; end if;
  foreach rid in array array['what_lost_weight','what_gained_weight','double_count_check','dependency_check','best_supported_rival_check','thesis_threat','semantic_change_check'] loop if length(btrim(coalesce(new.second_pass_review->>rid,'')))<4 then raise exception 'SECOND_PASS_FIELD_REQUIRED:%',rid using errcode='23514'; end if; end loop;
  if jsonb_typeof(new.directional_bias_check)<>'object' or upper(coalesce(new.directional_bias_check->>'status','')) not in ('PASS','CONDITIONED') or lower(coalesce(new.directional_bias_check->>'searched_opposite_direction','false')) not in ('true','1','yes') or lower(coalesce(new.directional_bias_check->>'fabricated_balance','true')) not in ('false','0','no') then raise exception 'DIRECTIONAL_BIAS_CHECK_REQUIRED' using errcode='23514'; end if;
  if jsonb_typeof(new.epistemic_compression)<>'object' or upper(coalesce(new.epistemic_compression->>'status',''))<>'PASS' or lower(coalesce(new.epistemic_compression->>'metric_votes_forbidden','false')) not in ('true','1','yes') then raise exception 'EPISTEMIC_COMPRESSION_REQUIRED' using errcode='23514'; end if;
  if jsonb_typeof(new.semantic_reclassifications)<>'array' then raise exception 'SEMANTIC_RECLASSIFICATIONS_ARRAY_REQUIRED' using errcode='23514'; end if;
  for rid in select jsonb_array_elements_text(new.semantic_reclassifications) loop if not exists(select 1 from public.nrfimetrica_semantic_reclassification_events e where e.event_id=rid and e.sports_packet_id=new.packet_id and e.run_id=new.run_id and e.game_id=new.game_id) then raise exception 'SEMANTIC_RECLASSIFICATION_EVENT_NOT_FOUND:%',rid using errcode='23514'; end if; end loop;
  if jsonb_typeof(new.best_yrfi_rival)<>'object' or not public.nrfim_validate_materialization_path(new.best_yrfi_rival) then raise exception 'BEST_SUPPORTED_RIVAL_REPRESENTATION_INVALID' using errcode='23514'; end if;
  rival_evidence:=case when lower(coalesce(new.best_yrfi_rival->>'supported_rival','true')) in ('false','0','no') then coalesce(new.best_yrfi_rival->'evidence_ids','[]'::jsonb) else coalesce(new.best_yrfi_rival #> '{materialization_path,evidence_ids}','[]'::jsonb) end;
  for eid in select jsonb_array_elements_text(rival_evidence) loop if not eid=any(coalesce(new.evidence_ids,'{}')) or not exists(select 1 from public.evidence e where e.evidence_id=eid and e.run_id=new.run_id and e.game_id=new.game_id and e.kernel_attested) then raise exception 'BEST_RIVAL_EVIDENCE_NOT_IN_PACKET_OR_NOT_ATTESTED:%',eid using errcode='23514'; end if; end loop;
  return new;
end;
$$;

create or replace function public.nrfimetrica_assert_a8_lineage_v17(a8 jsonb,a7 jsonb)
returns void
language plpgsql
immutable
set search_path=public,pg_temp
as $$
declare line_key text; lb numeric; break_even numeric; decodds numeric; edge numeric; ev numeric; target text; elig text; finalv text; exauth text;
begin
  if upper(coalesce(a7->>'release_token',''))<>'ISSUED' or upper(coalesce(a8->>'a7_release_token',''))<>'ISSUED' then raise exception 'A8_RELEASE_BLOCKED' using errcode='23514'; end if;
  target:=upper(coalesce(a7->>'target_id',''));
  if target<>'U0.5' then raise exception 'A8_TARGET_SPECIFIC_CERTIFICATION_REQUIRED:%',target using errcode='23514'; end if;
  if upper(coalesce(a8->>'target_id',''))<>target then raise exception 'A8_TARGET_ID_LINEAGE_MISMATCH' using errcode='23514'; end if;
  elig:=upper(coalesce(a7->>'absolute_eligibility',''));
  if elig not in ('A7_ELIGIBLE','A7_ELIGIBLE_CONDITIONED') then raise exception 'A8_A7_ABSOLUTE_ELIGIBILITY_INVALID' using errcode='23514'; end if;
  if upper(coalesce(a8->>'a7_eligibility_status',''))<>elig then raise exception 'A8_A7_ELIGIBILITY_STATUS_LINEAGE_MISMATCH' using errcode='23514'; end if;
  if upper(coalesce(a7 #>> '{system_reliability,economic_effect}',''))='BLOCK' then raise exception 'A8_SYSTEM_RELIABILITY_BLOCKS_ECONOMIC_EXECUTION' using errcode='23514'; end if;
  if upper(coalesce(a8 #>> '{system_reliability,status}','')) is distinct from upper(coalesce(a7 #>> '{system_reliability,status}','')) then raise exception 'A8_SYSTEM_RELIABILITY_STATUS_LINEAGE_MISMATCH' using errcode='23514'; end if;
  if upper(coalesce(a8 #>> '{system_reliability,economic_effect}','')) is distinct from upper(coalesce(a7 #>> '{system_reliability,economic_effect}','')) then raise exception 'A8_SYSTEM_RELIABILITY_EFFECT_LINEAGE_MISMATCH' using errcode='23514'; end if;
  if lower(coalesce(a7 #>> '{press_integration,reanalysis_required}','false')) in ('true','1','yes') or coalesce((a7 #>> '{press_integration,unresolved_count}')::integer,0)>0 then raise exception 'A8_BLOCKED_PENDING_CAUSAL_REANALYSIS' using errcode='23514'; end if;
  line_key:=case upper(coalesce(a8->>'line_recommended','')) when 'NRFI' then 'u0_5' when 'U0.5' then 'u0_5' when 'U1.5' then 'u1_5' when 'U2.5' then 'u2_5' else null end;
  if line_key is null then raise exception 'A8_LINE_INVALID' using errcode='23514'; end if;
  if line_key<>'u0_5' then raise exception 'A8_TARGET_SPECIFIC_CERTIFICATION_REQUIRED:%',upper(coalesce(a8->>'line_recommended','')) using errcode='23514'; end if;
  if upper(coalesce(a8 #>> '{market,p_conservative_source}',''))<>'GAME_SPECIFIC_UNCERTAINTY_ONLY' then raise exception 'A8_P_CONSERVATIVE_SOURCE_MUST_BE_GAME_SPECIFIC' using errcode='23514'; end if;
  lb:=public.nrfim_json_num(a7,'game_uncertainty.'||line_key||'.lower_bound');
  if abs(public.nrfim_json_num(a8,'market.p_conservative')-lb)>0.000001 then raise exception 'A8_P_CONSERVATIVE_NOT_FROM_GAME_SPECIFIC_UNCERTAINTY' using errcode='23514'; end if;
  if abs(public.nrfim_json_num(a8,'game_specific_lower_bound')-lb)>0.000001 then raise exception 'A8_GAME_SPECIFIC_LOWER_BOUND_LINEAGE_MISMATCH' using errcode='23514'; end if;
  if a8 ? 'calibrated_p' or a8 ? 'historical_adjusted_p' then raise exception 'A8_HISTORICAL_GAME_PROBABILITY_OVERRIDE_FORBIDDEN' using errcode='23514'; end if;
  break_even:=public.nrfim_json_num(a8,'market.break_even'); decodds:=(a8 #>> '{market,decimal_odds}')::numeric; edge:=(a8 #>> '{market,edge}')::numeric; ev:=(a8 #>> '{market,ev}')::numeric;
  if decodds<=1 or abs(edge-(lb-break_even))>0.000001 or abs(ev-(lb*decodds-1))>0.000001 then raise exception 'A8_ROBUST_EDGE_MATH_FAIL' using errcode='23514'; end if;
  exauth:=upper(coalesce(a8->>'execution_authority','')); finalv:=upper(coalesce(a8->>'final_verdict',''));
  if exauth not in ('PASS','FAIL') then raise exception 'A8_EXECUTION_AUTHORITY_INVALID' using errcode='23514'; end if;
  if finalv not in ('APOSTAR','SOLO_SI_CUOTA','NO_APOSTAR','NON_EXECUTABLE') then raise exception 'A8_FINAL_VERDICT_INVALID' using errcode='23514'; end if;
  if finalv in ('APOSTAR','SOLO_SI_CUOTA') and exauth<>'PASS' then raise exception 'A8_BET_VERDICT_REQUIRES_EXECUTION_AUTHORITY_PASS' using errcode='23514'; end if;
  if exauth='PASS' and finalv not in ('APOSTAR','SOLO_SI_CUOTA') then raise exception 'A8_EXECUTION_PASS_REQUIRES_EXECUTABLE_VERDICT' using errcode='23514'; end if;
  if exauth='FAIL' and finalv in ('APOSTAR','SOLO_SI_CUOTA') then raise exception 'A8_EXECUTION_FAIL_CANNOT_RECOMMEND_BET' using errcode='23514'; end if;
end;
$$;

create or replace function public.nrfimetrica_assert_a8_game_specific_execution_v16(a8 jsonb,a7 jsonb)
returns void
language plpgsql
immutable
set search_path=public,pg_temp
as $$ begin perform public.nrfimetrica_assert_a8_lineage_v17(a8,a7); end; $$;

update public.protocol_phase_catalog
set required_fields=array['a7_release_token','a7_eligibility_status','target_id','verdict_emitted_at','probability.p0','probability.p1','probability.p2','probability.p3plus','line_recommended','market.sportsbook','market.line_exact','market.price_exact','market.decimal_odds','market.as_of','market.break_even','market.p_conservative','market.p_conservative_source','market.edge','market.ev','market.minimum_acceptable_price','market.offer_id','t5.revalidation_id','t5.active_freeze_id','t5.as_of','t5.starter_confirmed','t5.official_lineup_verified','t5.catcher_confirmed','t5.scratches_status','t5.roof_weather_critical_context','t5.contract_identity','t5.line_exact','t5.price_exact','t5.break_even','t5.primary_risk','t5.material_change','t5.recompute_status','ranking_state','execution_authority','primary_reason','primary_risk','final_verdict','phase_result','system_reliability.status','system_reliability.economic_effect','game_specific_lower_bound']
where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and phase_id='A8_MARKET_VALUE_EXECUTION';

create or replace function public.nrfimetrica_a8_separation_guard_v16()
returns trigger
language plpgsql
set search_path=public,extensions,pg_temp
as $$
declare a7 jsonb; sp public.sports_reasoning_packets%rowtype; start_at timestamptz; emitted timestamptz;
begin
  if new.protocol_id<>'NRFIMETRICA_MOTHER_V3_AUTONOMOUS' or new.phase_id<>'A8_MARKET_VALUE_EXECUTION' then return new; end if;
  select payload into a7 from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=new.protocol_id and phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS';
  if a7 is null then raise exception 'A8_A7_PAYLOAD_NOT_FOUND' using errcode='23514'; end if;
  perform public.nrfimetrica_assert_a8_game_specific_execution_v16(new.payload,a7);
  select * into sp from public.sports_reasoning_packets where run_id=new.run_id and game_id=new.game_id order by version desc limit 1;
  if not found or sp.status<>'ANALYSIS_COMPLETE' or sp.process_audit_status<>'PASS' or sp.drive_verified_at is null or sp.drive_content_hash is distinct from sp.packet_hash then raise exception 'A8_EXECUTION_REQUIRES_VERIFIED_SPORTS_PACKET_PROCESS_AND_DRIVE_HASH' using errcode='23514'; end if;
  if not public.nrfim_latest_bilateral_nrfi_valid(new.run_id,new.game_id) then raise exception 'A8_EXECUTION_REQUIRES_BILATERAL_CAUSAL_PROOF' using errcode='23514'; end if;
  select scheduled_start into start_at from public.games where run_id=new.run_id and game_id=new.game_id;
  begin emitted:=(new.payload->>'verdict_emitted_at')::timestamptz; exception when others then raise exception 'A8_VERDICT_EMITTED_AT_INVALID' using errcode='23514'; end;
  if start_at is null or emitted>start_at-interval '10 minutes' then raise exception 'A8_VERDICT_MUST_BE_EMITTED_BY_T_MINUS_10' using errcode='23514'; end if;
  return new;
end;
$$;

create or replace view public.nrfimetrica_game_dual_status as
with latest_packet as (
  select distinct on (s.run_id,s.game_id) s.run_id,s.game_id,s.packet_id,s.status packet_status,s.sports_verdict,s.process_audit_status,s.packet_hash,s.drive_content_hash,s.drive_verified_at,s.evidence_ids,s.top_half_verdict,s.bottom_half_verdict
  from public.sports_reasoning_packets s order by s.run_id,s.game_id,s.version desc
), base as (
  select lp.*, exists(select 1 from public.evidence e where e.run_id=lp.run_id and e.game_id=lp.game_id and e.evidence_id=any(coalesce(lp.evidence_ids,'{}'))) basic_data_present,
         public.nrfim_latest_bilateral_nrfi_valid(lp.run_id,lp.game_id) bilateral_nrfi_proven
  from latest_packet lp
), a7 as (select run_id,game_id,payload from public.protocol_phase_state where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS'),
a8 as (select run_id,game_id,payload from public.protocol_phase_state where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and phase_id='A8_MARKET_VALUE_EXECUTION'),
res as (select run_id,game_id,resolution_code,authority_level,reason from public.protocol_game_resolution where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS')
select g.run_id,g.game_id,g.status game_status,b.packet_id,b.packet_status,b.sports_verdict,b.process_audit_status,
       (b.drive_verified_at is not null and b.drive_content_hash=b.packet_hash) drive_hash_verified,
       case when g.status='AUDIT_ONLY' then 'AUDIT_ONLY' when b.sports_verdict='NRFI_LEAN' and b.basic_data_present and b.bilateral_nrfi_proven then 'SPORTS_CANDIDATE' when b.sports_verdict in ('YRFI_LEAN','NO_PLAY','NEUTRAL') and b.basic_data_present then 'NO_PLAY' else 'WATCHLIST' end sports_status,
       case when g.status='AUDIT_ONLY' then 'AUDIT_ONLY'
            when b.sports_verdict='NRFI_LEAN' and b.basic_data_present and not coalesce(b.bilateral_nrfi_proven,false) then 'WATCHLIST'
            when b.sports_verdict='NRFI_LEAN' and b.basic_data_present and b.bilateral_nrfi_proven and res.resolution_code in ('A4_ENGINE_NOT_INTEGRATED','A4_TRUE_MODEL_FAILURE','A6_INDEPENDENT_AUDIT_UNAVAILABLE','A7_NOT_ELIGIBLE','A7_RESEARCH_ONLY','A7_MODEL_AUDIT_REQUIRED','A7_SYSTEM_RELIABILITY_BLOCK','A7_PRESS_INTEGRATION_UNRESOLVED','A7_CALIBRATION_UNCERTIFIED','A7_PRESS_UNAVAILABLE') then 'TECHNICAL_BLOCK'
            when b.sports_verdict='NRFI_LEAN' and b.basic_data_present and b.bilateral_nrfi_proven and not (b.packet_status='ANALYSIS_COMPLETE' and b.process_audit_status='PASS' and b.drive_verified_at is not null and b.drive_content_hash=b.packet_hash) then 'PROCESS_BLOCK'
            when b.sports_verdict='NRFI_LEAN' and b.basic_data_present and b.bilateral_nrfi_proven and a7.payload is null then 'PENDING'
            when b.sports_verdict='NRFI_LEAN' and b.basic_data_present and b.bilateral_nrfi_proven and (upper(coalesce(a7.payload->>'release_token',''))<>'ISSUED' or upper(coalesce(a7.payload->>'absolute_eligibility','')) not in ('A7_ELIGIBLE','A7_ELIGIBLE_CONDITIONED') or upper(coalesce(a7.payload #>> '{system_reliability,economic_effect}',''))='BLOCK' or lower(coalesce(a7.payload #>> '{press_integration,reanalysis_required}','false')) in ('true','1','yes') or coalesce((a7.payload #>> '{press_integration,unresolved_count}')::integer,0)>0 or upper(coalesce(a7.payload->>'target_id',''))<>'U0.5') then 'TECHNICAL_BLOCK'
            when b.sports_verdict='NRFI_LEAN' and b.basic_data_present and b.bilateral_nrfi_proven and a8.payload is null then 'PENDING'
            when b.sports_verdict='NRFI_LEAN' and b.basic_data_present and b.bilateral_nrfi_proven and upper(coalesce(a8.payload->>'a7_release_token',''))='ISSUED' and upper(coalesce(a8.payload->>'a7_eligibility_status',''))=upper(coalesce(a7.payload->>'absolute_eligibility','')) and upper(coalesce(a8.payload->>'target_id',''))='U0.5' and upper(coalesce(a8.payload->>'line_recommended','')) in ('NRFI','U0.5') and upper(coalesce(a8.payload->>'execution_authority',''))='PASS' and upper(coalesce(a8.payload->>'final_verdict','')) in ('APOSTAR','SOLO_SI_CUOTA') then 'EXECUTABLE'
            when b.sports_verdict='NRFI_LEAN' and b.basic_data_present and b.bilateral_nrfi_proven then 'NOT_EXECUTABLE'
            when b.sports_verdict in ('YRFI_LEAN','NO_PLAY','NEUTRAL') and b.basic_data_present then 'NOT_APPLICABLE' else 'WATCHLIST' end execution_status,
       res.resolution_code technical_resolution_code,res.reason technical_resolution_reason,
       case when g.status='AUDIT_ONLY' then 'NOT_APPLICABLE' when b.packet_id is null then 'MISSING' when b.packet_status='ANALYSIS_COMPLETE' and b.process_audit_status='PASS' and b.drive_verified_at is not null and b.drive_content_hash=b.packet_hash then 'VERIFIED' when b.packet_status='PROCESS_FAIL' or b.process_audit_status='FAIL' then 'FAIL' when b.process_audit_status='REVIEW' then 'REVIEW' when b.drive_verified_at is null or b.drive_content_hash is distinct from b.packet_hash then 'UNVERIFIED' when b.packet_status in ('RESEARCH_INCOMPLETE','INFORMATION_UNAVAILABLE','WITHDRAWN_POST_FREEZE') then 'INCOMPLETE' else 'PENDING' end process_status,
       b.top_half_verdict,b.bottom_half_verdict,coalesce(b.bilateral_nrfi_proven,false) bilateral_nrfi_proven,
       case when b.sports_verdict='NRFI_LEAN' and not coalesce(b.bilateral_nrfi_proven,false) then 'REQUIRES_BILATERAL_REEVALUATION' else 'CURRENT_RULE_OK' end bilateral_rule_status
from public.games g left join base b on b.run_id=g.run_id and b.game_id=g.game_id left join a7 on a7.run_id=g.run_id and a7.game_id=g.game_id left join a8 on a8.run_id=g.run_id and a8.game_id=g.game_id left join res on res.run_id=g.run_id and res.game_id=g.game_id;

create or replace view public.nrfimetrica_user_action as
select run_id,game_id,game_status,packet_id,packet_status,sports_verdict,process_audit_status,drive_hash_verified,sports_status,execution_status,technical_resolution_code,technical_resolution_reason,process_status,top_half_verdict,bottom_half_verdict,bilateral_nrfi_proven,bilateral_rule_status,
       public.nrfim_latest_bilateral_nrfi_valid(run_id,game_id) bilateral_1_1_valid,
       case when execution_status='EXECUTABLE' and process_status='VERIFIED' and drive_hash_verified and public.nrfim_latest_bilateral_nrfi_valid(run_id,game_id) then 'BET_APPROVED' when sports_verdict='NRFI_LEAN' and not public.nrfim_latest_bilateral_nrfi_valid(run_id,game_id) then 'REANALYSIS_REQUIRED_DO_NOT_BET' when sports_status='SPORTS_CANDIDATE' then 'RESEARCH_CANDIDATE_DO_NOT_BET' else 'DO_NOT_BET' end user_action,
       (execution_status='EXECUTABLE' and process_status='VERIFIED' and drive_hash_verified and public.nrfim_latest_bilateral_nrfi_valid(run_id,game_id)) bet_allowed
from public.nrfimetrica_game_dual_status;

alter table public.nrfimetrica_system_calibration_audits enable row level security;
do $$ declare r record; begin
  for r in select p.oid::regprocedure::text sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and (p.proname like 'nrfimetrica_%' or p.proname like 'nrfim_%' or p.proname like 'enforce_nrfimetrica_%') loop
    execute format('alter function %s set search_path = public, extensions, pg_temp',r.sig);
    execute format('revoke execute on function %s from public, anon, authenticated',r.sig);
    execute format('grant execute on function %s to service_role',r.sig);
  end loop;
end $$;
