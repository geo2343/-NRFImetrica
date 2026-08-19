-- Applied physically to Supabase project yejaollmavoudbxnbpll.
-- @NRFiPrensa V0.2 base persistent state. RESEARCH ONLY / TRADING HALT.

create table if not exists public.nrfiprensa_authority (
  protocol_id text primary key, agent_id text not null, agent_version text not null,
  kernel_version text not null, document_sha256 text not null check (document_sha256 ~ '^[0-9a-f]{64}$'),
  document_lines integer not null, system_state text not null check (system_state='RESEARCH_ONLY_TRADING_HALT'),
  real_money_authority boolean not null default false check (real_money_authority=false),
  max_transfer_candidates integer not null default 3 check (max_transfer_candidates=3),
  execution_firewall boolean not null default true check (execution_firewall=true), updated_at timestamptz not null default now());

insert into public.nrfiprensa_authority(protocol_id,agent_id,agent_version,kernel_version,document_sha256,document_lines,system_state,real_money_authority,max_transfer_candidates,execution_firewall)
values ('SO_MEDIA_NRFI_V02','@NRFiPrensa','V0.2-AGENT-1.0','NRFIPRENSA-KERNEL-0.1-RESEARCH-CUSTODY','a6ed0be85ea66750dbea7e3deafe717675433a78d141f0656688421e15dacbac',1248,'RESEARCH_ONLY_TRADING_HALT',false,3,true)
on conflict (protocol_id) do update set agent_id=excluded.agent_id,agent_version=excluded.agent_version,kernel_version=excluded.kernel_version,document_sha256=excluded.document_sha256,document_lines=excluded.document_lines,system_state=excluded.system_state,real_money_authority=false,max_transfer_candidates=3,execution_firewall=true,updated_at=now();

create table if not exists public.nrfiprensa_runs (
 run_id text primary key, invocation_id text not null unique, protocol_id text not null references public.nrfiprensa_authority(protocol_id), slate_date date not null,
 timezone text not null default 'America/Santo_Domingo', status text not null default 'OPEN' check (status in ('OPEN','RESEARCHING','HANDOFF_READY','CLOSED','ABORTED')),
 clean_room boolean not null default true check (clean_room=true), prior_run_analysis_allowed boolean not null default false check (prior_run_analysis_allowed=false), created_at timestamptz not null default now(), closed_at timestamptz, metadata jsonb not null default '{}'::jsonb);

create table if not exists public.nrfiprensa_report_documents (
 run_id text primary key references public.nrfiprensa_runs(run_id) on delete cascade, drive_file_id text not null unique, drive_url text not null, title text not null,
 status text not null default 'CREATED' check (status in ('CREATED','ACTIVE','FINAL_VERIFIED')), content_hash text, created_at timestamptz not null default now(), verified_at timestamptz);

create table if not exists public.nrfiprensa_games (
 run_id text not null references public.nrfiprensa_runs(run_id) on delete cascade, game_id text not null, away_team text not null, home_team text not null, scheduled_start timestamptz not null,
 pregame_state text not null default 'PREGAME' check (pregame_state in ('PREGAME','OUT_PREGAME','POSTPONED','CANCELLED')),
 away_first_inning_pitcher text, away_pitcher_status text check (away_pitcher_status in ('CONFIRMED','PROBABLE','OPENER','PENDING') or away_pitcher_status is null),
 home_first_inning_pitcher text, home_pitcher_status text check (home_pitcher_status in ('CONFIRMED','PROBABLE','OPENER','PENDING') or home_pitcher_status is null),
 park text, roof_weather_material jsonb not null default '{}'::jsonb, as_of timestamptz not null default now(), primary key(run_id,game_id));

create table if not exists public.nrfiprensa_source_families (
 source_family_id text primary key, run_id text not null references public.nrfiprensa_runs(run_id) on delete cascade, canonical_origin text not null, publisher text,
 lane text not null check (lane in ('A_FACTUAL','B_ANALYST','SOCIAL_TIP','TECHNICAL_DATA')), created_at timestamptz not null default now(), unique(run_id,canonical_origin));

