alter table public.runs
  add column if not exists invocation_id text,
  add column if not exists clean_room_mode boolean not null default false,
  add column if not exists historical_reports_as_analysis_input boolean not null default false;

create unique index if not exists runs_invocation_id_unique
  on public.runs(invocation_id) where invocation_id is not null;

create table if not exists public.run_report_documents (
  report_document_id text primary key,
  run_id text not null unique references public.runs(run_id) on delete cascade,
  invocation_id text not null,
  drive_file_id text not null unique,
  document_title text not null,
  status text not null default 'DRAFT' check (status in ('DRAFT','FINAL_VERIFIED')),
  content_hash text,
  created_at timestamptz not null default now(),
  finalized_at timestamptz,
  check (length(trim(drive_file_id)) > 5),
  check (length(trim(document_title)) > 3)
);
alter table public.run_report_documents enable row level security;

create or replace function public.enforce_mother_clean_room_run()
returns trigger language plpgsql as $$
begin
  if new.system_version <> 'NRFIM MOTHER V3' then return new; end if;
  if tg_op='INSERT' then
    new.invocation_id := coalesce(nullif(new.invocation_id,''),'INV-'||gen_random_uuid()::text);
    new.clean_room_mode := true;
    new.historical_reports_as_analysis_input := false;
    new.metadata := coalesce(new.metadata,'{}'::jsonb) || jsonb_build_object(
      'execution_isolation','CLEAN_ROOM_CURRENT_RUN_ONLY',
      'historical_reports_policy','FORBIDDEN_AS_SPORTS_ANALYSIS_INPUT',
      'new_report_document_required',true,
      'prior_run_reasoning_reuse_allowed',false,
      'invocation_id',new.invocation_id
    );
  else
    if old.clean_room_mode then
      if new.invocation_id is distinct from old.invocation_id then raise exception 'CLEAN_ROOM_INVOCATION_ID_IMMUTABLE' using errcode='23514'; end if;
      if not new.clean_room_mode then raise exception 'CLEAN_ROOM_MODE_CANNOT_BE_DISABLED' using errcode='23514'; end if;
      if new.historical_reports_as_analysis_input then raise exception 'HISTORICAL_REPORTS_FORBIDDEN_AS_ANALYSIS_INPUT' using errcode='23514'; end if;
    end if;
  end if;
  return new;
end $$;
drop trigger if exists trg_00_mother_clean_room_run on public.runs;
create trigger trg_00_mother_clean_room_run before insert or update on public.runs for each row execute function public.enforce_mother_clean_room_run();

create or replace function public.enforce_run_report_document()
returns trigger language plpgsql as $$
declare r public.runs%rowtype; other_run text;
begin
  select * into r from public.runs where run_id=new.run_id;
  if not found then raise exception 'REPORT_DOCUMENT_RUN_NOT_FOUND' using errcode='23514'; end if;
  if not r.clean_room_mode then raise exception 'REPORT_DOCUMENT_REQUIRES_CLEAN_ROOM_RUN' using errcode='23514'; end if;
  new.invocation_id := r.invocation_id;
  new.created_at := clock_timestamp(); new.status := 'DRAFT'; new.content_hash := null; new.finalized_at := null;
  select a.run_id into other_run from public.research_drive_artifacts a where a.drive_file_id=new.drive_file_id and a.run_id<>new.run_id limit 1;
  if other_run is not null then raise exception 'REPORT_DOCUMENT_ALREADY_USED_BY_OTHER_RUN:%',other_run using errcode='23514'; end if;
  return new;
end $$;
drop trigger if exists trg_00_run_report_document on public.run_report_documents;
create trigger trg_00_run_report_document before insert on public.run_report_documents for each row execute function public.enforce_run_report_document();

create or replace function public.enforce_clean_room_packet_start()
returns trigger language plpgsql as $$
declare r public.runs%rowtype;
begin
  select * into r from public.runs where run_id=new.run_id;
  if found and r.clean_room_mode then
    if not exists(select 1 from public.run_report_documents d where d.run_id=new.run_id and d.invocation_id=r.invocation_id) then
      raise exception 'CLEAN_ROOM_RUN_REQUIRES_NEW_REPORT_DOCUMENT_BEFORE_ANALYSIS' using errcode='23514';
    end if;
    if tg_op='INSERT' then new.analysis_started_at:=clock_timestamp(); end if;
  end if;
  return new;
end $$;
drop trigger if exists trg_00_clean_room_packet_start on public.sports_reasoning_packets;
create trigger trg_00_clean_room_packet_start before insert or update on public.sports_reasoning_packets for each row execute function public.enforce_clean_room_packet_start();

