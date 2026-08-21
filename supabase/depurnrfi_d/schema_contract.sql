-- @AnalistaDepuracionRNFI_D — V1.1.1 current architecture assertions.
-- This file is intentionally read-only. It must fail against a V1.0 or partially migrated database.

do $$
declare n integer; located integer; failed integer; old_exec boolean;
begin
  if to_regclass('public.depurnrfi_d_runs') is null then raise exception 'MISSING depurnrfi_d_runs'; end if;
  if to_regclass('public.depurnrfi_d_requirement_catalog') is null then raise exception 'MISSING depurnrfi_d_requirement_catalog'; end if;
  if to_regclass('public.depurnrfi_d_evidence') is null then raise exception 'MISSING depurnrfi_d_evidence'; end if;
  if to_regclass('public.depurnrfi_d_tool_events') is null then raise exception 'MISSING depurnrfi_d_tool_events'; end if;
  if to_regclass('public.depurnrfi_d_drive_readbacks') is null then raise exception 'MISSING depurnrfi_d_drive_readbacks'; end if;
  if to_regclass('public.depurnrfi_d_commands') is null then raise exception 'MISSING depurnrfi_d_commands'; end if;

  select count(*),count(*) filter(
    where source_start_line>0 and source_end_line>=source_start_line
      and source_text_sha256='c46dc9a945d37e3e53e2a6e3879045c6c7de38b25ea5f92894fded5cbaff857b'
      and title not like 'Canonical source subsection %'
  ) into n,located from public.depurnrfi_d_requirement_catalog where binding;
  if n<>1057 or located<>1057 then raise exception 'LITERAL_CATALOG_NOT_READY total=% located=%',n,located; end if;

  if not exists(select 1 from public.depurnrfi_d_phase_catalog where phase_code='F9' and order_index=9) then raise exception 'F9_ORDER_MISSING'; end if;
  if not exists(select 1 from public.depurnrfi_d_phase_catalog where phase_code='D1' and order_index=10 and expected_requirement_count=19) then raise exception 'D1_ORDER_OR_COUNT_MISSING'; end if;
  if not exists(select 1 from public.depurnrfi_d_phase_catalog where phase_code='D2' and order_index=11 and expected_requirement_count=20) then raise exception 'D2_ORDER_OR_COUNT_MISSING'; end if;
  if not exists(select 1 from public.depurnrfi_d_phase_catalog where phase_code='F10' and order_index=12 and expected_requirement_count=54) then raise exception 'F10_ORDER_OR_COUNT_MISSING'; end if;
  if not exists(select 1 from public.depurnrfi_d_phase_catalog where phase_code='F11' and order_index=13 and expected_requirement_count=45) then raise exception 'F11_ORDER_OR_COUNT_MISSING'; end if;

  if to_regprocedure('public.depurnrfi_d_create_run_v11(text,date,jsonb,text,text)') is null then raise exception 'MISSING create_run_v11'; end if;
  if to_regprocedure('public.depurnrfi_d_submit_command_v11(jsonb)') is null then raise exception 'MISSING command_bus_v11'; end if;
  if to_regprocedure('public.depurnrfi_d_get_execution_plan_v11(text)') is null then raise exception 'MISSING execution_plan_v11'; end if;
  if to_regprocedure('public.depurnrfi_d_attest_requirement_v11(text,text,text,text,text,jsonb,text)') is null then raise exception 'MISSING requirement_attestation_v11'; end if;
  if to_regprocedure('public.depurnrfi_d_commit_pre_dialogue_report_v11(text,text,jsonb,jsonb,integer,text)') is null then raise exception 'MISSING report_commit_v11'; end if;
  if to_regprocedure('public.depurnrfi_d_commit_dialogue_turn_v11(uuid,text,text,text,text,jsonb,jsonb,jsonb,integer,text)') is null then raise exception 'MISSING dialogue_turn_v11'; end if;

  old_exec=has_function_privilege('service_role','public.depurnrfi_d_submit_phase(text,text,jsonb,jsonb)','EXECUTE');
  if old_exec then raise exception 'LEGACY_V1_SUBMIT_BYPASS_REOPENED'; end if;
  if (select count(*) from pg_class c join pg_namespace ns on ns.oid=c.relnamespace where ns.nspname='public' and c.relkind='r' and c.relname like 'depurnrfi_d_%' and not c.relrowsecurity)>0 then raise exception 'DEPURNRFI_D_TABLE_WITHOUT_RLS'; end if;
  if (select count(*) from pg_proc p join pg_namespace ns on ns.oid=p.pronamespace where ns.nspname='public' and p.proname like 'depurnrfi_d_%' and has_function_privilege('anon',p.oid,'EXECUTE'))>0 then raise exception 'ANON_RPC_EXPOSURE'; end if;
  if (select count(*) from pg_proc p join pg_namespace ns on ns.oid=p.pronamespace where ns.nspname='public' and p.proname like 'depurnrfi_d_%' and has_function_privilege('authenticated',p.oid,'EXECUTE'))>0 then raise exception 'AUTHENTICATED_DIRECT_RPC_EXPOSURE'; end if;

  select count(*) filter(where not passed) into failed from public.kendel_current_agent_test_results where canonical_agent_id='@AnalistaDepuracionRNFI_D' and suite_id='DEPURNRFI-D-CURRENT-1.1';
  if failed<>0 then raise exception 'CURRENT_SUITE_HAS_FAILURES:%',failed; end if;
end $$;
