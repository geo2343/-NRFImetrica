-- Final trusted-artifact gate for A4/A6/A7/A8.

create or replace function public.enforce_nrfimetrica_trusted_artifacts_v2()
returns trigger language plpgsql as $$
declare
  p text:='NRFIMETRICA_MOTHER_V3_AUTONOMOUS';
  run_mode text; ex public.numeric_engine_executions%rowtype; aud public.independent_audit_executions%rowtype;
  press public.nrfiprensa_packets%rowtype; sra public.sra_packets%rowtype; cert public.calibration_certifications%rowtype;
  offer public.market_offers%rowtype; t5 public.t5_revalidations%rowtype; a5 jsonb;
  target_key text; target_id text; cert_id text; eid text; market_odds numeric; market_asof timestamptz;
begin
  if new.protocol_id<>p then return new; end if;
  select mode into run_mode from public.runs where run_id=new.run_id;

  if new.phase_id='A4_NUMERIC_STATE_ENGINE' then
    select * into ex from public.numeric_engine_executions where execution_id=new.payload #>> '{numeric_engine,execution_id}';
    if not found then raise exception 'A4_TRUSTED_NUMERIC_EXECUTION_REQUIRED' using errcode='23514'; end if;
    if ex.output_hash<>encode(digest(ex.output_payload::text,'sha256'),'hex') then raise exception 'A4_NUMERIC_OUTPUT_HASH_INVALID' using errcode='23514'; end if;
    if ex.output_payload->'top' is distinct from new.payload->'top' or ex.output_payload->'bottom' is distinct from new.payload->'bottom' then
      raise exception 'A4_PHASE_OUTPUT_DIFFERS_FROM_ENGINE_OUTPUT' using errcode='23514';
    end if;

  elsif new.phase_id='A6_CAUSAL_FALSIFICATION_SPORTS_SEAL' then
    select * into aud from public.independent_audit_executions where audit_execution_id=new.payload #>> '{independent_audit,audit_execution_id}';
    if not found then raise exception 'A6_TRUSTED_INDEPENDENT_AUDIT_EXECUTION_REQUIRED' using errcode='23514'; end if;
    if aud.output_hash<>encode(digest(aud.payload::text,'sha256'),'hex') then raise exception 'A6_AUDIT_OUTPUT_HASH_INVALID' using errcode='23514'; end if;
    if coalesce(aud.payload->>'central_case','') is distinct from coalesce(new.payload #>> '{independent_audit,central_case}','')
       or coalesce(aud.payload->>'best_yrfi_rival','') is distinct from coalesce(new.payload #>> '{independent_audit,best_yrfi_rival}','')
       or coalesce(aud.payload->>'divergence_class','') is distinct from coalesce(new.payload #>> '{independent_audit,divergence_class}','')
       or upper(coalesce(aud.payload->>'status','')) is distinct from upper(coalesce(new.payload #>> '{independent_audit,status}','')) then
      raise exception 'A6_PHASE_AUDIT_DIFFERS_FROM_AUDITOR_OUTPUT' using errcode='23514';
    end if;

    select * into sra from public.sra_packets where packet_id=new.payload #>> '{sra,packet_id}';
    if not found or sra.run_id<>new.run_id or sra.game_id<>new.game_id then raise exception 'A6_SRA_PACKET_REQUIRED' using errcode='23514'; end if;
    if sra.content_hash<>encode(digest(sra.payload::text,'sha256'),'hex') or sra.content_hash is distinct from new.payload #>> '{sra,packet_hash}' then raise exception 'A6_SRA_PACKET_HASH_MISMATCH' using errcode='23514'; end if;
    if run_mode='DIAGNOSTIC' then
      if sra.status<>'DIAGNOSTIC_COMPLETE' then raise exception 'A6_SRA_NOT_DIAGNOSTIC_COMPLETE' using errcode='23514'; end if;
    else
      if sra.status not in ('COMPLETE','DATA_UNAVAILABLE') then raise exception 'A6_SRA_NOT_COMPLETE' using errcode='23514'; end if;
    end if;
    if sra.generated_at>new.submitted_at then raise exception 'A6_SRA_PACKET_FROM_FUTURE' using errcode='23514'; end if;
    if coalesce(sra.payload->>'team_packet_status','') is distinct from coalesce(new.payload #>> '{sra,team_packet_status}','')
       or coalesce(sra.payload->>'b1_b4_packet_status','') is distinct from coalesce(new.payload #>> '{sra,b1_b4_packet_status}','') then
      raise exception 'A6_PHASE_SRA_DIFFERS_FROM_PACKET' using errcode='23514';
    end if;

  elsif new.phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS' then
    select * into press from public.nrfiprensa_packets where packet_id=new.payload #>> '{nrfi_prensa,packet_id}';
    if not found then raise exception 'A7_TRUSTED_NRFIPRENSA_PACKET_REQUIRED' using errcode='23514'; end if;
    if press.content_hash<>encode(digest(press.payload::text,'sha256'),'hex') or press.content_hash is distinct from new.payload #>> '{nrfi_prensa,packet_hash}' then raise exception 'A7_NRFIPRENSA_PACKET_HASH_MISMATCH' using errcode='23514'; end if;
    if press.payload->'coincidences' is distinct from new.payload #> '{nrfi_prensa,coincidences}'
       or press.payload->'discrepancies' is distinct from new.payload #> '{nrfi_prensa,discrepancies}'
       or press.payload->'new_data' is distinct from new.payload #> '{nrfi_prensa,new_data}'
       or press.payload->'unverified_data' is distinct from new.payload #> '{nrfi_prensa,unverified_data}'
       or press.payload->'omitted_risks' is distinct from new.payload #> '{nrfi_prensa,omitted_risks}' then
      raise exception 'A7_PHASE_PRESS_DATA_DIFFERS_FROM_PACKET' using errcode='23514';
    end if;

    foreach target_key in array array['u0_5','u1_5','u2_5'] loop
      if upper(coalesce(new.payload #>> array['contract_calibration',target_key,'status'],'')) in ('CERTIFIED','CERTIFIED_CONDITIONED') then
        cert_id:=new.payload #>> array['contract_calibration',target_key,'certification_id'];
        target_id:=case target_key when 'u0_5' then 'U0.5' when 'u1_5' then 'U1.5' else 'U2.5' end;
        select * into cert from public.calibration_certifications where certification_id=cert_id;
        if not found or not cert.active or cert.target_id<>target_id or cert.model_version<>new.payload->>'model_version'
           or upper(cert.engine_mode)<>upper(new.payload->>'engine_mode') or upper(cert.model_tier)<>upper(new.payload->>'model_tier')
           or cert.calibrator_version<>coalesce(new.payload #>> array['contract_calibration',target_key,'calibrator_version'],new.payload->>'calibrator_version')
           or cert.status not in ('CERTIFIED','CERTIFIED_CONDITIONED') or cert.oos_validation_status<>'PASS' or cert.provenance_status<>'PASS' then
          raise exception 'A7_TRUSTED_CALIBRATION_CERTIFICATION_REQUIRED:%',target_id using errcode='23514';
        end if;
      end if;
    end loop;

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
    begin
      market_odds:=(new.payload #>> '{market,decimal_odds}')::numeric;
      market_asof:=(new.payload #>> '{market,as_of}')::timestamptz;
    exception when others then
      raise exception 'A8_MARKET_OFFER_FIELDS_INVALID' using errcode='23514';
    end;
    if offer.sportsbook is distinct from new.payload #>> '{market,sportsbook}'
       or offer.line_exact is distinct from new.payload #>> '{market,line_exact}'
       or offer.price_exact is distinct from new.payload #>> '{market,price_exact}'
       or abs(offer.decimal_odds-market_odds)>0.000001 then
      raise exception 'A8_MARKET_FIELDS_DIFFER_FROM_VERIFIED_OFFER' using errcode='23514';
    end if;
    if market_asof is distinct from offer.retrieved_at then raise exception 'A8_MARKET_ASOF_DIFFERS_FROM_VERIFIED_OFFER' using errcode='23514'; end if;
    if abs(public.nrfim_json_num(new.payload,'market.break_even')-(1/offer.decimal_odds))>0.000001 then raise exception 'A8_BREAK_EVEN_NOT_FROM_VERIFIED_PRICE' using errcode='23514'; end if;
    if offer.retrieved_at>new.submitted_at then raise exception 'A8_MARKET_OFFER_FROM_FUTURE' using errcode='23514'; end if;
    if not exists(select 1 from public.evidence e where e.evidence_id=offer.evidence_id and e.run_id=new.run_id and (e.game_id is null or e.game_id=new.game_id)
                  and coalesce(e.data_available_at,e.retrieved_at)<=offer.retrieved_at
                  and (coalesce(e.source_ref,'')='' or e.source_ref=offer.source_ref)) then
      raise exception 'A8_MARKET_OFFER_EVIDENCE_INVALID' using errcode='23514';
    end if;

    select * into t5 from public.t5_revalidations where revalidation_id=new.payload #>> '{t5,revalidation_id}';
    if not found or t5.run_id<>new.run_id or t5.game_id<>new.game_id or t5.offer_id<>offer.offer_id then raise exception 'A8_T5_VERIFIED_RECORD_REQUIRED' using errcode='23514'; end if;
    if run_mode='DIAGNOSTIC' then
      if t5.status<>'DIAGNOSTIC_VERIFIED' then raise exception 'A8_T5_NOT_DIAGNOSTIC_VERIFIED' using errcode='23514'; end if;
    else
      if t5.status<>'VERIFIED' then raise exception 'A8_T5_NOT_VERIFIED' using errcode='23514'; end if;
    end if;
    if t5.material_change then raise exception 'A8_T5_MATERIAL_CHANGE_FULL_RECOMPUTE_REQUIRED' using errcode='23514'; end if;
    if not t5.starter_confirmed or not t5.official_lineup_verified then raise exception 'A8_T5_STARTER_OR_LINEUP_NOT_VERIFIED' using errcode='23514'; end if;
    if t5.active_freeze_id is distinct from new.payload #>> '{t5,active_freeze_id}'
       or t5.as_of is distinct from (new.payload #>> '{t5,as_of}')::timestamptz
       or t5.line_exact is distinct from new.payload #>> '{t5,line_exact}'
       or t5.price_exact is distinct from new.payload #>> '{t5,price_exact}'
       or abs(t5.break_even-public.nrfim_json_num(new.payload,'t5.break_even'))>0.000001 then
      raise exception 'A8_T5_FIELDS_DIFFER_FROM_VERIFIED_RECORD' using errcode='23514';
    end if;
    foreach eid in array t5.evidence_ids loop
      if not exists(select 1 from public.evidence e where e.evidence_id=eid and e.run_id=new.run_id and (e.game_id is null or e.game_id=new.game_id) and coalesce(e.data_available_at,e.retrieved_at)<=t5.as_of) then raise exception 'A8_T5_EVIDENCE_INVALID:%',eid using errcode='23514'; end if;
    end loop;
    if lower(coalesce(new.payload #>> '{t5,material_change}','false')) not in ('false','0','no')
       or upper(coalesce(new.payload #>> '{t5,recompute_status}','')) not in ('NOT_REQUIRED','PASS') then
      raise exception 'A8_T5_RECOMPUTE_STATE_INVALID' using errcode='23514';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_04_nrfimetrica_trusted_artifacts_v2 on public.protocol_phase_state;
create trigger trg_04_nrfimetrica_trusted_artifacts_v2 before insert or update on public.protocol_phase_state
for each row execute function public.enforce_nrfimetrica_trusted_artifacts_v2();
