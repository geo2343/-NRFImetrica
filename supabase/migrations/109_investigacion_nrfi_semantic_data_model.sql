-- @investigacionNRFI semantic historical persistence patch 1.1
-- Applied to project yejaollmavoudbxnbpll as investigacion_nrfi_semantic_data_model.

alter table public.investigacion_nrfi_games
  add column if not exists scheduled_start_at timestamptz,
  add column if not exists actual_first_pitch_at timestamptz,
  add column if not exists first_pitch_verified boolean not null default false,
  add column if not exists venue_id text,
  add column if not exists venue_name text,
  add column if not exists away_starter_id text,
  add column if not exists away_starter_name text,
  add column if not exists home_starter_id text,
  add column if not exists home_starter_name text,
  add column if not exists away_catcher_id text,
  add column if not exists home_catcher_id text,
  add column if not exists final_score_away integer,
  add column if not exists final_score_home integer,
  add column if not exists day_night text,
  add column if not exists roof_state text,
  add column if not exists weather_state jsonb not null default '{}'::jsonb,
  add column if not exists data_era text;

create table if not exists public.investigacion_nrfi_lineup_entries (
  daily_run_id text not null,
  game_pk text not null,
  team_side text not null check (team_side in ('AWAY','HOME')),
  batting_slot integer not null check (batting_slot between 1 and 9),
  player_id text not null,
  player_name text,
  handedness text,
  lineup_version text,
  available_at timestamptz,
  pregame_available boolean,
  coverage_state text not null,
  source_lineage jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  primary key (daily_run_id, game_pk, team_side, batting_slot),
  foreign key (daily_run_id, game_pk) references public.investigacion_nrfi_games(daily_run_id, game_pk) on delete cascade
);

create table if not exists public.investigacion_nrfi_half_innings (
  daily_run_id text not null,
  game_pk text not null,
  inning integer not null default 1 check (inning=1),
  half text not null check (half in ('TOP','BOTTOM')),
  batting_team text,
  pitching_team text,
  pitcher_sequence jsonb not null default '[]'::jsonb check (jsonb_typeof(pitcher_sequence)='array'),
  batter_sequence jsonb not null default '[]'::jsonb check (jsonb_typeof(batter_sequence)='array'),
  bf integer not null check (bf>=3),
  pa integer not null check (pa>=3),
  pitches integer not null check (pitches>=0),
  runs integer not null check (runs>=0),
  hits integer not null default 0 check (hits>=0),
  singles integer not null default 0 check (singles>=0),
  xbh integer not null default 0 check (xbh>=0),
  doubles integer not null default 0 check (doubles>=0),
  triples integer not null default 0 check (triples>=0),
  bb integer not null default 0 check (bb>=0),
  hbp integer not null default 0 check (hbp>=0),
  roe integer not null default 0 check (roe>=0),
  k integer not null default 0 check (k>=0),
  hr integer not null default 0 check (hr>=0),
  b4_exposed boolean not null,
  b5_exposed boolean not null,
  b6_exposed boolean not null,
  leadoff_reach boolean not null,
  run_after_leadoff_reach boolean not null,
  two_out_extension boolean not null,
  runners_before_first_out integer not null default 0 check (runners_before_first_out>=0),
  runners_before_second_out integer not null default 0 check (runners_before_second_out>=0),
  three_up_three_down boolean not null,
  exact_event_sequence jsonb not null check (jsonb_typeof(exact_event_sequence)='array' and jsonb_array_length(exact_event_sequence)>0),
  primary_path text not null,
  contributing_paths text[] not null default '{}',
  mechanism_classifier_version text not null,
  coverage_state text not null,
  source_lineage jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  primary key (daily_run_id, game_pk, inning, half),
  foreign key (daily_run_id, game_pk) references public.investigacion_nrfi_games(daily_run_id, game_pk) on delete cascade
);

