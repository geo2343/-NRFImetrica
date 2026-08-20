create or replace function public.nrfim_assign_kernel_evidence_identity_and_family()
returns trigger language plpgsql as $$
declare ev public.research_tool_events%rowtype; prior record; origin_key text; host_key text; famid text; exact_match boolean:=false; origin_match boolean:=false; sim numeric:=0;
begin
  if upper(coalesce(new.evidence_scope,''))<>'SPORTS_REASONING' then return new; end if;
  if tg_op='UPDATE' then
    if old.custody_version='SEMANTIC-CUSTODY-1.0' and (
      new.evidence_id is distinct from old.evidence_id or new.run_id is distinct from old.run_id or new.game_id is distinct from old.game_id or new.tool_event_id is distinct from old.tool_event_id or new.source_url is distinct from old.source_url or new.payload is distinct from old.payload or new.snapshot_hash is distinct from old.snapshot_hash or new.factual_extract_text is distinct from old.factual_extract_text or new.source_family_id is distinct from old.source_family_id
    ) then raise exception 'KERNEL_EVIDENCE_CORE_IMMUTABLE' using errcode='23514'; end if;
    return new;
  end if;
  new.evidence_id:='EVID-SR-'||replace(gen_random_uuid()::text,'-','');
  new.custody_version:='SEMANTIC-CUSTODY-1.0';
  select * into ev from public.research_tool_events where event_id=new.tool_event_id;
  if not found or not ev.kernel_attested or ev.retrieval_mode not in ('KERNEL_SERVER_FETCH','KERNEL_PROVIDER_FETCH') then raise exception 'SPORTS_EVIDENCE_REQUIRES_KERNEL_ATTESTED_EXTRACTION' using errcode='23514'; end if;
  if ev.run_id<>new.run_id or ev.game_id is distinct from new.game_id then raise exception 'SPORTS_EVIDENCE_TOOL_EVENT_MISMATCH' using errcode='23514'; end if;
  if length(trim(coalesce(new.factual_extract_text,'')))<8 then raise exception 'SPORTS_EVIDENCE_FACTUAL_EXTRACT_REQUIRED' using errcode='23514'; end if;
  new.kernel_attested:=true;
  new.retrieved_at:=ev.occurred_at;
  new.published_or_updated_at:=ev.source_published_at;
  new.data_available_since:=coalesce(ev.data_available_since_kernel,ev.source_published_at,ev.occurred_at);
  new.data_available_at:=new.data_available_since;
  new.normalized_extract_text:=public.nrfim_normalize_extract(new.factual_extract_text);
  new.extraction_hash:=public.nrfim_sha256_text(new.normalized_extract_text);
  host_key:=lower(coalesce(substring(new.source_url from '^https?://([^/]+)'),''));
  origin_key:=lower(trim(coalesce(nullif(new.original_publisher,''),nullif(host_key,''),new.tool_name,'unknown')));

  select e.source_family_id,
         (e.snapshot_hash=new.snapshot_hash or e.extraction_hash=new.extraction_hash) as exact_match,
         (coalesce(new.original_publisher,'')<>'' and lower(coalesce(e.original_publisher,''))=lower(new.original_publisher)) as origin_match,
         extensions.similarity(e.normalized_extract_text,new.normalized_extract_text) as similarity_score
    into prior
  from public.evidence e
  where e.run_id=new.run_id and e.game_id=new.game_id and upper(coalesce(e.evidence_scope,''))='SPORTS_REASONING'
    and e.custody_version='SEMANTIC-CUSTODY-1.0'
    and (
      e.snapshot_hash=new.snapshot_hash or e.extraction_hash=new.extraction_hash
      or (coalesce(new.original_publisher,'')<>'' and lower(coalesce(e.original_publisher,''))=lower(new.original_publisher))
      or (e.normalized_extract_text is not null and extensions.similarity(e.normalized_extract_text,new.normalized_extract_text)>=0.80)
    )
  order by (e.snapshot_hash=new.snapshot_hash or e.extraction_hash=new.extraction_hash) desc,
           (coalesce(new.original_publisher,'')<>'' and lower(coalesce(e.original_publisher,''))=lower(new.original_publisher)) desc,
           extensions.similarity(e.normalized_extract_text,new.normalized_extract_text) desc
  limit 1;

  if prior.source_family_id is not null then
    new.source_family_id:=prior.source_family_id;
    exact_match:=coalesce(prior.exact_match,false); origin_match:=coalesce(prior.origin_match,false); sim:=coalesce(prior.similarity_score,0);
    new.family_assignment_method:=case when exact_match then 'EXACT_CONTENT_HASH' when origin_match then 'DECLARED_ORIGIN_COLLAPSE' when sim>=0.80 then 'SEMANTIC_OVERLAP_80' else 'KERNEL_ORIGIN' end;
  else
    famid:='FAM-'||substr(public.nrfim_sha256_text(concat_ws('|',new.run_id,new.game_id,origin_key)),1,24);
    insert into public.research_source_families(source_family_id,run_id,game_id,family_key,original_publisher,canonical_origin,family_basis)
    values(famid,new.run_id,new.game_id,origin_key,new.original_publisher,host_key,'KERNEL_ORIGIN')
    on conflict(run_id,game_id,family_key) do nothing;
    select source_family_id into new.source_family_id from public.research_source_families where run_id=new.run_id and game_id=new.game_id and family_key=origin_key limit 1;
    new.family_assignment_method:='KERNEL_ORIGIN';
  end if;
  return new;
end $$;

update public.agent_registry set metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('database_migrations_required_through',54,'semantic_family_assignment_label_fix',true) where agent_id='@NRFImetrica';
