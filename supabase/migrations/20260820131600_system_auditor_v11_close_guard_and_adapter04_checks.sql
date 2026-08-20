-- Completes the V1.1 migration mirror with the exact closure contract,
-- target-time adapter metadata refresh and @investigacionNRFI specific checks.

create or replace function public.system_audit_enforce_close()
returns trigger
language plpgsql
as $function$
declare
  required_count int;
  present_count int;
  bad_critical int;
  critical_fail int;
  system_key text;
  schema_ver text;
  trace_count int;
  chat_ok int;
  root_count int;
begin
  new.updated_at := now();
  if new.status='CLOSED' and old.status is distinct from 'CLOSED' then
    if new.verdict is null then
      raise exception 'AUDITOR_CLOSE_REQUIRES_VERDICT' using errcode='23514';
    end if;
    select target_system_id,auditor_schema_version into system_key,schema_ver
      from public.system_audit_runs where audit_run_id=new.audit_run_id;
    select count(*) into required_count
      from public.system_audit_adapter_checks where system_id=system_key and required=true;
    select count(*) into present_count
      from public.system_audit_check_results r
      join public.system_audit_adapter_checks c
        on c.system_id=system_key and c.check_id=r.check_id
      where r.audit_run_id=new.audit_run_id and c.required=true;
    if present_count <> required_count then
      raise exception 'AUDITOR_CLOSE_REQUIRES_ALL_REQUIRED_CHECKS:%/%',present_count,required_count using errcode='23514';
    end if;
    select count(*) into bad_critical
      from public.system_audit_check_results
      where audit_run_id=new.audit_run_id and severity='CRITICAL'
        and status in ('FAIL','NOT_PROVEN','INCONSISTENT');
    if new.verdict in ('PROCESS_VALIDATED','PROCESS_VALIDATED_WITH_OBSERVATIONS') and bad_critical>0 then
      raise exception 'AUDITOR_VALIDATED_VERDICT_FORBIDDEN_WITH_CRITICAL_OPEN:%',bad_critical using errcode='23514';
    end if;
    select count(*) into critical_fail
      from public.system_audit_check_results
      where audit_run_id=new.audit_run_id and severity='CRITICAL'
        and status in ('FAIL','INCONSISTENT');
    if new.verdict='PROCESS_INVALID' and critical_fail=0 then
      raise exception 'AUDITOR_PROCESS_INVALID_REQUIRES_CRITICAL_FAIL_OR_INCONSISTENCY' using errcode='23514';
    end if;
    if new.verdict='AUDIT_BLOCKED' and not exists(
      select 1 from public.system_audit_check_results
      where audit_run_id=new.audit_run_id and status='NOT_PROVEN'
    ) then
      raise exception 'AUDITOR_AUDIT_BLOCKED_REQUIRES_NOT_PROVEN_CHECK' using errcode='23514';
    end if;
    if new.report_drive_file_id is null then
      raise exception 'AUDITOR_CLOSE_REQUIRES_DRIVE_REPORT' using errcode='23514';
    end if;

    if schema_ver='V1.1' then
      if new.target_lock_status <> 'CONFIRMED' then
        raise exception 'AUDITOR_V11_CLOSE_REQUIRES_CONFIRMED_TARGET_LOCK' using errcode='23514';
      end if;
      if not exists(
        select 1 from public.system_audit_check_results
        where audit_run_id=new.audit_run_id and check_id='SYS-P0-TARGET-IDENTITY' and status='PASS'
      ) then raise exception 'AUDITOR_V11_CLOSE_REQUIRES_TARGET_IDENTITY_PASS' using errcode='23514'; end if;
      if not exists(
        select 1 from public.system_audit_check_results
        where audit_run_id=new.audit_run_id and check_id='SYS-P11-TRACE-COMPLETE' and status='PASS'
      ) then raise exception 'AUDITOR_V11_CLOSE_REQUIRES_TRACE_COMPLETE_PASS' using errcode='23514'; end if;
      if not exists(
        select 1 from public.system_audit_check_results
        where audit_run_id=new.audit_run_id and check_id='SYS-P12-FORENSIC-CHAT-REPORT' and status='PASS'
      ) then raise exception 'AUDITOR_V11_CLOSE_REQUIRES_FORENSIC_CHAT_REPORT_PASS' using errcode='23514'; end if;
      if not exists(
        select 1 from public.system_audit_check_results
        where audit_run_id=new.audit_run_id and check_id='SYS-P12-COMPLIANCE-ONLY-CORRECTIONS' and status='PASS'
      ) then raise exception 'AUDITOR_V11_CLOSE_REQUIRES_COMPLIANCE_ONLY_CORRECTIONS_PASS' using errcode='23514'; end if;
      select count(*) into trace_count from public.system_audit_execution_trace where audit_run_id=new.audit_run_id;
      if trace_count=0 then raise exception 'AUDITOR_V11_CLOSE_REQUIRES_EXECUTION_TRACE' using errcode='23514'; end if;
      select count(*) into chat_ok from public.system_audit_chat_reports
        where audit_run_id=new.audit_run_id and status='COMPLETE';
      if chat_ok<>1 or new.chat_report_status<>'COMPLETE' then
        raise exception 'AUDITOR_V11_CLOSE_REQUIRES_COMPLETE_CHAT_REPORT_OBJECT' using errcode='23514';
      end if;
      if new.forensic_replay_status='OPEN' then
        raise exception 'AUDITOR_V11_CLOSE_FORBIDS_OPEN_FORENSIC_REPLAY' using errcode='23514';
      end if;
      if new.forensic_replay_status='COMPLETE' and not exists(
        select 1 from public.system_audit_forensic_replays
        where audit_run_id=new.audit_run_id and status='COMPLETE' and target_write_performed=false
      ) then raise exception 'AUDITOR_V11_COMPLETE_REPLAY_REQUIRES_READ_ONLY_REPLAY_OBJECT' using errcode='23514'; end if;
      select count(*) into root_count from public.system_audit_findings
        where audit_run_id=new.audit_run_id and is_root_failure=true;
      if new.root_failure_finding_id is not null and not exists(
        select 1 from public.system_audit_findings
        where audit_run_id=new.audit_run_id and finding_id=new.root_failure_finding_id and is_root_failure=true
      ) then raise exception 'AUDITOR_V11_ROOT_FAILURE_REFERENCE_INVALID:%',new.root_failure_finding_id using errcode='23514'; end if;
    end if;
    new.completed_at:=coalesce(new.completed_at,now());
  end if;
  return new;
