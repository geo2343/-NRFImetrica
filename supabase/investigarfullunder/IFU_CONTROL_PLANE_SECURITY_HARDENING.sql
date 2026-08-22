-- @Investigarfullunder — control-plane security hardening
-- Production target: Supabase project yejaollmavoudbxnbpll
-- Applied after IFU-EXHAUSTIVE-REPORT-1.0.

-- Every internal fullunder_* table in exposed public schema must have RLS enabled.
do $rls$
declare r record;
begin
  for r in
    select c.relname
    from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind='r' and c.relname like 'fullunder_%' and not c.relrowsecurity
  loop
    execute format('alter table public.%I enable row level security',r.relname);
  end loop;
end
$rls$;

-- Internal SECURITY DEFINER helpers are service-role surfaces, not browser RPCs.
do $rpc$
declare r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and p.prosecdef
      and p.proname in (
        'fullunder_build_requirement_execution_appendix',
        'fullunder_capture_requirement_execution_from_command',
        'fullunder_chat_handoff_exhaustive_gate',
        'fullunder_compile_active_policy',
        'fullunder_compute_deterministic_audit',
        'fullunder_guard_atomic_requirement_support',
        'fullunder_handoff_exhaustive_report_gate',
        'fullunder_issue_capability',
        'fullunder_mark_descendants_stale',
        'fullunder_phase_requirement_detail_gate',
        'fullunder_requirement_detail_audit',
        'fullunder_requirement_execution_appendix_hash',
        'fullunder_requirement_support_is_valid',
        'fullunder_run_readiness_invariant',
        'fullunder_commit_requirement_details'
      )
  loop
    execute format('revoke all on function %s from public, anon, authenticated',r.sig);
    execute format('grant execute on function %s to service_role',r.sig);
  end loop;
end
$rpc$;

-- Pin search_path on Full Under guards/triggers flagged by the database linter.
do $sp$
declare r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and p.proname in (
        'fullunder_requirement_detail_write_guard','fullunder_guard_run_binding','fullunder_guard_handoff',
        'fullunder_after_phase_receipt','fullunder_after_handoff','fullunder_compute_target_binding_hash',
        'fullunder_guard_run_insert','fullunder_guard_phase_receipt','fullunder_guard_requirement_state_phase',
        'fullunder_terminal_receipt_immutable','fullunder_json_has_forbidden_key','fullunder_handoff_immutable',
        'fullunder_guard_source_temporal','fullunder_guard_artifact_mutation','fullunder_chain_run_event',
        'fullunder_guard_requirement_state_mutation','fullunder_structure_receipt_immutable',
        'fullunder_guard_structure_receipt','fullunder_chat_output_permit_write_guard','fullunder_event_store_immutable',
        'fullunder_kernel_commit_guard','fullunder_guard_external_lineage','fullunder_command_bus_guard'
      )
  loop
    execute format('alter function %s set search_path to public, extensions',r.sig);
  end loop;
end
$sp$;

-- Validation performed after production application:
-- * fullunder_* ordinary tables with RLS disabled: 0
-- * internal Full Under SECURITY DEFINER helpers executable by anon/authenticated: 0
-- * service-role command bus smoke after hardening: CREATE_RUN PASS, REQUEST_TOOL PASS
-- * fixture transaction rolled back: residue 0
