-- @NRFImetrica v1.7 guarded activation after terminal self-audit.
do $$
declare
  terminal_total integer;
  terminal_pass integer;
  terminal_fail integer;
  post_total integer;
  post_pass integer;
  gap_count integer;
  bad_dml integer;
  bad_definer integer;
  bad_search_path integer;
  bad_exec integer;
  open_runs integer;
  migration_count integer;
begin
  if not exists (
    select 1 from public.agent_registry
    where agent_id='@NRFImetrica'
      and status='DISABLED'
      and agent_version='MOTHER-V3-AGENT-1.12'
      and kernel_version='NRFIM-KERNEL-1.7-SELF-AUDIT-HARDENED'
      and mother_document_sha256='799ccb5a483e7991f880ae7d49d2f191a98e292478ec64e76a55aa8250ec498b'
  ) then
    raise exception 'NRFIM_V17_ACTIVATION_REGISTRY_IDENTITY_OR_STATE_INVALID' using errcode='23514';
  end if;

  if not exists (
    select 1 from public.system_versions
    where system_version='NRFIM MOTHER V3'
      and kernel_version='NRFIM-KERNEL-1.7-SELF-AUDIT-HARDENED'
      and contract_doc_id='MOTHER_SHA256:799ccb5a483e7991f880ae7d49d2f191a98e292478ec64e76a55aa8250ec498b'
      and calibration_status='SYSTEM_AUDIT_ONLY_NO_GAME_OVERRIDE'
  ) then
    raise exception 'NRFIM_V17_ACTIVATION_SYSTEM_VERSION_INVALID' using errcode='23514';
  end if;

  if not exists (
    select 1 from public.protocol_authority
    where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS'
      and document_sha256='799ccb5a483e7991f880ae7d49d2f191a98e292478ec64e76a55aa8250ec498b'
      and latest_sovereign_patch='POST_ACTIVATION_SELF_AUDIT_HARDENING — 2026-08-20'
      and active
  ) then
    raise exception 'NRFIM_V17_ACTIVATION_PROTOCOL_AUTHORITY_INVALID' using errcode='23514';
  end if;

  select count(*) into migration_count
  from supabase_migrations.schema_migrations
  where name in (
    'nrfimetrica_v17_self_audit_hardening',
    'nrfimetrica_v17_unresolved_reanalysis_assertion',
    'nrfimetrica_v17_lock_client_dml_views'
  );
  if migration_count<>3 then
    raise exception 'NRFIM_V17_ACTIVATION_REQUIRED_MIGRATIONS_MISSING:%',migration_count using errcode='23514';
  end if;

  select count(*),count(*) filter(where passed),count(*) filter(where not passed)
    into terminal_total,terminal_pass,terminal_fail
  from public.nrfimetrica_kernel_tests
  where test_suite='V17_POST_071_TERMINAL_AUDIT';
  if terminal_total<>20 or terminal_pass<>20 or terminal_fail<>0 then
    raise exception 'NRFIM_V17_ACTIVATION_TERMINAL_AUDIT_NOT_20_OF_20:%/%/%',terminal_total,terminal_pass,terminal_fail using errcode='23514';
  end if;

  select count(*),count(*) filter(where passed)
    into post_total,post_pass
  from public.nrfimetrica_kernel_tests
  where test_suite='V17_SELF_AUDIT_POST_FIX';
  if post_total<>12 or post_pass<>12 then
    raise exception 'NRFIM_V17_ACTIVATION_POST_FIX_SUITE_NOT_12_OF_12:%/%',post_total,post_pass using errcode='23514';
  end if;

  select count(*) into gap_count
  from public.nrfimetrica_kernel_tests
  where test_suite='V16_SELF_AUDIT_PRE_FIX'
    and actual_outcome='GAP_CONFIRMED'
    and passed=false;
  if gap_count<>2 then
    raise exception 'NRFIM_V17_ACTIVATION_GAP_TRACE_NOT_PRESERVED:%',gap_count using errcode='23514';
  end if;

  if exists (
    select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind='r' and c.relname like 'nrfimetrica_%' and not c.relrowsecurity
  ) then
    raise exception 'NRFIM_V17_ACTIVATION_RLS_GAP' using errcode='23514';
  end if;

  select count(*) into bad_dml
  from information_schema.role_table_grants
  where table_schema='public' and table_name like 'nrfimetrica_%'
    and grantee in ('anon','authenticated')
    and privilege_type in ('INSERT','UPDATE','DELETE','TRUNCATE');
  if bad_dml<>0 then
    raise exception 'NRFIM_V17_ACTIVATION_CLIENT_DML_GRANTS:%',bad_dml using errcode='23514';
  end if;

  select count(*) into bad_definer
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and (p.proname like 'nrfimetrica_%' or p.proname like 'nrfim_%' or p.proname like 'enforce_nrfimetrica_%')
    and p.prosecdef;
  if bad_definer<>0 then
    raise exception 'NRFIM_V17_ACTIVATION_SECURITY_DEFINER:%',bad_definer using errcode='23514';
  end if;

  select count(*) into bad_search_path
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and (p.proname like 'nrfimetrica_%' or p.proname like 'nrfim_%' or p.proname like 'enforce_nrfimetrica_%')
    and coalesce(array_to_string(p.proconfig,','),'') not ilike '%search_path=public%';
  if bad_search_path<>0 then
    raise exception 'NRFIM_V17_ACTIVATION_UNSAFE_SEARCH_PATH:%',bad_search_path using errcode='23514';
  end if;

  select count(*) into bad_exec
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and (p.proname like 'nrfimetrica_%' or p.proname like 'nrfim_%' or p.proname like 'enforce_nrfimetrica_%')
    and (has_function_privilege('anon',p.oid,'EXECUTE') or has_function_privilege('authenticated',p.oid,'EXECUTE'));
  if bad_exec<>0 then
    raise exception 'NRFIM_V17_ACTIVATION_CLIENT_EXECUTE:%',bad_exec using errcode='23514';
  end if;

  if (select count(*) from pg_trigger t where not t.tgisinternal and t.tgenabled<>'D' and t.tgname in (
      'trg_000_nrfimetrica_no_ai_probability_v17',
      'trg_nrfimetrica_system_audit_guard_v17',
      'trg_036_nrfimetrica_a7_press_integration_v16',
      'trg_037_nrfimetrica_a8_separation_v16'))<>4 then
    raise exception 'NRFIM_V17_ACTIVATION_REQUIRED_TRIGGERS_MISSING' using errcode='23514';
  end if;

  if not exists (
    select 1 from public.protocol_phase_catalog
    where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS'
      and phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS'
      and required_fields @> array['system_reliability.audit_id','press_integration.market_effect','press_integration.conclusion_effect']
  ) or not exists (
    select 1 from public.protocol_phase_catalog
    where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS'
      and phase_id='A8_MARKET_VALUE_EXECUTION'
      and required_fields @> array['target_id','a7_eligibility_status']
  ) then
    raise exception 'NRFIM_V17_ACTIVATION_PHASE_CONTRACT_INVALID' using errcode='23514';
  end if;

  if position('process_status = ''VERIFIED''' in pg_get_viewdef('public.nrfimetrica_user_action'::regclass,true))=0
     or position('drive_hash_verified' in pg_get_viewdef('public.nrfimetrica_user_action'::regclass,true))=0
     or position('execution_status = ''EXECUTABLE''' in pg_get_viewdef('public.nrfimetrica_user_action'::regclass,true))=0
     or position('U0.5' in pg_get_viewdef('public.nrfimetrica_game_dual_status'::regclass,true))=0 then
    raise exception 'NRFIM_V17_ACTIVATION_USER_ACTION_NOT_FAIL_CLOSED' using errcode='23514';
  end if;

  if position('A7_PRESS_UNAVAILABLE' in pg_get_functiondef('public.enforce_nrfimetrica_game_resolution()'::regprocedure))>0
     or position('A7_CALIBRATION_UNCERTIFIED' in pg_get_functiondef('public.enforce_nrfimetrica_game_resolution()'::regprocedure))>0 then
    raise exception 'NRFIM_V17_ACTIVATION_LEGACY_RESOLUTION_ROUTE_ACTIVE' using errcode='23514';
  end if;

  select count(*) into open_runs
  from public.runs
  where system_version='NRFIM MOTHER V3'
    and status not in ('CLOSED','SUPERSEDED_HISTORICAL','AUDIT_ONLY');
  if open_runs<>0 then
    raise exception 'NRFIM_V17_ACTIVATION_OPEN_RUNS:%',open_runs using errcode='23514';
  end if;

  update public.agent_registry
  set status='ACTIVE',
      agent_version='MOTHER-V3-AGENT-1.12',
      kernel_version='NRFIM-KERNEL-1.7-SELF-AUDIT-HARDENED',
      mother_document_sha256='799ccb5a483e7991f880ae7d49d2f191a98e292478ec64e76a55aa8250ec498b',
      metadata=(coalesce(metadata,'{}'::jsonb)
        - 'database_migrations_required_through'
        - 'github_migrations_through'
        - 'terminal_validation_state'
        - 'github_parity_state'
        - 'post_activation_audit_state'
        - 'real_money_authority')
        || jsonb_build_object(
          'database_migrations_required_through',72,
          'github_migrations_through',72,
          'terminal_validation_state','PASS_20_OF_20_POST_071',
          'github_parity_state','MIGRATION_072_VERSIONED_BEFORE_ACTIVATION',
          'post_activation_audit_state','V17_ACTIVE_AFTER_SELF_AUDIT',
          'post_fix_adversarial_suite','PASS_12_OF_12',
          'pre_fix_gap_confirmed',2,
          'mother_hash_external_readback','PASS',
          'client_dml_view_surface','LOCKED_READ_ONLY',
          'real_money_authority',false,
          'system_reliability_default_without_audit','NOT_AVAILABLE_BLOCK',
          'target_execution_scope','U0.5_ONLY_UNTIL_TARGET_SPECIFIC_CERTIFICATION'
        ),
      updated_at=clock_timestamp()
  where agent_id='@NRFImetrica';
end $$;
