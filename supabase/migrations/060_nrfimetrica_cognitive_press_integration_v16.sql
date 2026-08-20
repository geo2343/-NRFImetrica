-- @NRFImetrica Agent 1.11 / Kernel 1.6
-- Cognitive contract + A7/A8 no-override architecture.
-- This migration modifies only @NRFImetrica.

alter table public.sports_reasoning_packets add column if not exists cognitive_contract_version text;
alter table public.sports_reasoning_packets add column if not exists press_intake_id text;
alter table public.sports_reasoning_packets add column if not exists provisional_representation jsonb not null default '{}'::jsonb;
alter table public.sports_reasoning_packets add column if not exists autonomous_questions jsonb not null default '[]'::jsonb;
alter table public.sports_reasoning_packets add column if not exists second_pass_review jsonb not null default '{}'::jsonb;
alter table public.sports_reasoning_packets add column if not exists causal_bottlenecks jsonb not null default '[]'::jsonb;
alter table public.sports_reasoning_packets add column if not exists directional_bias_check jsonb not null default '{}'::jsonb;
alter table public.sports_reasoning_packets add column if not exists epistemic_compression jsonb not null default '{}'::jsonb;
alter table public.sports_reasoning_packets add column if not exists semantic_reclassifications jsonb not null default '[]'::jsonb;
alter table public.sports_reasoning_packets add column if not exists press_disposition_summary jsonb not null default '{}'::jsonb;

do $$ begin
 if not exists(select 1 from pg_constraint where conname='sports_reasoning_packets_press_intake_fk') then
   alter table public.sports_reasoning_packets add constraint sports_reasoning_packets_press_intake_fk foreign key(press_intake_id) references public.nrfimetrica_press_intakes(intake_id);
 end if;
end $$;

create table if not exists public.nrfimetrica_semantic_reclassification_events (
 event_id text primary key,
 run_id text not null references public.runs(run_id) on delete cascade,
 game_id text not null,
 sports_packet_id text not null references public.sports_reasoning_packets(packet_id) on delete cascade,
 changed_object text not null,
 old_meaning text not null,
 new_meaning text not null,
 trigger_evidence_ids text[] not null default '{}'::text[],
 affected_claim_ids text[] not null default '{}'::text[],
 changed_claim_ids text[] not null default '{}'::text[],
 unchanged_claim_ids text[] not null default '{}'::text[],
 propagation_stop_reason text not null,
 created_at timestamptz not null default now(),
 check(length(btrim(changed_object))>=3),
 check(length(btrim(old_meaning))>=5),
 check(length(btrim(new_meaning))>=5),
 check(length(btrim(propagation_stop_reason))>=8)
);

create or replace function public.nrfimetrica_enforce_semantic_reclassification_event()
returns trigger language plpgsql set search_path=public,pg_temp as $$
declare sp public.sports_reasoning_packets%rowtype; eid text; cid text;
begin
 if tg_op='INSERT' and coalesce(new.event_id,'')='' then new.event_id:='SRE-'||replace(gen_random_uuid()::text,'-',''); end if;
 select * into sp from public.sports_reasoning_packets where packet_id=new.sports_packet_id;
 if not found or sp.run_id<>new.run_id or sp.game_id<>new.game_id then raise exception 'SEMANTIC_RECLASSIFICATION_PACKET_IDENTITY_MISMATCH' using errcode='23514'; end if;
 if sp.freeze_timestamp is not null then raise exception 'SEMANTIC_RECLASSIFICATION_AFTER_PACKET_FREEZE_FORBIDDEN' using errcode='23514'; end if;
 foreach eid in array coalesce(new.trigger_evidence_ids,'{}') loop
   if not exists(select 1 from public.evidence e where e.evidence_id=eid and e.run_id=new.run_id and e.game_id=new.game_id and e.kernel_attested) then raise exception 'SEMANTIC_RECLASSIFICATION_EVIDENCE_INVALID:%',eid using errcode='23514'; end if;
 end loop;
 foreach cid in array coalesce(new.affected_claim_ids,'{}') loop
   if not exists(select 1 from public.sports_reasoning_claims c where c.claim_id=cid and c.packet_id=new.sports_packet_id and c.run_id=new.run_id and c.game_id=new.game_id) then raise exception 'SEMANTIC_RECLASSIFICATION_CLAIM_INVALID:%',cid using errcode='23514'; end if;
 end loop;
 return new;
