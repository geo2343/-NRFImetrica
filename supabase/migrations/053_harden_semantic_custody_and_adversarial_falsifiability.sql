create schema if not exists extensions;
create extension if not exists pg_trgm with schema extensions;

create table if not exists public.research_kernel_queries (
  query_id text primary key,
  run_id text not null references public.runs(run_id) on delete cascade,
  game_id text not null,
  query_text text not null,
  query_scope text not null check (query_scope in ('DISCOVERY','SOURCE_EXTRACTION','STRUCTURED_PROVIDER','REVALIDATION')),
  status text not null default 'REQUESTED' check (status in ('REQUESTED','FULFILLED','CANCELLED')),
  query_hash text not null,
  requested_at timestamptz not null,
  fulfilled_at timestamptz,
  fulfilled_event_id text,
  created_at timestamptz not null default clock_timestamp()
);
alter table public.research_kernel_queries enable row level security;

alter table public.research_tool_events
  add column if not exists kernel_query_id text,
  add column if not exists retrieval_mode text not null default 'LEGACY',
  add column if not exists kernel_attested boolean not null default false,
  add column if not exists source_published_at timestamptz,
  add column if not exists data_available_since_kernel timestamptz,
  add column if not exists custody_version text not null default 'LEGACY';

do $$ begin
  if not exists (select 1 from pg_constraint where conname='research_tool_events_kernel_query_id_fkey') then
    alter table public.research_tool_events add constraint research_tool_events_kernel_query_id_fkey foreign key(kernel_query_id) references public.research_kernel_queries(query_id);
  end if;
  if not exists (select 1 from pg_constraint where conname='research_tool_events_kernel_query_id_key') then
    alter table public.research_tool_events add constraint research_tool_events_kernel_query_id_key unique(kernel_query_id);
  end if;
end $$;

alter table public.evidence
  add column if not exists factual_extract_text text,
  add column if not exists normalized_extract_text text,
  add column if not exists extraction_hash text,
  add column if not exists family_assignment_method text,
  add column if not exists kernel_attested boolean not null default false,
  add column if not exists custody_version text not null default 'LEGACY';

alter table public.sports_reasoning_packets
  add column if not exists custody_version text not null default 'LEGACY',
  add column if not exists lineup_status text not null default 'UNKNOWN',
  add column if not exists projected_analysis jsonb not null default '{}'::jsonb,
  add column if not exists confirmed_analysis jsonb not null default '{}'::jsonb,
  add column if not exists first_inning_factors jsonb not null default '[]'::jsonb,
  add column if not exists unresolved_contradictions jsonb not null default '[]'::jsonb,
  add column if not exists adversarial_balance jsonb not null default '{}'::jsonb,
  add column if not exists saturation_reached boolean not null default false,
  add column if not exists adaptive_required_families integer not null default 2;

do $$ begin
  if not exists (select 1 from pg_constraint where conname='sports_reasoning_packets_lineup_status_check') then
    alter table public.sports_reasoning_packets add constraint sports_reasoning_packets_lineup_status_check check (lineup_status in ('UNKNOWN','PROJECTED','CONFIRMED','MIXED'));
  end if;
end $$;

alter table public.sports_process_audits
  add column if not exists semantic_custody_pass boolean not null default false,
  add column if not exists adversarial_balance_pass boolean not null default false,
  add column if not exists adaptive_depth_pass boolean not null default false,
  add column if not exists first_inning_materiality_pass boolean not null default false;

alter table public.research_source_families drop constraint if exists research_source_families_family_basis_check;
alter table public.research_source_families add constraint research_source_families_family_basis_check check (family_basis in ('PRIMARY_ORIGIN','WIRE_ORIGIN','DATASET_ORIGIN','EXACT_CONTENT_HASH','SEMANTIC_OVERLAP','KERNEL_ORIGIN','MANUAL_REVIEW'));

create or replace function public.nrfim_normalize_extract(t text)
returns text language sql immutable as $$
  select trim(regexp_replace(lower(coalesce(t,'')), '\s+', ' ', 'g'))
$$;

create or replace function public.kernel_prepare_research_query()
returns trigger language plpgsql as $$
begin
  if tg_op='INSERT' then
    if not exists(select 1 from public.games g where g.run_id=new.run_id and g.game_id=new.game_id) then
      raise exception 'KERNEL_QUERY_GAME_NOT_REGISTERED:%/%',new.run_id,new.game_id using errcode='23514';
    end if;
    if length(trim(coalesce(new.query_text,'')))<3 then raise exception 'KERNEL_QUERY_TEXT_REQUIRED' using errcode='23514'; end if;
    new.query_id:='KRQ-'||replace(gen_random_uuid()::text,'-','');
    new.requested_at:=clock_timestamp(); new.created_at:=new.requested_at;
    new.status:='REQUESTED'; new.fulfilled_at:=null; new.fulfilled_event_id:=null;
    new.query_hash:=public.nrfim_sha256_text(concat_ws('|',new.run_id,new.game_id,new.query_scope,new.query_text,new.requested_at::text));
  else
    if new.run_id is distinct from old.run_id or new.game_id is distinct from old.game_id or new.query_text is distinct from old.query_text or new.query_scope is distinct from old.query_scope or new.query_hash is distinct from old.query_hash or new.requested_at is distinct from old.requested_at then
      raise exception 'KERNEL_QUERY_IMMUTABLE_CORE' using errcode='23514';
    end if;
    new.query_id:=old.query_id; new.created_at:=old.created_at;
    if new.status='FULFILLED' and (coalesce(new.fulfilled_event_id,'')='' or new.fulfilled_at is null) then raise exception 'FULFILLED_KERNEL_QUERY_REQUIRES_EVENT' using errcode='23514'; end if;
  end if;
  return new;
