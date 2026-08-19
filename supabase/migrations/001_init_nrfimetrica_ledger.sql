-- Canonical ledger schema applied to Supabase project yejaollmavoudbxnbpll.
-- RLS is intentionally enabled with no public policies; server writes require service-role credentials.

create extension if not exists pgcrypto;

create table if not exists public.system_versions (
  id uuid primary key default gen_random_uuid(),
  system_version text not null unique,
  contract_doc_id text,
  kernel_version text,
  model_version text,
  calibration_status text not null default 'NOT_CERTIFIED',
  created_at timestamptz not null default now()
);

create table if not exists public.runs (
  run_id text primary key,
  system_version text not null,
  run_date date not null,
  timezone text not null default 'America/Santo_Domingo',
  status text not null,
  mode text not null default 'CONTROLLED_REAL',
  universe_hash text,
  started_at timestamptz not null default now(),
  closed_at timestamptz,
  tool_call_count integer not null default 0,
  recovery_count integer not null default 0,
  metadata jsonb not null default '{}'::jsonb
);

create table if not exists public.games (
  id uuid primary key default gen_random_uuid(),
  run_id text not null references public.runs(run_id) on delete cascade,
  game_id text not null,
  away_team text,
  home_team text,
  scheduled_start timestamptz,
  cutoff_at timestamptz,
  status text not null,
  decision text,
  governing_uncertainty text,
  central_nrfi_case jsonb,
  best_yrfi_rival jsonb,
  decision_reason jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(run_id, game_id)
);

create table if not exists public.evidence (
  evidence_id text primary key,
  run_id text not null references public.runs(run_id) on delete cascade,
  game_id text,
  tool_name text not null,
  source_ref text,
  source_url text,
  retrieved_at timestamptz not null,
  data_available_at timestamptz,
  input_hash text,
  payload_hash text not null,
  payload jsonb not null,
  created_at timestamptz not null default now()
);

create table if not exists public.trace_events (
  event_id text primary key,
  run_id text not null references public.runs(run_id) on delete cascade,
  game_id text,
  task_id text not null,
  event_type text not null,
  status text not null,
  occurred_at timestamptz not null,
  input_hash text,
  output_hash text,
  tool_name text,
  evidence_ids text[] not null default '{}',
  prev_event_hash text,
  event_hash text not null,
  details jsonb not null default '{}'::jsonb
);

create table if not exists public.recoveries (
  id uuid primary key default gen_random_uuid(),
  run_id text not null references public.runs(run_id) on delete cascade,
  game_id text,
  issue_id text not null,
  task_id text,
  reason text not null,
  attempt integer not null check (attempt = 1),
  outcome text,
  occurred_at timestamptz not null default now(),
  unique(run_id, issue_id)
);

create table if not exists public.decisions (
  id uuid primary key default gen_random_uuid(),
  run_id text not null references public.runs(run_id) on delete cascade,
  game_id text not null,
  decision text not null,
  central_nrfi_case jsonb not null,
  best_yrfi_rival jsonb not null,
  decisive_factor text not null,
  materiality text not null,
  what_would_change text not null,
  numeric_status text not null default 'NOT_EXECUTED',
  raw_p_nrfi numeric,
  model_version text,
  calibration_status text,
  created_at timestamptz not null default now(),
  unique(run_id, game_id)
);

create table if not exists public.audit_events (
  id uuid primary key default gen_random_uuid(),
  run_id text references public.runs(run_id) on delete cascade,
  game_id text,
  severity text not null,
  code text not null,
  message text not null,
  details jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

create index if not exists idx_games_run on public.games(run_id);
create index if not exists idx_evidence_run_game on public.evidence(run_id, game_id);
create index if not exists idx_trace_run_game on public.trace_events(run_id, game_id);
create index if not exists idx_audit_run on public.audit_events(run_id);

alter table public.system_versions enable row level security;
alter table public.runs enable row level security;
alter table public.games enable row level security;
alter table public.evidence enable row level security;
alter table public.trace_events enable row level security;
alter table public.recoveries enable row level security;
alter table public.decisions enable row level security;
alter table public.audit_events enable row level security;
