create table if not exists public.sports_process_auditor_registry (
  auditor_id text primary key,
  auditor_type text not null check (auditor_type in ('DETERMINISTIC_STRUCTURAL','INDEPENDENT_SEMANTIC_PROCESS')),
  status text not null check (status in ('ACTIVE','DISABLED')),
  may_vote_sports boolean not null default false,
  owner text not null,
  version text not null,
  code_hash text,
  metadata jsonb not null default '{}'::jsonb,
  registered_at timestamptz not null default now()
);
alter table public.sports_process_auditor_registry enable row level security;

insert into public.sports_process_auditor_registry(auditor_id,auditor_type,status,may_vote_sports,owner,version,code_hash,metadata)
values(
  'KERNEL_PROCESS_AUDITOR_0.2','DETERMINISTIC_STRUCTURAL','ACTIVE',false,'NRFIMETRICA_KERNEL','0.2',
  public.nrfim_sha256_text('KERNEL_PROCESS_AUDITOR_0.2|DERIVED_DB_CHECKS'),
  jsonb_build_object('authority','PROCESS_ONLY','sports_vote','FORBIDDEN','derived_checks',array['STRUCTURAL','TEMPORAL','EVIDENCE','FALSIFICATION','INDEPENDENCE','DRIVE_HASH'])
)
on conflict(auditor_id) do update set status='ACTIVE',may_vote_sports=false,version=excluded.version,code_hash=excluded.code_hash,metadata=excluded.metadata;

create or replace function public.enforce_source_family_identity()
returns trigger language plpgsql as $$
declare existing_id text;
begin
  new.family_key:=lower(trim(new.family_key));
  new.original_publisher:=nullif(trim(coalesce(new.original_publisher,'')),'');
  new.canonical_origin:=nullif(trim(coalesce(new.canonical_origin,'')),'');
  if new.original_publisher is not null or new.canonical_origin is not null then
    select source_family_id into existing_id
    from public.research_source_families
    where run_id=new.run_id and game_id=new.game_id
      and source_family_id<>new.source_family_id
      and lower(coalesce(original_publisher,''))=lower(coalesce(new.original_publisher,''))
      and lower(coalesce(canonical_origin,''))=lower(coalesce(new.canonical_origin,''))
    limit 1;
    if existing_id is not null then
      raise exception 'SOURCE_FAMILY_SAME_DECLARED_ORIGIN_MUST_COLLAPSE:%/%',existing_id,new.source_family_id using errcode='23514';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists trg_01_source_family_identity on public.research_source_families;
create trigger trg_01_source_family_identity before insert or update on public.research_source_families
for each row execute function public.enforce_source_family_identity();

create or replace function public.enforce_sports_process_audit()
returns trigger language plpgsql as $$
declare
  p public.sports_reasoning_packets%rowtype;
  g record;
  req_families integer;
  ev_total integer:=0; ev_valid integer:=0; bad_temporal integer:=0;
  factual_total integer:=0; factual_bad integer:=0;
  fa jsonb; nrfi_test boolean:=false; yrfi_test boolean:=false; fa_bad integer:=0;
