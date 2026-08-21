create table if not exists public.fullunder_artifact_structure_receipts (
  receipt_id uuid primary key default gen_random_uuid(),
  artifact_id uuid not null unique references public.fullunder_artifacts(artifact_id) on delete cascade,
  run_id uuid not null references public.fullunder_runs(run_id) on delete cascade,
  format_contract_id text not null,
  document_role text not null,
  required_section_count integer not null,
  section_inventory jsonb not null,
  heading_count integer not null,
  table_count integer not null,
  bold_anchor_count integer not null,
  visual_hierarchy_pass boolean not null default false,
  structure_readback_pass boolean not null default false,
  structure_hash text not null,
  verified_at timestamptz not null default now()
);

alter table public.fullunder_artifact_structure_receipts enable row level security;

create or replace function public.fullunder_structure_receipt_immutable()
returns trigger language plpgsql as $$
begin
  if current_setting('fullunder.audit_cleanup',true)='on' then return coalesce(new,old); end if;
  raise exception 'FULLUNDER_STRUCTURE_RECEIPT_IMMUTABLE';
end $$;

drop trigger if exists trg_fullunder_structure_receipt_immutable on public.fullunder_artifact_structure_receipts;
create trigger trg_fullunder_structure_receipt_immutable
before update or delete on public.fullunder_artifact_structure_receipts
for each row execute function public.fullunder_structure_receipt_immutable();

create or replace function public.fullunder_guard_structure_receipt()
returns trigger language plpgsql as $$
declare a public.fullunder_artifacts%rowtype;
        expected_sections jsonb := '["01","02","03","04","05","06","07","08","09","10","11","12","13","14","15","16","17","18","19","20"]'::jsonb;
begin
  select * into a from public.fullunder_artifacts where artifact_id=new.artifact_id;
  if not found then raise exception 'FULLUNDER_STRUCTURE_ARTIFACT_NOT_FOUND'; end if;
  if a.run_id<>new.run_id then raise exception 'FULLUNDER_STRUCTURE_RUN_MISMATCH'; end if;
  if a.artifact_type<>'ANALYST_HANDOFF_BRIEF' then raise exception 'FULLUNDER_STRUCTURE_ONLY_HANDOFF_BRIEF'; end if;
  if new.format_contract_id<>'FULLUNDER-HANDOFF-FORMAT-1.1' then raise exception 'FULLUNDER_HANDOFF_FORMAT_CONTRACT_INVALID'; end if;
  if new.document_role<>'ANALYST_HANDOFF_BRIEF' then raise exception 'FULLUNDER_HANDOFF_DOCUMENT_ROLE_INVALID'; end if;
  if new.required_section_count<>20 then raise exception 'FULLUNDER_HANDOFF_SECTION_COUNT_INVALID'; end if;
  if jsonb_typeof(new.section_inventory)<>'array' or jsonb_array_length(new.section_inventory)<>20 or not (new.section_inventory @> expected_sections) then
    raise exception 'FULLUNDER_HANDOFF_SECTION_INVENTORY_INVALID';
  end if;
  if new.heading_count<20 then raise exception 'FULLUNDER_HANDOFF_HEADINGS_INCOMPLETE'; end if;
  if new.table_count<15 then raise exception 'FULLUNDER_HANDOFF_TABLE_STRUCTURE_INCOMPLETE'; end if;
  if new.bold_anchor_count<20 then raise exception 'FULLUNDER_HANDOFF_BOLD_HIERARCHY_INCOMPLETE'; end if;
  if not new.visual_hierarchy_pass or not new.structure_readback_pass then raise exception 'FULLUNDER_HANDOFF_VISUAL_READBACK_REQUIRED'; end if;
  return new;
end $$;

drop trigger if exists trg_fullunder_guard_structure_receipt on public.fullunder_artifact_structure_receipts;
create trigger trg_fullunder_guard_structure_receipt
before insert on public.fullunder_artifact_structure_receipts
for each row execute function public.fullunder_guard_structure_receipt();

create or replace function public.fullunder_guard_handoff()
returns trigger language plpgsql as $$
declare
  r public.fullunder_runs%rowtype;
  phase_count int;
  dossier public.fullunder_artifacts%rowtype;
  brief public.fullunder_artifacts%rowtype;
  master public.fullunder_artifacts%rowtype;
  sr public.fullunder_artifact_structure_receipts%rowtype;
  expected_handoff_hash text;