end; $$;

drop trigger if exists trg_nrfimetrica_semantic_reclassification_event on public.nrfimetrica_semantic_reclassification_events;
create trigger trg_nrfimetrica_semantic_reclassification_event before insert or update on public.nrfimetrica_semantic_reclassification_events for each row execute function public.nrfimetrica_enforce_semantic_reclassification_event();

create or replace function public.nrfimetrica_assert_a7_no_external_override_v16(a7 jsonb)
returns void language plpgsql immutable set search_path=public,pg_temp as $$
begin
 if upper(coalesce(a7->>'calibration_role',''))<>'SYSTEM_AUDIT_ONLY' then raise exception 'A7_CALIBRATION_ROLE_MUST_BE_SYSTEM_AUDIT_ONLY' using errcode='23514'; end if;
 if lower(coalesce(a7->>'calibration_game_override','true')) not in ('false','0','no') or lower(coalesce(a7->>'calibration_sports_authority','true')) not in ('false','0','no') or lower(coalesce(a7->>'calibration_ranking_authority','true')) not in ('false','0','no') then raise exception 'A7_HISTORICAL_CALIBRATION_HAS_FORBIDDEN_GAME_AUTHORITY' using errcode='23514'; end if;
 if upper(coalesce(a7 #>> '{system_reliability,sports_effect}',''))<>'NONE' or upper(coalesce(a7 #>> '{system_reliability,ranking_effect}',''))<>'NONE' or upper(coalesce(a7 #>> '{system_reliability,probability_effect}',''))<>'NONE' then raise exception 'A7_SYSTEM_CALIBRATION_CANNOT_CHANGE_GAME_SPORTS_OR_PROBABILITY' using errcode='23514'; end if;
 if upper(coalesce(a7 #>> '{press_integration,sports_effect}',''))<>'NONE' or upper(coalesce(a7 #>> '{press_integration,probability_effect}',''))<>'NONE' or upper(coalesce(a7 #>> '{press_integration,ranking_effect}',''))<>'NONE' then raise exception 'A7_PRESS_INTEGRATION_HAS_FORBIDDEN_DIRECT_EFFECT' using errcode='23514'; end if;
 if upper(coalesce(a7->>'sports_verdict_effect',''))<>'NONE' then raise exception 'A7_CANNOT_REFORMULATE_SPORTS_VERDICT' using errcode='23514'; end if;
 if a7 ? 'reformulated_verdict' or a7 ? 'contrast_effect' or a7 ? 'calibrated_p' or a7 ? 'historical_adjusted_p' then raise exception 'A7_EXTERNAL_OR_HISTORICAL_GAME_OVERRIDE_FORBIDDEN' using errcode='23514'; end if;
end; $$;

create or replace function public.nrfimetrica_assert_press_reanalysis_gate_v16(a7 jsonb)
returns void language plpgsql immutable set search_path=public,pg_temp as $$
begin
 if lower(coalesce(a7 #>> '{press_integration,reanalysis_required}','false')) in ('true','1','yes') and upper(coalesce(a7->>'release_token',''))='ISSUED' then raise exception 'A7_RELEASE_BLOCKED_PENDING_CAUSAL_REANALYSIS' using errcode='23514'; end if;
end; $$;

create or replace function public.nrfimetrica_cognitive_packet_guard_v16()
returns trigger language plpgsql set search_path=public,pg_temp as $$
declare pstate public.protocol_phase_state%rowtype; intake public.nrfimetrica_press_intakes%rowtype; item_count integer:=0; disposition_count integer:=0; x jsonb; topb integer:=0; botb integer:=0; eid text; rid text;
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
   if upper(coalesce(new.press_disposition_summary->>'sports_authority',''))<>'NONE' or upper(coalesce(new.press_disposition_summary->>'probability_authority',''))<>'NONE' or upper(coalesce(new.press_disposition_summary->>'ranking_authority',''))<>'NONE' then raise exception 'PRESS_DISPOSITION_SUMMARY_FORBIDDEN_AUTHORITY' using errcode='23514'; end if;
 else
   if new.press_intake_id is not null then raise exception 'A0P_SKIPPED_PACKET_CANNOT_BIND_PRESS_INTAKE' using errcode='23514'; end if;
 end if;
 if jsonb_typeof(new.provisional_representation)<>'object' or length(btrim(coalesce(new.provisional_representation->>'representation_class','')))<4 or length(btrim(coalesce(new.provisional_representation->>'working_hypothesis','')))<8 or upper(coalesce(new.provisional_representation->>'revision_status',''))<>'REVISABLE' then raise exception 'PROVISIONAL_REPRESENTATION_REQUIRED_AND_REVISABLE' using errcode='23514'; end if;
 if lower(coalesce(new.provisional_representation->>'inherited_press_conclusion','true')) not in ('false','0','no') then raise exception 'PROVISIONAL_REPRESENTATION_CANNOT_INHERIT_PRESS_CONCLUSION' using errcode='23514'; end if;
 if jsonb_typeof(new.autonomous_questions)<>'array' or exists(select 1 from jsonb_array_elements(new.autonomous_questions) q where length(btrim(coalesce(q->>'question','')))<8 or upper(coalesce(q->>'status','')) not in ('ANSWERED','OPEN_NON_GOVERNING','NOT_TRIGGERED')) then raise exception 'AUTONOMOUS_QUESTIONS_INVALID' using errcode='23514'; end if;
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
 if jsonb_typeof(new.best_yrfi_rival)<>'object' or not public.nrfim_validate_materialization_path(new.best_yrfi_rival) then raise exception 'BEST_SUPPORTED_YRFI_RIVAL_WITH_MATERIALIZATION_REQUIRED' using errcode='23514'; end if;
 if lower(coalesce(new.best_yrfi_rival->>'supported_rival','false')) not in ('true','1','yes') then raise exception 'BEST_YRFI_RIVAL_MUST_BE_SUPPORTED_NOT_IMAGINED' using errcode='23514'; end if;
 return new;
end; $$;

drop trigger if exists trg_00y_nrfimetrica_cognitive_packet_v16 on public.sports_reasoning_packets;
create trigger trg_00y_nrfimetrica_cognitive_packet_v16 before insert or update on public.sports_reasoning_packets for each row execute function public.nrfimetrica_cognitive_packet_guard_v16();

create or replace function public.nrfimetrica_a7_press_integration_guard_v16()
returns trigger language plpgsql set search_path=public,extensions,pg_temp as $$
declare p text:='NRFIMETRICA_MOTHER_V3_AUTONOMOUS'; a1 jsonb; a4 jsonb; a5 jsonb; a6 jsonb; a0p public.protocol_phase_state%rowtype; intake public.nrfimetrica_press_intakes%rowtype; sp public.sports_reasoning_packets%rowtype; item_count integer:=0; disposition_count integer:=0; unresolved integer:=0; raw0 numeric; raw1 numeric; raw2 numeric; rel_status text; econ_effect text;
begin
 if new.protocol_id<>p or new.phase_id<>'A7_CALIBRATION_ELIGIBILITY_PRESS' then return new; end if;
 perform public.nrfimetrica_assert_a7_no_external_override_v16(new.payload); perform public.nrfimetrica_assert_press_reanalysis_gate_v16(new.payload);
 select payload into a1 from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=p and phase_id='A1_DATA_INTEGRITY_FREEZE';
 select payload into a4 from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=p and phase_id='A4_NUMERIC_STATE_ENGINE';
 select payload into a5 from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=p and phase_id='A5_JOINT_INTEGRATION';
 select payload into a6 from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=p and phase_id='A6_CAUSAL_FALSIFICATION_SPORTS_SEAL';
 if a1 is null or a4 is null or a5 is null or a6 is null then raise exception 'A7_CAUSAL_LINEAGE_INCOMPLETE' using errcode='23514'; end if;
 if new.payload->>'input_freeze_id' is distinct from a1->>'input_freeze_id' then raise exception 'A7_FREEZE_LINEAGE_MISMATCH' using errcode='23514'; end if;
 if new.payload->>'a4_execution_id' is distinct from a4 #>> '{numeric_engine,execution_id}' then raise exception 'A7_A4_EXECUTION_LINEAGE_MISMATCH' using errcode='23514'; end if;
 raw0:=public.nrfim_json_num(a5,'contracts.p_u0_5'); raw1:=public.nrfim_json_num(a5,'contracts.p_u1_5'); raw2:=public.nrfim_json_num(a5,'contracts.p_u2_5');
 if abs(public.nrfim_json_num(new.payload,'game_causal_p')-raw0)>0.000001 then raise exception 'A7_GAME_CAUSAL_P_NOT_FROM_A5' using errcode='23514'; end if;
 if upper(coalesce(new.payload->>'game_probability_source',''))<>'A5_GAME_CAUSAL_ONLY' or upper(coalesce(new.payload->>'eligibility_basis',''))<>'GAME_CAUSAL_ONLY' then raise exception 'A7_GAME_PROBABILITY_AND_ELIGIBILITY_MUST_BE_CAUSAL_ONLY' using errcode='23514'; end if;
 if lower(coalesce(new.payload #>> '{game_uncertainty,historical_calibration_used}','true')) not in ('false','0','no') then raise exception 'A7_GAME_UNCERTAINTY_CANNOT_USE_HISTORICAL_CALIBRATION' using errcode='23514'; end if;
 if upper(coalesce(new.payload #>> '{game_uncertainty,u0_5,source}',''))<>'GAME_SPECIFIC_STRESS_TEST' or upper(coalesce(new.payload #>> '{game_uncertainty,u1_5,source}',''))<>'GAME_SPECIFIC_STRESS_TEST' or upper(coalesce(new.payload #>> '{game_uncertainty,u2_5,source}',''))<>'GAME_SPECIFIC_STRESS_TEST' then raise exception 'A7_CONSERVATIVE_BOUNDS_MUST_BE_GAME_SPECIFIC' using errcode='23514'; end if;
 if public.nrfim_json_num(new.payload,'game_uncertainty.u0_5.lower_bound')>raw0 or public.nrfim_json_num(new.payload,'game_uncertainty.u1_5.lower_bound')>raw1 or public.nrfim_json_num(new.payload,'game_uncertainty.u2_5.lower_bound')>raw2 then raise exception 'A7_GAME_UNCERTAINTY_LOWER_BOUND_ABOVE_CENTRAL' using errcode='23514'; end if;
 rel_status:=upper(coalesce(new.payload #>> '{system_reliability,status}','')); econ_effect:=upper(coalesce(new.payload #>> '{system_reliability,economic_effect}',''));
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
   select * into intake from public.nrfimetrica_press_intakes where intake_id=a0p.payload->>'intake_id'; if not found then raise exception 'A7_PRESS_INTAKE_NOT_FOUND' using errcode='23514'; end if;
   if new.payload #>> '{press_integration,intake_id}' is distinct from intake.intake_id or sp.press_intake_id is distinct from intake.intake_id then raise exception 'A7_PRESS_INTAKE_LINEAGE_MISMATCH' using errcode='23514'; end if;
   select count(*) into item_count from public.nrfimetrica_press_items where intake_id=intake.intake_id; select count(*) into disposition_count from public.nrfimetrica_press_item_dispositions where intake_id=intake.intake_id and sports_packet_id=sp.packet_id; select count(*) into unresolved from public.nrfimetrica_press_item_dispositions where intake_id=intake.intake_id and sports_packet_id=sp.packet_id and disposition='UNRESOLVED';
   if item_count<>disposition_count then raise exception 'A7_PRESS_DISPOSITIONS_INCOMPLETE:%/%',disposition_count,item_count using errcode='23514'; end if;
   if coalesce((new.payload #>> '{press_integration,unresolved_count}')::integer,-1)<>unresolved then raise exception 'A7_PRESS_UNRESOLVED_COUNT_MISMATCH' using errcode='23514'; end if;
   if lower(coalesce(new.payload #>> '{press_integration,disposition_complete}','false')) not in ('true','1','yes') then raise exception 'A7_PRESS_DISPOSITION_COMPLETE_REQUIRED' using errcode='23514'; end if;
 else
   if nullif(new.payload #>> '{press_integration,intake_id}','') is not null then raise exception 'A7_SKIPPED_A0P_CANNOT_HAVE_INTAKE_ID' using errcode='23514'; end if;
   if coalesce((new.payload #>> '{press_integration,unresolved_count}')::integer,-1)<>0 then raise exception 'A7_SKIPPED_A0P_UNRESOLVED_MUST_BE_ZERO' using errcode='23514'; end if;
 end if;
 if upper(coalesce(new.payload->>'release_token',''))='ISSUED' then
   if upper(coalesce(new.payload->>'absolute_eligibility','')) not in ('A7_ELIGIBLE','A7_ELIGIBLE_CONDITIONED') then raise exception 'A7_RELEASE_REQUIRES_GAME_CAUSAL_ELIGIBILITY' using errcode='23514'; end if;
   if econ_effect='BLOCK' then raise exception 'A7_RELEASE_BLOCKED_BY_SYSTEM_RELIABILITY_AUDIT' using errcode='23514'; end if;
 elsif upper(coalesce(new.payload->>'release_token','')) not in ('NOT_ISSUED','BLOCKED','N/A','NA') then raise exception 'A7_RELEASE_TOKEN_INVALID' using errcode='23514'; end if;
 return new;
end; $$;

drop trigger if exists trg_036_nrfimetrica_a7_press_integration_v16 on public.protocol_phase_state;
create trigger trg_036_nrfimetrica_a7_press_integration_v16 before insert or update on public.protocol_phase_state for each row when (new.protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and new.phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS') execute function public.nrfimetrica_a7_press_integration_guard_v16();

create or replace function public.nrfimetrica_a8_separation_guard_v16()
returns trigger language plpgsql set search_path=public,pg_temp as $$
declare a7 jsonb; line_key text; lb numeric; break_even numeric; decodds numeric; edge numeric; ev numeric;
begin
 if new.protocol_id<>'NRFIMETRICA_MOTHER_V3_AUTONOMOUS' or new.phase_id<>'A8_MARKET_VALUE_EXECUTION' then return new; end if;
 select payload into a7 from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=new.protocol_id and phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS';
 if a7 is null or upper(coalesce(a7->>'release_token',''))<>'ISSUED' or upper(coalesce(new.payload->>'a7_release_token',''))<>'ISSUED' then raise exception 'A8_RELEASE_BLOCKED' using errcode='23514'; end if;
 if upper(coalesce(a7 #>> '{system_reliability,economic_effect}',''))='BLOCK' then raise exception 'A8_SYSTEM_RELIABILITY_BLOCKS_ECONOMIC_EXECUTION' using errcode='23514'; end if;
 if upper(coalesce(new.payload #>> '{system_reliability,status}','')) is distinct from upper(coalesce(a7 #>> '{system_reliability,status}','')) then raise exception 'A8_SYSTEM_RELIABILITY_STATUS_LINEAGE_MISMATCH' using errcode='23514'; end if;
 if upper(coalesce(new.payload #>> '{system_reliability,economic_effect}','')) is distinct from upper(coalesce(a7 #>> '{system_reliability,economic_effect}','')) then raise exception 'A8_SYSTEM_RELIABILITY_EFFECT_LINEAGE_MISMATCH' using errcode='23514'; end if;
 if lower(coalesce(a7 #>> '{press_integration,reanalysis_required}','false')) in ('true','1','yes') then raise exception 'A8_BLOCKED_PENDING_CAUSAL_REANALYSIS' using errcode='23514'; end if;
 line_key:=case upper(coalesce(new.payload->>'line_recommended','')) when 'NRFI' then 'u0_5' when 'U0.5' then 'u0_5' when 'U1.5' then 'u1_5' when 'U2.5' then 'u2_5' else null end;
 if line_key is null then raise exception 'A8_LINE_INVALID' using errcode='23514'; end if;
 if upper(coalesce(new.payload #>> '{market,p_conservative_source}',''))<>'GAME_SPECIFIC_UNCERTAINTY_ONLY' then raise exception 'A8_P_CONSERVATIVE_SOURCE_MUST_BE_GAME_SPECIFIC' using errcode='23514'; end if;
 lb:=public.nrfim_json_num(a7,'game_uncertainty.'||line_key||'.lower_bound');
 if abs(public.nrfim_json_num(new.payload,'market.p_conservative')-lb)>0.000001 then raise exception 'A8_P_CONSERVATIVE_NOT_FROM_GAME_SPECIFIC_UNCERTAINTY' using errcode='23514'; end if;
 if abs(public.nrfim_json_num(new.payload,'game_specific_lower_bound')-lb)>0.000001 then raise exception 'A8_GAME_SPECIFIC_LOWER_BOUND_LINEAGE_MISMATCH' using errcode='23514'; end if;
 if new.payload ? 'calibrated_p' or new.payload ? 'historical_adjusted_p' then raise exception 'A8_HISTORICAL_GAME_PROBABILITY_OVERRIDE_FORBIDDEN' using errcode='23514'; end if;
 break_even:=public.nrfim_json_num(new.payload,'market.break_even'); decodds:=(new.payload #>> '{market,decimal_odds}')::numeric; edge:=(new.payload #>> '{market,edge}')::numeric; ev:=(new.payload #>> '{market,ev}')::numeric;
 if decodds<=1 or abs(edge-(lb-break_even))>0.000001 or abs(ev-(lb*decodds-1))>0.000001 then raise exception 'A8_ROBUST_EDGE_MATH_FAIL' using errcode='23514'; end if;
 return new;
end; $$;

drop trigger if exists trg_037_nrfimetrica_a8_separation_v16 on public.protocol_phase_state;
create trigger trg_037_nrfimetrica_a8_separation_v16 before insert or update on public.protocol_phase_state for each row when (new.protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and new.phase_id='A8_MARKET_VALUE_EXECUTION') execute function public.nrfimetrica_a8_separation_guard_v16();

update public.protocol_phase_catalog set required_fields=array_replace(array_replace(array_replace(array_replace(array_replace(required_fields,'pre_press_verdict.frozen','sports_verdict.frozen'),'pre_press_verdict.hash','sports_verdict.hash'),'pre_press_verdict.central_under_case','sports_verdict.central_under_case'),'pre_press_verdict.best_yrfi_rival','sports_verdict.best_yrfi_rival'),'pre_press_verdict.status','sports_verdict.status') where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and phase_id='A6_CAUSAL_FALSIFICATION_SPORTS_SEAL';
update public.protocol_phase_catalog set required_fields=array_replace(required_fields,'raw_p','game_causal_p') where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS';
update public.protocol_phase_catalog set required_fields=(select array_agg(x order by ord) from (select x,ord from unnest(required_fields) with ordinality u(x,ord) where x<>'calibration_status' union all select 'system_reliability.status',1000001 union all select 'system_reliability.economic_effect',1000002 union all select 'game_specific_lower_bound',1000003) q) where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and phase_id='A8_MARKET_VALUE_EXECUTION';

alter table public.nrfimetrica_semantic_reclassification_events enable row level security;
revoke all on public.nrfimetrica_semantic_reclassification_events from anon,authenticated;
grant select,insert,update,delete on public.nrfimetrica_semantic_reclassification_events to service_role;