end $$;
drop trigger if exists trg_00_kernel_research_query on public.research_kernel_queries;
create trigger trg_00_kernel_research_query before insert or update on public.research_kernel_queries for each row execute function public.kernel_prepare_research_query();

create or replace function public.enforce_research_tool_event()
returns trigger language plpgsql as $$
declare prevh text; traceh text; q public.research_kernel_queries%rowtype;
begin
  if tg_op<>'INSERT' then return new; end if;
  new.event_id:='RTE-'||replace(gen_random_uuid()::text,'-','');
  new.occurred_at:=clock_timestamp(); new.created_at:=new.occurred_at;
  new.custody_version:='SEMANTIC-CUSTODY-1.0';
  if coalesce(new.kernel_query_id,'')='' then raise exception 'RESEARCH_TOOL_EVENT_REQUIRES_KERNEL_QUERY' using errcode='23514'; end if;
  select * into q from public.research_kernel_queries where query_id=new.kernel_query_id;
  if not found or q.run_id<>new.run_id or q.game_id<>new.game_id or q.status<>'REQUESTED' then raise exception 'RESEARCH_TOOL_EVENT_KERNEL_QUERY_MISMATCH_OR_ALREADY_USED' using errcode='23514'; end if;
  if new.source_published_at is not null and new.source_published_at>new.occurred_at then raise exception 'SOURCE_PUBLISHED_TIMESTAMP_IN_FUTURE' using errcode='23514'; end if;
  if new.data_available_since_kernel is not null and new.data_available_since_kernel>new.occurred_at then raise exception 'DATA_AVAILABLE_TIMESTAMP_IN_FUTURE' using errcode='23514'; end if;
  new.kernel_attested := (new.retrieval_mode in ('KERNEL_SERVER_FETCH','KERNEL_PROVIDER_FETCH') and coalesce(new.response_hash,'')<>'');
  new.event_hash:=public.nrfim_sha256_text(concat_ws('|',new.event_id,new.run_id,coalesce(new.game_id,''),new.kernel_query_id,new.tool_name,new.operation,new.retrieval_mode,coalesce(new.request_hash,''),coalesce(new.response_hash,''),new.kernel_attested::text,new.occurred_at::text));
  update public.runs set tool_call_count=coalesce(tool_call_count,0)+1 where run_id=new.run_id;
  select event_hash into prevh from public.trace_events where run_id=new.run_id order by occurred_at desc limit 1;
  traceh:=public.nrfim_sha256_text(concat_ws('|',new.event_id,new.run_id,coalesce(new.game_id,''),'RESEARCH_TOOL_CALL',new.event_hash,coalesce(prevh,''),new.occurred_at::text));
  insert into public.trace_events(event_id,run_id,game_id,task_id,event_type,status,occurred_at,input_hash,output_hash,tool_name,evidence_ids,prev_event_hash,event_hash,details)
  values('TRACE-'||new.event_id,new.run_id,new.game_id,'SPORTS_RESEARCH','RESEARCH_TOOL_CALL','COMPLETE',new.occurred_at,new.request_hash,new.response_hash,new.tool_name,'{}',prevh,traceh,jsonb_build_object('research_event_id',new.event_id,'kernel_query_id',new.kernel_query_id,'operation',new.operation,'retrieval_mode',new.retrieval_mode,'kernel_attested',new.kernel_attested,'source_ref',new.source_ref,'source_url',new.source_url));
  return new;
end $$;

create or replace function public.kernel_fulfill_research_query()
returns trigger language plpgsql as $$
begin
  update public.research_kernel_queries set status='FULFILLED',fulfilled_at=new.occurred_at,fulfilled_event_id=new.event_id where query_id=new.kernel_query_id and status='REQUESTED';
  return new;
end $$;
drop trigger if exists trg_02_kernel_fulfill_research_query on public.research_tool_events;
create trigger trg_02_kernel_fulfill_research_query after insert on public.research_tool_events for each row execute function public.kernel_fulfill_research_query();

