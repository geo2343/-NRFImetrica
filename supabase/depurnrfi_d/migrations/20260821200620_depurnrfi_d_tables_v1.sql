create extension if not exists pgcrypto;

create table if not exists public.depurnrfi_d_agent_registry (
  agent_id text primary key,
  display_name text not null,
  agent_version text not null,
  kernel_version text not null,
  protocol_id text not null,
  status text not null check (status in ('ACTIVE','DISABLED','SUPERSEDED')),
  scope text not null,
  source_doc_id text not null,
  source_sha256 text not null,
  source_lines integer not null,
  source_requirement_count integer not null,
  drive_root_folder_id text not null,
  sports_decision_authority boolean not null default true,
  betting_authority boolean not null default false,
  publication_authority boolean not null default false,
  manual_dialogue_authorization boolean not null default true,
  auto_chain_dialogue boolean not null default false,
  d_closes_first boolean not null default true,
  a_closes_system boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default clock_timestamp()
);

create table if not exists public.depurnrfi_d_phase_catalog (
  phase_code text primary key,
  order_index integer not null unique,
  expected_requirement_count integer not null check (expected_requirement_count>=0),
  source_owned boolean not null default true
);

create table if not exists public.depurnrfi_d_requirement_catalog (
  requirement_id text primary key,
  phase_code text not null references public.depurnrfi_d_phase_catalog(phase_code),
  source_code text not null,
  title text not null,
  source_start_line integer not null,
  source_end_line integer not null,
  binding boolean not null default true
);
create index if not exists depurnrfi_d_req_phase_idx on public.depurnrfi_d_requirement_catalog(phase_code);

create table if not exists public.depurnrfi_d_runs (
  run_id text primary key,
  agent_id text not null default '@AnalistaDepuracionRNFI_D' check (agent_id='@AnalistaDepuracionRNFI_D'),
  slate_date date not null,
  input_manifest jsonb not null,
  source_sha256 text not null,
  status text not null check (status in ('RUN_ACTIVE','WAITING_USER_AUTHORIZATION','DIALOGUE_ACTIVE','D_DIALOGUE_PARTICIPATION_COMPLETE','RUN_BLOCKED','RUN_ABORTED')),
  phase_cursor text not null,
  state_version integer not null default 1,
  pre_dialogue_frozen boolean not null default false,
  report_id uuid,
  started_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  completed_at timestamptz
);

create table if not exists public.depurnrfi_d_requirement_state (
  run_id text not null references public.depurnrfi_d_runs(run_id) on delete cascade,
  requirement_id text not null references public.depurnrfi_d_requirement_catalog(requirement_id),
  phase_code text not null,
  state text not null check (state in ('NOT_EXECUTED','SATISFIED')),
  evaluated_at timestamptz,
  primary key(run_id,requirement_id)
);
create index if not exists depurnrfi_d_reqstate_phase_idx on public.depurnrfi_d_requirement_state(run_id,phase_code,state);

create table if not exists public.depurnrfi_d_phase_receipts (
  receipt_id uuid primary key default gen_random_uuid(),
  run_id text not null references public.depurnrfi_d_runs(run_id) on delete cascade,
  phase_code text not null,
  order_index integer not null,
  status text not null check (status='COMMITTED'),
  requirements_evaluated integer not null,
  output jsonb not null,
  output_hash text not null,
  committed_at timestamptz not null default clock_timestamp(),
  unique(run_id,phase_code)
);

create table if not exists public.depurnrfi_d_artifacts (
  artifact_id text primary key,
  run_id text not null references public.depurnrfi_d_runs(run_id) on delete cascade,
  artifact_type text not null,
  drive_file_id text,
  content_hash text not null,
  readback_verified boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default clock_timestamp()
);

create table if not exists public.depurnrfi_d_pre_dialogue_reports (
  report_id uuid primary key default gen_random_uuid(),
  run_id text not null unique references public.depurnrfi_d_runs(run_id) on delete cascade,
  artifact_id text,
  report_type text not null check (report_type='FINAL_DEPURATION_REPORT_D'),
  candidate_count integer not null check(candidate_count between 0 and 4),
  report_sections jsonb not null,
  chat_payload text not null,
  report_hash text not null,
  frozen boolean not null default true check(frozen=true),
  created_at timestamptz not null default clock_timestamp()
);

create table if not exists public.depurnrfi_d_dialogue_turns (
  turn_id uuid primary key default gen_random_uuid(),
  run_id text not null references public.depurnrfi_d_runs(run_id) on delete cascade,
  turn_number integer not null,
  authorization_id uuid not null unique,
  inbound_actor text not null check(inbound_actor in ('ANALISTA_DEPURACION_NRFI_A','USER_TRANSPORTED_A_MESSAGE','USER')),
  inbound_text text not null,
  outbound_text text not null,
  topics jsonb not null default '[]'::jsonb,
  evidence_refs jsonb not null default '[]'::jsonb,
  inbound_hash text not null,
  outbound_hash text not null,
  created_at timestamptz not null default clock_timestamp(),
  unique(run_id,turn_number)
);

create table if not exists public.depurnrfi_d_dialogue_closings (
  closing_id uuid primary key default gen_random_uuid(),
  run_id text not null unique references public.depurnrfi_d_runs(run_id) on delete cascade,
  authorization_id uuid not null unique,
  artifact_id text,
  closing_payload jsonb not null,
  closing_hash text not null,
  created_at timestamptz not null default clock_timestamp()
);

