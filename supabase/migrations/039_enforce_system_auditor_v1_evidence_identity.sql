-- @AuditorSistema V1.0 — adapter identity, evidence and close guards
create or replace function public.system_audit_enforce_check_result() returns trigger
language plpgsql as $$
declare target_system text; expected_layer text;
begin
  select target_system_id into target_system from public.system_audit_runs where audit_run_id=new.audit_run_id;
  if target_system is null then raise exception 'AUDITOR_CHECK_REQUIRES_EXISTING_AUDIT_RUN' using errcode='23514'; end if;
  select layer_id into expected_layer from public.system_audit_adapter_checks where system_id=target_system and check_id=new.check_id and required=true;
  if expected_layer is null then raise exception 'AUDITOR_CHECK_NOT_REGISTERED_FOR_TARGET:%:%',target_system,new.check_id using errcode='23514'; end if;
  if new.layer_id<>expected_layer then raise exception 'AUDITOR_CHECK_LAYER_MISMATCH:%:%/%',new.check_id,new.layer_id,expected_layer using errcode='23514'; end if;
  if new.status in ('PASS','FAIL','INCONSISTENT') and jsonb_array_length(new.evidence_refs)=0 then raise exception 'AUDITOR_MATERIAL_CHECK_REQUIRES_PHYSICAL_EVIDENCE:%',new.check_id using errcode='23514'; end if;
  if length(trim(new.detail))<20 then raise exception 'AUDITOR_CHECK_DETAIL_TOO_THIN:%',new.check_id using errcode='23514'; end if;
  return new;
end $$;

drop trigger if exists trg_system_audit_check_guard on public.system_audit_check_results;
create trigger trg_system_audit_check_guard before insert or update on public.system_audit_check_results for each row execute function public.system_audit_enforce_check_result();

create or replace function public.system_audit_enforce_run_identity() returns trigger
language plpgsql as $$
begin
  new.updated_at:=now();
  if new.status='CLOSED' then
    if new.audit_scope='FULL_PROCESS' and new.target_run_id is null then raise exception 'AUDITOR_FULL_PROCESS_CLOSE_REQUIRES_TARGET_RUN_ID' using errcode='23514'; end if;
    if new.drive_folder_id is null then raise exception 'AUDITOR_CLOSE_REQUIRES_UNIQUE_DRIVE_FOLDER' using errcode='23514'; end if;
    if new.report_hash is null then raise exception 'AUDITOR_CLOSE_REQUIRES_REPORT_HASH' using errcode='23514'; end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_system_audit_run_identity_guard on public.system_audit_runs;
create trigger trg_system_audit_run_identity_guard before insert or update on public.system_audit_runs for each row execute function public.system_audit_enforce_run_identity();