create table if not exists public.nrfiprensa_evidence (
 evidence_id text primary key, run_id text not null, game_id text not null, source_family_id text not null references public.nrfiprensa_source_families(source_family_id),
 lane text not null check (lane in ('A_FACTUAL','B_ANALYST','SOCIAL_TIP','TECHNICAL_DATA')),
 evidence_type text not null check (evidence_type in ('FACT','DECLARATION','RECONSTRUCTION','ANALYSIS','RUMOR','METRIC','LINEUP','STATUS','WEATHER','VIDEO','SOCIAL_POST')),
 source_url text not null, source_author text, source_title text, published_at timestamptz, retrieved_at timestamptz not null default now(), as_of timestamptz not null default now(),
 data_status text not null check (data_status in ('CONFIRMADO','CORROBORADO','PENDIENTE','NO_RESUELTO','NO_APLICA')),
 fact_confidence text check (fact_confidence in ('K3','K2','K1','K0') or fact_confidence is null), materiality text check (materiality in ('M3','M2','M1','M0') or materiality is null),
 content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'), snapshot_drive_file_id text, payload jsonb not null default '{}'::jsonb,
 foreign key(run_id,game_id) references public.nrfiprensa_games(run_id,game_id) on delete cascade);

create table if not exists public.nrfiprensa_phase_state (
 id bigserial primary key, run_id text not null, game_id text not null, phase_id text not null check (phase_id in ('F0','F1','F2','F3','F4','F5','F6','F7','F8','F9','F10')),
 status text not null, payload jsonb not null default '{}'::jsonb, evidence_ids text[] not null default '{}', frozen boolean not null default false, submitted_at timestamptz not null default now(),
 unique(run_id,game_id,phase_id), foreign key(run_id,game_id) references public.nrfiprensa_games(run_id,game_id) on delete cascade);

create table if not exists public.nrfiprensa_f7q (
 run_id text not null, game_id text not null, half text not null check (half in ('TOP','BOTTOM')), lineup_version_id text not null, official_b1_b5 boolean not null default false,
 q1 text not null check (q1 in ('PASS','PROVISIONAL','FAIL')), q2 text not null check (q2 in ('PASS','PROVISIONAL','FAIL')), q3 text not null check (q3 in ('PASS','PROVISIONAL','FAIL')),
 q4 text not null check (q4 in ('PASS','PROVISIONAL','FAIL')), q5 text not null check (q5 in ('PASS','PROVISIONAL','FAIL')), q6 text not null check (q6 in ('PASS','PROVISIONAL','FAIL')),
 q7 text not null check (q7 in ('PASS','PROVISIONAL','FAIL')), q8 text not null check (q8 in ('PASS','PROVISIONAL','FAIL')), q9 text not null check (q9 in ('PASS','PROVISIONAL','FAIL')),
 q10 text not null check (q10 in ('PASS','PROVISIONAL','FAIL')), q11 text not null check (q11 in ('PASS','PROVISIONAL','FAIL')), q12 text not null check (q12 in ('PASS','PROVISIONAL','FAIL')),
 osr_status text not null check (osr_status in ('NO_MATERIAL_SIGNAL','MATERIAL','GOVERNING','UNCERTAIN')), run_paths jsonb not null,
 current_roster_bvp_label text not null default 'ROSTER_BVP_SECONDARY', metrics_payload jsonb not null, as_of timestamptz not null default now(),
 primary key(run_id,game_id,half), foreign key(run_id,game_id) references public.nrfiprensa_games(run_id,game_id) on delete cascade);

