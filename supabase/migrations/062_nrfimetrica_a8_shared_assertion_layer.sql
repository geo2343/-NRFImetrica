create or replace function public.nrfimetrica_assert_a8_game_specific_execution_v16(a8 jsonb, a7 jsonb)
returns void
language plpgsql
immutable
set search_path=public,pg_temp
as $$
declare
  line_key text;
  lb numeric;
  break_even numeric;
  decodds numeric;
  edge numeric;
  ev numeric;
begin
  if upper(coalesce(a7->>'release_token',''))<>'ISSUED' or upper(coalesce(a8->>'a7_release_token',''))<>'ISSUED' then
    raise exception 'A8_RELEASE_BLOCKED' using errcode='23514';
  end if;
  if upper(coalesce(a7 #>> '{system_reliability,economic_effect}',''))='BLOCK' then
    raise exception 'A8_SYSTEM_RELIABILITY_BLOCKS_ECONOMIC_EXECUTION' using errcode='23514';
  end if;
  if upper(coalesce(a8 #>> '{system_reliability,status}','')) is distinct from upper(coalesce(a7 #>> '{system_reliability,status}','')) then
    raise exception 'A8_SYSTEM_RELIABILITY_STATUS_LINEAGE_MISMATCH' using errcode='23514';
  end if;
  if upper(coalesce(a8 #>> '{system_reliability,economic_effect}','')) is distinct from upper(coalesce(a7 #>> '{system_reliability,economic_effect}','')) then
    raise exception 'A8_SYSTEM_RELIABILITY_EFFECT_LINEAGE_MISMATCH' using errcode='23514';
  end if;
  if lower(coalesce(a7 #>> '{press_integration,reanalysis_required}','false')) in ('true','1','yes') then
    raise exception 'A8_BLOCKED_PENDING_CAUSAL_REANALYSIS' using errcode='23514';
  end if;
  line_key:=case upper(coalesce(a8->>'line_recommended','')) when 'NRFI' then 'u0_5' when 'U0.5' then 'u0_5' when 'U1.5' then 'u1_5' when 'U2.5' then 'u2_5' else null end;
  if line_key is null then raise exception 'A8_LINE_INVALID' using errcode='23514'; end if;
  if upper(coalesce(a8 #>> '{market,p_conservative_source}',''))<>'GAME_SPECIFIC_UNCERTAINTY_ONLY' then
    raise exception 'A8_P_CONSERVATIVE_SOURCE_MUST_BE_GAME_SPECIFIC' using errcode='23514';
  end if;
  lb:=public.nrfim_json_num(a7,'game_uncertainty.'||line_key||'.lower_bound');
  if abs(public.nrfim_json_num(a8,'market.p_conservative')-lb)>0.000001 then
    raise exception 'A8_P_CONSERVATIVE_NOT_FROM_GAME_SPECIFIC_UNCERTAINTY' using errcode='23514';
  end if;
  if abs(public.nrfim_json_num(a8,'game_specific_lower_bound')-lb)>0.000001 then
    raise exception 'A8_GAME_SPECIFIC_LOWER_BOUND_LINEAGE_MISMATCH' using errcode='23514';
  end if;
  if a8 ? 'calibrated_p' or a8 ? 'historical_adjusted_p' then
    raise exception 'A8_HISTORICAL_GAME_PROBABILITY_OVERRIDE_FORBIDDEN' using errcode='23514';
  end if;
  break_even:=public.nrfim_json_num(a8,'market.break_even');
  decodds:=(a8 #>> '{market,decimal_odds}')::numeric;
  edge:=(a8 #>> '{market,edge}')::numeric;
  ev:=(a8 #>> '{market,ev}')::numeric;
  if decodds<=1 or abs(edge-(lb-break_even))>0.000001 or abs(ev-(lb*decodds-1))>0.000001 then
    raise exception 'A8_ROBUST_EDGE_MATH_FAIL' using errcode='23514';
  end if;
end;
$$;

create or replace function public.nrfimetrica_a8_separation_guard_v16()
returns trigger
language plpgsql
set search_path=public,pg_temp
as $$
declare a7 jsonb;
begin
  if new.protocol_id<>'NRFIMETRICA_MOTHER_V3_AUTONOMOUS' or new.phase_id<>'A8_MARKET_VALUE_EXECUTION' then return new; end if;
  select payload into a7 from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=new.protocol_id and phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS';
  if a7 is null then raise exception 'A8_A7_PAYLOAD_NOT_FOUND' using errcode='23514'; end if;
  perform public.nrfimetrica_assert_a8_game_specific_execution_v16(new.payload,a7);
  return new;
end;
$$;