begin
  select * into p from public.sports_reasoning_packets where packet_id=new.packet_id;
  if not found then raise exception 'PROCESS_AUDIT_PACKET_NOT_FOUND' using errcode='23514'; end if;
  select scheduled_start into g from public.games where run_id=p.run_id and game_id=p.game_id;
  if not found then raise exception 'PROCESS_AUDIT_GAME_NOT_FOUND' using errcode='23514'; end if;

  new.run_id:=p.run_id;
  new.game_id:=p.game_id;
  new.auditor_id:='KERNEL_PROCESS_AUDITOR_0.2';
  new.created_at:=clock_timestamp();
  if not exists(select 1 from public.sports_process_auditor_registry r where r.auditor_id=new.auditor_id and r.status='ACTIVE' and r.auditor_type='DETERMINISTIC_STRUCTURAL' and r.may_vote_sports=false) then
    raise exception 'PROCESS_AUDITOR_NOT_ACTIVE_OR_SPORTS_VOTE_ENABLED' using errcode='23514';
  end if;

  req_families:=case p.complexity_tier when 'CLEAR' then 3 when 'NORMAL' then 5 else 7 end;

  new.structural_pass := (
    p.status='ANALYSIS_COMPLETE'
    and p.freeze_timestamp is not null
    and coalesce(p.packet_hash,'')<>''
    and p.top_1st_analysis<>'{}'::jsonb
    and p.bottom_1st_analysis<>'{}'::jsonb
    and p.central_nrfi_case<>'{}'::jsonb
    and p.best_yrfi_rival<>'{}'::jsonb
    and p.strongest_counterevidence<>'{}'::jsonb
    and p.what_would_change<>'{}'::jsonb
    and p.sports_verdict is not null
    and p.dimensions_covered @> array['TOP_1ST','BOTTOM_1ST','STARTER_CURRENT_FORM','TOP_ORDER_MATCHUP','FIRST_INNING_SPECIFIC','COUNTEREVIDENCE']
    and p.drive_verified_at is not null
    and p.drive_content_hash is not distinct from p.packet_hash
  );

  select count(*) into ev_total from unnest(coalesce(p.evidence_ids,'{}')) x;
  select count(*) into ev_valid
  from public.evidence e
  where e.evidence_id=any(coalesce(p.evidence_ids,'{}'))
    and e.run_id=p.run_id and e.game_id=p.game_id
    and upper(coalesce(e.evidence_scope,''))='SPORTS_REASONING'
    and coalesce(e.tool_event_id,'')<>''
    and coalesce(e.source_family_id,'')<>''
    and coalesce(e.snapshot_hash,'')<>''
    and coalesce(e.snapshot_drive_file_id,'')<>''
    and e.snapshot_drive_hash=e.snapshot_hash;
  select count(*) into factual_total from public.sports_reasoning_claims c where c.packet_id=p.packet_id and c.claim_type='FACTUAL';
  select count(*) into factual_bad from public.sports_reasoning_claims c where c.packet_id=p.packet_id and c.claim_type='FACTUAL' and coalesce(array_length(c.evidence_ids,1),0)=0;
  new.evidence_pass := (ev_total>0 and ev_valid=ev_total and factual_total>0 and factual_bad=0);

  select count(*) into bad_temporal
  from public.evidence e
  where e.evidence_id=any(coalesce(p.evidence_ids,'{}'))
    and (
      e.retrieved_at is null
      or e.data_available_at is null
      or e.data_available_at>e.retrieved_at
      or (p.freeze_timestamp is not null and e.retrieved_at>p.freeze_timestamp)
      or (g.scheduled_start is not null and e.retrieved_at>=g.scheduled_start)
    );
  new.temporal_pass := (p.as_of_kernel is not null and p.as_of_kernel<g.scheduled_start and bad_temporal=0);

  if jsonb_typeof(p.falsification_attempts)='array' then
    for fa in select value from jsonb_array_elements(p.falsification_attempts) loop
      if upper(coalesce(fa->>'against',''))='NRFI' then nrfi_test:=true; end if;
      if upper(coalesce(fa->>'against',''))='YRFI' then yrfi_test:=true; end if;
      if jsonb_typeof(coalesce(fa->'evidence_ids','[]'::jsonb))<>'array' or jsonb_array_length(coalesce(fa->'evidence_ids','[]'::jsonb))=0 then fa_bad:=fa_bad+1; end if;
    end loop;
  end if;
  new.falsification_pass := (nrfi_test and yrfi_test and fa_bad=0 and jsonb_array_length(coalesce(p.falsification_attempts,'[]'::jsonb))>=2);
  new.independence_pass := (p.source_family_count>=req_families);

  if new.structural_pass and new.temporal_pass and new.evidence_pass and new.falsification_pass and new.independence_pass then
    if upper(coalesce(new.clone_risk,'NOT_EVALUATED'))='HIGH' then new.status:='REVIEW'; else new.status:='PASS'; end if;
  else
    new.status:='FAIL';
  end if;

  new.findings:=coalesce(new.findings,'{}'::jsonb) || jsonb_build_object(
    'derived_by','KERNEL_PROCESS_AUDITOR_0.2',
    'requested_status_ignored',true,
    'required_source_families',req_families,
    'actual_source_families',p.source_family_count,
    'evidence_total',ev_total,
    'evidence_chain_valid',ev_valid,
    'factual_claim_count',factual_total,
    'bad_temporal_evidence_count',bad_temporal,
    'sports_vote_authority','FORBIDDEN'
  );
  new.audit_hash:=public.nrfim_sha256_text(concat_ws('|',new.audit_id,new.packet_id,new.auditor_id,new.status,new.structural_pass::text,new.temporal_pass::text,new.evidence_pass::text,new.falsification_pass::text,new.independence_pass::text,new.findings::text));
  update public.sports_reasoning_packets
    set process_audit_status=new.status,process_audit_id=new.audit_id,updated_at=clock_timestamp()
    where packet_id=new.packet_id;
  return new;
end $$;

drop trigger if exists trg_01_sports_process_audit on public.sports_process_audits;
create trigger trg_01_sports_process_audit before insert on public.sports_process_audits
for each row execute function public.enforce_sports_process_audit();

update public.agent_registry
set metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object(
  'process_auditor','KERNEL_PROCESS_AUDITOR_0.2',
  'process_audit_inputs_are_derived_by_db',true,
  'same_declared_source_origin_must_collapse',true
),updated_at=now()
where agent_id='@NRFImetrica';