create or replace function public.nrfim_assign_kernel_evidence_identity_and_family()
returns trigger language plpgsql as $$
declare ev public.research_tool_events%rowtype; prior record; origin_key text; host_key text; sim numeric:=0; famid text;
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
         case when e.snapshot_hash=new.snapshot_hash or e.extraction_hash=new.extraction_hash then 1.0 else extensions.similarity(e.normalized_extract_text,new.normalized_extract_text) end as s,
         e.original_publisher
    into prior
  from public.evidence e
  where e.run_id=new.run_id and e.game_id=new.game_id and upper(coalesce(e.evidence_scope,''))='SPORTS_REASONING'
    and e.custody_version='SEMANTIC-CUSTODY-1.0'
    and (
      e.snapshot_hash=new.snapshot_hash or e.extraction_hash=new.extraction_hash
      or lower(coalesce(e.original_publisher,''))=lower(coalesce(new.original_publisher,'')) and coalesce(new.original_publisher,'')<>''
      or (e.normalized_extract_text is not null and extensions.similarity(e.normalized_extract_text,new.normalized_extract_text)>=0.80)
    )
  order by case when e.snapshot_hash=new.snapshot_hash or e.extraction_hash=new.extraction_hash then 1.0 else extensions.similarity(e.normalized_extract_text,new.normalized_extract_text) end desc
  limit 1;
  if prior.source_family_id is not null then
    new.source_family_id:=prior.source_family_id;
    sim:=coalesce(prior.s,0);
    new.family_assignment_method:=case when sim>=0.999 then 'EXACT_CONTENT_HASH' when coalesce(new.original_publisher,'')<>'' and lower(coalesce(prior.original_publisher,''))=lower(new.original_publisher) then 'DECLARED_ORIGIN_COLLAPSE' else 'SEMANTIC_OVERLAP_80' end;
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
drop trigger if exists trg_00_kernel_evidence_identity_family on public.evidence;
create trigger trg_00_kernel_evidence_identity_family before insert or update on public.evidence for each row execute function public.nrfim_assign_kernel_evidence_identity_and_family();

create or replace function public.enforce_research_evidence_chain()
returns trigger language plpgsql as $$
declare ev public.research_tool_events%rowtype; dup_family text;
begin
  if upper(coalesce(new.evidence_scope,''))<>'SPORTS_REASONING' then return new; end if;
  if new.game_id is null then raise exception 'SPORTS_EVIDENCE_REQUIRES_GAME_ID' using errcode='23514'; end if;
  if coalesce(new.tool_event_id,'')='' then raise exception 'SPORTS_EVIDENCE_TOOL_EVENT_REQUIRED' using errcode='23514'; end if;
  select * into ev from public.research_tool_events where event_id=new.tool_event_id;
  if not found or ev.run_id<>new.run_id or ev.game_id is distinct from new.game_id then raise exception 'SPORTS_EVIDENCE_TOOL_EVENT_MISMATCH' using errcode='23514'; end if;
  if new.custody_version='SEMANTIC-CUSTODY-1.0' and (not ev.kernel_attested or not new.kernel_attested) then raise exception 'SPORTS_EVIDENCE_KERNEL_ATTESTATION_REQUIRED' using errcode='23514'; end if;
  if coalesce(new.source_family_id,'')='' then raise exception 'SPORTS_EVIDENCE_SOURCE_FAMILY_REQUIRED' using errcode='23514'; end if;
  if not exists(select 1 from public.research_source_families f where f.source_family_id=new.source_family_id and f.run_id=new.run_id and f.game_id=new.game_id) then raise exception 'SPORTS_EVIDENCE_SOURCE_FAMILY_NOT_REGISTERED' using errcode='23514'; end if;
  if coalesce(new.snapshot_hash,'')='' then raise exception 'SPORTS_EVIDENCE_SNAPSHOT_HASH_REQUIRED' using errcode='23514'; end if;
  new.retrieved_at:=ev.occurred_at;
  if new.custody_version='SEMANTIC-CUSTODY-1.0' then
    new.published_or_updated_at:=ev.source_published_at;
    new.data_available_since:=coalesce(ev.data_available_since_kernel,ev.source_published_at,ev.occurred_at);
    new.data_available_at:=new.data_available_since;
  else
    new.data_available_at:=coalesce(new.data_available_at,new.data_available_since,new.published_or_updated_at,ev.occurred_at);
  end if;
  if new.data_available_at>ev.occurred_at then raise exception 'SPORTS_EVIDENCE_NOT_YET_AVAILABLE:%/%',new.data_available_at,ev.occurred_at using errcode='23514'; end if;
  select e.source_family_id into dup_family from public.evidence e where e.run_id=new.run_id and e.game_id=new.game_id and e.evidence_id<>new.evidence_id and e.payload_hash=new.payload_hash and upper(coalesce(e.evidence_scope,''))='SPORTS_REASONING' limit 1;
  if dup_family is not null and dup_family<>new.source_family_id then raise exception 'DUPLICATE_CONTENT_CANNOT_CREATE_NEW_SOURCE_FAMILY:%/%',dup_family,new.source_family_id using errcode='23514'; end if;
  return new;
end $$;

