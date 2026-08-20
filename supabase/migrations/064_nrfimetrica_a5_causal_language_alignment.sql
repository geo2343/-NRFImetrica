update public.protocol_phase_catalog
set required_fields=array_replace(required_fields,'raw_not_calibrated_check','game_causal_not_historical_check')
where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and phase_id='A5_JOINT_INTEGRATION';

do $do$
declare ddl text;
begin
  select pg_get_functiondef('public.enforce_nrfimetrica_mother_semantics()'::regprocedure) into ddl;
  ddl:=replace(ddl,$old$upper(coalesce(new.payload->>'raw_not_calibrated_check',''))<>'PASS'$old$,$new$upper(coalesce(new.payload->>'game_causal_not_historical_check',''))<>'PASS'$new$);
  execute ddl;
end $do$;