create table if not exists public.nrfiprensa_red_team (
 run_id text not null, game_id text not null, status text not null check (status in ('RED_TEAM_CLEAR','RED_TEAM_MATERIAL','RED_TEAM_REOPEN','RED_TEAM_BLOCK')), yrfi_routes jsonb not null,
 fragile_half text not null check (fragile_half in ('TOP','BOTTOM','NONE')), omitted_risk jsonb not null default '{}'::jsonb, falsifier text not null, independent_reader_id text not null,
 as_of timestamptz not null default now(), primary key(run_id,game_id), foreign key(run_id,game_id) references public.nrfiprensa_games(run_id,game_id) on delete cascade);

create table if not exists public.nrfiprensa_final_seals (
 run_id text not null, game_id text not null, status text not null check (status in ('PASS','HOLD','FAIL','OUT_PREGAME')), away_starter_current boolean not null default false,
 home_starter_current boolean not null default false, official_lineups_match boolean not null default false, catcher_material_resolved boolean not null default true,
 scratches_revalidated boolean not null default false, restrictions_revalidated boolean not null default false, roof_weather_revalidated boolean not null default true,
 as_of_final timestamptz not null default now(), seal_hash text not null check (seal_hash ~ '^[0-9a-f]{64}$'), primary key(run_id,game_id),
 foreign key(run_id,game_id) references public.nrfiprensa_games(run_id,game_id) on delete cascade);

create table if not exists public.nrfiprensa_handoffs (
 handoff_id text primary key, run_id text not null, game_id text not null,
 disposition text not null check (disposition in ('REVIEW_PRIORITY_1','REVIEW_PRIORITY_2','REVIEW_PRIORITY_3','HOLD_DYNAMIC','DO_NOT_RECOMMEND','OUT_PREGAME')),
 transfer_state text not null check (transfer_state in ('TRANSFER_HIGH','TRANSFER_MATERIAL','TRANSFER_CONTEXT','NO_NEW_DELTA','REOPEN_REQUIRED','UNRESOLVED_PREGAME','OUT_PREGAME','READY_FOR_IA_REVIEW')),
 pack_a jsonb not null default '{}'::jsonb, pack_i jsonb not null default '{}'::jsonb, as_of timestamptz not null default now(), content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'),
 unique(run_id,game_id), foreign key(run_id,game_id) references public.nrfiprensa_games(run_id,game_id) on delete cascade);

create table if not exists public.nrfiprensa_drive_artifacts (
 artifact_id text primary key, run_id text not null references public.nrfiprensa_runs(run_id) on delete cascade, game_id text,
 artifact_type text not null check (artifact_type in ('REPORT','PACKET','SNAPSHOT','HANDOFF','AUDIT')), drive_file_id text not null, drive_url text not null,
 content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'), verified boolean not null default false, created_at timestamptz not null default now(), unique(run_id,drive_file_id));

create table if not exists public.nrfiprensa_recoveries (
 run_id text not null references public.nrfiprensa_runs(run_id) on delete cascade, issue_id text not null, action_taken text not null, created_at timestamptz not null default now(), primary key(run_id,issue_id));

create table if not exists public.nrfiprensa_postresult_audits (
 audit_id text primary key, run_id text not null references public.nrfiprensa_runs(run_id) on delete cascade, source_family_id text references public.nrfiprensa_source_families(source_family_id),
 analyst_or_source text not null, classification text not null check (classification in ('FACTUAL_RELIABLE','FACTUAL_USEFUL_BUT_LIMITED','FACTUAL_ERROR','ANALYST_CAUSAL_VALUE','ANALYST_DESCRIPTIVE_ONLY','ANALYST_CONTAMINATED','ANALYST_MISSED_MECHANISM','UNRESOLVED')),
 process_notes text not null, outcome_used_as_process_proof boolean not null default false check (outcome_used_as_process_proof=false), created_at timestamptz not null default now());

create index if not exists idx_nrfiprensa_evidence_run_game on public.nrfiprensa_evidence(run_id,game_id);
create index if not exists idx_nrfiprensa_phase_run_game on public.nrfiprensa_phase_state(run_id,game_id,phase_id);
create index if not exists idx_nrfiprensa_handoffs_run on public.nrfiprensa_handoffs(run_id,disposition);
