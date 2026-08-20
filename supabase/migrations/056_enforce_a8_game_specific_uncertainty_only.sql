-- 056 — A8 must use current-game stress-test uncertainty, never historical calibration.
CREATE OR REPLACE FUNCTION public.nrfim_assert_game_specific_conservative_probability(p_a7 jsonb, p_a8 jsonb, p_line_key text)
RETURNS void LANGUAGE plpgsql IMMUTABLE SET search_path TO 'public','pg_temp' AS $$
DECLARE lb numeric; used numeric;
BEGIN
  IF p_line_key NOT IN ('u0_5','u1_5','u2_5') THEN RAISE EXCEPTION 'NRFIM_A8_LINE_KEY_INVALID' USING ERRCODE='23514'; END IF;
  IF upper(coalesce(p_a8 #>> '{market,p_conservative_source}',''))<>'GAME_SPECIFIC_UNCERTAINTY_ONLY' THEN RAISE EXCEPTION 'A8_P_CONSERVATIVE_SOURCE_MUST_BE_GAME_SPECIFIC' USING ERRCODE='23514'; END IF;
  IF lower(coalesce(p_a7 #>> '{game_uncertainty,historical_calibration_used}','true')) NOT IN ('false','0','no') THEN RAISE EXCEPTION 'A8_A7_GAME_UNCERTAINTY_CONTAINS_HISTORICAL_CALIBRATION' USING ERRCODE='23514'; END IF;
  IF upper(coalesce(p_a7 #>> ARRAY['game_uncertainty',p_line_key,'source'],''))<>'GAME_SPECIFIC_STRESS_TEST' THEN RAISE EXCEPTION 'A8_A7_LOWER_BOUND_SOURCE_NOT_GAME_SPECIFIC' USING ERRCODE='23514'; END IF;
  lb:=public.nrfim_json_num(p_a7,'game_uncertainty.'||p_line_key||'.lower_bound');
  used:=public.nrfim_json_num(p_a8,'market.p_conservative');
  IF abs(lb-used)>0.000001 THEN RAISE EXCEPTION 'A8_P_CONSERVATIVE_NOT_FROM_GAME_SPECIFIC_UNCERTAINTY' USING ERRCODE='23514'; END IF;
  IF p_a8 ? 'calibrated_p' OR p_a8 ? 'historical_adjusted_p' OR (p_a8->'market') ?| ARRAY['historical_calibrated_p','historical_adjusted_p'] THEN RAISE EXCEPTION 'A8_HISTORICAL_GAME_PROBABILITY_OVERRIDE_FORBIDDEN' USING ERRCODE='23514'; END IF;
END $$;

CREATE OR REPLACE FUNCTION public.nrfim_a8_game_specific_uncertainty_guard()
RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public','pg_temp' AS $$
DECLARE a7 jsonb; line_key text;
BEGIN
  IF new.protocol_id<>'NRFIMETRICA_MOTHER_V3_AUTONOMOUS' OR new.phase_id<>'A8_MARKET_VALUE_EXECUTION' THEN RETURN new; END IF;
  SELECT payload INTO a7 FROM public.protocol_phase_state WHERE run_id=new.run_id AND game_id=new.game_id AND protocol_id=new.protocol_id AND phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS';
  IF a7 IS NULL THEN RAISE EXCEPTION 'A8_A7_REQUIRED_FOR_GAME_SPECIFIC_UNCERTAINTY' USING ERRCODE='23514'; END IF;
  line_key:=CASE upper(coalesce(new.payload->>'line_recommended','')) WHEN 'NRFI' THEN 'u0_5' WHEN 'U0.5' THEN 'u0_5' WHEN 'U1.5' THEN 'u1_5' WHEN 'U2.5' THEN 'u2_5' ELSE NULL END;
  PERFORM public.nrfim_assert_game_specific_conservative_probability(a7,new.payload,line_key);
  RETURN new;
END $$;

DROP TRIGGER IF EXISTS trg_034_nrfim_a8_game_specific_uncertainty ON public.protocol_phase_state;
CREATE TRIGGER trg_034_nrfim_a8_game_specific_uncertainty
BEFORE INSERT OR UPDATE ON public.protocol_phase_state
FOR EACH ROW WHEN (new.protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' AND new.phase_id='A8_MARKET_VALUE_EXECUTION')
EXECUTE FUNCTION public.nrfim_a8_game_specific_uncertainty_guard();

UPDATE public.agent_registry
SET metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object(
  'database_migrations_required_through',56,
  'a8_game_uncertainty_assertion','public.nrfim_assert_game_specific_conservative_probability')
WHERE agent_id='@NRFImetrica';
