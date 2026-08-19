-- Preserve game/freeze/model lineage across A1->A8 and prevent one contract
-- from borrowing another contract's calibration.

update public.protocol_phase_catalog
set required_fields=case when not ('a4_execution_id'=any(required_fields)) then array_append(required_fields,'a4_execution_id') else required_fields end
where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and phase_id='A5_JOINT_INTEGRATION';

update public.protocol_phase_catalog
set required_fields = required_fields
  || array(select x from unnest(array[
       'input_freeze_id','a4_execution_id',
       'contract_calibration.u0_5.raw_p','contract_calibration.u0_5.status',
       'contract_calibration.u1_5.raw_p','contract_calibration.u1_5.status',
       'contract_calibration.u2_5.raw_p','contract_calibration.u2_5.status'
     ]) x where not (x=any(required_fields)))
where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS';

update public.protocol_phase_catalog
set required_fields=case when not ('market.minimum_acceptable_price'=any(required_fields)) then array_append(required_fields,'market.minimum_acceptable_price') else required_fields end
where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and phase_id='A8_MARKET_VALUE_EXECUTION';

create or replace function public.enforce_nrfimetrica_mother_lineage()
returns trigger
language plpgsql
as $$
declare
  p text:='NRFIMETRICA_MOTHER_V3_AUTONOMOUS';
  g public.games%rowtype;
  a1 jsonb; a2 jsonb; a3 jsonb; a4 jsonb; a5 jsonb; a7 jsonb;
  raw0 numeric; raw1 numeric; raw2 numeric;
  cal jsonb; cal_status text; line_key text;
  selected_cons numeric; used_cons numeric;
  start_payload timestamptz;