create table if not exists public.investigacion_nrfi_plate_appearances (
  daily_run_id text not null,
  game_pk text not null,
  pa_id text not null,
  inning integer not null default 1 check (inning=1),
  half text not null check (half in ('TOP','BOTTOM')),
  batter_id text,
  batter_name text,
  pitcher_id text,
  pitcher_name text,
  batter_slot integer check (batter_slot between 1 and 9),
  pa_ordinal_in_half integer not null check (pa_ordinal_in_half>=1),
  outs_before integer not null check (outs_before between 0 and 2),
  runners_before jsonb not null default '{}'::jsonb,
  pitch_sequence jsonb not null default '[]'::jsonb check (jsonb_typeof(pitch_sequence)='array'),
  pitch_count integer not null default 0 check (pitch_count>=0),
  pa_result text not null,
  reach_type text,
  runs_scored integer not null default 0 check (runs_scored>=0),
  outs_after integer not null check (outs_after between 0 and 3),
  runners_after jsonb not null default '{}'::jsonb,
  exact_pa_transition jsonb not null,
  source_lineage jsonb not null default '[]'::jsonb,
  coverage_state text not null,
  created_at timestamptz not null default now(),
  primary key (daily_run_id, game_pk, pa_id),
  foreign key (daily_run_id, game_pk) references public.investigacion_nrfi_games(daily_run_id, game_pk) on delete cascade
);

create table if not exists public.investigacion_nrfi_pitch_events (
  daily_run_id text not null,
  game_pk text not null,
  pa_id text not null,
  pitch_number integer not null check (pitch_number>=1),
  inning integer not null default 1 check (inning=1),
  half text not null check (half in ('TOP','BOTTOM')),
  pitcher_id text,
  batter_id text,
  batter_slot integer check (batter_slot between 1 and 9),
  balls_before integer check (balls_before between 0 and 3),
  strikes_before integer check (strikes_before between 0 and 2),
  outs_before integer check (outs_before between 0 and 2),
  runners_before jsonb not null default '{}'::jsonb,
  score_before jsonb not null default '{}'::jsonb,
  pitch_type text,
  release_speed numeric,
  pfx_x numeric,
  pfx_z numeric,
  release_position jsonb not null default '{}'::jsonb,
  extension numeric,
  plate_x numeric,
  plate_z numeric,
  sz_top numeric,
  sz_bot numeric,
  description text,
  result text,
  swing_flag boolean,
  whiff_flag boolean,
  contact_flag boolean,
  batted_ball_type text,
  exit_velocity numeric,
  launch_angle numeric,
  expected_metrics jsonb not null default '{}'::jsonb,
  outs_after integer check (outs_after between 0 and 3),
  runners_after jsonb not null default '{}'::jsonb,
  score_after jsonb not null default '{}'::jsonb,
  event_time timestamptz,
  source_ref text not null,
  coverage_state text not null,
  created_at timestamptz not null default now(),
  primary key (daily_run_id, game_pk, pa_id, pitch_number),
  foreign key (daily_run_id, game_pk, pa_id) references public.investigacion_nrfi_plate_appearances(daily_run_id, game_pk, pa_id) on delete cascade
);

create table if not exists public.investigacion_nrfi_first_innings (
  daily_run_id text not null,
  game_pk text not null,
  top_runs integer not null check (top_runs>=0),
  bottom_runs integer not null check (bottom_runs>=0),
  total_runs integer not null check (total_runs>=0),
  p0 boolean not null,
  exactly_1 boolean not null,
  exactly_2 boolean not null,
  three_plus boolean not null,
  nrfi boolean not null,
  yrfi boolean not null,
  top_bf integer not null check (top_bf>=3),
  bottom_bf integer not null check (bottom_bf>=3),
  top_path text not null,
  bottom_path text not null,
  first_inning_exact_sequence jsonb not null check (jsonb_typeof(first_inning_exact_sequence)='array' and jsonb_array_length(first_inning_exact_sequence)>0),
  reconstruction_check text not null,
  coverage_gaps jsonb not null default '[]'::jsonb,
  coverage_state text not null,
  source_lineage jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  primary key (daily_run_id, game_pk),
  foreign key (daily_run_id, game_pk) references public.investigacion_nrfi_games(daily_run_id, game_pk) on delete cascade,
  check (total_runs=top_runs+bottom_runs),
  check (p0=(total_runs=0)),
  check (exactly_1=(total_runs=1)),
  check (exactly_2=(total_runs=2)),
  check (three_plus=(total_runs>=3)),
  check (nrfi=(total_runs=0)),
  check (yrfi=(total_runs>0))
);