create table if not exists public.depurnrfi_d_events (
  event_id uuid primary key default gen_random_uuid(),
  run_id text not null,
  phase_code text,
  event_type text not null,
  state_version integer not null,
  payload jsonb not null default '{}'::jsonb,
  payload_hash text not null,
  created_at timestamptz not null default clock_timestamp()
);
create index if not exists depurnrfi_d_events_run_idx on public.depurnrfi_d_events(run_id,created_at);

create table if not exists public.depurnrfi_d_kernel_test_results (
  test_id text primary key,
  test_name text not null,
  expected text not null,
  observed text not null,
  passed boolean not null,
  details jsonb not null default '{}'::jsonb,
  tested_at timestamptz not null default clock_timestamp()
);

insert into public.depurnrfi_d_phase_catalog(phase_code,order_index,expected_requirement_count,source_owned) values
('F1',1,27,true),('F2',2,69,true),('F3',3,80,true),('F4',4,124,true),('F5',5,145,true),('F6',6,144,true),('F7',7,152,true),('F8',8,85,true),('F9',9,93,true),('D1',10,19,true),('D2',11,20,true),('F10',12,54,true),('F11',13,45,true),('REPORT_D',14,0,false)
on conflict(phase_code) do update set order_index=excluded.order_index,expected_requirement_count=excluded.expected_requirement_count,source_owned=excluded.source_owned;

insert into public.depurnrfi_d_agent_registry(agent_id,display_name,agent_version,kernel_version,protocol_id,status,scope,source_doc_id,source_sha256,source_lines,source_requirement_count,drive_root_folder_id,sports_decision_authority,betting_authority,publication_authority,manual_dialogue_authorization,auto_chain_dialogue,d_closes_first,a_closes_system,metadata)
values('@AnalistaDepuracionRNFI_D','AnalistaDepuracionRNFI. D','ANALISTADEPURACIONRNFI-D-AGENT-1.0','ANALISTADEPURACIONRNFI-D-KERNEL-1.0','ANALISTADEPURACIONRNFI_D_MLB_V1','ACTIVE','FULL_MLB_SLATE_DEPURATION','1ZsPlc2tOSzRH4_XQB0IpzwLGTQxeGASsjy8Cbzy3HLM','121f80c4569de1f87c438f96fbd48364a1756afee17a38f3f1f33698a67caea9',18569,1057,'1WItLWad07tx1QyODDu-nq_XLmAqRWLH4',true,false,false,true,false,true,true,jsonb_build_object('execution_mode','AUTO_CONTINUOUS_UNTIL_FINAL_DEPURATION_REPORT_D','post_report_state','STOP_WAITING_USER_AUTHORIZATION','dialogue_transport','USER_MANUAL_CHAT_TRANSPORT','dialogue_round_cap',null,'source_immutable',true))
on conflict(agent_id) do update set display_name=excluded.display_name,agent_version=excluded.agent_version,kernel_version=excluded.kernel_version,protocol_id=excluded.protocol_id,status='ACTIVE',scope=excluded.scope,source_doc_id=excluded.source_doc_id,source_sha256=excluded.source_sha256,source_lines=excluded.source_lines,source_requirement_count=excluded.source_requirement_count,drive_root_folder_id=excluded.drive_root_folder_id,manual_dialogue_authorization=true,auto_chain_dialogue=false,d_closes_first=true,a_closes_system=true,metadata=excluded.metadata,updated_at=clock_timestamp();

alter table public.kendel_user_authorizations drop constraint if exists kendel_user_authorizations_canonical_agent_id_check;
alter table public.kendel_user_authorizations add constraint kendel_user_authorizations_canonical_agent_id_check check (canonical_agent_id = any(array['@AnalistaNRFI_A'::text,'@AnalistaNRFI_D'::text,'@AnalistaDepuracionRNFI_D'::text]));
alter table public.kendel_user_authorizations drop constraint if exists kendel_user_authorizations_stage_check;
alter table public.kendel_user_authorizations add constraint kendel_user_authorizations_stage_check check (stage = any(array['COUNTERPART_REPORT_RECEIVE'::text,'DISCREPANCY_PACKET_RECEIVE'::text,'ANSWER_RECEIVE'::text,'FINAL_REPLY_RECEIVE'::text,'RESEARCH_REQUEST'::text,'RESEARCH_RESPONSE_RECEIVE'::text,'MARKET_SYNC'::text,'D_CLOSING'::text,'A_POST_DIALOGUE_SPORTS'::text,'A_POST_DIALOGUE_BETTING'::text,'A_FINALIZATION'::text,'DEPURATION_D_DIALOGUE_TURN'::text,'DEPURATION_D_CLOSING'::text]));

alter table public.depurnrfi_d_runs enable row level security;
alter table public.depurnrfi_d_requirement_state enable row level security;
alter table public.depurnrfi_d_phase_receipts enable row level security;
alter table public.depurnrfi_d_artifacts enable row level security;
alter table public.depurnrfi_d_pre_dialogue_reports enable row level security;
alter table public.depurnrfi_d_dialogue_turns enable row level security;
alter table public.depurnrfi_d_dialogue_closings enable row level security;
alter table public.depurnrfi_d_events enable row level security;