create or replace function public.reject_prior_run_analysis_artifact_as_sports_evidence()
returns trigger language plpgsql as $$
declare foreign_run text;
begin
  if upper(coalesce(new.evidence_scope,'')) <> 'SPORTS_REASONING' then return new; end if;
  select a.run_id into foreign_run from public.research_drive_artifacts a
  where a.run_id<>new.run_id and a.artifact_type in ('PACKET','RUN_MANIFEST','FINAL_REPORT')
    and (coalesce(new.source_ref,'')=a.drive_file_id or coalesce(new.snapshot_drive_file_id,'')=a.drive_file_id or coalesce(new.source_url,'') like '%'||a.drive_file_id||'%') limit 1;
  if foreign_run is not null then raise exception 'PRIOR_RUN_ARTIFACT_FORBIDDEN_AS_SPORTS_EVIDENCE:%',foreign_run using errcode='23514'; end if;
  select d.run_id into foreign_run from public.run_report_documents d
  where d.run_id<>new.run_id and (coalesce(new.source_ref,'')=d.drive_file_id or coalesce(new.snapshot_drive_file_id,'')=d.drive_file_id or coalesce(new.source_url,'') like '%'||d.drive_file_id||'%') limit 1;
  if foreign_run is not null then raise exception 'PRIOR_RUN_REPORT_FORBIDDEN_AS_SPORTS_EVIDENCE:%',foreign_run using errcode='23514'; end if;
  select r.run_id into foreign_run from public.runs r
  where r.run_id<>new.run_id and (coalesce(new.source_ref,'')=r.run_id or coalesce(new.source_url,'') like '%'||r.run_id||'%') limit 1;
  if foreign_run is not null then raise exception 'PRIOR_RUN_REFERENCE_FORBIDDEN_AS_SPORTS_EVIDENCE:%',foreign_run using errcode='23514'; end if;
  return new;
end $$;
drop trigger if exists trg_00_no_prior_run_sports_evidence on public.evidence;
create trigger trg_00_no_prior_run_sports_evidence before insert or update on public.evidence for each row execute function public.reject_prior_run_analysis_artifact_as_sports_evidence();

create or replace function public.enforce_clean_room_final_report_stage()
returns trigger language plpgsql as $$
declare r public.runs%rowtype;
begin
  if new.protocol_id<>'NRFIMETRICA_MOTHER_V3_AUTONOMOUS' or new.stage_id<>'FINAL_REPORT' then return new; end if;
  select * into r from public.runs where run_id=new.run_id;
  if found and r.clean_room_mode and not exists(select 1 from public.run_report_documents d where d.run_id=new.run_id and d.invocation_id=r.invocation_id) then
    raise exception 'FINAL_REPORT_REQUIRES_UNIQUE_RUN_REPORT_DOCUMENT' using errcode='23514';
  end if;
  return new;
end $$;
drop trigger if exists trg_00_clean_room_final_report_stage on public.protocol_run_state;
create trigger trg_00_clean_room_final_report_stage before insert or update on public.protocol_run_state for each row execute function public.enforce_clean_room_final_report_stage();

create or replace function public.enforce_clean_room_final_report_artifact()
returns trigger language plpgsql as $$
declare r public.runs%rowtype; d public.run_report_documents%rowtype;
begin
  if new.artifact_type<>'FINAL_REPORT' then return new; end if;
  select * into r from public.runs where run_id=new.run_id;
  if found and r.clean_room_mode then
    select * into d from public.run_report_documents where run_id=new.run_id;
    if not found then raise exception 'FINAL_REPORT_ARTIFACT_REQUIRES_REGISTERED_NEW_DOCUMENT' using errcode='23514'; end if;
    if new.drive_file_id<>d.drive_file_id then raise exception 'FINAL_REPORT_MUST_USE_THIS_RUN_UNIQUE_DOCUMENT:%',d.drive_file_id using errcode='23514'; end if;
  end if;
  return new;
end $$;
drop trigger if exists trg_00_clean_room_final_report_artifact on public.research_drive_artifacts;
create trigger trg_00_clean_room_final_report_artifact before insert on public.research_drive_artifacts for each row execute function public.enforce_clean_room_final_report_artifact();

create or replace function public.finalize_run_report_document_from_artifact()
returns trigger language plpgsql as $$
begin
  if new.artifact_type='FINAL_REPORT' then
    update public.run_report_documents set status='FINAL_VERIFIED',content_hash=new.content_hash,finalized_at=new.verified_at where run_id=new.run_id and drive_file_id=new.drive_file_id;
  end if;
  return new;
end $$;
drop trigger if exists trg_99_finalize_run_report_document on public.research_drive_artifacts;
create trigger trg_99_finalize_run_report_document after insert on public.research_drive_artifacts for each row execute function public.finalize_run_report_document_from_artifact();

create or replace function public.enforce_clean_room_run_close()
returns trigger language plpgsql as $$
begin
  if tg_op='UPDATE' and old.status is distinct from 'CLOSED' and new.status='CLOSED' and new.clean_room_mode then
    if not exists(select 1 from public.run_report_documents d where d.run_id=new.run_id and d.status='FINAL_VERIFIED' and d.content_hash is not null) then
      raise exception 'CLEAN_ROOM_RUN_CANNOT_CLOSE_WITHOUT_UNIQUE_VERIFIED_REPORT_DOCUMENT' using errcode='23514';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists trg_99_clean_room_run_close on public.runs;
create trigger trg_99_clean_room_run_close before update on public.runs for each row execute function public.enforce_clean_room_run_close();

update public.agent_registry set agent_version='MOTHER-V3-AGENT-1.2',kernel_version='NRFIM-KERNEL-0.7-CLEAN-ROOM',metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('clean_room_execution_required',true,'new_run_per_invocation_required',true,'new_report_document_per_run_required',true,'prior_reports_as_sports_input_forbidden',true,'prior_run_reasoning_reuse_forbidden',true,'database_migrations_required_through',25) where agent_id='@NRFImetrica';
update public.system_versions set kernel_version='NRFIM-KERNEL-0.7-CLEAN-ROOM' where system_version='NRFIM MOTHER V3';