create or replace function public.nrfim_validate_materialization_path(obj jsonb)
returns boolean language plpgsql immutable as $$
declare p jsonb; steps jsonb; pt text;
begin
  if jsonb_typeof(obj)<>'object' then return false; end if;
  p:=obj->'materialization_path';
  if jsonb_typeof(p)<>'object' then return false; end if;
  if upper(coalesce(p->>'half','')) not in ('TOP_1ST','BOTTOM_1ST') then return false; end if;
  pt:=upper(coalesce(p->>'path_type',''));
  if pt not in ('FREE_TRAFFIC_CHAIN','ONE_SWING','EXTRA_BASE_CHAIN','CONTACT_CLUSTER','ERROR_ADVANCEMENT','OTHER_SPECIFIC') then return false; end if;
  if length(trim(coalesce(p->>'vulnerability_activator','')))<4 then return false; end if;
  if jsonb_typeof(coalesce(p->'evidence_ids','[]'::jsonb))<>'array' or jsonb_array_length(coalesce(p->'evidence_ids','[]'::jsonb))=0 then return false; end if;
  steps:=coalesce(p->'steps','[]'::jsonb);
  if jsonb_typeof(steps)<>'array' or jsonb_array_length(steps)=0 then return false; end if;
  if pt='ONE_SWING' then
    if length(trim(coalesce(p->>'batter_or_profile','')))<2 or length(trim(coalesce(p->>'pitch_or_zone_vulnerability','')))<2 then return false; end if;
  elsif jsonb_array_length(steps)<2 then return false;
  end if;
  if exists(select 1 from jsonb_array_elements(steps) s where jsonb_typeof(s)<>'object' or length(trim(coalesce(s->>'event','')))<2 or length(trim(coalesce(s->>'actor_or_profile','')))<2) then return false; end if;
  return true;
end $$;

create or replace function public.nrfim_validate_change_condition(obj jsonb, scheduled_start timestamptz)
returns boolean language plpgsql immutable as $$
declare t text; d timestamptz;
begin
  if jsonb_typeof(obj)<>'object' then return false; end if;
  t:=upper(coalesce(obj->>'trigger_type',''));
  if t not in ('METRIC_THRESHOLD','LINEUP_EVENT','STARTER_CHANGE','ROLE_CHANGE','WEATHER_EVENT','OTHER_OBSERVABLE') then return false; end if;
  if length(trim(coalesce(obj->>'observable','')))<4 or coalesce(obj->>'deadline_at','')='' then return false; end if;
  begin d:=(obj->>'deadline_at')::timestamptz; exception when others then return false; end;
  if scheduled_start is not null and d>scheduled_start then return false; end if;
  if t='METRIC_THRESHOLD' and (length(trim(coalesce(obj->>'metric_name','')))<2 or coalesce(obj->>'operator','') not in ('>','>=','<','<=','=','!=') or not (obj ? 'threshold')) then return false; end if;
  return true;
end $$;