create table if not exists public.investigacion_nrfi_starter_contexts (
  daily_run_id text not null,
  game_pk text not null,
  pitcher_id text not null,
  pitcher_name text,
  pitching_half text not null check (pitching_half in ('TOP','BOTTOM')),
  first_inning jsonb not null,
  first_tto jsonb not null,
  start_complete jsonb not null,
  season_to_date_as_of_game jsonb not null,
  career_available_as_of_game jsonb not null,
  days_since_previous_start integer,
  prior_start_workload jsonb not null default '{}'::jsonb,
  rest_context jsonb not null default '{}'::jsonb,
  catcher_id text,
  coverage_state text not null,
  source_lineage jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  primary key (daily_run_id, game_pk, pitcher_id),
  foreign key (daily_run_id, game_pk) references public.investigacion_nrfi_games(daily_run_id, game_pk) on delete cascade
);

create table if not exists public.investigacion_nrfi_feature_values (
  feature_value_id text primary key,
  daily_run_id text not null references public.investigacion_nrfi_runs(daily_run_id) on delete cascade,
  game_pk text,
  entity_level text not null,
  entity_id text not null,
  feature_id text not null,
  feature_name text not null,
  feature_family text not null check (feature_family in ('RESULTS','SEQUENCE','EXPOSURE','OUT_CREATION','TRAFFIC','DAMAGE','PITCHER_PROCESS','TOP_ORDER','CONTEXT')),
  source_fields jsonb not null default '[]'::jsonb,
  formula_or_transformation text,
  definition_version text not null,
  feature_window text not null,
  split text not null default 'ALL',
  as_of_query timestamptz not null,
  n integer not null check (n>=0),
  numerator numeric,
  denominator numeric,
  raw_value jsonb not null,
  mean numeric,
  median numeric,
  variance numeric,
  distribution jsonb not null default '{}'::jsonb,
  percentiles jsonb not null default '{}'::jsonb,
  regressed_value jsonb,
  uncertainty jsonb not null default '{}'::jsonb,
  effective_sample numeric,
  reliability_state text not null,
  data_coverage_state text not null,
  source_lineage jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  foreign key (daily_run_id, game_pk) references public.investigacion_nrfi_games(daily_run_id, game_pk) on delete cascade
);
create index if not exists investigacion_nrfi_feature_values_run_game_family_idx on public.investigacion_nrfi_feature_values(daily_run_id,game_pk,feature_family);
create index if not exists investigacion_nrfi_feature_values_entity_window_idx on public.investigacion_nrfi_feature_values(entity_level,entity_id,feature_window,as_of_query);

create table if not exists public.investigacion_nrfi_human_claims (
  claim_id text primary key,
  daily_run_id text not null references public.investigacion_nrfi_runs(daily_run_id) on delete cascade,
  game_pk text,
  entity_type text not null,
  entity_id text,
  claim_type text not null,
  text_raw text,
  faithful_summary text not null,
  source text not null,
  author text,
  published_at timestamptz,
  available_at timestamptz,
  fetched_at timestamptz not null,
  first_pitch_at timestamptz,
  pregame_available boolean not null,
  confidence_state text not null,
  corroboration_count integer not null default 0 check (corroboration_count>=0),
  corroboration_refs jsonb not null default '[]'::jsonb,
  contradiction_state text not null,
  evidence_id text references public.investigacion_nrfi_evidence(evidence_id) on delete set null,
  created_at timestamptz not null default now(),
  foreign key (daily_run_id, game_pk) references public.investigacion_nrfi_games(daily_run_id,game_pk) on delete cascade,
  check ((pregame_available=false) or (available_at is not null and first_pitch_at is not null and available_at<first_pitch_at))
);

create table if not exists public.investigacion_nrfi_cohorts (
  cohort_id text primary key,
  daily_run_id text not null references public.investigacion_nrfi_runs(daily_run_id) on delete cascade,
  game_pk text,
  query_as_of timestamptz not null,
  inclusion_rules jsonb not null,
  exclusion_rules jsonb not null,
  feature_space jsonb not null,
  era_compatibility text not null,
  n_games integer not null check (n_games>=0),
  n_half_innings integer not null check (n_half_innings>=0),
  entity_set jsonb not null,
  outcome_distribution jsonb not null,
  process_distribution jsonb not null,
  sensitivity_checks jsonb not null,
  limitations jsonb not null,
  created_at timestamptz not null default now(),
  foreign key (daily_run_id, game_pk) references public.investigacion_nrfi_games(daily_run_id,game_pk) on delete cascade
);