begin
  if new.protocol_id<>p then return new; end if;
  select * into g from public.games where run_id=new.run_id and game_id=new.game_id;
  if not found then raise exception 'MOTHER_GAME_NOT_REGISTERED' using errcode='23514'; end if;

  if new.phase_id='A1_DATA_INTEGRITY_FREEZE' then
    if new.payload #>> '{game,game_id}' is distinct from new.game_id then raise exception 'A1_GAME_IDENTITY_MISMATCH' using errcode='23514'; end if;
    begin start_payload:=(new.payload #>> '{game,start_time}')::timestamptz;
    exception when others then raise exception 'A1_GAME_START_TIME_INVALID' using errcode='23514'; end;
    if g.scheduled_start is not null and start_payload is distinct from g.scheduled_start then raise exception 'A1_GAME_START_TIME_MISMATCH' using errcode='23514'; end if;

  elsif new.phase_id='A2_HIERARCHICAL_BASELINES' then
    select payload into a1 from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=p and phase_id='A1_DATA_INTEGRITY_FREEZE';
    if new.payload->>'input_freeze_id' is distinct from a1->>'input_freeze_id' then raise exception 'A2_FREEZE_LINEAGE_MISMATCH' using errcode='23514'; end if;

  elsif new.phase_id='A3_CURRENT_VERSION_MATCHUP' then
    select payload into a2 from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=p and phase_id='A2_HIERARCHICAL_BASELINES';
    if new.payload->>'input_freeze_id' is distinct from a2->>'input_freeze_id' then raise exception 'A3_FREEZE_LINEAGE_MISMATCH' using errcode='23514'; end if;
    if new.payload->>'a2_baseline_spec_version' is distinct from a2->>'baseline_spec_version' then raise exception 'A3_A2_SPEC_VERSION_MISMATCH' using errcode='23514'; end if;

  elsif new.phase_id='A4_NUMERIC_STATE_ENGINE' then
    select payload into a3 from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=p and phase_id='A3_CURRENT_VERSION_MATCHUP';
    if new.payload #>> '{numeric_engine,input_freeze_id}' is distinct from a3->>'input_freeze_id' then raise exception 'A4_FREEZE_LINEAGE_MISMATCH' using errcode='23514'; end if;
    if (new.payload #>> '{numeric_engine,as_of}')::timestamptz>new.submitted_at then raise exception 'A4_AS_OF_FROM_FUTURE' using errcode='23514'; end if;

  elsif new.phase_id='A5_JOINT_INTEGRATION' then
    select payload into a4 from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=p and phase_id='A4_NUMERIC_STATE_ENGINE';
    if new.payload->>'input_freeze_id' is distinct from a4 #>> '{numeric_engine,input_freeze_id}' then raise exception 'A5_FREEZE_LINEAGE_MISMATCH' using errcode='23514'; end if;
    if new.payload->>'a4_execution_id' is distinct from a4 #>> '{numeric_engine,execution_id}' then raise exception 'A5_A4_EXECUTION_LINEAGE_MISMATCH' using errcode='23514'; end if;

  elsif new.phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS' then
    select payload into a1 from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=p and phase_id='A1_DATA_INTEGRITY_FREEZE';
    select payload into a4 from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=p and phase_id='A4_NUMERIC_STATE_ENGINE';
    select payload into a5 from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=p and phase_id='A5_JOINT_INTEGRATION';
    if new.payload->>'input_freeze_id' is distinct from a1->>'input_freeze_id' then raise exception 'A7_FREEZE_LINEAGE_MISMATCH' using errcode='23514'; end if;
    if new.payload->>'a4_execution_id' is distinct from a4 #>> '{numeric_engine,execution_id}' then raise exception 'A7_A4_EXECUTION_LINEAGE_MISMATCH' using errcode='23514'; end if;
    if new.payload->>'model_version' is distinct from a4 #>> '{numeric_engine,model_version}' then raise exception 'A7_MODEL_VERSION_MISMATCH' using errcode='23514'; end if;
    if upper(coalesce(new.payload->>'engine_mode','')) is distinct from upper(coalesce(a4 #>> '{numeric_engine,engine_mode}','')) then raise exception 'A7_ENGINE_MODE_MISMATCH' using errcode='23514'; end if;
    if upper(coalesce(new.payload->>'model_tier','')) is distinct from upper(coalesce(a4 #>> '{numeric_engine,model_tier}','')) then raise exception 'A7_MODEL_TIER_MISMATCH' using errcode='23514'; end if;
    if upper(coalesce(new.payload->>'target_id','')) not in ('U0.5','NRFI') then raise exception 'A7_CORE_TARGET_MUST_BE_ZERO_RUNS' using errcode='23514'; end if;
    raw0:=public.nrfim_json_num(a5,'contracts.p_u0_5'); raw1:=public.nrfim_json_num(a5,'contracts.p_u1_5'); raw2:=public.nrfim_json_num(a5,'contracts.p_u2_5');
    if abs(public.nrfim_json_num(new.payload,'raw_p')-raw0)>0.000001 then raise exception 'A7_RAW_P_NOT_FROM_A5_P0' using errcode='23514'; end if;
    if abs(public.nrfim_json_num(new.payload,'contract_calibration.u0_5.raw_p')-raw0)>0.000001
       or abs(public.nrfim_json_num(new.payload,'contract_calibration.u1_5.raw_p')-raw1)>0.000001
       or abs(public.nrfim_json_num(new.payload,'contract_calibration.u2_5.raw_p')-raw2)>0.000001 then
      raise exception 'A7_CONTRACT_RAW_PROBABILITIES_NOT_FROM_A5' using errcode='23514';
    end if;
    if upper(coalesce(new.payload->>'release_token',''))='ISSUED' then
      cal:=new.payload #> '{contract_calibration,u0_5}';
      if upper(coalesce(cal->>'status','')) not in ('CERTIFIED','CERTIFIED_CONDITIONED') then raise exception 'A7_ZERO_RUN_CALIBRATION_REQUIRED_FOR_RELEASE' using errcode='23514'; end if;
      perform public.nrfim_json_num(new.payload,'contract_calibration.u0_5.calibrated_p');
      perform public.nrfim_json_num(new.payload,'contract_calibration.u0_5.conservative_p');
      if upper(coalesce(cal->>'region_support','')) not in ('HIGH','MEDIUM') or length(btrim(coalesce(cal->>'calibrator_version','')))=0 then raise exception 'A7_ZERO_RUN_CALIBRATION_METADATA_INCOMPLETE' using errcode='23514'; end if;
    end if;

  elsif new.phase_id='A8_MARKET_VALUE_EXECUTION' then
    select payload into a1 from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=p and phase_id='A1_DATA_INTEGRITY_FREEZE';
    select payload into a7 from public.protocol_phase_state where run_id=new.run_id and game_id=new.game_id and protocol_id=p and phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS';
    if new.payload #>> '{t5,active_freeze_id}' is distinct from a1->>'final_input_freeze_id' then raise exception 'A8_T5_ACTIVE_FREEZE_MISMATCH' using errcode='23514'; end if;
    if upper(coalesce(new.payload->>'a7_eligibility_status','')) is distinct from upper(coalesce(a7->>'absolute_eligibility','')) then raise exception 'A8_A7_ELIGIBILITY_MISMATCH' using errcode='23514'; end if;
    line_key:=case upper(coalesce(new.payload->>'line_recommended','')) when 'NRFI' then 'u0_5' when 'U0.5' then 'u0_5' when 'U1.5' then 'u1_5' when 'U2.5' then 'u2_5' else null end;
    if line_key is null then raise exception 'A8_LINE_INVALID' using errcode='23514'; end if;
    cal:=a7 #> array['contract_calibration',line_key]; cal_status:=upper(coalesce(cal->>'status',''));
    if cal_status not in ('CERTIFIED','CERTIFIED_CONDITIONED') then raise exception 'A8_SELECTED_CONTRACT_NOT_CALIBRATED:%',line_key using errcode='23514'; end if;
    if upper(coalesce(new.payload->>'calibration_status','')) is distinct from cal_status then raise exception 'A8_SELECTED_CONTRACT_CALIBRATION_STATUS_MISMATCH' using errcode='23514'; end if;
    selected_cons:=public.nrfim_json_num(cal,'conservative_p'); used_cons:=public.nrfim_json_num(new.payload,'market.p_conservative');
    if abs(selected_cons-used_cons)>0.000001 then raise exception 'A8_P_CONSERVATIVE_NOT_FROM_SELECTED_CONTRACT_CALIBRATION' using errcode='23514'; end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_03_nrfimetrica_mother_lineage on public.protocol_phase_state;
create trigger trg_03_nrfimetrica_mother_lineage
before insert or update on public.protocol_phase_state
for each row execute function public.enforce_nrfimetrica_mother_lineage();
