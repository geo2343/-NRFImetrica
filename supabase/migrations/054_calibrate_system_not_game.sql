-- 054 — CALIBRAR EL SISTEMA != CALIBRAR EL PARTIDO
-- Agent 1.10 / Kernel 1.5 calibration-separation refactor.

CREATE TABLE IF NOT EXISTS public.nrfimetrica_system_calibration_audits (
  audit_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  model_version text NOT NULL,
  target_id text NOT NULL,
  evaluation_start date,
  evaluation_end date,
  sample_size integer NOT NULL CHECK (sample_size >= 0),
  methodology text NOT NULL CHECK (methodology IN ('WALK_FORWARD','SEALED_TEMPORAL_HOLDOUT','ROLLING_OOS','DIAGNOSTIC_ONLY')),
  context_scope jsonb NOT NULL DEFAULT '{}'::jsonb,
  metrics jsonb NOT NULL DEFAULT '{}'::jsonb,
  baseline_comparison jsonb NOT NULL DEFAULT '{}'::jsonb,
  ablation_summary jsonb NOT NULL DEFAULT '{}'::jsonb,
  confidence_behavior text NOT NULL CHECK (confidence_behavior IN ('RELIABLE','OVERCONFIDENT','UNDERCONFIDENT','MIXED','INSUFFICIENT_SAMPLE','NOT_EVALUATED')),
  drift_status text NOT NULL CHECK (drift_status IN ('PASS','DRIFT_DETECTED','INSUFFICIENT_SAMPLE','NOT_EVALUATED')),
  economic_effect text NOT NULL CHECK (economic_effect IN ('ALLOW','CONDITION','BLOCK')),
  sports_effect text NOT NULL DEFAULT 'NONE' CHECK (sports_effect='NONE'),
  ranking_effect text NOT NULL DEFAULT 'NONE' CHECK (ranking_effect='NONE'),
  probability_effect text NOT NULL DEFAULT 'NONE' CHECK (probability_effect='NONE'),
  historical_override_allowed boolean NOT NULL DEFAULT false CHECK (historical_override_allowed=false),
  universal_game_equivalence_allowed boolean NOT NULL DEFAULT false CHECK (universal_game_equivalence_allowed=false),
  status text NOT NULL CHECK (status IN ('PASS','CONDITIONED','FAIL','INSUFFICIENT_SAMPLE','DIAGNOSTIC')),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE public.nrfimetrica_system_calibration_audits ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.nrfimetrica_calibration_observations (
  observation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  run_id text,
  game_id text,
  model_version text NOT NULL,
  target_id text NOT NULL,
  pregame_game_causal_p numeric NOT NULL CHECK (pregame_game_causal_p BETWEEN 0 AND 1),
  expressed_conviction text,
  outcome integer CHECK (outcome IN (0,1)),
  context_fingerprint text NOT NULL,
  context_tags jsonb NOT NULL DEFAULT '{}'::jsonb,
  freeze_status text NOT NULL DEFAULT 'VALID' CHECK (freeze_status IN ('VALID','INVALIDATED','AUDIT_ONLY')),
  validation_use text NOT NULL DEFAULT 'ELIGIBLE' CHECK (validation_use IN ('ELIGIBLE','POSTMORTEM_ONLY','EXCLUDED')),
  historical_override_applied boolean NOT NULL DEFAULT false CHECK (historical_override_applied=false),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE(run_id,game_id,target_id,model_version)
);
ALTER TABLE public.nrfimetrica_calibration_observations ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.calibration_certifications
  ADD COLUMN IF NOT EXISTS calibration_role text NOT NULL DEFAULT 'SYSTEM_AUDIT_ONLY',
  ADD COLUMN IF NOT EXISTS game_probability_override boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS sports_authority boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS ranking_authority boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS system_audit_id uuid REFERENCES public.nrfimetrica_system_calibration_audits(audit_id),
  ADD COLUMN IF NOT EXISTS context_signature jsonb NOT NULL DEFAULT '{}'::jsonb;

UPDATE public.calibration_certifications
SET authority_class='SYSTEM_AUDIT_ONLY', calibration_role='SYSTEM_AUDIT_ONLY',
    game_probability_override=false, sports_authority=false, ranking_authority=false;

ALTER TABLE public.calibration_certifications DROP CONSTRAINT IF EXISTS nrfim_calibration_role_system_only;
ALTER TABLE public.calibration_certifications ADD CONSTRAINT nrfim_calibration_role_system_only CHECK (calibration_role='SYSTEM_AUDIT_ONLY');
ALTER TABLE public.calibration_certifications DROP CONSTRAINT IF EXISTS nrfim_calibration_no_game_override;
ALTER TABLE public.calibration_certifications ADD CONSTRAINT nrfim_calibration_no_game_override CHECK (game_probability_override=false AND sports_authority=false AND ranking_authority=false);

CREATE OR REPLACE FUNCTION public.nrfim_guard_calibration_certification_system_only()
RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public','pg_temp' AS $$
BEGIN
  IF new.calibration_role<>'SYSTEM_AUDIT_ONLY' OR new.authority_class<>'SYSTEM_AUDIT_ONLY'
     OR new.game_probability_override OR new.sports_authority OR new.ranking_authority THEN
    RAISE EXCEPTION 'NRFIM_CALIBRATION_MUST_BE_SYSTEM_AUDIT_ONLY' USING ERRCODE='23514';
  END IF;
  RETURN new;
END $$;
DROP TRIGGER IF EXISTS trg_nrfim_calibration_cert_system_only ON public.calibration_certifications;
CREATE TRIGGER trg_nrfim_calibration_cert_system_only
BEFORE INSERT OR UPDATE ON public.calibration_certifications
FOR EACH ROW EXECUTE FUNCTION public.nrfim_guard_calibration_certification_system_only();

UPDATE public.protocol_phase_catalog
SET required_fields = ARRAY[
 'model_version','engine_mode','model_tier','target_id','raw_p','total_uncertainty','sports_stability','absolute_eligibility',
 'nrfi_prensa.packet_id','nrfi_prensa.received_at','nrfi_prensa.original_verdict_hash','nrfi_prensa.coincidences','nrfi_prensa.discrepancies','nrfi_prensa.new_data','nrfi_prensa.unverified_data','nrfi_prensa.omitted_risks','nrfi_prensa.questions','nrfi_prensa.responses','nrfi_prensa.impact_p0','nrfi_prensa.impact_p1','nrfi_prensa.impact_p2plus','nrfi_prensa.effect',
 'reformulated_verdict','sports_seal_final','hard_gates','release_token','phase_result','nrfi_prensa.packet_hash','input_freeze_id','a4_execution_id',
 'contract_calibration.u0_5.raw_p','contract_calibration.u1_5.raw_p','contract_calibration.u2_5.raw_p',
 'calibration_role','calibration_game_override','calibration_sports_authority','calibration_ranking_authority','game_probability_source','eligibility_basis',
 'system_reliability.status','system_reliability.economic_effect','system_reliability.sports_effect','system_reliability.ranking_effect','system_reliability.probability_effect',
 'game_uncertainty.u0_5.lower_bound','game_uncertainty.u0_5.source','game_uncertainty.u1_5.lower_bound','game_uncertainty.u1_5.source','game_uncertainty.u2_5.lower_bound','game_uncertainty.u2_5.source','game_uncertainty.historical_calibration_used'
]::text[]
WHERE protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' AND phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS';

UPDATE public.protocol_phase_catalog
SET required_fields = ARRAY[
 'a7_release_token','a7_eligibility_status','verdict_emitted_at','probability.p0','probability.p1','probability.p2','probability.p3plus','line_recommended',
 'market.sportsbook','market.line_exact','market.price_exact','market.decimal_odds','market.as_of','market.break_even','market.p_conservative','market.p_conservative_source','market.edge','market.ev','calibration_status',
 't5.revalidation_id','t5.active_freeze_id','t5.as_of','t5.starter_confirmed','t5.official_lineup_verified','t5.catcher_confirmed','t5.scratches_status','t5.roof_weather_critical_context','t5.contract_identity','t5.line_exact','t5.price_exact','t5.break_even','t5.primary_risk','ranking_state','execution_authority','primary_reason','primary_risk','final_verdict','phase_result','market.minimum_acceptable_price','market.offer_id','t5.material_change','t5.recompute_status'
]::text[]
WHERE protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' AND phase_id='A8_MARKET_VALUE_EXECUTION';

-- Legacy A7/A8 calibration semantics are isolated; historical functions remain for old phases/rows.
DROP TRIGGER IF EXISTS trg_03_nrfimetrica_mother_lineage ON public.protocol_phase_state;
CREATE TRIGGER trg_03_nrfimetrica_mother_lineage BEFORE INSERT OR UPDATE ON public.protocol_phase_state
FOR EACH ROW WHEN (new.phase_id NOT IN ('A7_CALIBRATION_ELIGIBILITY_PRESS','A8_MARKET_VALUE_EXECUTION'))
EXECUTE FUNCTION public.enforce_nrfimetrica_mother_lineage();

DROP TRIGGER IF EXISTS trg_enforce_nrfimetrica_mother_semantics ON public.protocol_phase_state;
CREATE TRIGGER trg_enforce_nrfimetrica_mother_semantics BEFORE INSERT OR UPDATE ON public.protocol_phase_state
FOR EACH ROW WHEN (new.phase_id NOT IN ('A7_CALIBRATION_ELIGIBILITY_PRESS','A8_MARKET_VALUE_EXECUTION'))
EXECUTE FUNCTION public.enforce_nrfimetrica_mother_semantics();

DROP TRIGGER IF EXISTS trg_04_nrfimetrica_trusted_artifacts_v2 ON public.protocol_phase_state;
CREATE TRIGGER trg_04_nrfimetrica_trusted_artifacts_v2 BEFORE INSERT OR UPDATE ON public.protocol_phase_state
FOR EACH ROW WHEN (new.phase_id<>'A7_CALIBRATION_ELIGIBILITY_PRESS')
EXECUTE FUNCTION public.enforce_nrfimetrica_trusted_artifacts_v2();

DROP TRIGGER IF EXISTS trg_05_nrfimetrica_calibration_authority_class ON public.protocol_phase_state;

CREATE OR REPLACE FUNCTION public.nrfim_enforce_calibration_separation_v15()
RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public','extensions','pg_temp' AS $$
DECLARE
  p text:='NRFIMETRICA_MOTHER_V3_AUTONOMOUS';
  a1 jsonb; a2 jsonb; a3 jsonb; a4 jsonb; a5 jsonb; a6 jsonb; a7 jsonb;
  press public.nrfiprensa_packets%rowtype;
  start_at timestamptz; line_key text; rel_status text; econ_effect text;
  raw0 numeric; raw1 numeric; raw2 numeric; lb numeric; break_even numeric; decodds numeric; edge numeric; ev numeric;
BEGIN
  IF new.protocol_id<>p OR new.phase_id NOT IN ('A7_CALIBRATION_ELIGIBILITY_PRESS','A8_MARKET_VALUE_EXECUTION') THEN RETURN new; END IF;
  SELECT scheduled_start INTO start_at FROM public.games WHERE run_id=new.run_id AND game_id=new.game_id;

  IF new.phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS' THEN
    SELECT payload INTO a1 FROM public.protocol_phase_state WHERE run_id=new.run_id AND game_id=new.game_id AND protocol_id=p AND phase_id='A1_DATA_INTEGRITY_FREEZE';
    SELECT payload INTO a2 FROM public.protocol_phase_state WHERE run_id=new.run_id AND game_id=new.game_id AND protocol_id=p AND phase_id='A2_HIERARCHICAL_BASELINES';
    SELECT payload INTO a3 FROM public.protocol_phase_state WHERE run_id=new.run_id AND game_id=new.game_id AND protocol_id=p AND phase_id='A3_CURRENT_VERSION_MATCHUP';
    SELECT payload INTO a4 FROM public.protocol_phase_state WHERE run_id=new.run_id AND game_id=new.game_id AND protocol_id=p AND phase_id='A4_NUMERIC_STATE_ENGINE';
    SELECT payload INTO a5 FROM public.protocol_phase_state WHERE run_id=new.run_id AND game_id=new.game_id AND protocol_id=p AND phase_id='A5_JOINT_INTEGRATION';
    SELECT payload INTO a6 FROM public.protocol_phase_state WHERE run_id=new.run_id AND game_id=new.game_id AND protocol_id=p AND phase_id='A6_CAUSAL_FALSIFICATION_SPORTS_SEAL';
    IF a1 IS NULL OR a4 IS NULL OR a5 IS NULL OR a6 IS NULL THEN RAISE EXCEPTION 'A7_CAUSAL_LINEAGE_INCOMPLETE' USING ERRCODE='23514'; END IF;
    IF new.payload->>'input_freeze_id' IS DISTINCT FROM a1->>'input_freeze_id' THEN RAISE EXCEPTION 'A7_FREEZE_LINEAGE_MISMATCH' USING ERRCODE='23514'; END IF;
    IF new.payload->>'a4_execution_id' IS DISTINCT FROM a4 #>> '{numeric_engine,execution_id}' THEN RAISE EXCEPTION 'A7_A4_EXECUTION_LINEAGE_MISMATCH' USING ERRCODE='23514'; END IF;
    IF new.payload->>'model_version' IS DISTINCT FROM a4 #>> '{numeric_engine,model_version}' THEN RAISE EXCEPTION 'A7_MODEL_VERSION_MISMATCH' USING ERRCODE='23514'; END IF;
    IF upper(coalesce(new.payload->>'engine_mode','')) IS DISTINCT FROM upper(coalesce(a4 #>> '{numeric_engine,engine_mode}','')) THEN RAISE EXCEPTION 'A7_ENGINE_MODE_MISMATCH' USING ERRCODE='23514'; END IF;
    IF upper(coalesce(new.payload->>'model_tier','')) IS DISTINCT FROM upper(coalesce(a4 #>> '{numeric_engine,model_tier}','')) THEN RAISE EXCEPTION 'A7_MODEL_TIER_MISMATCH' USING ERRCODE='23514'; END IF;

    raw0:=public.nrfim_json_num(a5,'contracts.p_u0_5'); raw1:=public.nrfim_json_num(a5,'contracts.p_u1_5'); raw2:=public.nrfim_json_num(a5,'contracts.p_u2_5');
    IF abs(public.nrfim_json_num(new.payload,'raw_p')-raw0)>0.000001 THEN RAISE EXCEPTION 'A7_GAME_CAUSAL_P_NOT_FROM_A5' USING ERRCODE='23514'; END IF;
    IF abs(public.nrfim_json_num(new.payload,'contract_calibration.u0_5.raw_p')-raw0)>0.000001 OR abs(public.nrfim_json_num(new.payload,'contract_calibration.u1_5.raw_p')-raw1)>0.000001 OR abs(public.nrfim_json_num(new.payload,'contract_calibration.u2_5.raw_p')-raw2)>0.000001 THEN RAISE EXCEPTION 'A7_CONTRACT_RAW_PROBABILITIES_NOT_FROM_A5' USING ERRCODE='23514'; END IF;

    IF upper(coalesce(new.payload->>'game_probability_source',''))<>'A5_GAME_CAUSAL_ONLY' THEN RAISE EXCEPTION 'A7_GAME_PROBABILITY_SOURCE_MUST_BE_CAUSAL_ONLY' USING ERRCODE='23514'; END IF;
    IF upper(coalesce(new.payload->>'eligibility_basis',''))<>'GAME_CAUSAL_ONLY' THEN RAISE EXCEPTION 'A7_ELIGIBILITY_CANNOT_BE_HISTORICAL_CALIBRATION' USING ERRCODE='23514'; END IF;
    IF upper(coalesce(new.payload->>'calibration_role',''))<>'SYSTEM_AUDIT_ONLY' THEN RAISE EXCEPTION 'A7_CALIBRATION_ROLE_MUST_BE_SYSTEM_AUDIT_ONLY' USING ERRCODE='23514'; END IF;
    IF lower(coalesce(new.payload->>'calibration_game_override','true')) NOT IN ('false','0','no') OR lower(coalesce(new.payload->>'calibration_sports_authority','true')) NOT IN ('false','0','no') OR lower(coalesce(new.payload->>'calibration_ranking_authority','true')) NOT IN ('false','0','no') THEN RAISE EXCEPTION 'A7_HISTORICAL_CALIBRATION_HAS_FORBIDDEN_GAME_AUTHORITY' USING ERRCODE='23514'; END IF;
    IF lower(coalesce(new.payload #>> '{game_uncertainty,historical_calibration_used}','true')) NOT IN ('false','0','no') THEN RAISE EXCEPTION 'A7_GAME_UNCERTAINTY_CANNOT_USE_HISTORICAL_CALIBRATION' USING ERRCODE='23514'; END IF;
    IF upper(coalesce(new.payload #>> '{game_uncertainty,u0_5,source}',''))<>'GAME_SPECIFIC_STRESS_TEST' OR upper(coalesce(new.payload #>> '{game_uncertainty,u1_5,source}',''))<>'GAME_SPECIFIC_STRESS_TEST' OR upper(coalesce(new.payload #>> '{game_uncertainty,u2_5,source}',''))<>'GAME_SPECIFIC_STRESS_TEST' THEN RAISE EXCEPTION 'A7_CONSERVATIVE_BOUNDS_MUST_BE_GAME_SPECIFIC' USING ERRCODE='23514'; END IF;
    IF public.nrfim_json_num(new.payload,'game_uncertainty.u0_5.lower_bound')>raw0 OR public.nrfim_json_num(new.payload,'game_uncertainty.u1_5.lower_bound')>raw1 OR public.nrfim_json_num(new.payload,'game_uncertainty.u2_5.lower_bound')>raw2 THEN RAISE EXCEPTION 'A7_GAME_UNCERTAINTY_LOWER_BOUND_ABOVE_CENTRAL' USING ERRCODE='23514'; END IF;

    IF new.payload ? 'calibrated_p' OR new.payload ? 'conservative_p' OR new.payload ? 'historical_adjusted_p'
       OR (new.payload #> '{contract_calibration,u0_5}') ?| ARRAY['calibrated_p','conservative_p','adjusted_p','historical_probability']
       OR (new.payload #> '{contract_calibration,u1_5}') ?| ARRAY['calibrated_p','conservative_p','adjusted_p','historical_probability']
       OR (new.payload #> '{contract_calibration,u2_5}') ?| ARRAY['calibrated_p','conservative_p','adjusted_p','historical_probability'] THEN
      RAISE EXCEPTION 'A7_HISTORICAL_GAME_PROBABILITY_OVERRIDE_FORBIDDEN' USING ERRCODE='23514';
    END IF;

    rel_status:=upper(coalesce(new.payload #>> '{system_reliability,status}',''));
    econ_effect:=upper(coalesce(new.payload #>> '{system_reliability,economic_effect}',''));
    IF rel_status NOT IN ('RELIABLE','OVERCONFIDENT','UNDERCONFIDENT','MIXED','INSUFFICIENT_SAMPLE','DRIFT_DETECTED','NOT_AVAILABLE') THEN RAISE EXCEPTION 'A7_SYSTEM_RELIABILITY_STATUS_INVALID' USING ERRCODE='23514'; END IF;
    IF econ_effect NOT IN ('ALLOW','CONDITION','BLOCK') THEN RAISE EXCEPTION 'A7_SYSTEM_RELIABILITY_ECONOMIC_EFFECT_INVALID' USING ERRCODE='23514'; END IF;
    IF upper(coalesce(new.payload #>> '{system_reliability,sports_effect}',''))<>'NONE' OR upper(coalesce(new.payload #>> '{system_reliability,ranking_effect}',''))<>'NONE' OR upper(coalesce(new.payload #>> '{system_reliability,probability_effect}',''))<>'NONE' THEN RAISE EXCEPTION 'A7_SYSTEM_CALIBRATION_CANNOT_CHANGE_GAME_SPORTS_OR_PROBABILITY' USING ERRCODE='23514'; END IF;
    IF rel_status IN ('NOT_AVAILABLE','DRIFT_DETECTED') AND econ_effect<>'BLOCK' THEN RAISE EXCEPTION 'A7_SYSTEM_RELIABILITY_MUST_BLOCK_ECONOMIC_AUTHORITY:%',rel_status USING ERRCODE='23514'; END IF;

    SELECT * INTO press FROM public.nrfiprensa_packets WHERE packet_id=new.payload #>> '{nrfi_prensa,packet_id}';
    IF NOT FOUND OR press.content_hash<>encode(extensions.digest(press.payload::text,'sha256'),'hex') OR press.content_hash IS DISTINCT FROM new.payload #>> '{nrfi_prensa,packet_hash}' THEN RAISE EXCEPTION 'A7_TRUSTED_NRFIPRENSA_PACKET_REQUIRED' USING ERRCODE='23514'; END IF;
    IF press.payload->'coincidences' IS DISTINCT FROM new.payload #> '{nrfi_prensa,coincidences}' OR press.payload->'discrepancies' IS DISTINCT FROM new.payload #> '{nrfi_prensa,discrepancies}' OR press.payload->'new_data' IS DISTINCT FROM new.payload #> '{nrfi_prensa,new_data}' OR press.payload->'unverified_data' IS DISTINCT FROM new.payload #> '{nrfi_prensa,unverified_data}' OR press.payload->'omitted_risks' IS DISTINCT FROM new.payload #> '{nrfi_prensa,omitted_risks}' THEN RAISE EXCEPTION 'A7_PHASE_PRESS_DATA_DIFFERS_FROM_PACKET' USING ERRCODE='23514'; END IF;
    IF new.payload #>> '{nrfi_prensa,original_verdict_hash}' IS DISTINCT FROM a6 #>> '{pre_press_verdict,hash}' THEN RAISE EXCEPTION 'A7_PRESS_CONTRAST_NOT_BOUND_TO_FROZEN_VERDICT' USING ERRCODE='23514'; END IF;

    IF upper(coalesce(new.payload->>'release_token',''))='ISSUED' THEN
      IF upper(coalesce(a1->>'a1_real_money_status',''))<>'PASS' OR upper(coalesce(a2->>'a2_baseline_status',''))<>'A2_BASELINE_PASS' OR upper(coalesce(a3->>'a3_current_version_status',''))<>'A3_CURRENT_VERSION_PASS' OR upper(coalesce(a4->>'a4_numeric_provenance_status',''))<>'A4_NUMERIC_PROVENANCE_PASS' OR upper(coalesce(a6 #>> '{sports_seal,status}','')) NOT IN ('PASS','A6_SPORTS_SEALED','A6_SPORTS_SEALED_CONDITIONED') OR upper(coalesce(a6 #>> '{independent_audit,status}',''))<>'PASS' THEN RAISE EXCEPTION 'A7_RELEASE_BLOCKED_BY_UPSTREAM_REAL_MONEY_PREFLIGHT' USING ERRCODE='23514'; END IF;
      IF upper(coalesce(new.payload->>'absolute_eligibility','')) NOT IN ('A7_ELIGIBLE','A7_ELIGIBLE_CONDITIONED') THEN RAISE EXCEPTION 'A7_RELEASE_REQUIRES_GAME_CAUSAL_ELIGIBILITY' USING ERRCODE='23514'; END IF;
      IF econ_effect='BLOCK' THEN RAISE EXCEPTION 'A7_RELEASE_BLOCKED_BY_SYSTEM_RELIABILITY_AUDIT' USING ERRCODE='23514'; END IF;
    ELSIF upper(coalesce(new.payload->>'release_token','')) NOT IN ('NOT_ISSUED','BLOCKED','N/A','NA') THEN RAISE EXCEPTION 'A7_RELEASE_TOKEN_INVALID' USING ERRCODE='23514'; END IF;
  ELSE
    SELECT payload INTO a5 FROM public.protocol_phase_state WHERE run_id=new.run_id AND game_id=new.game_id AND protocol_id=p AND phase_id='A5_JOINT_INTEGRATION';
    SELECT payload INTO a7 FROM public.protocol_phase_state WHERE run_id=new.run_id AND game_id=new.game_id AND protocol_id=p AND phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS';
    IF a7 IS NULL OR upper(coalesce(a7->>'release_token',''))<>'ISSUED' OR upper(coalesce(new.payload->>'a7_release_token',''))<>'ISSUED' THEN RAISE EXCEPTION 'A8_RELEASE_BLOCKED' USING ERRCODE='23514'; END IF;
    IF upper(coalesce(new.payload->>'a7_eligibility_status','')) IS DISTINCT FROM upper(coalesce(a7->>'absolute_eligibility','')) THEN RAISE EXCEPTION 'A8_A7_ELIGIBILITY_MISMATCH' USING ERRCODE='23514'; END IF;
    IF upper(coalesce(a7 #>> '{system_reliability,economic_effect}',''))='BLOCK' THEN RAISE EXCEPTION 'A8_SYSTEM_RELIABILITY_BLOCKS_ECONOMIC_EXECUTION' USING ERRCODE='23514'; END IF;
    line_key:=CASE upper(coalesce(new.payload->>'line_recommended','')) WHEN 'NRFI' THEN 'u0_5' WHEN 'U0.5' THEN 'u0_5' WHEN 'U1.5' THEN 'u1_5' WHEN 'U2.5' THEN 'u2_5' ELSE NULL END;
    IF line_key IS NULL THEN RAISE EXCEPTION 'A8_LINE_INVALID' USING ERRCODE='23514'; END IF;
    IF upper(coalesce(new.payload #>> '{market,p_conservative_source}',''))<>'GAME_SPECIFIC_UNCERTAINTY_ONLY' THEN RAISE EXCEPTION 'A8_P_CONSERVATIVE_SOURCE_MUST_BE_GAME_SPECIFIC' USING ERRCODE='23514'; END IF;
    lb:=public.nrfim_json_num(a7,'game_uncertainty.'||line_key||'.lower_bound');
    IF abs(public.nrfim_json_num(new.payload,'market.p_conservative')-lb)>0.000001 THEN RAISE EXCEPTION 'A8_P_CONSERVATIVE_NOT_FROM_GAME_SPECIFIC_UNCERTAINTY' USING ERRCODE='23514'; END IF;
    IF upper(coalesce(new.payload->>'calibration_status','')) IS DISTINCT FROM upper(coalesce(a7 #>> '{system_reliability,status}','')) THEN RAISE EXCEPTION 'A8_CALIBRATION_STATUS_IS_SYSTEM_AUDIT_STATUS_ONLY' USING ERRCODE='23514'; END IF;
    IF new.payload ? 'calibrated_p' OR new.payload ? 'historical_adjusted_p' THEN RAISE EXCEPTION 'A8_HISTORICAL_GAME_PROBABILITY_OVERRIDE_FORBIDDEN' USING ERRCODE='23514'; END IF;
    break_even:=public.nrfim_json_num(new.payload,'market.break_even'); decodds:=(new.payload #>> '{market,decimal_odds}')::numeric; edge:=(new.payload #>> '{market,edge}')::numeric; ev:=(new.payload #>> '{market,ev}')::numeric;
    IF decodds<=1 OR abs(edge-(lb-break_even))>0.000001 OR abs(ev-(lb*decodds-1))>0.000001 THEN RAISE EXCEPTION 'A8_ROBUST_EDGE_MATH_FAIL' USING ERRCODE='23514'; END IF;
    IF upper(coalesce(new.payload->>'final_verdict',''))='APOSTAR' AND (edge<=0 OR ev<=0) THEN RAISE EXCEPTION 'A8_NONPOSITIVE_ROBUST_EDGE_OR_EV_NO_BET' USING ERRCODE='23514'; END IF;
    IF upper(coalesce(new.payload->>'final_verdict','')) IN ('APOSTAR','SOLO_SI_CUOTA') AND upper(coalesce(new.payload->>'execution_authority',''))<>'PASS' THEN RAISE EXCEPTION 'A8_EXECUTION_AUTHORITY_NOT_PASS' USING ERRCODE='23514'; END IF;
    IF start_at IS NOT NULL THEN
      IF (new.payload->>'verdict_emitted_at')::timestamptz > start_at - interval '10 minutes' THEN RAISE EXCEPTION 'A8_VERDICT_AFTER_T10' USING ERRCODE='23514'; END IF;
      IF (new.payload #>> '{t5,as_of}')::timestamptz < start_at - interval '10 minutes' OR (new.payload #>> '{t5,as_of}')::timestamptz >= start_at THEN RAISE EXCEPTION 'A8_T5_REVALIDATION_OUTSIDE_FINAL_WINDOW' USING ERRCODE='23514'; END IF;
    END IF;
  END IF;
  RETURN new;
END $$;

DROP TRIGGER IF EXISTS trg_035_nrfimetrica_calibration_separation_v15 ON public.protocol_phase_state;
CREATE TRIGGER trg_035_nrfimetrica_calibration_separation_v15 BEFORE INSERT OR UPDATE ON public.protocol_phase_state
FOR EACH ROW WHEN (new.protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' AND new.phase_id IN ('A7_CALIBRATION_ELIGIBILITY_PRESS','A8_MARKET_VALUE_EXECUTION'))
EXECUTE FUNCTION public.nrfim_enforce_calibration_separation_v15();

UPDATE public.agent_registry
SET status='DISABLED', agent_version='MOTHER-V3-AGENT-1.10', kernel_version='NRFIM-KERNEL-1.5-CALIBRATION-SEPARATION',
    metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object(
      'database_migrations_required_through',54,
      'calibration_role','SYSTEM_AUDIT_ONLY',
      'historical_calibration_may_override_game_probability',false,
      'historical_calibration_may_change_sports_verdict',false,
      'historical_calibration_may_change_ranking',false,
      'game_probability_source','A5_GAME_CAUSAL_ONLY',
      'conservative_probability_source','GAME_SPECIFIC_STRESS_TEST_ONLY',
      'system_calibration_economic_role','SYSTEM_LEVEL_TRUST_GATE_ONLY',
      'no_game_equivalence_by_probability_score_band',true,
      'hierarchical_contextual_calibration_required',true,
      'universal_calibration_forbidden',true,
      'calibrate_system_not_game',true,
      'refactor_state','CALIBRATION_SEPARATION_VALIDATION_PENDING')
WHERE agent_id='@NRFImetrica';
