drop trigger if exists trg_034_nrfim_a8_game_specific_uncertainty on public.protocol_phase_state;
drop function if exists public.nrfim_a8_game_specific_uncertainty_guard();
drop function if exists public.nrfim_assert_game_specific_conservative_probability(jsonb,jsonb,text);
drop function if exists public.nrfimetrica_assert_a8_lineage_v16(jsonb,jsonb);
drop function if exists public.nrfim_enforce_calibration_separation_v15();

do $$
declare r record;
begin
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
end $$;

revoke all on public.nrfimetrica_press_intakes from anon,authenticated;
revoke all on public.nrfimetrica_press_items from anon,authenticated;
revoke all on public.nrfimetrica_press_item_dispositions from anon,authenticated;
revoke all on public.nrfimetrica_semantic_reclassification_events from anon,authenticated;
revoke all on public.nrfimetrica_kernel_tests from anon,authenticated;
grant select,insert,update,delete on public.nrfimetrica_press_intakes to service_role;
grant select,insert,update,delete on public.nrfimetrica_press_items to service_role;
grant select,insert,update,delete on public.nrfimetrica_press_item_dispositions to service_role;
grant select,insert,update,delete on public.nrfimetrica_semantic_reclassification_events to service_role;
grant select,insert,update,delete on public.nrfimetrica_kernel_tests to service_role;