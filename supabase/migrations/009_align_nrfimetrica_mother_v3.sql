-- @NRFImetrica mother-document alignment.
-- Authority: mother document SHA-256 d16896eba602af272117a5c83b56245aa201979d394301781d424e705b3642d3
-- Latest sovereign patch: A0-GOV.18 — REFORMA OPERATIVA SOBERANA V3.
-- This migration mirrors the live production migration applied to Supabase.

create table if not exists public.protocol_authority (
  protocol_id text primary key,
  authority_name text not null,
  document_sha256 text not null,
  document_lines integer not null,
  precedence_rule text not null,
  latest_sovereign_patch text not null,
  manual_phase_authorization_required boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.protocol_authority enable row level security;

insert into public.protocol_authority(
  protocol_id, authority_name, document_sha256, document_lines,
  precedence_rule, latest_sovereign_patch, manual_phase_authorization_required, active
) values (
  'NRFIMETRICA_MOTHER_V3_AUTONOMOUS',
  '@NRFImetrica DOCUMENTO MADRE',
  'd16896eba602af272117a5c83b56245aa201979d394301781d424e705b3642d3',
  15570,
  'LATEST_SOVEREIGN_PATCH_WINS',
  'A0-GOV.18 — REFORMA OPERATIVA SOBERANA V3',
  false,
  true
)
on conflict (protocol_id) do update set
  authority_name=excluded.authority_name,
  document_sha256=excluded.document_sha256,
  document_lines=excluded.document_lines,
  precedence_rule=excluded.precedence_rule,
  latest_sovereign_patch=excluded.latest_sovereign_patch,
  manual_phase_authorization_required=excluded.manual_phase_authorization_required,
  active=true;

create table if not exists public.protocol_run_state (
  id uuid primary key default gen_random_uuid(),
  run_id text not null references public.runs(run_id) on delete cascade,
  protocol_id text not null,
  stage_id text not null,
  status text not null default 'COMPLETE',
  payload jsonb not null default '{}'::jsonb,
  evidence_ids text[] not null default '{}',
  output_text text not null default '',
  submitted_at timestamptz not null default now(),
  unique(run_id, protocol_id, stage_id)
);
alter table public.protocol_run_state enable row level security;
create index if not exists idx_protocol_run_state_run on public.protocol_run_state(run_id, protocol_id);

insert into public.protocol_phase_catalog(
  protocol_id,phase_id,conditional,trigger_path,required_fields,
  min_source_calls,min_evidence_ids,required_documents,required_phrases,max_items
) values
(
 'NRFIMETRICA_MOTHER_V3_AUTONOMOUS','A1_DATA_INTEGRITY_FREEZE',false,null,
 array[
 'model_version','as_of','data_available_at','input_freeze_id','target_scope','targets_enabled',
 'game.game_id','game.date','game.start_time','game.status','game.venue',
 'first_inning_pitcher.away.name','first_inning_pitcher.away.status','first_inning_pitcher.away.role','first_inning_pitcher.away.hand',
 'first_inning_pitcher.home.name','first_inning_pitcher.home.status','first_inning_pitcher.home.role','first_inning_pitcher.home.hand',
 'lineup.away.state','lineup.away.order_1_9','lineup.home.state','lineup.home.order_1_9',
 'catcher.away.status','catcher.home.status','umpire.status','park','roof.status','weather.status','weather.materiality',
 'scratches_status','injury_restriction_status','governing_unknowns','material_unknowns','data_source_map','conflict_log',
 'market_quarantine','market_contamination_flag','post_first_pitch_contamination','temporal_integrity','freeze_integrity',
 'sra_freeze_status','research_handoff','a1_real_money_status','hard_gates','phase_result'
 ],1,1,'{}','{}','{}'::jsonb
),
(
 'NRFIMETRICA_MOTHER_V3_AUTONOMOUS','A2_HIERARCHICAL_BASELINES',false,null,
 array[
 'input_freeze_id','baseline_spec_version','pitcher_priors.away','pitcher_priors.home',
 'batter_priors.away_b1_b5','batter_priors.home_b1_b5','out_creation_baseline','free_traffic_baseline','contact_damage_baseline',
 'platoon_shrinkage','sample_states','dependency_clusters','double_count_check','baseline_provenance',
 'sra.baseline_comparison','sra.shrinkage','central_baseline_case','strongest_baseline_rival','questions_for_a3',
 'market_blindness','hard_gates','a2_baseline_status','phase_result'
 ],0,1,'{}','{}','{}'::jsonb
),
(
 'NRFIMETRICA_MOTHER_V3_AUTONOMOUS','A3_CURRENT_VERSION_MATCHUP',false,null,
 array[
 'input_freeze_id','a2_baseline_spec_version','a3_spec_version','current_version.away_pitcher','current_version.home_pitcher',
 'current_version.hitters','current_version_evidence_ids','matchup.b1_b3','matchup.b4_b5_conditional',
 'out_creation_updated_state','free_traffic_updated_state','contact_damage_updated_state','execution_state','arsenal_expectation','location_access',
 'first_inning_failure_modes','two_out_extension_risk','b4_plus_exposure_state','best_pitcher_suppression_mechanism','best_offensive_rupture_route',
 'bilateral_vulnerability_flag','dependency_clusters','uncertainty_objects','sra.process_state','numeric_fabrication_check','market_blindness',
 'hard_gates','a3_current_version_status','phase_result'
 ],0,1,'{}','{}','{}'::jsonb
),
(
 'NRFIMETRICA_MOTHER_V3_AUTONOMOUS','A4_NUMERIC_STATE_ENGINE',false,null,
 array[
 'numeric_engine.execution_id','numeric_engine.model_version','numeric_engine.engine_mode','numeric_engine.model_tier',
 'numeric_engine.transition_version','numeric_engine.as_of','numeric_engine.input_freeze_id','numeric_engine.provenance_status','numeric_engine.transformation_status',
 'top.p0','top.p1','top.p2','top.p3plus','bottom.p0','bottom.p1','bottom.p2','bottom.p3plus',
 'mass_conservation_check','state_sanity_checks','parameter_uncertainty','model_uncertainty','sensitivity','fragility','sra.integration_status',
 'hard_gates','a4_numeric_provenance_status','phase_result'
 ],1,1,'{}','{}','{}'::jsonb
),
(
 'NRFIMETRICA_MOTHER_V3_AUTONOMOUS','A5_JOINT_INTEGRATION',false,null,
 array[
 'input_freeze_id','shared_context','context_distribution','same_context_realization_check','residual_dependence_audit','double_adjustment_check',
 'joint.p0','joint.p1','joint.p2','joint.p3plus','contracts.p_u0_5','contracts.p_u1_5','contracts.p_u2_5','p_yrfi',
 'weakest_half','more_fragile_half','primary_yrfi_risk','joint_sensitivity','breakpoints','joint_fragility','joint_uncertainty','data_lineage',
 'raw_not_calibrated_check','market_blindness','hard_gates','a5_joint_model_status','phase_result'
 ],0,0,'{}','{}','{"breakpoints":2}'::jsonb
),
(
 'NRFIMETRICA_MOTHER_V3_AUTONOMOUS','A6_CAUSAL_FALSIFICATION_SPORTS_SEAL',false,null,
 array[
 'primary_analyst_id','central_nrfi_case','best_yrfi_rival','governing_mechanisms','weakest_half','governing_uncertainty','breakpoints',
 'falsification.central_case','falsification.rival','dependency_control',
 'independent_audit.auditor_id','independent_audit.central_case','independent_audit.best_yrfi_rival','independent_audit.divergence_class','independent_audit.status',
 'sports_stability','sports_seal.status','sports_seal.market_blindness',
 'sra.packet_status','sra.team_packet_status','sra.b1_b4_packet_status','sra.confounding_check','sra.shrinkage','sra.a3_state','sra.a4_integration',
 'pre_press_verdict.frozen','pre_press_verdict.hash','pre_press_verdict.central_under_case','pre_press_verdict.best_yrfi_rival','pre_press_verdict.status',
 'hard_gates','phase_result'
 ],0,0,'{}',array['ESPERANDO RESULTADO DE NRFI-PRENSA'],'{"breakpoints":2}'::jsonb
),
(
 'NRFIMETRICA_MOTHER_V3_AUTONOMOUS','A7_CALIBRATION_ELIGIBILITY_PRESS',false,null,
 array[
 'model_version','engine_mode','model_tier','target_id','raw_p','calibrator_version','calibration_status','calibration_region_support',
 'oos_validation_status','temporal_validation_status','leakage_control_status','provenance_status','total_uncertainty','sports_stability','absolute_eligibility',
 'calibration_in_the_large','calibration_slope','reliability_analysis','brier_score','log_loss','baseline_comparison','ablation_status','drift_audit','calibration_uncertainty',
 'nrfi_prensa.packet_id','nrfi_prensa.received_at','nrfi_prensa.original_verdict_hash','nrfi_prensa.coincidences','nrfi_prensa.discrepancies',
 'nrfi_prensa.new_data','nrfi_prensa.unverified_data','nrfi_prensa.omitted_risks','nrfi_prensa.questions','nrfi_prensa.responses',
 'nrfi_prensa.impact_p0','nrfi_prensa.impact_p1','nrfi_prensa.impact_p2plus','nrfi_prensa.effect',
 'reformulated_verdict','sports_seal_final','hard_gates','release_token','phase_result'
 ],1,1,'{}','{}','{}'::jsonb
),
(
 'NRFIMETRICA_MOTHER_V3_AUTONOMOUS','A8_MARKET_VALUE_EXECUTION',false,null,
 array[
 'a7_release_token','a7_eligibility_status','verdict_emitted_at',
 'probability.p0','probability.p1','probability.p2','probability.p3plus','line_recommended',
 'market.sportsbook','market.line_exact','market.price_exact','market.decimal_odds','market.as_of','market.break_even','market.p_conservative','market.edge','market.ev',
 'calibration_status','t5.revalidation_id','t5.active_freeze_id','t5.as_of','t5.starter_confirmed','t5.official_lineup_verified','t5.catcher_confirmed',
 't5.scratches_status','t5.roof_weather_critical_context','t5.contract_identity','t5.line_exact','t5.price_exact','t5.break_even','t5.primary_risk',
 'ranking_state','execution_authority','primary_reason','primary_risk','final_verdict','phase_result'
 ],0,0,'{}','{}','{}'::jsonb
)
on conflict (protocol_id,phase_id) do update set
  conditional=excluded.conditional,
  trigger_path=excluded.trigger_path,
  required_fields=excluded.required_fields,
  min_source_calls=excluded.min_source_calls,
  min_evidence_ids=excluded.min_evidence_ids,
  required_documents=excluded.required_documents,
  required_phrases=excluded.required_phrases,
  max_items=excluded.max_items;

insert into public.protocol_phase_prerequisites(protocol_id,phase_id,prerequisite_phase_id) values
('NRFIMETRICA_MOTHER_V3_AUTONOMOUS','A2_HIERARCHICAL_BASELINES','A1_DATA_INTEGRITY_FREEZE'),
('NRFIMETRICA_MOTHER_V3_AUTONOMOUS','A3_CURRENT_VERSION_MATCHUP','A2_HIERARCHICAL_BASELINES'),
('NRFIMETRICA_MOTHER_V3_AUTONOMOUS','A4_NUMERIC_STATE_ENGINE','A3_CURRENT_VERSION_MATCHUP'),
('NRFIMETRICA_MOTHER_V3_AUTONOMOUS','A5_JOINT_INTEGRATION','A4_NUMERIC_STATE_ENGINE'),
('NRFIMETRICA_MOTHER_V3_AUTONOMOUS','A6_CAUSAL_FALSIFICATION_SPORTS_SEAL','A5_JOINT_INTEGRATION'),
('NRFIMETRICA_MOTHER_V3_AUTONOMOUS','A7_CALIBRATION_ELIGIBILITY_PRESS','A6_CAUSAL_FALSIFICATION_SPORTS_SEAL'),
('NRFIMETRICA_MOTHER_V3_AUTONOMOUS','A8_MARKET_VALUE_EXECUTION','A7_CALIBRATION_ELIGIBILITY_PRESS')
on conflict do nothing;

create or replace function public.nrfim_json_num(doc jsonb, dotted_path text)
returns numeric language plpgsql immutable as $$
declare t text;
begin
  t := doc #>> string_to_array(dotted_path,'.');
  if t is null or btrim(t)='' then raise exception 'NUMERIC_FIELD_MISSING:%', dotted_path using errcode='23514'; end if;
  return t::numeric;
exception when invalid_text_representation then
  raise exception 'NUMERIC_FIELD_INVALID:%', dotted_path using errcode='23514';
end; $$;

create or replace function public.nrfim_assert_distribution(doc jsonb, prefix text)
returns void language plpgsql as $$
declare p0 numeric; p1 numeric; p2 numeric; p3 numeric; total numeric;
begin
  p0:=public.nrfim_json_num(doc,prefix||'.p0'); p1:=public.nrfim_json_num(doc,prefix||'.p1');
  p2:=public.nrfim_json_num(doc,prefix||'.p2'); p3:=public.nrfim_json_num(doc,prefix||'.p3plus');
  if p0<0 or p0>1 or p1<0 or p1>1 or p2<0 or p2>1 or p3<0 or p3>1 then
    raise exception 'PROBABILITY_OUT_OF_RANGE:%',prefix using errcode='23514';
  end if;
  total:=p0+p1+p2+p3;
  if abs(total-1)>0.000001 then raise exception 'PROBABILITY_MASS_NOT_ONE:%:%',prefix,total using errcode='23514'; end if;
end; $$;

create or replace function public.enforce_nrfimetrica_mother_semantics()
returns trigger language plpgsql as $$
declare
  p text := 'NRFIMETRICA_MOTHER_V3_AUTONOMOUS';
  start_at timestamptz;
  a1 jsonb; a2 jsonb; a3 jsonb; a4 jsonb; a6 jsonb; a7 jsonb;
  p0 numeric; p1 numeric; p2 numeric; p3 numeric; pu05 numeric; pu15 numeric; pu25 numeric; pyrfi numeric;
  break_even numeric; pcons numeric; decodds numeric; edge numeric; ev numeric;
  executable_count integer; bad_evidence integer; press_packet text;
begin
  if new.protocol_id <> p then return new; end if;

  if not exists (
    select 1 from public.protocol_run_state rs
    where rs.run_id=new.run_id and rs.protocol_id=p and rs.stage_id='A0_CONSTITUTION_SEALED'
      and rs.payload->>'mother_document_sha256'='d16896eba602af272117a5c83b56245aa201979d394301781d424e705b3642d3'
  ) then raise exception 'A0_MOTHER_CONSTITUTION_NOT_SEALED' using errcode='23514'; end if;

  select count(*) into bad_evidence from unnest(new.evidence_ids) eid
  where not exists (
    select 1 from public.evidence e where e.evidence_id=eid and e.run_id=new.run_id
      and (e.game_id is null or e.game_id=new.game_id)
      and coalesce(e.data_available_at,e.retrieved_at)<=new.submitted_at
  );
  if bad_evidence>0 then raise exception 'MOTHER_EVIDENCE_NOT_REAL_OR_TEMPORALLY_INVALID:%',bad_evidence using errcode='23514'; end if;

  if new.payload ? 'ai_estimate' or new.payload ? 'ai_nrfi_estimate' or new.payload ? 'ai_probability' then
    raise exception 'MOTHER_DOCUMENT_FORBIDS_AI_PROBABILITY_FABRICATION' using errcode='23514';
  end if;

  select scheduled_start into start_at from public.games where run_id=new.run_id and game_id=new.game_id;

  if new.phase_id='A1_DATA_INTEGRITY_FREEZE' then
    if upper(coalesce(new.payload->>'market_quarantine','')) not in ('PASS','SEALED','INTACT','ACTIVE') then raise exception 'A1_MARKET_QUARANTINE_FAIL' using errcode='23514'; end if;
    if upper(coalesce(new.payload->>'temporal_integrity',''))<>'PASS' then raise exception 'A1_TEMPORAL_INTEGRITY_FAIL' using errcode='23514'; end if;
    if upper(coalesce(new.payload->>'freeze_integrity',''))<>'PASS' then raise exception 'A1_FREEZE_INTEGRITY_FAIL' using errcode='23514'; end if;
    if upper(coalesce(new.payload->>'research_handoff','')) not in ('READY_FOR_A2','PROVISIONAL_FOR_A2','HOLD','NOT_EXECUTABLE','EXCLUDED') then raise exception 'A1_RESEARCH_HANDOFF_INVALID' using errcode='23514'; end if;
    if upper(coalesce(new.payload->>'a1_real_money_status','')) not in ('PASS','FAIL','NOT_YET_EVALUATED') then raise exception 'A1_REAL_MONEY_STATUS_INVALID' using errcode='23514'; end if;
    if upper(coalesce(new.payload->>'a1_real_money_status',''))='PASS' then
      if upper(coalesce(new.payload #>> '{first_inning_pitcher,away,status}','')) not in ('CONFIRMED_STARTER','CONFIRMED_OPENER')
         or upper(coalesce(new.payload #>> '{first_inning_pitcher,home,status}','')) not in ('CONFIRMED_STARTER','CONFIRMED_OPENER') then
        raise exception 'A1_REAL_MONEY_REQUIRES_CONFIRMED_FIRST_INNING_PITCHERS' using errcode='23514';
      end if;
      if upper(coalesce(new.payload #>> '{lineup,away,state}',''))<>'OFFICIAL' or upper(coalesce(new.payload #>> '{lineup,home,state}',''))<>'OFFICIAL' then
        raise exception 'A1_REAL_MONEY_REQUIRES_OFFICIAL_LINEUPS' using errcode='23514';
      end if;
      if not public.jsonb_path_nonempty(new.payload,'final_input_freeze_id') then raise exception 'A1_REAL_MONEY_REQUIRES_FINAL_INPUT_FREEZE_ID' using errcode='23514'; end if;
      if upper(coalesce(new.payload->>'market_contamination_flag','')) not in ('NO','FALSE','PASS') then raise exception 'A1_MARKET_CONTAMINATION_FAIL' using errcode='23514'; end if;
    end if;

  elsif new.phase_id='A2_HIERARCHICAL_BASELINES' then
    select payload into a1 from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=p and phase_id='A1_DATA_INTEGRITY_FREEZE';
    if new.payload->>'input_freeze_id' is distinct from a1->>'input_freeze_id' then raise exception 'A2_FREEZE_LINEAGE_MISMATCH' using errcode='23514'; end if;
    if upper(coalesce(new.payload->>'market_blindness',''))<>'PASS' or upper(coalesce(new.payload->>'double_count_check',''))<>'PASS' then raise exception 'A2_MARKET_OR_DEPENDENCY_GATE_FAIL' using errcode='23514'; end if;
    if upper(coalesce(new.payload->>'a2_baseline_status','')) not in ('A2_BASELINE_PASS','A2_RESEARCH_READY','A2_CONDITIONED','A2_FAIL','A2_REOPEN_A1') then raise exception 'A2_STATUS_INVALID' using errcode='23514'; end if;

  elsif new.phase_id='A3_CURRENT_VERSION_MATCHUP' then
    select payload into a2 from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=p and phase_id='A2_HIERARCHICAL_BASELINES';
    if upper(coalesce(a2->>'a2_baseline_status','')) in ('A2_FAIL','A2_REOPEN_A1') then raise exception 'A3_CANNOT_ADVANCE_FROM_FAILED_A2' using errcode='23514'; end if;
    if upper(coalesce(new.payload->>'market_blindness',''))<>'PASS' or upper(coalesce(new.payload->>'numeric_fabrication_check',''))<>'PASS' then raise exception 'A3_MARKET_OR_NUMERIC_BOUNDARY_FAIL' using errcode='23514'; end if;
    if upper(coalesce(new.payload->>'a3_current_version_status','')) not in ('A3_CURRENT_VERSION_PASS','A3_RESEARCH_READY','A3_CONDITIONED','A3_FAIL','A3_REOPEN_A2','A3_REOPEN_A1') then raise exception 'A3_STATUS_INVALID' using errcode='23514'; end if;

  elsif new.phase_id='A4_NUMERIC_STATE_ENGINE' then
    select payload into a3 from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=p and phase_id='A3_CURRENT_VERSION_MATCHUP';
    if upper(coalesce(a3->>'a3_current_version_status','')) in ('A3_FAIL','A3_REOPEN_A2','A3_REOPEN_A1') then raise exception 'A4_CANNOT_ADVANCE_FROM_FAILED_A3' using errcode='23514'; end if;
    if upper(coalesce(new.payload #>> '{numeric_engine,provenance_status}',''))<>'PASS' then raise exception 'A4_NUMERIC_PROVENANCE_NOT_PASS' using errcode='23514'; end if;
    if upper(coalesce(new.payload #>> '{numeric_engine,transformation_status}',''))<>'PASS' then raise exception 'A4_VALIDATED_TRANSFORM_REQUIRED' using errcode='23514'; end if;
    if not exists (
      select 1 from public.evidence e where e.run_id=new.run_id and (e.game_id is null or e.game_id=new.game_id)
        and e.evidence_id=any(new.evidence_ids) and lower(e.tool_name) like '%numeric%'
        and coalesce(e.payload->>'execution_id','')=coalesce(new.payload #>> '{numeric_engine,execution_id}','')
    ) then raise exception 'A4_NUMERIC_ENGINE_EXECUTION_NOT_EVIDENCED' using errcode='23514'; end if;
    perform public.nrfim_assert_distribution(new.payload,'top'); perform public.nrfim_assert_distribution(new.payload,'bottom');
    if upper(coalesce(new.payload->>'mass_conservation_check',''))<>'PASS' or upper(coalesce(new.payload->>'state_sanity_checks',''))<>'PASS' then raise exception 'A4_NUMERIC_SANITY_FAIL' using errcode='23514'; end if;

  elsif new.phase_id='A5_JOINT_INTEGRATION' then
    select payload into a4 from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=p and phase_id='A4_NUMERIC_STATE_ENGINE';
    if upper(coalesce(a4->>'a4_numeric_provenance_status','')) in ('A4_REOPEN_A3','A4_REOPEN_A2','A4_REOPEN_A1','A4_TRUE_MODEL_FAILURE') then raise exception 'A5_CANNOT_ADVANCE_FROM_FAILED_A4' using errcode='23514'; end if;
    perform public.nrfim_assert_distribution(new.payload,'joint');
    p0:=public.nrfim_json_num(new.payload,'joint.p0'); p1:=public.nrfim_json_num(new.payload,'joint.p1'); p2:=public.nrfim_json_num(new.payload,'joint.p2'); p3:=public.nrfim_json_num(new.payload,'joint.p3plus');
    pu05:=public.nrfim_json_num(new.payload,'contracts.p_u0_5'); pu15:=public.nrfim_json_num(new.payload,'contracts.p_u1_5'); pu25:=public.nrfim_json_num(new.payload,'contracts.p_u2_5'); pyrfi:=public.nrfim_json_num(new.payload,'p_yrfi');
    if abs(pu05-p0)>0.000001 or abs(pu15-(p0+p1))>0.000001 or abs(pu25-(p0+p1+p2))>0.000001 or abs(pyrfi-(1-p0))>0.000001 then raise exception 'A5_CONTRACT_DERIVATION_OR_COMPLEMENT_FAIL' using errcode='23514'; end if;
    if upper(coalesce(new.payload->>'same_context_realization_check',''))<>'PASS' or upper(coalesce(new.payload->>'double_adjustment_check',''))<>'PASS'
       or upper(coalesce(new.payload->>'raw_not_calibrated_check',''))<>'PASS' or upper(coalesce(new.payload->>'market_blindness',''))<>'PASS' then raise exception 'A5_INTEGRATION_GATES_FAIL' using errcode='23514'; end if;

  elsif new.phase_id='A6_CAUSAL_FALSIFICATION_SPORTS_SEAL' then
    if coalesce(new.payload->>'primary_analyst_id','')=coalesce(new.payload #>> '{independent_audit,auditor_id}','') then raise exception 'A6_INDEPENDENT_AUDIT_NOT_INDEPENDENT' using errcode='23514'; end if;
    if upper(coalesce(new.payload #>> '{independent_audit,status}','')) not in ('PASS','CONDITIONED') then raise exception 'A6_INDEPENDENT_AUDIT_UNSATISFIED' using errcode='23514'; end if;
    if upper(coalesce(new.payload #>> '{sra,packet_status}','')) not in ('COMPLETE','DATA_UNAVAILABLE') then raise exception 'SRA_GATE_NOT_EXECUTED' using errcode='23514'; end if;
    if lower(coalesce(new.payload #>> '{pre_press_verdict,frozen}','false')) not in ('true','1','yes') then raise exception 'A6_PRE_PRESS_VERDICT_NOT_FROZEN' using errcode='23514'; end if;
    if upper(coalesce(new.payload #>> '{sports_seal,market_blindness}',''))<>'PASS' then raise exception 'A6_MARKET_BLINDNESS_FAIL' using errcode='23514'; end if;

  elsif new.phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS' then
    select payload into a6 from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=p and phase_id='A6_CAUSAL_FALSIFICATION_SPORTS_SEAL';
    press_packet:=new.payload #>> '{nrfi_prensa,packet_id}';
    if new.payload #>> '{nrfi_prensa,original_verdict_hash}' is distinct from a6 #>> '{pre_press_verdict,hash}' then raise exception 'A7_PRESS_CONTRAST_NOT_BOUND_TO_FROZEN_VERDICT' using errcode='23514'; end if;
    if (new.payload #>> '{nrfi_prensa,received_at}')::timestamptz <= (select submitted_at from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=p and phase_id='A6_CAUSAL_FALSIFICATION_SPORTS_SEAL') then raise exception 'A7_PRESS_PACKET_NOT_POST_FREEZE' using errcode='23514'; end if;
    if not exists (select 1 from jsonb_array_elements(new.source_calls) x where lower(coalesce(x->>'system',''))='@nrfiprensa' and coalesce(x->>'packet_id','')=coalesce(press_packet,'')) then raise exception 'A7_NRFI_PRENSA_PACKET_WITHOUT_REAL_TRACE' using errcode='23514'; end if;
    if upper(coalesce(new.payload #>> '{nrfi_prensa,effect}','')) not in ('CONFIRM','STRENGTHEN','CONDITION','REVISE','REJECT','NON_DISCRIMINANT') then raise exception 'A7_NRFI_PRENSA_EFFECT_INVALID' using errcode='23514'; end if;
    if upper(coalesce(new.payload->>'release_token',''))='ISSUED' then
      select payload into a1 from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=p and phase_id='A1_DATA_INTEGRITY_FREEZE';
      select payload into a2 from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=p and phase_id='A2_HIERARCHICAL_BASELINES';
      select payload into a3 from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=p and phase_id='A3_CURRENT_VERSION_MATCHUP';
      select payload into a4 from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=p and phase_id='A4_NUMERIC_STATE_ENGINE';
      if upper(coalesce(a1->>'a1_real_money_status',''))<>'PASS' or upper(coalesce(a2->>'a2_baseline_status',''))<>'A2_BASELINE_PASS'
         or upper(coalesce(a3->>'a3_current_version_status',''))<>'A3_CURRENT_VERSION_PASS' or upper(coalesce(a4->>'a4_numeric_provenance_status',''))<>'A4_NUMERIC_PROVENANCE_PASS'
         or upper(coalesce(a6 #>> '{sports_seal,status}','')) not in ('PASS','A6_SPORTS_SEALED','A6_SPORTS_SEALED_CONDITIONED') or upper(coalesce(a6 #>> '{independent_audit,status}',''))<>'PASS' then
        raise exception 'A7_RELEASE_BLOCKED_BY_UPSTREAM_REAL_MONEY_PREFLIGHT' using errcode='23514';
      end if;
      if upper(coalesce(new.payload->>'calibration_status','')) not in ('CERTIFIED','CERTIFIED_CONDITIONED') or upper(coalesce(new.payload->>'oos_validation_status',''))<>'PASS'
         or upper(coalesce(new.payload->>'provenance_status',''))<>'PASS' or upper(coalesce(new.payload->>'calibration_region_support','')) not in ('HIGH','MEDIUM')
         or upper(coalesce(new.payload->>'absolute_eligibility','')) not in ('A7_ELIGIBLE','A7_ELIGIBLE_CONDITIONED') then raise exception 'A7_NOT_CERTIFIED_A8_LOCKED' using errcode='23514';
      end if;
    else
      if upper(coalesce(new.payload->>'release_token','')) not in ('NOT_ISSUED','BLOCKED','N/A','NA') then raise exception 'A7_RELEASE_TOKEN_INVALID' using errcode='23514'; end if;
    end if;

  elsif new.phase_id='A8_MARKET_VALUE_EXECUTION' then
    select payload into a7 from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=p and phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS';
    if upper(coalesce(a7->>'release_token',''))<>'ISSUED' or upper(coalesce(new.payload->>'a7_release_token',''))<>'ISSUED' then raise exception 'A8_RELEASE_BLOCKED' using errcode='23514'; end if;
    if upper(coalesce(new.payload->>'a7_eligibility_status','')) not in ('A7_ELIGIBLE','A7_ELIGIBLE_CONDITIONED') then raise exception 'A8_ELIGIBILITY_BLOCKED' using errcode='23514'; end if;
    if upper(coalesce(new.payload->>'calibration_status','')) not in ('CERTIFIED','CERTIFIED_CONDITIONED') then raise exception 'A8_REQUIRES_CERTIFIED_CALIBRATION' using errcode='23514'; end if;
    perform public.nrfim_assert_distribution(new.payload,'probability');
    break_even:=public.nrfim_json_num(new.payload,'market.break_even'); pcons:=public.nrfim_json_num(new.payload,'market.p_conservative');
    decodds:=(new.payload #>> '{market,decimal_odds}')::numeric; edge:=(new.payload #>> '{market,edge}')::numeric; ev:=(new.payload #>> '{market,ev}')::numeric;
    if decodds<=1 then raise exception 'A8_DECIMAL_ODDS_INVALID' using errcode='23514'; end if;
    if abs(edge-(pcons-break_even))>0.000001 then raise exception 'A8_EDGE_MATH_FAIL' using errcode='23514'; end if;
    if abs(ev-(pcons*decodds-1))>0.000001 then raise exception 'A8_EV_MATH_FAIL' using errcode='23514'; end if;
    if upper(coalesce(new.payload->>'final_verdict',''))='APOSTAR' and (edge<=0 or ev<=0) then raise exception 'A8_NONPOSITIVE_EDGE_OR_EV_NO_BET' using errcode='23514'; end if;
    if start_at is not null then
      if (new.payload->>'verdict_emitted_at')::timestamptz > start_at-interval '10 minutes' then raise exception 'A8_VERDICT_AFTER_T10' using errcode='23514'; end if;
      if (new.payload #>> '{t5,as_of}')::timestamptz < start_at-interval '10 minutes' or (new.payload #>> '{t5,as_of}')::timestamptz >= start_at then raise exception 'A8_T5_REVALIDATION_OUTSIDE_FINAL_WINDOW' using errcode='23514'; end if;
    end if;
    if upper(coalesce(new.payload #>> '{t5,starter_confirmed}','')) not in ('YES','TRUE','PASS') or upper(coalesce(new.payload #>> '{t5,official_lineup_verified}','')) not in ('YES','TRUE','PASS') then raise exception 'A8_T5_STARTER_OR_LINEUP_NOT_VERIFIED' using errcode='23514'; end if;
    if upper(coalesce(new.payload->>'final_verdict','')) in ('APOSTAR','SOLO_SI_CUOTA') then
      if upper(coalesce(new.payload->>'execution_authority',''))<>'PASS' then raise exception 'A8_EXECUTION_AUTHORITY_NOT_PASS' using errcode='23514'; end if;
      select count(*) into executable_count from public.protocol_phase_state s where s.run_id=new.run_id and s.protocol_id=p and s.phase_id='A8_MARKET_VALUE_EXECUTION'
        and s.id<>new.id and upper(coalesce(s.payload->>'final_verdict','')) in ('APOSTAR','SOLO_SI_CUOTA');
      if executable_count>=3 then raise exception 'A8_MAX_THREE_CANDIDATES' using errcode='23514'; end if;
    end if;
    if upper(coalesce(new.payload->>'line_recommended',''))='U1.5' and position('El partido fue seleccionado por su fortaleza para cero carreras.' in new.output_text)=0 then raise exception 'A8_U15_REQUIRED_MESSAGE_MISSING' using errcode='23514'; end if;
  end if;
  return new;
end; $$;

drop trigger if exists trg_enforce_nrfimetrica_mother_semantics on public.protocol_phase_state;
create trigger trg_enforce_nrfimetrica_mother_semantics before insert or update on public.protocol_phase_state
for each row execute function public.enforce_nrfimetrica_mother_semantics();

create or replace function public.enforce_nrfimetrica_run_stage()
returns trigger language plpgsql as $$
declare p text:='NRFIMETRICA_MOTHER_V3_AUTONOMOUS'; actual_candidates integer;
begin
  if new.protocol_id<>p then return new; end if;
  if new.stage_id='A0_CONSTITUTION_SEALED' then
    if new.payload->>'mother_document_sha256'<>'d16896eba602af272117a5c83b56245aa201979d394301781d424e705b3642d3' then raise exception 'A0_MOTHER_HASH_MISMATCH' using errcode='23514'; end if;
    if lower(coalesce(new.payload->>'manual_phase_authorization_required','true')) not in ('false','0','no') then raise exception 'A0_AUTONOMOUS_ADAPTATION_NOT_ACTIVE' using errcode='23514'; end if;
  elsif new.stage_id='A8_PORTFOLIO' then
    select count(*) into actual_candidates from public.protocol_phase_state s
    where s.run_id=new.run_id and s.protocol_id=p and s.phase_id='A8_MARKET_VALUE_EXECUTION'
      and upper(coalesce(s.payload->>'final_verdict','')) in ('APOSTAR','SOLO_SI_CUOTA');
    if actual_candidates>3 then raise exception 'PORTFOLIO_OVER_THREE_CANDIDATES' using errcode='23514'; end if;
    if coalesce((new.payload->>'candidate_count')::integer,-1)<>actual_candidates then raise exception 'PORTFOLIO_CANDIDATE_COUNT_MISMATCH:%/%',(new.payload->>'candidate_count'),actual_candidates using errcode='23514'; end if;
  elsif new.stage_id='FINAL_REPORT' then
    if not exists(select 1 from public.protocol_run_state x where x.run_id=new.run_id and x.protocol_id=p and x.stage_id='A8_PORTFOLIO' and x.status='COMPLETE') then raise exception 'FINAL_REPORT_REQUIRES_A8_PORTFOLIO' using errcode='23514'; end if;
  end if;
  return new;
end; $$;

drop trigger if exists trg_enforce_nrfimetrica_run_stage on public.protocol_run_state;
create trigger trg_enforce_nrfimetrica_run_stage before insert or update on public.protocol_run_state
for each row execute function public.enforce_nrfimetrica_run_stage();

create or replace function public.require_final_report_before_close()
returns trigger language plpgsql as $$
begin
  if new.status='CLOSED' and old.status is distinct from 'CLOSED' and coalesce(new.mode,'')<>'DIAGNOSTIC' then
    if not exists(select 1 from public.run_report_state r where r.run_id=new.run_id and r.status='COMPLETE')
       and not exists(select 1 from public.protocol_run_state rs where rs.run_id=new.run_id and rs.protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and rs.stage_id='FINAL_REPORT' and rs.status='COMPLETE') then
      raise exception 'FINAL_REPORT_GATE_INCOMPLETE' using errcode='23514';
    end if;
  end if;
  return new;
end; $$;

insert into public.system_versions(system_version,contract_doc_id,kernel_version,model_version,calibration_status)
values('NRFIM MOTHER V3','MOTHER_SHA256:d16896eba602af272117a5c83b56245aa201979d394301781d424e705b3642d3','NRFIM-KERNEL-0.4-MOTHER-ALIGNED','NUMERIC_MODEL_NOT_INTEGRATED','NOT_CERTIFIED')
on conflict(system_version) do update set contract_doc_id=excluded.contract_doc_id,kernel_version=excluded.kernel_version,model_version=excluded.model_version,calibration_status=excluded.calibration_status;