create or replace function public.nrfim_semantic_packet_guard()
returns trigger language plpgsql as $$
declare g record; f jsonb; pr jsonb; eid text; topn int:=0; botn int:=0; fams int:=0; contradiction_count int:=0; governing_open int:=0; required_fams int:=2; last_fams text[]:='{}'; a record; b record;
begin
  if tg_op='INSERT' then new.custody_version:='SEMANTIC-CUSTODY-1.0'; end if;
  if new.custody_version<>'SEMANTIC-CUSTODY-1.0' then return new; end if;
  if new.status<>'ANALYSIS_COMPLETE' then return new; end if;
  select scheduled_start into g from public.games where run_id=new.run_id and game_id=new.game_id;
  if not found then raise exception 'SEMANTIC_PACKET_GAME_NOT_FOUND' using errcode='23514'; end if;
  if new.lineup_status='UNKNOWN' then raise exception 'PACKET_LINEUP_STATUS_REQUIRED' using errcode='23514'; end if;
  if new.lineup_status='PROJECTED' and new.projected_analysis='{}'::jsonb then raise exception 'PROJECTED_LINEUP_REQUIRES_PROJECTED_ANALYSIS' using errcode='23514'; end if;
  if new.lineup_status='CONFIRMED' and new.confirmed_analysis='{}'::jsonb then raise exception 'CONFIRMED_LINEUP_REQUIRES_CONFIRMED_ANALYSIS' using errcode='23514'; end if;
  if new.lineup_status='MIXED' and (new.projected_analysis='{}'::jsonb or new.confirmed_analysis='{}'::jsonb) then raise exception 'MIXED_LINEUP_REQUIRES_SEPARATE_PROJECTED_AND_CONFIRMED_ANALYSIS' using errcode='23514'; end if;
  if jsonb_typeof(new.first_inning_factors)<>'array' then raise exception 'FIRST_INNING_FACTORS_ARRAY_REQUIRED' using errcode='23514'; end if;
  for f in select value from jsonb_array_elements(new.first_inning_factors) loop
    if upper(coalesce(f->>'half',''))='TOP_1ST' then topn:=topn+1; elsif upper(coalesce(f->>'half',''))='BOTTOM_1ST' then botn:=botn+1; else raise exception 'FIRST_INNING_FACTOR_HALF_INVALID' using errcode='23514'; end if;
    if length(trim(coalesce(f->>'mechanism','')))<4 then raise exception 'FIRST_INNING_FACTOR_MECHANISM_REQUIRED' using errcode='23514'; end if;
    if jsonb_typeof(coalesce(f->'evidence_ids','[]'::jsonb))<>'array' or jsonb_array_length(coalesce(f->'evidence_ids','[]'::jsonb))=0 then raise exception 'FIRST_INNING_FACTOR_EVIDENCE_REQUIRED' using errcode='23514'; end if;
    for eid in select jsonb_array_elements_text(f->'evidence_ids') loop
      if not (eid=any(coalesce(new.evidence_ids,'{}'))) or not exists(select 1 from public.evidence e where e.evidence_id=eid and e.run_id=new.run_id and e.game_id=new.game_id and e.kernel_attested) then raise exception 'FIRST_INNING_FACTOR_EVIDENCE_NOT_KERNEL_ATTESTED:%',eid using errcode='23514'; end if;
    end loop;
  end loop;
  if topn=0 or botn=0 then raise exception 'FIRST_INNING_FACTORS_MUST_COVER_BOTH_HALVES' using errcode='23514'; end if;
  if jsonb_typeof(new.full_game_proxies)<>'array' then raise exception 'FULL_GAME_PROXIES_MUST_BE_ARRAY' using errcode='23514'; end if;
  for pr in select value from jsonb_array_elements(new.full_game_proxies) loop
    if upper(coalesce(pr->>'role',''))<>'MODIFIER' or length(trim(coalesce(pr->>'first_inning_link','')))<8 then raise exception 'FULL_GAME_DATA_MUST_BE_EXPLICIT_FIRST_INNING_MODIFIER' using errcode='23514'; end if;
    if jsonb_typeof(coalesce(pr->'evidence_ids','[]'::jsonb))<>'array' or jsonb_array_length(coalesce(pr->'evidence_ids','[]'::jsonb))=0 then raise exception 'FULL_GAME_MODIFIER_EVIDENCE_REQUIRED' using errcode='23514'; end if;
  end loop;
  if upper(coalesce(new.dominant_factor->>'basis_scope',''))='FULL_GAME_ONLY' then raise exception 'FULL_GAME_ONLY_FACTOR_CANNOT_GOVERN_FIRST_INNING_VERDICT' using errcode='23514'; end if;
  if jsonb_typeof(coalesce(new.dominant_factor->'evidence_ids','[]'::jsonb))<>'array' or jsonb_array_length(coalesce(new.dominant_factor->'evidence_ids','[]'::jsonb))=0 then raise exception 'DOMINANT_FACTOR_EVIDENCE_REQUIRED' using errcode='23514'; end if;
  if not public.nrfim_validate_materialization_path(new.best_yrfi_rival) then raise exception 'BEST_YRFI_RIVAL_REQUIRES_SPECIFIC_MATERIALIZATION_PATH' using errcode='23514'; end if;
  if not public.nrfim_validate_change_condition(new.what_would_change,g.scheduled_start) then raise exception 'WHAT_WOULD_CHANGE_MUST_BE_OBSERVABLE_AND_TIME_BOUND' using errcode='23514'; end if;
  if jsonb_typeof(new.adversarial_balance)<>'object' or jsonb_typeof(coalesce(new.adversarial_balance->'nrfi_evidence_ids','[]'::jsonb))<>'array' or jsonb_typeof(coalesce(new.adversarial_balance->'yrfi_evidence_ids','[]'::jsonb))<>'array' or jsonb_array_length(coalesce(new.adversarial_balance->'nrfi_evidence_ids','[]'::jsonb))=0 or jsonb_array_length(coalesce(new.adversarial_balance->'yrfi_evidence_ids','[]'::jsonb))=0 then raise exception 'ADVERSARIAL_BALANCE_REQUIRES_NRFI_AND_YRFI_EVIDENCE' using errcode='23514'; end if;
  for eid in select jsonb_array_elements_text(new.adversarial_balance->'nrfi_evidence_ids') union select jsonb_array_elements_text(new.adversarial_balance->'yrfi_evidence_ids') loop
    if not (eid=any(coalesce(new.evidence_ids,'{}'))) then raise exception 'ADVERSARIAL_BALANCE_EVIDENCE_OUTSIDE_PACKET:%',eid using errcode='23514'; end if;
  end loop;
  if jsonb_typeof(new.unresolved_contradictions)<>'array' then raise exception 'UNRESOLVED_CONTRADICTIONS_ARRAY_REQUIRED' using errcode='23514'; end if;
  select count(*) filter(where upper(coalesce(x->>'materiality','')) in ('MATERIAL','GOVERNING')),
         count(*) filter(where upper(coalesce(x->>'materiality',''))='GOVERNING' and upper(coalesce(x->>'status',''))='OPEN')
    into contradiction_count,governing_open from jsonb_array_elements(new.unresolved_contradictions) x;
  if governing_open>0 then raise exception 'GOVERNING_CONTRADICTION_CANNOT_CLOSE_ANALYSIS' using errcode='23514'; end if;
  required_fams:=case when contradiction_count>0 then 4 else 2 end;
  new.adaptive_required_families:=required_fams;
  select count(distinct e.source_family_id) into fams from public.evidence e where e.evidence_id=any(coalesce(new.evidence_ids,'{}')) and e.run_id=new.run_id and e.game_id=new.game_id and e.kernel_attested;
  if fams<required_fams then raise exception 'ADAPTIVE_RESEARCH_DEPTH_NOT_MET:%/%',fams,required_fams using errcode='23514'; end if;
  if not new.saturation_reached then raise exception 'ANALYSIS_COMPLETE_REQUIRES_SATURATION_REACHED' using errcode='23514'; end if;
  select coalesce(array_agg(z.source_family_id order by z.last_seen),'{}') into last_fams from (
    select e.source_family_id,max(te.occurred_at) last_seen from public.evidence e join public.research_tool_events te on te.event_id=e.tool_event_id
    where e.evidence_id=any(coalesce(new.evidence_ids,'{}')) and e.run_id=new.run_id and e.game_id=new.game_id and e.kernel_attested group by e.source_family_id order by max(te.occurred_at) desc limit 2
  ) z;
  new.saturation_family_ids:=last_fams;
  if coalesce(array_length(new.saturation_family_ids,1),0)<2 then raise exception 'SATURATION_REQUIRES_TWO_FINAL_INDEPENDENT_FAMILIES' using errcode='23514'; end if;
  if length(trim(coalesce(new.why_stop_detail,'')))<8 then raise exception 'WHY_RESEARCH_STOPPED_DETAIL_REQUIRED' using errcode='23514'; end if;
  if jsonb_typeof(new.causal_clusters)='array' then
    for a in select ordinality,value from jsonb_array_elements(new.causal_clusters) with ordinality loop
      if length(trim(coalesce(a.value->>'mechanism','')))<4 or jsonb_typeof(coalesce(a.value->'evidence_ids','[]'::jsonb))<>'array' or jsonb_array_length(coalesce(a.value->'evidence_ids','[]'::jsonb))=0 then raise exception 'CAUSAL_CLUSTER_REQUIRES_MECHANISM_AND_EVIDENCE' using errcode='23514'; end if;
      for b in select ordinality,value from jsonb_array_elements(new.causal_clusters) with ordinality where ordinality>a.ordinality loop
        if extensions.similarity(public.nrfim_normalize_extract(a.value->>'mechanism'),public.nrfim_normalize_extract(b.value->>'mechanism'))>=0.80 then raise exception 'CAUSAL_CLUSTER_NEAR_DUPLICATE_MUST_COLLAPSE:%/%',a.ordinality,b.ordinality using errcode='23514'; end if;
      end loop;
    end loop;
  end if;
  return new;
