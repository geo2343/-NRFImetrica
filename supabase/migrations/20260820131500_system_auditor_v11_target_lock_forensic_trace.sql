-- @AuditorSistema V1.1
-- Canonical DB migration mirror for the migration already applied to Supabase.
-- Scope: exact target lock, target-time authority, total execution trace,
-- read-only forensic replay, detailed chat report, compliance-only corrections.

alter table public.system_audit_runs add column if not exists auditor_schema_version text;
update public.system_audit_runs set auditor_schema_version='V1.0' where auditor_schema_version is null;
alter table public.system_audit_runs alter column auditor_schema_version set default 'V1.1';
alter table public.system_audit_runs alter column auditor_schema_version set not null;

alter table public.system_audit_runs add column if not exists target_lock_status text;
update public.system_audit_runs set target_lock_status='LEGACY_UNVERIFIED' where target_lock_status is null;
alter table public.system_audit_runs alter column target_lock_status set default 'UNRESOLVED';
alter table public.system_audit_runs alter column target_lock_status set not null;

alter table public.system_audit_runs add column if not exists target_identity jsonb;
update public.system_audit_runs set target_identity='{}'::jsonb where target_identity is null;
alter table public.system_audit_runs alter column target_identity set default '{}'::jsonb;
alter table public.system_audit_runs alter column target_identity set not null;
alter table public.system_audit_runs add column if not exists target_match_reason text;
alter table public.system_audit_runs add column if not exists target_ambiguity jsonb;
update public.system_audit_runs set target_ambiguity='[]'::jsonb where target_ambiguity is null;
alter table public.system_audit_runs alter column target_ambiguity set default '[]'::jsonb;
alter table public.system_audit_runs alter column target_ambiguity set not null;
alter table public.system_audit_runs add column if not exists target_locked_at timestamptz;

alter table public.system_audit_runs add column if not exists forensic_replay_status text;
update public.system_audit_runs set forensic_replay_status='NOT_REQUIRED' where forensic_replay_status is null;
alter table public.system_audit_runs alter column forensic_replay_status set default 'NOT_REQUIRED';
alter table public.system_audit_runs alter column forensic_replay_status set not null;
alter table public.system_audit_runs add column if not exists chat_report_status text;
update public.system_audit_runs set chat_report_status='LEGACY_NOT_REQUIRED' where chat_report_status is null;
alter table public.system_audit_runs alter column chat_report_status set default 'PENDING';
alter table public.system_audit_runs alter column chat_report_status set not null;
alter table public.system_audit_runs add column if not exists root_failure_finding_id text;

alter table public.system_audit_runs drop constraint if exists system_audit_runs_target_lock_status_check;
alter table public.system_audit_runs add constraint system_audit_runs_target_lock_status_check
  check (target_lock_status in ('UNRESOLVED','CONFIRMED','AMBIGUOUS','MISMATCH','LEGACY_UNVERIFIED'));
alter table public.system_audit_runs drop constraint if exists system_audit_runs_forensic_replay_status_check;
alter table public.system_audit_runs add constraint system_audit_runs_forensic_replay_status_check
  check (forensic_replay_status in ('NOT_REQUIRED','OPEN','COMPLETE','ABORTED'));
alter table public.system_audit_runs drop constraint if exists system_audit_runs_chat_report_status_check;
alter table public.system_audit_runs add constraint system_audit_runs_chat_report_status_check
  check (chat_report_status in ('PENDING','COMPLETE','LEGACY_NOT_REQUIRED'));

alter table public.system_audit_findings add column if not exists authority_rule_ref text;
alter table public.system_audit_findings add column if not exists failure_mode text;
alter table public.system_audit_findings add column if not exists root_cause text;
alter table public.system_audit_findings add column if not exists required_correction text;
alter table public.system_audit_findings add column if not exists retest_requirement text;
alter table public.system_audit_findings add column if not exists is_root_failure boolean not null default false;
alter table public.system_audit_findings add column if not exists downstream_of_finding_id text;

create table if not exists public.system_audit_execution_trace (
  trace_id text primary key,
  audit_run_id text not null references public.system_audit_runs(audit_run_id) on delete cascade,
  sequence_no integer not null check (sequence_no > 0),
  layer_id text not null check (layer_id ~ '^P([0-9]|1[0-2])$'),
  phase_or_object text not null,
  expected_requirement text not null,
  observed_execution text not null,
  input_refs jsonb not null default '[]'::jsonb,
  output_refs jsonb not null default '[]'::jsonb,
  evidence_refs jsonb not null default '[]'::jsonb,
  status text not null check (status in ('PASS','FAIL','NOT_PROVEN','NOT_APPLICABLE','INCONSISTENT')),
  failure_mode text,
  is_root_failure boolean not null default false,
  downstream_from_trace_id text,
  created_at timestamptz not null default now(),
  unique(audit_run_id,sequence_no)
);