create table if not exists public.investigacion_nrfi_component_coverage (
  daily_run_id text not null,
  game_pk text not null,
  component text not null,
  status text not null check (status in ('COMPLETE','BOUNDED_GAP','NOT_APPLICABLE')),
  source_families_attempted text[] not null default '{}',
  tool_event_ids text[] not null default '{}',
  evidence_ids text[] not null default '{}',
  notes text,
  created_at timestamptz not null default now(),
  primary key (daily_run_id,game_pk,component),
  foreign key (daily_run_id,game_pk) references public.investigacion_nrfi_games(daily_run_id,game_pk) on delete cascade,
  check ((status<>'BOUNDED_GAP') or (cardinality(tool_event_ids)>0 and cardinality(source_families_attempted)>0 and nullif(notes,'') is not null))
);

create table if not exists public.investigacion_nrfi_evidence_packets (
  packet_id text primary key,
  daily_run_id text not null unique references public.investigacion_nrfi_runs(daily_run_id) on delete cascade,
  query_as_of timestamptz not null,
  packet_payload jsonb not null,
  data_coverage jsonb not null,
  source_lineage jsonb not null,
  future_game_count integer not null default 0 check (future_game_count=0),
  postgame_leak_count integer not null default 0 check (postgame_leak_count=0),
  created_at timestamptz not null default now()
);

alter table public.investigacion_nrfi_drive_appends
  add column if not exists game_block_count integer not null default 0,
  add column if not exists phase_section_count integer not null default 0,
  add column if not exists daily_block_character_count integer not null default 0,
  add column if not exists required_section_markers jsonb not null default '{}'::jsonb,
  add column if not exists report_contract_verified boolean not null default false;

alter table public.investigacion_nrfi_audits
  add column if not exists semantic_completeness_pass boolean not null default false,
  add column if not exists f1_semantic_pass boolean not null default false,
  add column if not exists f2_semantic_pass boolean not null default false,
  add column if not exists f3_semantic_pass boolean not null default false,
  add column if not exists f4_semantic_pass boolean not null default false,
  add column if not exists f5_semantic_pass boolean not null default false,
  add column if not exists report_contract_pass boolean not null default false,
  add column if not exists semantic_details jsonb not null default '{}'::jsonb;

alter table public.investigacion_nrfi_lineup_entries enable row level security;
alter table public.investigacion_nrfi_half_innings enable row level security;
alter table public.investigacion_nrfi_plate_appearances enable row level security;
alter table public.investigacion_nrfi_pitch_events enable row level security;
alter table public.investigacion_nrfi_first_innings enable row level security;
alter table public.investigacion_nrfi_starter_contexts enable row level security;
alter table public.investigacion_nrfi_feature_values enable row level security;
alter table public.investigacion_nrfi_human_claims enable row level security;
alter table public.investigacion_nrfi_cohorts enable row level security;
alter table public.investigacion_nrfi_component_coverage enable row level security;
alter table public.investigacion_nrfi_evidence_packets enable row level security;

revoke all on table public.investigacion_nrfi_lineup_entries,public.investigacion_nrfi_half_innings,public.investigacion_nrfi_plate_appearances,public.investigacion_nrfi_pitch_events,public.investigacion_nrfi_first_innings,public.investigacion_nrfi_starter_contexts,public.investigacion_nrfi_feature_values,public.investigacion_nrfi_human_claims,public.investigacion_nrfi_cohorts,public.investigacion_nrfi_component_coverage,public.investigacion_nrfi_evidence_packets from anon,authenticated;
grant select,insert,update,delete on table public.investigacion_nrfi_lineup_entries,public.investigacion_nrfi_half_innings,public.investigacion_nrfi_plate_appearances,public.investigacion_nrfi_pitch_events,public.investigacion_nrfi_first_innings,public.investigacion_nrfi_starter_contexts,public.investigacion_nrfi_feature_values,public.investigacion_nrfi_human_claims,public.investigacion_nrfi_cohorts,public.investigacion_nrfi_component_coverage,public.investigacion_nrfi_evidence_packets to service_role;