end $$;
drop trigger if exists trg_00z_semantic_packet_guard on public.sports_reasoning_packets;
create trigger trg_00z_semantic_packet_guard before insert or update on public.sports_reasoning_packets for each row execute function public.nrfim_semantic_packet_guard();

insert into public.sports_process_auditor_registry(auditor_id,auditor_type,status,may_vote_sports,owner,version,code_hash,metadata,registered_at)
values('KERNEL_PROCESS_AUDITOR_0.3','DETERMINISTIC_STRUCTURAL','ACTIVE',false,'NRFIMETRICA_KERNEL','0.3',public.nrfim_sha256_text('KERNEL_PROCESS_AUDITOR_0.3|SEMANTIC-CUSTODY-1.0|ADAPTIVE-CONTRADICTION-1.0'),jsonb_build_object('authority','PROCESS_ONLY','sports_vote','FORBIDDEN','derived_checks',jsonb_build_array('STRUCTURAL','TEMPORAL','EVIDENCE','KERNEL_ATTESTATION','FALSIFICATION','ADVERSARIAL_BALANCE','ADAPTIVE_DEPTH','FIRST_INNING_MATERIALITY','DRIVE_HASH')) ,clock_timestamp())
on conflict(auditor_id) do update set status=excluded.status,code_hash=excluded.code_hash,metadata=excluded.metadata,registered_at=excluded.registered_at;