create table if not exists public.system_audit_forensic_replays (
  replay_id text primary key,
  audit_run_id text not null references public.system_audit_runs(audit_run_id) on delete cascade,
  trigger_trace_id text,
  status text not null default 'OPEN' check(status in ('OPEN','COMPLETE','ABORTED')),
  authority_snapshot jsonb not null,
  data_cutoff timestamptz not null,
  allowed_input_refs jsonb not null default '[]'::jsonb,
  expected_process text not null,
  reconstructed_observation text,
  comparison text,
  propagation_map jsonb not null default '[]'::jsonb,
  target_write_performed boolean not null default false check(target_write_performed=false),
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create table if not exists public.system_audit_chat_reports (
  audit_run_id text primary key references public.system_audit_runs(audit_run_id) on delete cascade,
  report_version text not null default 'FORENSIC_CHAT_REPORT_V1',
  status text not null default 'DRAFT' check(status in ('DRAFT','COMPLETE')),
  report_text text not null,
  report_hash text not null,
  sections jsonb not null default '{}'::jsonb,
  generated_at timestamptz not null default now(),
  completed_at timestamptz
);

create or replace function public.system_audit_enforce_run_identity()
returns trigger language plpgsql as $function$
declare
  required_keys text[] := array['requested_reference','requested_agent','resolved_agent','target_run_id','target_scope','target_report_locator','target_match_basis'];
  k text;
begin
  new.updated_at:=now();
  if new.auditor_schema_version='V1.1' and new.target_lock_status='CONFIRMED' then
    if new.target_run_id is null then raise exception 'AUDITOR_V11_TARGET_LOCK_REQUIRES_TARGET_RUN_ID' using errcode='23514'; end if;
    if jsonb_typeof(new.target_identity)<>'object' then raise exception 'AUDITOR_V11_TARGET_IDENTITY_MUST_BE_OBJECT' using errcode='23514'; end if;
    foreach k in array required_keys loop
      if not (new.target_identity ? k) or nullif(trim(new.target_identity->>k),'') is null then
        raise exception 'AUDITOR_V11_TARGET_IDENTITY_MISSING:%',k using errcode='23514';
      end if;
    end loop;
    if new.target_identity->>'requested_agent'<>new.target_system_id or new.target_identity->>'resolved_agent'<>new.target_system_id then
      raise exception 'AUDITOR_V11_TARGET_AGENT_MISMATCH:%:%:%',new.target_system_id,new.target_identity->>'requested_agent',new.target_identity->>'resolved_agent' using errcode='23514';
    end if;
    if new.target_identity->>'target_run_id'<>new.target_run_id then raise exception 'AUDITOR_V11_TARGET_RUN_MISMATCH' using errcode='23514'; end if;
    if jsonb_typeof(new.target_ambiguity)<>'array' or jsonb_array_length(new.target_ambiguity)<>0 then raise exception 'AUDITOR_V11_CONFIRMED_TARGET_CANNOT_HAVE_AMBIGUITY' using errcode='23514'; end if;
    if new.target_match_reason is null or length(trim(new.target_match_reason))<40 then raise exception 'AUDITOR_V11_TARGET_MATCH_REASON_TOO_THIN' using errcode='23514'; end if;
    if upper(new.target_identity->>'target_scope')='GAME' and nullif(trim(new.target_identity->>'game_id'),'') is null then raise exception 'AUDITOR_V11_GAME_SCOPE_REQUIRES_GAME_ID' using errcode='23514'; end if;
    if upper(new.target_identity->>'target_scope')='SLATE' and not (new.target_identity ? 'slate_date' or new.target_identity ? 'game_ids') then raise exception 'AUDITOR_V11_SLATE_SCOPE_REQUIRES_SLATE_DATE_OR_GAME_IDS' using errcode='23514'; end if;
    new.target_locked_at:=coalesce(new.target_locked_at,now());
  end if;
  if new.auditor_schema_version='V1.1' and new.status='CLOSED' then
    if new.target_lock_status<>'CONFIRMED' then raise exception 'AUDITOR_V11_CLOSE_REQUIRES_CONFIRMED_TARGET_LOCK' using errcode='23514'; end if;
    if new.chat_report_status<>'COMPLETE' then raise exception 'AUDITOR_V11_CLOSE_REQUIRES_COMPLETE_CHAT_REPORT' using errcode='23514'; end if;
    if new.forensic_replay_status='OPEN' then raise exception 'AUDITOR_V11_CLOSE_FORBIDS_OPEN_FORENSIC_REPLAY' using errcode='23514'; end if;
  end if;
  if new.status='CLOSED' then
    if new.audit_scope='FULL_PROCESS' and new.target_run_id is null then raise exception 'AUDITOR_FULL_PROCESS_CLOSE_REQUIRES_TARGET_RUN_ID' using errcode='23514'; end if;
    if new.drive_folder_id is null then raise exception 'AUDITOR_CLOSE_REQUIRES_UNIQUE_DRIVE_FOLDER' using errcode='23514'; end if;
    if new.report_hash is null then raise exception 'AUDITOR_CLOSE_REQUIRES_REPORT_HASH' using errcode='23514'; end if;
  end if;
  return new;
end $function$;

create or replace function public.system_audit_enforce_check_result()
returns trigger language plpgsql as $function$
declare target_system text; expected_layer text; schema_ver text; lock_status text;
begin
  select target_system_id,auditor_schema_version,target_lock_status into target_system,schema_ver,lock_status from public.system_audit_runs where audit_run_id=new.audit_run_id;
  if target_system is null then raise exception 'AUDITOR_CHECK_REQUIRES_EXISTING_AUDIT_RUN' using errcode='23514'; end if;
  select layer_id into expected_layer from public.system_audit_adapter_checks where system_id=target_system and check_id=new.check_id and required=true;
  if expected_layer is null then raise exception 'AUDITOR_CHECK_NOT_REGISTERED_FOR_TARGET:%:%',target_system,new.check_id using errcode='23514'; end if;
  if new.layer_id<>expected_layer then raise exception 'AUDITOR_CHECK_LAYER_MISMATCH:%:%/%',new.check_id,new.layer_id,expected_layer using errcode='23514'; end if;
  if schema_ver='V1.1' and new.layer_id<>'P0' and lock_status<>'CONFIRMED' then raise exception 'AUDITOR_V11_P1_P12_FORBIDDEN_BEFORE_TARGET_LOCK:%:%',new.check_id,lock_status using errcode='23514'; end if;
  if schema_ver='V1.1' and new.check_id='SYS-P0-TARGET-IDENTITY' and new.status='PASS' and lock_status<>'CONFIRMED' then raise exception 'AUDITOR_V11_TARGET_IDENTITY_PASS_REQUIRES_CONFIRMED_LOCK' using errcode='23514'; end if;
  if new.status in ('PASS','FAIL','INCONSISTENT') and jsonb_array_length(new.evidence_refs)=0 then raise exception 'AUDITOR_MATERIAL_CHECK_REQUIRES_PHYSICAL_EVIDENCE:%',new.check_id using errcode='23514'; end if;
  if length(trim(new.detail))<20 then raise exception 'AUDITOR_CHECK_DETAIL_TOO_THIN:%',new.check_id using errcode='23514'; end if;
  return new;
end $function$;

create or replace function public.system_audit_enforce_finding_v11()
returns trigger language plpgsql as $function$
declare
  schema_ver text;
  allowed_modes text[]:=array['NOT_EXECUTED','PARTIALLY_EXECUTED','EXECUTED_INCORRECTLY','OUT_OF_ORDER','WRONG_INPUT','STALE_INPUT','WRONG_AUTHORITY','BYPASS','FALSE_COMPLIANCE','STATE_MISREPRESENTATION','CONTAMINATION','MISSING_ARTIFACT','CROSS_SYSTEM_INCONSISTENCY','AUTHORITY_CONFLICT','TARGET_MISMATCH','LEGACY_UNCLASSIFIED'];
begin
  select auditor_schema_version into schema_ver from public.system_audit_runs where audit_run_id=new.audit_run_id;
  if schema_ver='V1.1' then
    if new.authority_rule_ref is null or length(trim(new.authority_rule_ref))<5 then raise exception 'AUDITOR_V11_FINDING_REQUIRES_AUTHORITY_RULE_REF:%',new.finding_id using errcode='23514'; end if;
    if new.failure_mode is null or not(new.failure_mode=any(allowed_modes)) then raise exception 'AUDITOR_V11_FINDING_REQUIRES_VALID_FAILURE_MODE:%',new.finding_id using errcode='23514'; end if;
    if new.severity in ('CRITICAL','MAJOR') then
      if new.required_correction is null or length(trim(new.required_correction))<20 then raise exception 'AUDITOR_V11_MAJOR_FINDING_REQUIRES_COMPLIANCE_CORRECTION:%',new.finding_id using errcode='23514'; end if;
      if new.retest_requirement is null or length(trim(new.retest_requirement))<20 then raise exception 'AUDITOR_V11_MAJOR_FINDING_REQUIRES_RETEST:%',new.finding_id using errcode='23514'; end if;
    end if;
  end if;
  return new;
end $function$;

drop trigger if exists trg_system_audit_finding_v11_guard on public.system_audit_findings;
create trigger trg_system_audit_finding_v11_guard before insert or update on public.system_audit_findings for each row execute function public.system_audit_enforce_finding_v11();

create or replace function public.system_audit_enforce_chat_report_v11()
returns trigger language plpgsql as $function$
declare
  required_sections text[]:=array['target_identification','authority_requirements','chronological_reconstruction','trace_matrix','correct_processes','root_failure','propagation_map','findings_explained','p0_p12_matrix','compliance_corrections','retest'];
  k text;
begin
  if new.status='COMPLETE' then
    if length(trim(new.report_text))<1200 then raise exception 'AUDITOR_V11_CHAT_REPORT_TOO_THIN' using errcode='23514'; end if;
    if jsonb_typeof(new.sections)<>'object' then raise exception 'AUDITOR_V11_CHAT_REPORT_SECTIONS_MUST_BE_OBJECT' using errcode='23514'; end if;
    foreach k in array required_sections loop
      if not(new.sections ? k) then raise exception 'AUDITOR_V11_CHAT_REPORT_MISSING_SECTION:%',k using errcode='23514'; end if;
    end loop;
    new.completed_at:=coalesce(new.completed_at,now());
  end if;
  return new;
end $function$;

drop trigger if exists trg_system_audit_chat_report_v11_guard on public.system_audit_chat_reports;
create trigger trg_system_audit_chat_report_v11_guard before insert or update on public.system_audit_chat_reports for each row execute function public.system_audit_enforce_chat_report_v11();

create or replace function public.system_audit_enforce_trace_v11()
returns trigger language plpgsql as $function$
declare schema_ver text; lock_status text;
begin
  select auditor_schema_version,target_lock_status into schema_ver,lock_status from public.system_audit_runs where audit_run_id=new.audit_run_id;
  if schema_ver='V1.1' and new.layer_id<>'P0' and lock_status<>'CONFIRMED' then raise exception 'AUDITOR_V11_TRACE_FORBIDDEN_BEFORE_TARGET_LOCK:%',new.trace_id using errcode='23514'; end if;
  if new.status in ('PASS','FAIL','INCONSISTENT') and jsonb_array_length(new.evidence_refs)=0 then raise exception 'AUDITOR_V11_TRACE_MATERIAL_STATE_REQUIRES_EVIDENCE:%',new.trace_id using errcode='23514'; end if;
  if length(trim(new.expected_requirement))<15 or length(trim(new.observed_execution))<15 then raise exception 'AUDITOR_V11_TRACE_EXPLANATION_TOO_THIN:%',new.trace_id using errcode='23514'; end if;
  return new;
end $function$;

drop trigger if exists trg_system_audit_trace_v11_guard on public.system_audit_execution_trace;
create trigger trg_system_audit_trace_v11_guard before insert or update on public.system_audit_execution_trace for each row execute function public.system_audit_enforce_trace_v11();

-- Adapter 04: current physically verified @investigacionNRFI identity.
insert into public.system_audit_registry(system_id,display_name,adapter_version,target_project_id,target_namespace,authority,drive_root_id,notion_page_id,active)
values('@investigacionNRFI','INVESTIGACIÓN HISTÓRICA NRFI / @investigacionNRFI','ADAPTER-1.0','yejaollmavoudbxnbpll','investigacion_nrfi_',
 jsonb_build_object('protocol_id','INVESTIGACION_NRFI_HISTORICAL_V1','system_version','INVESTIGACION-NRFI-HISTORICAL-V1.0','agent_version','INVESTIGACION-NRFI-AGENT-1.1','kernel_version','INVESTIGACION-NRFI-KERNEL-0.2-SEMANTIC-COMPLETENESS','mother_document_sha256','faaf79e94729a129ed790ee7cd9d90872c602cfdc3756769e5f6e415b25d89fd','authority_resolution_policy','RESOLVE_TARGET_TIME_CANONICAL_AUTHORITY','real_money_authority',false),
 '1jsuemCCNiDZlVOVNTgdLw67vUDTzhLkE',null,true)
on conflict(system_id) do update set display_name=excluded.display_name,adapter_version=excluded.adapter_version,target_project_id=excluded.target_project_id,target_namespace=excluded.target_namespace,authority=excluded.authority,drive_root_id=excluded.drive_root_id,active=true,updated_at=now();

-- Universal V1.1 checks for every registered adapter.
insert into public.system_audit_adapter_checks(system_id,check_id,layer_id,title,rule_text,default_severity,required,target_objects)
select r.system_id,v.check_id,v.layer_id,v.title,v.rule_text,v.severity,true,v.targets
from public.system_audit_registry r
cross join(values
 ('SYS-P0-TARGET-IDENTITY','P0','Exact target identity','Before P1 prove that system/RUN/game-or-slate/report is exactly the object requested. Wrong-target audit is invalid.','CRITICAL','["system_audit_runs","target physical run/report"]'::jsonb),
 ('SYS-P1-TARGET-TIME-AUTHORITY','P1','Target-time authority resolution','Resolve and freeze the authority that actually governed the target RUN; adapter metadata is a locator, not permanent authority.','CRITICAL','["authority_snapshot","authority sources"]'::jsonb),
 ('SYS-P10-FORENSIC-REPLAY','P10','Read-only forensic replay when needed','If normal evidence cannot locate a material failure, replay may reconstruct expected process using only target-time authority/data and never write target.','MAJOR','["system_audit_forensic_replays"]'::jsonb),
 ('SYS-P11-TRACE-COMPLETE','P11','Total execution trace','Reconstruct request through authority, run, inputs, evidence, phases, gates, states, freeze, closure and delivery; separate root from downstream.','CRITICAL','["system_audit_execution_trace"]'::jsonb),
 ('SYS-P12-FORENSIC-CHAT-REPORT','P12','Detailed forensic chat report','Produce complete human-readable forensic report for chat with target, requirements, chronology, trace, correct parts, root failure, propagation, findings, P0-P12, corrections and retest.','CRITICAL','["system_audit_chat_reports"]'::jsonb),
 ('SYS-P12-COMPLIANCE-ONLY-CORRECTIONS','P12','Compliance-only corrections','Every correction restores an explicit target-authority requirement; auditor must not redesign target or invent methodology.','MAJOR','["system_audit_findings","system_audit_chat_reports"]'::jsonb)
) v(check_id,layer_id,title,rule_text,severity,targets)
on conflict(system_id,check_id) do update set layer_id=excluded.layer_id,title=excluded.title,rule_text=excluded.rule_text,default_severity=excluded.default_severity,required=true,target_objects=excluded.target_objects;

create or replace view public.system_audit_live_authority_resolution as
select r.system_id,
 case when r.system_id='@NRFiPrensa' then coalesce((select to_jsonb(p) from public.nrfiprensa_authority p limit 1),r.authority)
      else coalesce((select to_jsonb(a) from public.agent_registry a where a.agent_id=r.system_id),r.authority) end as live_authority,
 case when r.system_id='@NRFiPrensa' and exists(select 1 from public.nrfiprensa_authority) then 'nrfiprensa_authority'
      when exists(select 1 from public.agent_registry a where a.agent_id=r.system_id) then 'agent_registry'
      else 'system_audit_registry_fallback' end as discovery_source,
 'RESOLVE_TARGET_TIME_CANONICAL_AUTHORITY'::text as audit_rule
from public.system_audit_registry r;

update public.system_auditor_authority
set protocol_id='SYSTEM_AUDITOR_V1_1',agent_version='AUDITOR-SYSTEM-1.1',kernel_version='SYSTEM-AUDITOR-KERNEL-1.1-TARGET-LOCK-FORENSIC',status='ACTIVE_PROCESS_COMPLIANCE_AUDITOR',read_only_target=true,migrations_required_through=53,
 constitution_document_id='103YAFM8k9o36F41UgiHl1W8HAd-38Id-0-dYvRpG9fY',mode_agent_document_id='1LkvsesZmOVvQFSRF2xv5Gh6ykrEeuD9mAsM1BFjObqE',
 metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('authority_version','V1.1','target_lock_required',true,'wrong_target_is_critical',true,'forensic_trace_required',true,'forensic_replay_read_only',true,'forensic_chat_report_required',true,'compliance_only_corrections',true,'audit_repair_reaudit_separated',true,'manifest_path','agents/system_auditor_v11.json'),updated_at=now()
where agent_id='@AuditorSistema';

-- The close guard is also replaced by the applied Supabase migration to require:
-- all adapter checks + confirmed target identity + total trace + complete forensic
-- chat report + no open replay + verdict/check consistency + Drive report/hash.
-- Keep the runtime DB as source of truth for the exact pg_get_functiondef copy.
