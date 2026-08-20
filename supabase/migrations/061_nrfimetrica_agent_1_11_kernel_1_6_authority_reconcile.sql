-- @NRFImetrica Agent 1.11 / Kernel 1.6 authority reconciliation.
-- Canonical Mother SHA256: 44edaa44707293115f8d129b8903c1d8f7dfa5f6bd79674de29cee01091228d8
-- Agent remains DISABLED until final regression/security audit and migration 062 activation.

do $do$
declare ddl text; pos integer;
begin
  select pg_get_functiondef('public.enforce_nrfimetrica_mother_semantics()'::regprocedure) into ddl;
  ddl := replace(ddl,'391fbdfdf78965f9454307267f7e3d048abc7ccb4329e29870ad58aeabcb55f1','44edaa44707293115f8d129b8903c1d8f7dfa5f6bd79674de29cee01091228d8');
  ddl := replace(ddl,'pre_press_verdict','sports_verdict');
  pos := strpos(ddl, $$  elsif new.phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS' then$$);
  if pos>0 then ddl := substr(ddl,1,pos-1) || E'  end if;\n\n  return new;\nend;\n$function$\n'; end if;
  execute ddl;
  execute 'alter function public.enforce_nrfimetrica_mother_semantics() set search_path = public, pg_temp';

  select pg_get_functiondef('public.enforce_nrfimetrica_mother_lineage()'::regprocedure) into ddl;
  pos := strpos(ddl, $$  elsif new.phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS' then$$);
  if pos>0 then ddl := substr(ddl,1,pos-1) || E'  end if;\n  return new;\nend;\n$function$\n'; end if;
  execute ddl;
  execute 'alter function public.enforce_nrfimetrica_mother_lineage() set search_path = public, pg_temp';

  select pg_get_functiondef('public.enforce_nrfimetrica_run_stage()'::regprocedure) into ddl;
  ddl := replace(ddl,'391fbdfdf78965f9454307267f7e3d048abc7ccb4329e29870ad58aeabcb55f1','44edaa44707293115f8d129b8903c1d8f7dfa5f6bd79674de29cee01091228d8');
  ddl := replace(ddl,
    $old$array['rank','game_id','zero_run_thesis','p_nrfi_u0_5','p_exact1','p_exact2','p3plus','pre_press_verdict','nrfiprensa','contrast_effect','reformulated_verdict','line_recommended','current_price','minimum_acceptable_price','break_even','p_conservative','edge','ev','calibration_state','primary_reason','primary_risk','verdict']$old$,
    $new$array['rank','game_id','zero_run_thesis','p_nrfi_u0_5','p_exact1','p_exact2','p3plus','sports_verdict','press_intake_a0p','press_disposition_summary','reanalysis_required','line_recommended','current_price','minimum_acceptable_price','break_even','p_conservative','edge','ev','system_reliability_status','system_reliability_economic_effect','primary_reason','primary_risk','verdict']$new$);
  execute ddl;
  execute 'alter function public.enforce_nrfimetrica_run_stage() set search_path = public, pg_temp';
end $do$;

update public.protocol_authority
set document_sha256='44edaa44707293115f8d129b8903c1d8f7dfa5f6bd79674de29cee01091228d8',
    document_lines=18563,
    latest_sovereign_patch='PRESS_PREANALYSIS_AND_COGNITIVE_ARCHITECTURE_AMENDMENT — 2026-08-20',
    precedence_rule='PREANALYSIS_PRESS_INFORMATION_ONLY_PLUS_CALIBRATE_SYSTEM_NOT_GAME'
where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and active=true;

update public.system_versions
set kernel_version='NRFIM-KERNEL-1.6-PREANALYSIS-COGNITIVE-GUARD',
    contract_doc_id='MOTHER_SHA256:44edaa44707293115f8d129b8903c1d8f7dfa5f6bd79674de29cee01091228d8',
    calibration_status='SYSTEM_AUDIT_ONLY_NO_GAME_OVERRIDE'
where system_version='NRFIM MOTHER V3';

update public.agent_registry
set agent_version='MOTHER-V3-AGENT-1.11',
    kernel_version='NRFIM-KERNEL-1.6-PREANALYSIS-COGNITIVE-GUARD',
    mother_document_sha256='44edaa44707293115f8d129b8903c1d8f7dfa5f6bd79674de29cee01091228d8',
    status='DISABLED',
    metadata=(coalesce(metadata,'{}'::jsonb)-'source_family_floor'-'fixed_source_family_floor'-'calibration_guard') || jsonb_build_object(
      'mother_export_sha256','44edaa44707293115f8d129b8903c1d8f7dfa5f6bd79674de29cee01091228d8',
      'mother_export_lines',18563,
      'press_delta_refactor_state','VALIDATION_PENDING',
      'press_intake_phase','A0P_PRESS_INFORMATION_INTAKE',
      'press_intake_role','OPTIONAL_INFORMATION_ONLY',
      'press_sports_authority','NONE',
      'press_probability_authority','NONE',
      'press_ranking_authority','NONE',
      'press_market_authority','NONE',
      'press_conclusion_authority','NONE',
      'cognitive_contract','COGNITIVE-1.0',
      'game_probability_source','A5_GAME_CAUSAL_ONLY',
      'calibration_role','SYSTEM_AUDIT_ONLY',
      'conservative_probability_source','GAME_SPECIFIC_STRESS_TEST_ONLY',
      'no_game_equivalence_by_probability_score_band',true,
      'protocol_floor_not_analysis_ceiling',true,
      'second_pass_required',true,
      'best_supported_rival_required',true,
      'causal_bottleneck_per_half_required',true,
      'directional_bias_check_required',true,
      'semantic_reclassification_supported',true,
      'notion_role','CONSULTATION_ONLY_NO_WRITE_AUTHORITY',
      'real_money_authority',false,
      'database_migrations_required_through',61)
where agent_id='@NRFImetrica';
