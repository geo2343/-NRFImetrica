-- Read-only architecture assertions for @AnalistaDepuracionRNFI_D.
-- Production DDL is tracked by the Supabase migration ledger documented in PRODUCTION_MIGRATION_CHAIN.md.

do $$
declare n integer;
begin
  if to_regclass('public.depurnrfi_d_runs') is null then raise exception 'MISSING depurnrfi_d_runs'; end if;
  if to_regclass('public.depurnrfi_d_phase_receipts') is null then raise exception 'MISSING depurnrfi_d_phase_receipts'; end if;
  if to_regclass('public.depurnrfi_d_pre_dialogue_reports') is null then raise exception 'MISSING depurnrfi_d_pre_dialogue_reports'; end if;
  if to_regclass('public.depurnrfi_d_dialogue_turns') is null then raise exception 'MISSING depurnrfi_d_dialogue_turns'; end if;
  if to_regclass('public.depurnrfi_d_dialogue_closings') is null then raise exception 'MISSING depurnrfi_d_dialogue_closings'; end if;

  select count(*) into n from public.depurnrfi_d_requirement_catalog where binding;
  if n <> 1057 then raise exception 'REQUIREMENT_COUNT_MISMATCH expected=1057 got=%', n; end if;

  if not exists(select 1 from public.depurnrfi_d_phase_catalog where phase_code='F9' and order_index=9) then raise exception 'F9_ORDER_MISSING'; end if;
  if not exists(select 1 from public.depurnrfi_d_phase_catalog where phase_code='D1' and order_index=10) then raise exception 'D1_ORDER_MISSING'; end if;
  if not exists(select 1 from public.depurnrfi_d_phase_catalog where phase_code='D2' and order_index=11) then raise exception 'D2_ORDER_MISSING'; end if;
  if not exists(select 1 from public.depurnrfi_d_phase_catalog where phase_code='F10' and order_index=12) then raise exception 'F10_ORDER_MISSING'; end if;
  if not exists(select 1 from public.depurnrfi_d_phase_catalog where phase_code='F11' and order_index=13) then raise exception 'F11_ORDER_MISSING'; end if;
  if not exists(select 1 from public.depurnrfi_d_phase_catalog where phase_code='REPORT_D' and order_index=14) then raise exception 'REPORT_D_ORDER_MISSING'; end if;

  if to_regprocedure('public.depurnrfi_d_create_run(text,date,jsonb)') is null then raise exception 'MISSING depurnrfi_d_create_run'; end if;
  if to_regprocedure('public.depurnrfi_d_submit_phase(text,text,jsonb,jsonb)') is null then raise exception 'MISSING depurnrfi_d_submit_phase'; end if;
  if to_regprocedure('public.depurnrfi_d_commit_pre_dialogue_report(text,text,jsonb)') is null then raise exception 'MISSING depurnrfi_d_commit_pre_dialogue_report'; end if;
  if to_regprocedure('public.depurnrfi_d_commit_dialogue_turn_authorized(uuid,text,text,text,text,jsonb,jsonb)') is null then raise exception 'MISSING depurnrfi_d_commit_dialogue_turn_authorized'; end if;
  if to_regprocedure('public.depurnrfi_d_commit_dialogue_closing_authorized(uuid,text,text,jsonb)') is null then raise exception 'MISSING depurnrfi_d_commit_dialogue_closing_authorized'; end if;
end $$;
