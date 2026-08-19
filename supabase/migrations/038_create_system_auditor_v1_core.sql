-- @AuditorSistema V1.0 — independent process audit core
create table if not exists public.system_audit_registry (
  system_id text primary key,
  display_name text not null,
  adapter_version text not null,
  target_project_id text,
  target_namespace text,
  authority jsonb not null default '{}'::jsonb,
  drive_root_id text,
  notion_page_id text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.system_audit_adapter_checks (
  system_id text not null references public.system_audit_registry(system_id) on delete cascade,
  check_id text not null,
  layer_id text not null check (layer_id ~ '^P([0-9]|1[0-2])$'),
  title text not null,
  rule_text text not null,
  default_severity text not null check (default_severity in ('CRITICAL','MAJOR','MODERATE','MINOR')),
  required boolean not null default true,
  target_objects jsonb not null default '[]'::jsonb,
  primary key (system_id, check_id)
);

create table if not exists public.system_audit_runs (
  audit_run_id text primary key,
  target_system_id text not null references public.system_audit_registry(system_id),
  target_run_id text,
  audit_scope text not null default 'FULL_PROCESS',
  status text not null default 'OPEN' check (status in ('OPEN','CLOSED')),
  verdict text check (verdict in ('PROCESS_VALIDATED','PROCESS_VALIDATED_WITH_OBSERVATIONS','PROCESS_INCOMPLETE','PROCESS_INVALID','STATE_MISREPRESENTATION','AUDIT_BLOCKED')),
  max_severity text check (max_severity in ('CRITICAL','MAJOR','MODERATE','MINOR','NONE')),
  authority_snapshot jsonb not null default '{}'::jsonb,
  target_snapshot jsonb not null default '{}'::jsonb,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  drive_folder_id text,
  report_drive_file_id text,
  report_hash text,
  summary jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.system_audit_check_results (
  audit_run_id text not null references public.system_audit_runs(audit_run_id) on delete cascade,
  check_id text not null,
  layer_id text not null check (layer_id ~ '^P([0-9]|1[0-2])$'),
  status text not null check (status in ('PASS','FAIL','NOT_PROVEN','NOT_APPLICABLE','INCONSISTENT')),
  severity text not null check (severity in ('CRITICAL','MAJOR','MODERATE','MINOR')),
  expected_state text,
  observed_state text,
  evidence_refs jsonb not null default '[]'::jsonb,
  detail text not null,
  checked_at timestamptz not null default now(),
  primary key (audit_run_id, check_id)
);

create table if not exists public.system_audit_findings (
  finding_id text primary key,
  audit_run_id text not null references public.system_audit_runs(audit_run_id) on delete cascade,
  check_id text,
  layer_id text not null check (layer_id ~ '^P([0-9]|1[0-2])$'),
  severity text not null check (severity in ('CRITICAL','MAJOR','MODERATE','MINOR')),
  classification text not null,
  component_owner text,
  evidence_refs jsonb not null default '[]'::jsonb,
  finding text not null,
  impact text not null,
  recommendation text,
  created_at timestamptz not null default now()
);

create table if not exists public.system_audit_artifacts (
  artifact_id text primary key,
  audit_run_id text not null references public.system_audit_runs(audit_run_id) on delete cascade,
  artifact_type text not null,
  drive_file_id text,
  content_hash text,
  verified_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.system_audit_enforce_close() returns trigger
language plpgsql as $$
declare required_count int; present_count int; bad_critical int; critical_fail int; system_key text;
begin
  new.updated_at := now();
  if new.status='CLOSED' and old.status is distinct from 'CLOSED' then
    if new.verdict is null then raise exception 'AUDITOR_CLOSE_REQUIRES_VERDICT' using errcode='23514'; end if;
    select target_system_id into system_key from public.system_audit_runs where audit_run_id=new.audit_run_id;
    select count(*) into required_count from public.system_audit_adapter_checks where system_id=system_key and required=true;
    select count(*) into present_count from public.system_audit_check_results r join public.system_audit_adapter_checks c on c.system_id=system_key and c.check_id=r.check_id where r.audit_run_id=new.audit_run_id and c.required=true;
    if present_count <> required_count then raise exception 'AUDITOR_CLOSE_REQUIRES_ALL_REQUIRED_CHECKS:%/%',present_count,required_count using errcode='23514'; end if;
    select count(*) into bad_critical from public.system_audit_check_results where audit_run_id=new.audit_run_id and severity='CRITICAL' and status in ('FAIL','NOT_PROVEN','INCONSISTENT');
    if new.verdict in ('PROCESS_VALIDATED','PROCESS_VALIDATED_WITH_OBSERVATIONS') and bad_critical>0 then raise exception 'AUDITOR_VALIDATED_VERDICT_FORBIDDEN_WITH_CRITICAL_OPEN:%',bad_critical using errcode='23514'; end if;
    select count(*) into critical_fail from public.system_audit_check_results where audit_run_id=new.audit_run_id and severity='CRITICAL' and status in ('FAIL','INCONSISTENT');
    if new.verdict='PROCESS_INVALID' and critical_fail=0 then raise exception 'AUDITOR_PROCESS_INVALID_REQUIRES_CRITICAL_FAIL_OR_INCONSISTENCY' using errcode='23514'; end if;
    if new.verdict='AUDIT_BLOCKED' and not exists (select 1 from public.system_audit_check_results where audit_run_id=new.audit_run_id and status='NOT_PROVEN') then raise exception 'AUDITOR_AUDIT_BLOCKED_REQUIRES_NOT_PROVEN_CHECK' using errcode='23514'; end if;
    if new.report_drive_file_id is null then raise exception 'AUDITOR_CLOSE_REQUIRES_DRIVE_REPORT' using errcode='23514'; end if;
    new.completed_at := coalesce(new.completed_at,now());
  end if;
  return new;
end $$;

drop trigger if exists trg_system_audit_close_guard on public.system_audit_runs;
create trigger trg_system_audit_close_guard before update on public.system_audit_runs for each row execute function public.system_audit_enforce_close();
create index if not exists idx_system_audit_runs_target on public.system_audit_runs(target_system_id,target_run_id);
create index if not exists idx_system_audit_checks_run on public.system_audit_check_results(audit_run_id,layer_id,status);
create index if not exists idx_system_audit_findings_run on public.system_audit_findings(audit_run_id,severity);