create or replace function public.enforce_sports_process_audit()
returns trigger language plpgsql as $$
declare p public.sports_reasoning_packets%rowtype; g record; req_families integer; ev_total integer:=0; ev_valid integer:=0; bad_temporal integer:=0; factual_total integer:=0; factual_bad integer:=0; fa jsonb; nrfi_test boolean:=false; yrfi_test boolean:=false; fa_bad integer:=0; contradiction_count integer:=0; governing_open integer:=0; topn integer:=0; botn integer:=0; bal_nrfi integer:=0; bal_yrfi integer:=0;
begin
  select * into p from public.sports_reasoning_packets where packet_id=new.packet_id; if not found then raise exception 'PROCESS_AUDIT_PACKET_NOT_FOUND' using errcode='23514'; end if;
  select scheduled_start into g from public.games where run_id=p.run_id and game_id=p.game_id; if not found then raise exception 'PROCESS_AUDIT_GAME_NOT_FOUND' using errcode='23514'; end if;
  new.run_id:=p.run_id; new.game_id:=p.game_id; new.created_at:=clock_timestamp();
  if p.custody_version='SEMANTIC-CUSTODY-1.0' then new.auditor_id:='KERNEL_PROCESS_AUDITOR_0.3'; else new.auditor_id:='KERNEL_PROCESS_AUDITOR_0.2'; end if;
  if not exists(select 1 from public.sports_process_auditor_registry r where r.auditor_id=new.auditor_id and r.status='ACTIVE' and r.auditor_type='DETERMINISTIC_STRUCTURAL' and r.may_vote_sports=false) then raise exception 'PROCESS_AUDITOR_NOT_ACTIVE_OR_SPORTS_VOTE_ENABLED' using errcode='23514'; end if;
  req_families:=case when p.complexity_tier='CLEAR' then 3 when p.complexity_tier='NORMAL' then 5 else 7 end;
  if p.custody_version='SEMANTIC-CUSTODY-1.0' then req_families:=p.adaptive_required_families; end if;
  new.structural_pass := (p.status='ANALYSIS_COMPLETE' and p.freeze_timestamp is not null and coalesce(p.packet_hash,'')<>'' and p.top_1st_analysis<>'{}'::jsonb and p.bottom_1st_analysis<>'{}'::jsonb and p.central_nrfi_case<>'{}'::jsonb and p.best_yrfi_rival<>'{}'::jsonb and p.strongest_counterevidence<>'{}'::jsonb and p.what_would_change<>'{}'::jsonb and p.sports_verdict is not null and p.dimensions_covered @> array['TOP_1ST','BOTTOM_1ST','STARTER_CURRENT_FORM','TOP_ORDER_MATCHUP','FIRST_INNING_SPECIFIC','COUNTEREVIDENCE'] and p.drive_verified_at is not null and p.drive_content_hash is not distinct from p.packet_hash);
  select count(*) into ev_total from unnest(coalesce(p.evidence_ids,'{}')) x;
  if p.custody_version='SEMANTIC-CUSTODY-1.0' then
    select count(*) into ev_valid from public.evidence e join public.research_tool_events te on te.event_id=e.tool_event_id where e.evidence_id=any(coalesce(p.evidence_ids,'{}')) and e.run_id=p.run_id and e.game_id=p.game_id and upper(coalesce(e.evidence_scope,''))='SPORTS_REASONING' and e.kernel_attested and te.kernel_attested and te.retrieval_mode in ('KERNEL_SERVER_FETCH','KERNEL_PROVIDER_FETCH') and coalesce(e.source_family_id,'')<>'' and coalesce(e.snapshot_hash,'')<>'' and coalesce(e.snapshot_drive_file_id,'')<>'' and e.snapshot_drive_hash=e.snapshot_hash;
  else
    select count(*) into ev_valid from public.evidence e where e.evidence_id=any(coalesce(p.evidence_ids,'{}')) and e.run_id=p.run_id and e.game_id=p.game_id and upper(coalesce(e.evidence_scope,''))='SPORTS_REASONING' and coalesce(e.tool_event_id,'')<>'' and coalesce(e.source_family_id,'')<>'' and coalesce(e.snapshot_hash,'')<>'' and coalesce(e.snapshot_drive_file_id,'')<>'' and e.snapshot_drive_hash=e.snapshot_hash;
  end if;
  select count(*) into factual_total from public.sports_reasoning_claims c where c.packet_id=p.packet_id and c.claim_type='FACTUAL';
  select count(*) into factual_bad from public.sports_reasoning_claims c where c.packet_id=p.packet_id and c.claim_type='FACTUAL' and coalesce(array_length(c.evidence_ids,1),0)=0;
  new.evidence_pass := (ev_total>0 and ev_valid=ev_total and factual_total>0 and factual_bad=0);
  new.semantic_custody_pass := case when p.custody_version='SEMANTIC-CUSTODY-1.0' then (ev_total>0 and ev_valid=ev_total) else true end;
  select count(*) into bad_temporal from public.evidence e where e.evidence_id=any(coalesce(p.evidence_ids,'{}')) and (e.retrieved_at is null or e.data_available_at is null or e.data_available_at>e.retrieved_at or (p.freeze_timestamp is not null and e.retrieved_at>p.freeze_timestamp) or (g.scheduled_start is not null and e.retrieved_at>=g.scheduled_start));
  new.temporal_pass := (p.as_of_kernel is not null and p.as_of_kernel<g.scheduled_start and bad_temporal=0);
  if jsonb_typeof(p.falsification_attempts)='array' then for fa in select value from jsonb_array_elements(p.falsification_attempts) loop if upper(coalesce(fa->>'against',''))='NRFI' then nrfi_test:=true; end if; if upper(coalesce(fa->>'against',''))='YRFI' then yrfi_test:=true; end if; if jsonb_typeof(coalesce(fa->'evidence_ids','[]'::jsonb))<>'array' or jsonb_array_length(coalesce(fa->'evidence_ids','[]'::jsonb))=0 then fa_bad:=fa_bad+1; end if; end loop; end if;
  new.falsification_pass := (nrfi_test and yrfi_test and fa_bad=0 and jsonb_array_length(coalesce(p.falsification_attempts,'[]'::jsonb))>=2 and (p.custody_version<>'SEMANTIC-CUSTODY-1.0' or public.nrfim_validate_materialization_path(p.best_yrfi_rival)));
  if p.custody_version='SEMANTIC-CUSTODY-1.0' then
    bal_nrfi:=jsonb_array_length(coalesce(p.adversarial_balance->'nrfi_evidence_ids','[]'::jsonb)); bal_yrfi:=jsonb_array_length(coalesce(p.adversarial_balance->'yrfi_evidence_ids','[]'::jsonb));
    new.adversarial_balance_pass:=(bal_nrfi>0 and bal_yrfi>0);
    if jsonb_typeof(p.first_inning_factors)='array' then select count(*) filter(where upper(coalesce(x->>'half',''))='TOP_1ST'),count(*) filter(where upper(coalesce(x->>'half',''))='BOTTOM_1ST') into topn,botn from jsonb_array_elements(p.first_inning_factors) x; end if;
    new.first_inning_materiality_pass:=(topn>0 and botn>0 and upper(coalesce(p.dominant_factor->>'basis_scope',''))<>'FULL_GAME_ONLY');
    if jsonb_typeof(p.unresolved_contradictions)='array' then select count(*) filter(where upper(coalesce(x->>'materiality','')) in ('MATERIAL','GOVERNING')),count(*) filter(where upper(coalesce(x->>'materiality',''))='GOVERNING' and upper(coalesce(x->>'status',''))='OPEN') into contradiction_count,governing_open from jsonb_array_elements(p.unresolved_contradictions) x; end if;
    new.adaptive_depth_pass:=(p.source_family_count>=req_families and p.saturation_reached and coalesce(array_length(p.saturation_family_ids,1),0)>=2 and governing_open=0);
    new.independence_pass:=new.adaptive_depth_pass;
  else
    new.adversarial_balance_pass:=true; new.first_inning_materiality_pass:=true; new.adaptive_depth_pass:=(p.source_family_count>=req_families); new.independence_pass:=new.adaptive_depth_pass;
  end if;
  if new.structural_pass and new.temporal_pass and new.evidence_pass and new.falsification_pass and new.independence_pass and new.semantic_custody_pass and new.adversarial_balance_pass and new.first_inning_materiality_pass then if upper(coalesce(new.clone_risk,'NOT_EVALUATED'))='HIGH' then new.status:='REVIEW'; else new.status:='PASS'; end if; else new.status:='FAIL'; end if;
  new.findings:=coalesce(new.findings,'{}'::jsonb)||jsonb_build_object('derived_by',new.auditor_id,'requested_status_ignored',true,'custody_version',p.custody_version,'adaptive_required_source_families',req_families,'actual_source_families',p.source_family_count,'evidence_total',ev_total,'evidence_chain_valid',ev_valid,'factual_claim_count',factual_total,'bad_temporal_evidence_count',bad_temporal,'semantic_custody_pass',new.semantic_custody_pass,'adversarial_balance_pass',new.adversarial_balance_pass,'adaptive_depth_pass',new.adaptive_depth_pass,'first_inning_materiality_pass',new.first_inning_materiality_pass,'sports_vote_authority','FORBIDDEN');
  new.audit_hash:=public.nrfim_sha256_text(concat_ws('|',new.audit_id,new.packet_id,new.auditor_id,new.status,new.structural_pass::text,new.temporal_pass::text,new.evidence_pass::text,new.falsification_pass::text,new.independence_pass::text,new.semantic_custody_pass::text,new.adversarial_balance_pass::text,new.adaptive_depth_pass::text,new.first_inning_materiality_pass::text,new.findings::text));
  update public.sports_reasoning_packets set process_audit_status=new.status,process_audit_id=new.audit_id,updated_at=clock_timestamp() where packet_id=new.packet_id; return new;