begin
  select * into r from public.fullunder_runs where run_id=new.run_id for update;
  if not found then raise exception 'FULLUNDER_RUN_NOT_FOUND'; end if;
  if r.phase_cursor<>8 or r.status<>'F8_COMPLETE' then raise exception 'FULLUNDER_F1_F8_NOT_COMPLETE'; end if;
  if new.game_pk<>r.game_pk or new.target_binding_hash<>r.target_binding_hash or new.mother_sha256<>r.mother_sha256 then raise exception 'FULLUNDER_HANDOFF_BINDING_MISMATCH'; end if;
  select count(*) into phase_count from public.fullunder_phase_receipts where run_id=new.run_id;
  if phase_count<>8 then raise exception 'FULLUNDER_RECEIPT_COUNT_INVALID'; end if;

  select * into dossier from public.fullunder_artifacts where artifact_id=new.dossier_artifact_id and run_id=new.run_id and artifact_type='FULL_UNDER_PREGAME_EVIDENCE_DOSSIER';
  select * into brief from public.fullunder_artifacts where artifact_id=new.brief_artifact_id and run_id=new.run_id and artifact_type='ANALYST_HANDOFF_BRIEF';
  select * into master from public.fullunder_artifacts where artifact_id=new.master_report_artifact_id and run_id=new.run_id and artifact_type='MASTER_RESEARCH_REPORT';
  if dossier.artifact_id is null or brief.artifact_id is null or master.artifact_id is null then raise exception 'FULLUNDER_HANDOFF_ARTIFACT_TYPE_BINDING_INVALID'; end if;
  if not dossier.readback_pass or dossier.readback_hash is null or dossier.readback_hash<>dossier.content_hash then raise exception 'FULLUNDER_DOSSIER_READBACK_INVALID'; end if;
  if not brief.readback_pass or brief.readback_hash is null or brief.readback_hash<>brief.content_hash then raise exception 'FULLUNDER_BRIEF_READBACK_INVALID'; end if;
  if not master.readback_pass or master.readback_hash is null or master.readback_hash<>master.content_hash then raise exception 'FULLUNDER_MASTER_REPORT_READBACK_INVALID'; end if;

  select * into sr from public.fullunder_artifact_structure_receipts where artifact_id=brief.artifact_id and run_id=new.run_id;
  if not found then raise exception 'FULLUNDER_HANDOFF_STRUCTURE_RECEIPT_REQUIRED'; end if;
  if sr.format_contract_id<>'FULLUNDER-HANDOFF-FORMAT-1.1' or sr.required_section_count<>20 or sr.heading_count<20 or sr.table_count<15 or sr.bold_anchor_count<20 or not sr.visual_hierarchy_pass or not sr.structure_readback_pass then
    raise exception 'FULLUNDER_HANDOFF_STRUCTURE_NOT_CERTIFIED';
  end if;

  if new.source_snapshot_hash<>dossier.content_hash then raise exception 'FULLUNDER_SOURCE_SNAPSHOT_HASH_MISMATCH'; end if;
  if new.source_agent<>'@Investigarfullunder' or new.destination_role<>'IA_ANALISTA_FULL_UNDER' then raise exception 'FULLUNDER_HANDOFF_ROLE_INVALID'; end if;

  expected_handoff_hash := encode(digest(
    new.run_id::text||'|'||new.game_pk::text||'|'||dossier.content_hash||'|'||brief.content_hash||'|'||master.content_hash||'|'||sr.structure_hash||'|'||new.target_binding_hash||'|'||new.mother_sha256,
    'sha256'),'hex');
  if new.handoff_hash<>expected_handoff_hash then raise exception 'FULLUNDER_HANDOFF_HASH_INVALID'; end if;
  return new;
end $$;

update public.fullunder_agent_registry
set agent_version='INVESTIGARFULLUNDER-AGENT-1.1',
    kernel_version='FULLUNDER-RESEARCH-KERNEL-1.1',
    status='KERNEL_CONNECTED',
    metadata = coalesce(metadata,'{}'::jsonb) || jsonb_build_object(
      'handoff_format_contract','FULLUNDER-HANDOFF-FORMAT-1.1',
      'handoff_required_sections',20,
      'handoff_min_tables',15,
      'handoff_min_headings',20,
      'handoff_min_bold_anchors',20,
      'handoff_visual_readback_required',true
    )
where agent_id='@Investigarfullunder';
