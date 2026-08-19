create extension if not exists pgcrypto;

create table if not exists public.research_source_families (
  source_family_id text primary key,
  run_id text not null references public.runs(run_id) on delete cascade,
  game_id text not null,
  family_key text not null,
  original_publisher text,
  canonical_origin text,
  family_basis text not null check (family_basis in ('PRIMARY_ORIGIN','WIRE_ORIGIN','DATASET_ORIGIN','EXACT_CONTENT_HASH','MANUAL_REVIEW')),
  created_at timestamptz not null default now(),
  unique(run_id,game_id,family_key)
);
alter table public.research_source_families enable row level security;

create table if not exists public.research_tool_events (
  event_id text primary key,
  run_id text not null references public.runs(run_id) on delete cascade,
  game_id text,
  tool_name text not null,
  operation text not null check (operation in ('SEARCH','OPEN','FETCH','READ','QUERY','EXTRACT','OTHER')),
  request_hash text,
  response_hash text,
  source_ref text,
  source_url text,
  occurred_at timestamptz not null default now(),
  material_new_info boolean,
  evidence_id text,
  event_hash text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists research_tool_events_run_game_idx on public.research_tool_events(run_id,game_id,occurred_at);
alter table public.research_tool_events enable row level security;

alter table public.evidence
  add column if not exists tool_event_id text,
  add column if not exists source_family_id text,
  add column if not exists original_publisher text,
  add column if not exists published_or_updated_at timestamptz,
  add column if not exists data_available_since timestamptz,
  add column if not exists snapshot_hash text,
  add column if not exists snapshot_drive_file_id text,
  add column if not exists snapshot_drive_hash text,
  add column if not exists claims_extracted jsonb not null default '[]'::jsonb,
  add column if not exists evidence_scope text not null default 'GENERAL';
create index if not exists evidence_research_chain_idx on public.evidence(run_id,game_id,source_family_id,retrieved_at);

create table if not exists public.sports_reasoning_packets (
  packet_id text primary key,
  run_id text not null references public.runs(run_id) on delete cascade,
  game_id text not null,
  protocol_id text not null default 'NRFIMETRICA_MOTHER_V3_AUTONOMOUS',
  version integer not null default 1 check (version > 0),
  previous_packet_hash text,
  complexity_tier text not null check (complexity_tier in ('CLEAR','NORMAL','DEEP')),
  status text not null check (status in ('IN_PROGRESS','ANALYSIS_COMPLETE','RESEARCH_INCOMPLETE','INFORMATION_UNAVAILABLE','NOT_EXECUTABLE','WITHDRAWN_POST_FREEZE','PROCESS_FAIL')),
  sports_verdict text check (sports_verdict in ('NRFI_LEAN','YRFI_LEAN','NEUTRAL','NO_PLAY','RESEARCH_ONLY')),
  analysis_started_at timestamptz not null default now(),
  analysis_completed_at timestamptz,
  as_of_kernel timestamptz,
  cutoff_at timestamptz,
  evidence_ids text[] not null default '{}',
  source_family_count integer not null default 0,
  top_1st_analysis jsonb not null default '{}'::jsonb,
  bottom_1st_analysis jsonb not null default '{}'::jsonb,
  central_nrfi_case jsonb not null default '{}'::jsonb,
  best_yrfi_rival jsonb not null default '{}'::jsonb,
  strongest_counterevidence jsonb not null default '{}'::jsonb,
  falsification_attempts jsonb not null default '[]'::jsonb,
  causal_clusters jsonb not null default '[]'::jsonb,
  dominant_factor jsonb not null default '{}'::jsonb,
  governing_uncertainty jsonb not null default '{}'::jsonb,
  what_would_change jsonb not null default '{}'::jsonb,
  why_research_stopped text,
  why_stop_detail text,
  saturation_family_ids text[] not null default '{}',
  dimensions_covered text[] not null default '{}',
  dimensions_missing jsonb not null default '[]'::jsonb,
  research_depth_justification text,
  known_unknowns jsonb not null default '[]'::jsonb,
  full_game_proxies jsonb not null default '[]'::jsonb,
  packet_payload jsonb not null default '{}'::jsonb,
  packet_hash text,
  freeze_timestamp timestamptz,
  drive_file_id text,
  drive_content_hash text,
  drive_verified_at timestamptz,
  process_audit_status text not null default 'PENDING' check (process_audit_status in ('PENDING','PASS','FAIL','REVIEW')),
  process_audit_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(run_id,game_id,version)
);
create index if not exists sports_packets_run_game_idx on public.sports_reasoning_packets(run_id,game_id,version desc);
alter table public.sports_reasoning_packets enable row level security;

create table if not exists public.sports_reasoning_claims (
  claim_id text primary key,
  packet_id text not null references public.sports_reasoning_packets(packet_id) on delete cascade,
  run_id text not null,
  game_id text not null,
  claim_type text not null check (claim_type in ('FACTUAL','INTERPRETIVE','HYPOTHESIS')),
  claim_text text not null,
  evidence_ids text[] not null default '{}',
  claim_hash text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists sports_claims_packet_idx on public.sports_reasoning_claims(packet_id,claim_type);
alter table public.sports_reasoning_claims enable row level security;

create table if not exists public.sports_process_audits (
  audit_id text primary key,
  packet_id text not null references public.sports_reasoning_packets(packet_id) on delete cascade,
  run_id text not null,
  game_id text not null,
  auditor_id text not null,
  structural_pass boolean not null,
  temporal_pass boolean not null,
  evidence_pass boolean not null,
  falsification_pass boolean not null,
  independence_pass boolean not null,
  clone_risk text not null default 'NOT_EVALUATED' check (clone_risk in ('NOT_EVALUATED','LOW','MEDIUM','HIGH')),
  findings jsonb not null default '{}'::jsonb,
  status text not null check (status in ('PASS','FAIL','REVIEW')),
  audit_hash text not null default '',
  created_at timestamptz not null default now()
);
alter table public.sports_process_audits enable row level security;

create table if not exists public.research_drive_artifacts (
  artifact_id text primary key,
  run_id text not null references public.runs(run_id) on delete cascade,
  game_id text,
  packet_id text references public.sports_reasoning_packets(packet_id) on delete cascade,
  artifact_type text not null check (artifact_type in ('PACKET','EVIDENCE_SNAPSHOT','RUN_MANIFEST','FINAL_REPORT')),
  drive_file_id text not null,
  content_hash text not null,
  verification_method text not null check (verification_method in ('GOOGLE_DRIVE_CONNECTOR_READBACK','KERNEL_PROVIDER_READBACK')),
  verified_at timestamptz not null default now(),
  immutable boolean not null default true,
  unique(run_id,artifact_type,drive_file_id)
);
alter table public.research_drive_artifacts enable row level security;

create or replace function public.nrfim_sha256_text(v text)
returns text language sql immutable as $$
  select encode(digest(coalesce(v,''),'sha256'),'hex')
$$;

create or replace function public.enforce_research_tool_event()
returns trigger language plpgsql as $$
declare prevh text; traceh text;
begin
  new.occurred_at:=clock_timestamp();
  new.created_at:=new.occurred_at;
  new.event_hash:=public.nrfim_sha256_text(concat_ws('|',new.event_id,new.run_id,coalesce(new.game_id,''),new.tool_name,new.operation,coalesce(new.request_hash,''),coalesce(new.response_hash,''),new.occurred_at::text));
  update public.runs set tool_call_count=coalesce(tool_call_count,0)+1 where run_id=new.run_id;
  select event_hash into prevh from public.trace_events where run_id=new.run_id order by occurred_at desc limit 1;
  traceh:=public.nrfim_sha256_text(concat_ws('|',new.event_id,new.run_id,coalesce(new.game_id,''),'RESEARCH_TOOL_CALL',new.event_hash,coalesce(prevh,''),new.occurred_at::text));
  insert into public.trace_events(event_id,run_id,game_id,task_id,event_type,status,occurred_at,input_hash,output_hash,tool_name,evidence_ids,prev_event_hash,event_hash,details)
  values('TRACE-'||new.event_id,new.run_id,new.game_id,'SPORTS_RESEARCH','RESEARCH_TOOL_CALL','COMPLETE',new.occurred_at,new.request_hash,new.response_hash,new.tool_name,'{}',prevh,traceh,jsonb_build_object('research_event_id',new.event_id,'operation',new.operation,'source_ref',new.source_ref,'source_url',new.source_url));
  return new;
end $$;
drop trigger if exists trg_01_research_tool_event on public.research_tool_events;
create trigger trg_01_research_tool_event before insert on public.research_tool_events for each row execute function public.enforce_research_tool_event();

create or replace function public.enforce_research_evidence_chain()
returns trigger language plpgsql as $$
declare ev public.research_tool_events%rowtype; dup_family text;
begin
  if upper(coalesce(new.evidence_scope,''))<>'SPORTS_REASONING' then return new; end if;
  if new.game_id is null then raise exception 'SPORTS_EVIDENCE_REQUIRES_GAME_ID' using errcode='23514'; end if;
  if coalesce(new.tool_event_id,'')='' then raise exception 'SPORTS_EVIDENCE_TOOL_EVENT_REQUIRED' using errcode='23514'; end if;
  select * into ev from public.research_tool_events where event_id=new.tool_event_id;
  if not found or ev.run_id<>new.run_id or ev.game_id is distinct from new.game_id then raise exception 'SPORTS_EVIDENCE_TOOL_EVENT_MISMATCH' using errcode='23514'; end if;
  if coalesce(new.source_family_id,'')='' then raise exception 'SPORTS_EVIDENCE_SOURCE_FAMILY_REQUIRED' using errcode='23514'; end if;
  if not exists(select 1 from public.research_source_families f where f.source_family_id=new.source_family_id and f.run_id=new.run_id and f.game_id=new.game_id) then raise exception 'SPORTS_EVIDENCE_SOURCE_FAMILY_NOT_REGISTERED' using errcode='23514'; end if;
  if coalesce(new.snapshot_hash,'')='' then raise exception 'SPORTS_EVIDENCE_SNAPSHOT_HASH_REQUIRED' using errcode='23514'; end if;
  new.retrieved_at:=ev.occurred_at;
  new.data_available_at:=coalesce(new.data_available_at,new.data_available_since,new.published_or_updated_at,ev.occurred_at);
  if new.data_available_at>ev.occurred_at then raise exception 'SPORTS_EVIDENCE_NOT_YET_AVAILABLE:%/%',new.data_available_at,ev.occurred_at using errcode='23514'; end if;
  select e.source_family_id into dup_family from public.evidence e where e.run_id=new.run_id and e.game_id=new.game_id and e.evidence_id<>new.evidence_id and e.payload_hash=new.payload_hash and upper(coalesce(e.evidence_scope,''))='SPORTS_REASONING' limit 1;
  if dup_family is not null and dup_family<>new.source_family_id then raise exception 'DUPLICATE_CONTENT_CANNOT_CREATE_NEW_SOURCE_FAMILY:%/%',dup_family,new.source_family_id using errcode='23514'; end if;
  return new;
end $$;
drop trigger if exists trg_01_research_evidence_chain on public.evidence;
create trigger trg_01_research_evidence_chain before insert or update on public.evidence for each row execute function public.enforce_research_evidence_chain();

create or replace function public.enforce_sports_reasoning_claim()
returns trigger language plpgsql as $$
declare p public.sports_reasoning_packets%rowtype; eid text; e public.evidence%rowtype;
begin
  select * into p from public.sports_reasoning_packets where packet_id=new.packet_id;
  if not found then raise exception 'SPORTS_CLAIM_PACKET_NOT_FOUND' using errcode='23514'; end if;
  new.run_id:=p.run_id; new.game_id:=p.game_id;
  if new.claim_type='FACTUAL' and coalesce(array_length(new.evidence_ids,1),0)=0 then raise exception 'FACTUAL_CLAIM_REQUIRES_EVIDENCE' using errcode='23514'; end if;
  foreach eid in array coalesce(new.evidence_ids,'{}') loop
    select * into e from public.evidence where evidence_id=eid;
    if not found or e.run_id<>p.run_id or e.game_id is distinct from p.game_id or upper(coalesce(e.evidence_scope,''))<>'SPORTS_REASONING' or coalesce(e.tool_event_id,'')='' then raise exception 'CLAIM_EVIDENCE_NOT_CHAIN_VERIFIED:%',eid using errcode='23514'; end if;
  end loop;
  new.claim_hash:=public.nrfim_sha256_text(new.claim_type||'|'||new.claim_text||'|'||array_to_string(new.evidence_ids,','));
  return new;
end $$;
drop trigger if exists trg_01_sports_reasoning_claim on public.sports_reasoning_claims;
create trigger trg_01_sports_reasoning_claim before insert or update on public.sports_reasoning_claims for each row execute function public.enforce_sports_reasoning_claim();

create or replace function public.enforce_sports_reasoning_packet()
returns trigger language plpgsql as $$
declare
  g record; eid text; e record; n_evidence integer:=0; n_families integer:=0; required_families integer:=3;
  factual_count integer:=0; bad_claim_count integer:=0; fa jsonb; has_against_nrfi boolean:=false; has_against_yrfi boolean:=false;
  proxy jsonb; prior_hash text; prior_version integer; family_id text;
begin
  select scheduled_start,cutoff_at into g from public.games where run_id=new.run_id and game_id=new.game_id;
  if not found then raise exception 'SPORTS_PACKET_GAME_NOT_REGISTERED' using errcode='23514'; end if;
  new.cutoff_at:=coalesce(g.cutoff_at,g.scheduled_start); new.updated_at:=clock_timestamp();
  if tg_op='UPDATE' and old.freeze_timestamp is not null and (new.packet_payload is distinct from old.packet_payload or new.top_1st_analysis is distinct from old.top_1st_analysis or new.bottom_1st_analysis is distinct from old.bottom_1st_analysis or new.central_nrfi_case is distinct from old.central_nrfi_case or new.best_yrfi_rival is distinct from old.best_yrfi_rival or new.falsification_attempts is distinct from old.falsification_attempts or new.causal_clusters is distinct from old.causal_clusters or new.sports_verdict is distinct from old.sports_verdict) then raise exception 'SPORTS_PACKET_FROZEN_CREATE_NEW_VERSION' using errcode='23514'; end if;
  if new.version=1 then
    if coalesce(new.previous_packet_hash,'')<>'' then raise exception 'PACKET_V1_CANNOT_HAVE_PREVIOUS_HASH' using errcode='23514'; end if;
  else
    select version,packet_hash into prior_version,prior_hash from public.sports_reasoning_packets where run_id=new.run_id and game_id=new.game_id and version<new.version order by version desc limit 1;
    if prior_version is null or prior_version<>new.version-1 or coalesce(prior_hash,'')='' or new.previous_packet_hash is distinct from prior_hash then raise exception 'PACKET_VERSION_CHAIN_INVALID' using errcode='23514'; end if;
  end if;
  if coalesce(array_length(new.evidence_ids,1),0)>0 then
    select count(*),count(distinct source_family_id),max(retrieved_at) into n_evidence,n_families,new.as_of_kernel from public.evidence where evidence_id=any(new.evidence_ids) and run_id=new.run_id and game_id=new.game_id and upper(coalesce(evidence_scope,''))='SPORTS_REASONING' and coalesce(tool_event_id,'')<>'' and coalesce(source_family_id,'')<>'';
    if n_evidence<>array_length(new.evidence_ids,1) then raise exception 'PACKET_EVIDENCE_SET_NOT_CHAIN_VERIFIED:%/%',n_evidence,array_length(new.evidence_ids,1) using errcode='23514'; end if;
  else new.as_of_kernel:=null; end if;
  new.source_family_count:=n_families;
  if new.status in ('ANALYSIS_COMPLETE','RESEARCH_INCOMPLETE','INFORMATION_UNAVAILABLE','NOT_EXECUTABLE') and new.analysis_completed_at is null then new.analysis_completed_at:=clock_timestamp(); end if;
  if new.status='ANALYSIS_COMPLETE' then
    required_families:=case new.complexity_tier when 'CLEAR' then 3 when 'NORMAL' then 5 else 7 end;
    if n_families<required_families then raise exception 'PACKET_INDEPENDENT_SOURCE_FLOOR_NOT_MET:%/%',n_families,required_families using errcode='23514'; end if;
    if new.as_of_kernel is null or (g.scheduled_start is not null and new.as_of_kernel>=g.scheduled_start) then raise exception 'PACKET_TEMPORAL_WINDOW_INVALID' using errcode='23514'; end if;
    foreach eid in array new.evidence_ids loop
      select snapshot_drive_file_id,snapshot_drive_hash,snapshot_hash into e from public.evidence where evidence_id=eid;
      if coalesce(e.snapshot_drive_file_id,'')='' or coalesce(e.snapshot_drive_hash,'')='' or coalesce(e.snapshot_hash,'')='' then raise exception 'PACKET_EVIDENCE_SNAPSHOT_NOT_PERSISTED:%',eid using errcode='23514'; end if;
      if e.snapshot_drive_hash<>e.snapshot_hash then raise exception 'PACKET_EVIDENCE_SNAPSHOT_HASH_MISMATCH:%',eid using errcode='23514'; end if;
    end loop;
    if new.top_1st_analysis='{}'::jsonb or new.bottom_1st_analysis='{}'::jsonb then raise exception 'PACKET_BILATERAL_FIRST_INNING_ANALYSIS_REQUIRED' using errcode='23514'; end if;
    if new.central_nrfi_case='{}'::jsonb or new.best_yrfi_rival='{}'::jsonb then raise exception 'PACKET_NRFI_AND_YRFI_THESES_REQUIRED' using errcode='23514'; end if;
    if new.strongest_counterevidence='{}'::jsonb then raise exception 'PACKET_STRONGEST_COUNTEREVIDENCE_REQUIRED' using errcode='23514'; end if;
    if jsonb_typeof(new.falsification_attempts)<>'array' or jsonb_array_length(new.falsification_attempts)<2 then raise exception 'PACKET_TWO_FALSIFICATION_ATTEMPTS_REQUIRED' using errcode='23514'; end if;
    for fa in select value from jsonb_array_elements(new.falsification_attempts) loop
      if upper(coalesce(fa->>'against',''))='NRFI' then has_against_nrfi:=true; end if;
      if upper(coalesce(fa->>'against',''))='YRFI' then has_against_yrfi:=true; end if;
      if jsonb_typeof(coalesce(fa->'evidence_ids','[]'::jsonb))<>'array' or jsonb_array_length(coalesce(fa->'evidence_ids','[]'::jsonb))=0 then raise exception 'PACKET_FALSIFICATION_EVIDENCE_REQUIRED' using errcode='23514'; end if;
    end loop;
    if not has_against_nrfi or not has_against_yrfi then raise exception 'PACKET_FALSIFICATION_MUST_TEST_BOTH_THESES' using errcode='23514'; end if;
    if coalesce(new.why_research_stopped,'') not in ('COVERAGE_COMPLETE','DIMINISHING_RETURNS','CONTRADICTION_RESOLVED') then raise exception 'PACKET_INVALID_COMPLETE_STOP_REASON:%',coalesce(new.why_research_stopped,'') using errcode='23514'; end if;
    if new.why_research_stopped='DIMINISHING_RETURNS' and coalesce(array_length(new.saturation_family_ids,1),0)<2 then raise exception 'DIMINISHING_RETURNS_REQUIRES_TWO_SATURATION_FAMILIES' using errcode='23514'; end if;
    foreach family_id in array coalesce(new.saturation_family_ids,'{}') loop if not exists(select 1 from public.research_source_families f where f.source_family_id=family_id and f.run_id=new.run_id and f.game_id=new.game_id) then raise exception 'SATURATION_FAMILY_NOT_REGISTERED:%',family_id using errcode='23514'; end if; end loop;
    if not (new.dimensions_covered @> array['TOP_1ST','BOTTOM_1ST','STARTER_CURRENT_FORM','TOP_ORDER_MATCHUP','FIRST_INNING_SPECIFIC','COUNTEREVIDENCE']) then raise exception 'PACKET_REQUIRED_DIMENSIONS_MISSING' using errcode='23514'; end if;
    if jsonb_typeof(new.full_game_proxies)<>'array' then raise exception 'FULL_GAME_PROXIES_MUST_BE_ARRAY' using errcode='23514'; end if;
    for proxy in select value from jsonb_array_elements(new.full_game_proxies) loop if length(trim(coalesce(proxy->>'justification','')))<15 then raise exception 'FULL_GAME_PROXY_REQUIRES_FIRST_INNING_JUSTIFICATION' using errcode='23514'; end if; end loop;
    select count(*) into factual_count from public.sports_reasoning_claims c where c.packet_id=new.packet_id and c.claim_type='FACTUAL';
    if factual_count=0 then raise exception 'PACKET_FACTUAL_CLAIMS_REQUIRED' using errcode='23514'; end if;
    select count(*) into bad_claim_count from public.sports_reasoning_claims c where c.packet_id=new.packet_id and c.claim_type='FACTUAL' and coalesce(array_length(c.evidence_ids,1),0)=0;
    if bad_claim_count>0 then raise exception 'PACKET_UNSUPPORTED_FACTUAL_CLAIMS:%',bad_claim_count using errcode='23514'; end if;
    if new.sports_verdict is null then raise exception 'PACKET_SPORTS_VERDICT_REQUIRED' using errcode='23514'; end if;
    if new.what_would_change='{}'::jsonb then raise exception 'PACKET_FALSIFIABLE_CHANGE_CONDITION_REQUIRED' using errcode='23514'; end if;
    if length(trim(coalesce(new.research_depth_justification,'')))<20 then raise exception 'PACKET_RESEARCH_DEPTH_JUSTIFICATION_REQUIRED' using errcode='23514'; end if;
    if new.freeze_timestamp is null then new.freeze_timestamp:=clock_timestamp(); end if;
    if coalesce(new.packet_hash,'')='' then
      new.packet_hash:=public.nrfim_sha256_text((jsonb_build_object('packet_id',new.packet_id,'run_id',new.run_id,'game_id',new.game_id,'version',new.version,'previous_packet_hash',new.previous_packet_hash,'complexity_tier',new.complexity_tier,'sports_verdict',new.sports_verdict,'as_of_kernel',new.as_of_kernel,'evidence_ids',new.evidence_ids,'top_1st_analysis',new.top_1st_analysis,'bottom_1st_analysis',new.bottom_1st_analysis,'central_nrfi_case',new.central_nrfi_case,'best_yrfi_rival',new.best_yrfi_rival,'strongest_counterevidence',new.strongest_counterevidence,'falsification_attempts',new.falsification_attempts,'causal_clusters',new.causal_clusters,'dominant_factor',new.dominant_factor,'governing_uncertainty',new.governing_uncertainty,'what_would_change',new.what_would_change,'why_research_stopped',new.why_research_stopped,'dimensions_covered',new.dimensions_covered,'research_depth_justification',new.research_depth_justification,'known_unknowns',new.known_unknowns,'full_game_proxies',new.full_game_proxies,'packet_payload',new.packet_payload))::text);
    end if;
  end if;
  return new;
end $$;
drop trigger if exists trg_01_sports_reasoning_packet on public.sports_reasoning_packets;
create trigger trg_01_sports_reasoning_packet before insert or update on public.sports_reasoning_packets for each row execute function public.enforce_sports_reasoning_packet();

create or replace function public.enforce_research_drive_artifact()
returns trigger language plpgsql as $$
declare p public.sports_reasoning_packets%rowtype;
begin
  new.verified_at:=clock_timestamp();
  if new.artifact_type='PACKET' then
    if new.packet_id is null then raise exception 'PACKET_DRIVE_ARTIFACT_REQUIRES_PACKET_ID' using errcode='23514'; end if;
    select * into p from public.sports_reasoning_packets where packet_id=new.packet_id;
    if not found or p.run_id<>new.run_id or p.game_id is distinct from new.game_id then raise exception 'PACKET_DRIVE_ARTIFACT_IDENTITY_MISMATCH' using errcode='23514'; end if;
    if coalesce(p.packet_hash,'')='' or new.content_hash<>p.packet_hash then raise exception 'PACKET_DRIVE_HASH_MISMATCH' using errcode='23514'; end if;
    update public.sports_reasoning_packets set drive_file_id=new.drive_file_id,drive_content_hash=new.content_hash,drive_verified_at=new.verified_at,updated_at=clock_timestamp() where packet_id=new.packet_id;
  end if;
  return new;
end $$;
drop trigger if exists trg_01_research_drive_artifact on public.research_drive_artifacts;
create trigger trg_01_research_drive_artifact before insert on public.research_drive_artifacts for each row execute function public.enforce_research_drive_artifact();

create or replace function public.enforce_sports_process_audit()
returns trigger language plpgsql as $$
declare p public.sports_reasoning_packets%rowtype;
begin
  select * into p from public.sports_reasoning_packets where packet_id=new.packet_id;
  if not found then raise exception 'PROCESS_AUDIT_PACKET_NOT_FOUND' using errcode='23514'; end if;
  new.run_id:=p.run_id; new.game_id:=p.game_id; new.created_at:=clock_timestamp();
  if new.status='PASS' then
    if p.status<>'ANALYSIS_COMPLETE' or p.freeze_timestamp is null or p.packet_hash is null then raise exception 'PROCESS_PASS_REQUIRES_FROZEN_COMPLETE_PACKET' using errcode='23514'; end if;
    if p.drive_verified_at is null or p.drive_content_hash is distinct from p.packet_hash then raise exception 'PROCESS_PASS_REQUIRES_DRIVE_HASH_MATCH' using errcode='23514'; end if;
    if not (new.structural_pass and new.temporal_pass and new.evidence_pass and new.falsification_pass and new.independence_pass) then raise exception 'PROCESS_PASS_REQUIRES_ALL_STRUCTURAL_CHECKS' using errcode='23514'; end if;
  end if;
  new.audit_hash:=public.nrfim_sha256_text(concat_ws('|',new.audit_id,new.packet_id,new.auditor_id,new.status,new.structural_pass::text,new.temporal_pass::text,new.evidence_pass::text,new.falsification_pass::text,new.independence_pass::text,new.findings::text));
  update public.sports_reasoning_packets set process_audit_status=new.status,process_audit_id=new.audit_id,updated_at=clock_timestamp() where packet_id=new.packet_id;
  return new;
end $$;
drop trigger if exists trg_01_sports_process_audit on public.sports_process_audits;
create trigger trg_01_sports_process_audit before insert on public.sports_process_audits for each row execute function public.enforce_sports_process_audit();