end $function$;

-- Keep adapter metadata as a locator while forcing target-time authority discovery.
update public.system_audit_registry r
set authority = case
  when r.system_id='@NRFiPrensa' then (
    select to_jsonb(a)||jsonb_build_object('authority_resolution_policy','RESOLVE_TARGET_TIME_CANONICAL_AUTHORITY')
    from public.nrfiprensa_authority a limit 1
  )
  when r.system_id in ('@NRFImetrica','@DepuracionMLB','@investigacionNRFI') then coalesce(
    (select to_jsonb(a)||jsonb_build_object('authority_resolution_policy','RESOLVE_TARGET_TIME_CANONICAL_AUTHORITY')
       from public.agent_registry a where a.agent_id=r.system_id),
    r.authority||jsonb_build_object('authority_resolution_policy','RESOLVE_TARGET_TIME_CANONICAL_AUTHORITY')
  )
  else r.authority||jsonb_build_object('authority_resolution_policy','RESOLVE_TARGET_TIME_CANONICAL_AUTHORITY')
end,
updated_at=now()
where r.system_id in ('@NRFiPrensa','@NRFImetrica','@DepuracionMLB','@investigacionNRFI');

insert into public.system_audit_adapter_checks
(system_id,check_id,layer_id,title,rule_text,default_severity,required,target_objects) values
('@investigacionNRFI','INV-P0-RUN-DATE','P0','Exact daily RUN/date identity','The audit must target the exact requested date/RUN and the RUN must belong to @investigacionNRFI.','CRITICAL',true,'["investigacion_nrfi_runs"]'),
('@investigacionNRFI','INV-P2-DAILY-CLEAN','P2','Daily run and volume identity','A daily execution must preserve the mandated daily-run and living-volume/report identity without silently reusing another date as current work.','CRITICAL',true,'["investigacion_nrfi_runs","investigacion_nrfi_volumes"]'),
('@investigacionNRFI','INV-P3-GAME-LEDGER','P3','Completed-game universe ledger','Daily universe must account physically for 100% of completed games and never certify coverage from a narrative number.','CRITICAL',true,'["investigacion_nrfi_games","investigacion_nrfi_runs"]'),
('@investigacionNRFI','INV-P4-TEMPORAL-CUSTODY','P4','Temporal evidence custody','Pregame/postgame lanes, AS_OF, tool events and source families must preserve target-time truth and forbid future leakage.','CRITICAL',true,'["investigacion_nrfi_tool_events","investigacion_nrfi_source_families","investigacion_nrfi_evidence"]'),
('@investigacionNRFI','INV-P5-SEMANTIC-OBJECTS','P5','Physical semantic completeness','F1-F5 completion requires the structured physical objects mandated by the current agent authority, not only JSON/status prose.','CRITICAL',true,'["investigacion_nrfi_phase_state","investigacion_nrfi_half_innings","investigacion_nrfi_plate_appearances","investigacion_nrfi_pitch_events","investigacion_nrfi_feature_values"]'),
('@investigacionNRFI','INV-P5-E1-RECEIPTS','P5','E1 receipts and evidence packets','Every required phase must have its E1 receipt/evidence lineage and daily close requires a queryable evidence packet.','CRITICAL',true,'["investigacion_nrfi_trace","investigacion_nrfi_evidence_packets"]'),
('@investigacionNRFI','INV-P8-DRIVE-READBACK','P8','Living Drive dossier contract','The active volume must use the mandated living Google Doc and append/readback evidence; rollover requires explicit user authorization.','MAJOR',true,'["investigacion_nrfi_drive_appends","Drive"]'),
('@investigacionNRFI','INV-P9-CROSS-STATE','P9','Supabase-GitHub-Drive authority consistency','Authority, run identity and state must reconcile across database, manifest/code and Drive dossier.','CRITICAL',true,'["Supabase","GitHub","Drive"]'),
('@investigacionNRFI','INV-P11-DAILY-CLOSE','P11','Daily semantic close','Daily close requires F1-F5 semantic completeness, physical game accounting, queryable evidence packet and Drive contract/readback.','CRITICAL',true,'["investigacion_nrfi_runs","investigacion_nrfi_phase_state","investigacion_nrfi_evidence_packets"]'),
('@investigacionNRFI','INV-P12-NO-SPORTS-AUTHORITY','P12','No pick or economic authority','Kernel and agent may research historical NRFI but cannot emit pick, stake, EV, odds or real-money authority.','CRITICAL',true,'["agent_registry","investigacion_nrfi_runs","reports"]')
on conflict(system_id,check_id) do update set
  rule_text=excluded.rule_text,
  default_severity=excluded.default_severity,
  required=true,
  target_objects=excluded.target_objects;
