-- Exact live-state reconciler for MOTHER-V3-AGENT-1.11 / KERNEL 1.6.

create or replace function public.nrfimetrica_assert_a8_lineage_v16(a8 jsonb, a7 jsonb)
returns void
language plpgsql
immutable
set search_path=public,extensions,pg_temp
as $$
declare line_key text; lb numeric; break_even numeric; decodds numeric; edge numeric; ev numeric;
begin
  if upper(coalesce(a7 #>> '{system_reliability,economic_effect}',''))='BLOCK' then raise exception 'A8_SYSTEM_RELIABILITY_BLOCKS_ECONOMIC_EXECUTION' using errcode='23514'; end if;
  if upper(coalesce(a8 #>> '{system_reliability,status}','')) is distinct from upper(coalesce(a7 #>> '{system_reliability,status}','')) then raise exception 'A8_SYSTEM_RELIABILITY_STATUS_LINEAGE_MISMATCH' using errcode='23514'; end if;
  if upper(coalesce(a8 #>> '{system_reliability,economic_effect}','')) is distinct from upper(coalesce(a7 #>> '{system_reliability,economic_effect}','')) then raise exception 'A8_SYSTEM_RELIABILITY_EFFECT_LINEAGE_MISMATCH' using errcode='23514'; end if;
  if lower(coalesce(a7 #>> '{press_integration,reanalysis_required}','false')) in ('true','1','yes') then raise exception 'A8_BLOCKED_PENDING_CAUSAL_REANALYSIS' using errcode='23514'; end if;
  line_key:=case upper(coalesce(a8->>'line_recommended','')) when 'NRFI' then 'u0_5' when 'U0.5' then 'u0_5' when 'U1.5' then 'u1_5' when 'U2.5' then 'u2_5' else null end;
  if line_key is null then raise exception 'A8_LINE_INVALID' using errcode='23514'; end if;
  if upper(coalesce(a8 #>> '{market,p_conservative_source}',''))<>'GAME_SPECIFIC_UNCERTAINTY_ONLY' then raise exception 'A8_P_CONSERVATIVE_SOURCE_MUST_BE_GAME_SPECIFIC' using errcode='23514'; end if;
  lb:=public.nrfim_json_num(a7,'game_uncertainty.'||line_key||'.lower_bound');
  if abs(public.nrfim_json_num(a8,'market.p_conservative')-lb)>0.000001 then raise exception 'A8_P_CONSERVATIVE_NOT_FROM_GAME_SPECIFIC_UNCERTAINTY' using errcode='23514'; end if;
  if abs(public.nrfim_json_num(a8,'game_specific_lower_bound')-lb)>0.000001 then raise exception 'A8_GAME_SPECIFIC_LOWER_BOUND_LINEAGE_MISMATCH' using errcode='23514'; end if;
  if a8 ? 'calibrated_p' or a8 ? 'historical_adjusted_p' then raise exception 'A8_HISTORICAL_GAME_PROBABILITY_OVERRIDE_FORBIDDEN' using errcode='23514'; end if;
  break_even:=public.nrfim_json_num(a8,'market.break_even');
  decodds:=(a8 #>> '{market,decimal_odds}')::numeric;
  edge:=(a8 #>> '{market,edge}')::numeric;
  ev:=(a8 #>> '{market,ev}')::numeric;
  if decodds<=1 or abs(edge-(lb-break_even))>0.000001 or abs(ev-(lb*decodds-1))>0.000001 then raise exception 'A8_ROBUST_EDGE_MATH_FAIL' using errcode='23514'; end if;
end;
$$;

create or replace function public.nrfimetrica_assert_a8_game_specific_execution_v16(a8 jsonb, a7 jsonb)
returns void
language plpgsql
immutable
set search_path=public,extensions,pg_temp
as $$
begin
  if upper(coalesce(a7->>'release_token',''))<>'ISSUED' or upper(coalesce(a8->>'a7_release_token',''))<>'ISSUED' then raise exception 'A8_RELEASE_BLOCKED' using errcode='23514'; end if;
  perform public.nrfimetrica_assert_a8_lineage_v16(a8,a7);
end;
$$;

create or replace function public.nrfimetrica_a8_separation_guard_v16()
returns trigger
language plpgsql
set search_path=public,extensions,pg_temp
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

drop trigger if exists trg_034_nrfim_a8_game_specific_uncertainty on public.protocol_phase_state;
drop function if exists public.nrfim_a8_game_specific_uncertainty_guard();
drop function if exists public.nrfim_assert_game_specific_conservative_probability(jsonb,jsonb,text);
drop function if exists public.nrfim_enforce_calibration_separation_v15();

update public.protocol_phase_catalog
set required_fields=array_replace(required_fields,'raw_not_calibrated_check','game_causal_not_historical_check')
where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and phase_id='A5_JOINT_INTEGRATION';

do $do$
declare ddl text; r record;
begin
  select pg_get_functiondef('public.enforce_nrfimetrica_mother_semantics()'::regprocedure) into ddl;
  ddl:=replace(ddl,$old$upper(coalesce(new.payload->>'raw_not_calibrated_check',''))<>'PASS'$old$,$new$upper(coalesce(new.payload->>'game_causal_not_historical_check',''))<>'PASS'$new$);
  execute ddl;

  for r in
    select p.oid::regprocedure::text as sig
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.prokind='f'
      and (p.proname like 'nrfimetrica_%' or p.proname like 'nrfim_%' or p.proname in ('enforce_nrfimetrica_mother_semantics','enforce_nrfimetrica_run_stage'))
  loop
    execute format('alter function %s set search_path = public, extensions, pg_temp',r.sig);
    execute format('revoke execute on function %s from public, anon, authenticated',r.sig);
    execute format('grant execute on function %s to service_role',r.sig);
  end loop;
end $do$;

update public.agent_registry
set metadata=(coalesce(metadata,'{}'::jsonb)
  - 'mother_export_lines' - 'activated_at' - 'a8_game_uncertainty_assertion'
  - 'database_migrations_required_through' - 'refactor_state' - 'press_delta_refactor_state')
  || jsonb_build_object(
    'refactor_state','FINAL_VALIDATION',
    'press_delta_refactor_state','PASS',
    'database_migrations_required_through',65,
    'mother_document_id','1U7UM5fkBAPt3FjZ7X7tKtxvudFyFpvM9FOs6A1C1ITw',
    'mother_export_sha256','44edaa44707293115f8d129b8903c1d8f7dfa5f6bd79674de29cee01091228d8',
    'mother_hash_external_readback','PASS',
    'a8_game_uncertainty_assertion','public.nrfimetrica_assert_a8_game_specific_execution_v16',
    'github_migrations_through',65,
    'github_parity_state','CODE_SYNCED_PENDING_ACTIVATION',
    'notion_role','CONSULTATION_ONLY_NO_WRITE_AUTHORITY',
    'nrfiprensa_write_scope','NONE',
    'receiver_side_only',true,
    'terminal_validation_state','IN_PROGRESS'
  ), updated_at=now()
where agent_id='@NRFImetrica';