end $$;

update public.agent_registry
set agent_version='MOTHER-V3-AGENT-1.9',kernel_version='NRFIM-KERNEL-1.4-DETERMINISTIC-SEMANTIC-CUSTODY',metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object(
  'process_auditor','KERNEL_PROCESS_AUDITOR_0.3',
  'semantic_custody_version','SEMANTIC-CUSTODY-1.0',
  'adaptive_research_depth','ADAPTIVE-CONTRADICTION-1.0',
  'kernel_query_required_before_research_event',true,
  'sports_evidence_requires_kernel_attested_extraction',true,
  'evidence_id_kernel_generated',true,
  'tool_event_id_kernel_generated',true,
  'source_family_kernel_derived',true,
  'semantic_overlap_collapse_threshold',0.80,
  'fixed_source_family_floor_retired_for_new_packets',true,
  'adaptive_family_floor_no_contradiction',2,
  'adaptive_family_floor_material_contradiction',4,
  'yrfi_materialization_path_required',true,
  'adversarial_balance_required',true,
  'projected_confirmed_analysis_separation_required',true,
  'full_game_data_role','MODIFIER_WITH_EXPLICIT_FIRST_INNING_LINK_ONLY',
  'what_would_change_must_be_observable_time_bound',true,
  'database_migrations_required_through',53)
where agent_id='@NRFImetrica';
update public.system_versions set kernel_version='NRFIM-KERNEL-1.4-DETERMINISTIC-SEMANTIC-CUSTODY' where system_version='NRFIM MOTHER V3';
