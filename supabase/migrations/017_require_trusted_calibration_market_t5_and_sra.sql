-- Physical artifact registries required by the @NRFImetrica mother document.
-- The enforcement function is installed by migration 018.

create table if not exists public.calibration_certifications (
  certification_id text primary key,
  model_version text not null,
  engine_mode text not null,
  model_tier text not null,
  target_id text not null check (target_id in ('U0.5','U1.5','U2.5')),
  calibrator_version text not null,
  status text not null check (status in ('CERTIFIED','CERTIFIED_CONDITIONED','DIAGNOSTIC_CERTIFIED','NOT_CERTIFIED','REVOKED')),
  region_support text not null,
  oos_validation_status text not null,
  provenance_status text not null,
  code_hash text not null,
  metrics jsonb not null default '{}'::jsonb,
  certified_at timestamptz not null,
  active boolean not null default false
);
alter table public.calibration_certifications enable row level security;

create table if not exists public.market_offers (
  offer_id text primary key,
  run_id text not null references public.runs(run_id) on delete cascade,
  game_id text not null,
  sportsbook text not null,
  line_exact text not null,
  price_exact text not null,
  decimal_odds numeric not null check (decimal_odds>1),
  retrieved_at timestamptz not null,
  source_ref text not null,
  evidence_id text not null references public.evidence(evidence_id),
  status text not null check (status in ('VERIFIED','DIAGNOSTIC_VERIFIED','REJECTED')),
  foreign key(run_id,game_id) references public.games(run_id,game_id) on delete cascade
);
alter table public.market_offers enable row level security;

create table if not exists public.t5_revalidations (
  revalidation_id text primary key,
  run_id text not null references public.runs(run_id) on delete cascade,
  game_id text not null,
  offer_id text not null references public.market_offers(offer_id),
  active_freeze_id text not null,
  as_of timestamptz not null,
  starter_confirmed boolean not null,
  official_lineup_verified boolean not null,
  catcher_confirmed boolean not null,
  scratches_status text not null,
  roof_weather_critical_context text not null,
  contract_identity text not null,
  line_exact text not null,
  price_exact text not null,
  break_even numeric not null check (break_even>=0 and break_even<=1),
  primary_risk text not null,
  material_change boolean not null default false,
  evidence_ids text[] not null default '{}',
  status text not null check (status in ('VERIFIED','DIAGNOSTIC_VERIFIED','INVALID')),
  foreign key(run_id,game_id) references public.games(run_id,game_id) on delete cascade
);
alter table public.t5_revalidations enable row level security;

create table if not exists public.sra_packets (
  packet_id text primary key,
  run_id text not null references public.runs(run_id) on delete cascade,
  game_id text not null,
  generated_at timestamptz not null,
  content_hash text not null,
  status text not null check (status in ('COMPLETE','DATA_UNAVAILABLE','DIAGNOSTIC_COMPLETE','REJECTED')),
  team_packet jsonb not null default '{}'::jsonb,
  b1_b4_packet jsonb not null default '{}'::jsonb,
  evidence_ids text[] not null default '{}',
  payload jsonb not null default '{}'::jsonb,
  foreign key(run_id,game_id) references public.games(run_id,game_id) on delete cascade
);
alter table public.sra_packets enable row level security;

-- Hashes are derived from the persisted JSONB artifact itself. This blocks an
-- LLM from citing a real execution/packet ID and then altering its output.
update public.numeric_engine_executions
set output_hash=encode(digest(output_payload::text,'sha256'),'hex');

update public.independent_audit_executions
set payload=jsonb_build_object(
      'central_case',s.payload #>> '{independent_audit,central_case}',
      'best_yrfi_rival',s.payload #>> '{independent_audit,best_yrfi_rival}',
      'divergence_class',s.payload #>> '{independent_audit,divergence_class}',
      'status',s.payload #>> '{independent_audit,status}'
    )
from public.protocol_phase_state s
where s.run_id=public.independent_audit_executions.run_id
  and s.game_id=public.independent_audit_executions.game_id
  and s.protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS'
  and s.phase_id='A6_CAUSAL_FALSIFICATION_SPORTS_SEAL';
update public.independent_audit_executions
set output_hash=encode(digest(payload::text,'sha256'),'hex');

update public.nrfiprensa_packets n
set payload=jsonb_build_object(
      'coincidences',s.payload #> '{nrfi_prensa,coincidences}',
      'discrepancies',s.payload #> '{nrfi_prensa,discrepancies}',
      'new_data',s.payload #> '{nrfi_prensa,new_data}',
      'unverified_data',s.payload #> '{nrfi_prensa,unverified_data}',
      'omitted_risks',s.payload #> '{nrfi_prensa,omitted_risks}',
      'questions',s.payload #> '{nrfi_prensa,questions}',
      'responses',s.payload #> '{nrfi_prensa,responses}'
    )
from public.protocol_phase_state s
where s.run_id=n.run_id and s.game_id=n.game_id
  and s.protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS'
  and s.phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS';
update public.nrfiprensa_packets set content_hash=encode(digest(payload::text,'sha256'),'hex');
update public.protocol_phase_state s
set payload=jsonb_set(s.payload,'{nrfi_prensa,packet_hash}',to_jsonb(n.content_hash))
from public.nrfiprensa_packets n
where s.run_id=n.run_id and s.game_id=n.game_id
  and s.protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS'
  and s.phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS';

-- Diagnostic SRA fixture only. It never grants CONTROLLED_REAL authority.
insert into public.sra_packets(packet_id,run_id,game_id,generated_at,content_hash,status,team_packet,b1_b4_packet,evidence_ids,payload)
select 'SRA-DIAG-1','DIAG-MOTHER-V3-20260819-K04','DIAG-MOTHER-GAME-1','2026-08-19T11:28:00Z','TEMP','DIAGNOSTIC_COMPLETE',
       '{"status":"COMPLETE"}'::jsonb,'{"status":"COMPLETE"}'::jsonb,'{}',
       jsonb_build_object('team_packet_status','COMPLETE','b1_b4_packet_status','COMPLETE','confounding_check','PASS','shrinkage','APPLIED')
where exists(select 1 from public.runs where run_id='DIAG-MOTHER-V3-20260819-K04')
on conflict(packet_id) do nothing;
update public.sra_packets set content_hash=encode(digest(payload::text,'sha256'),'hex') where packet_id='SRA-DIAG-1';
update public.protocol_phase_state s
set payload=jsonb_set(jsonb_set(s.payload,'{sra,packet_id}','"SRA-DIAG-1"'::jsonb),'{sra,packet_hash}',to_jsonb(p.content_hash))
from public.sra_packets p
where s.run_id=p.run_id and s.game_id=p.game_id
  and s.protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS'
  and s.phase_id='A6_CAUSAL_FALSIFICATION_SPORTS_SEAL'
  and p.packet_id='SRA-DIAG-1';

update public.protocol_phase_catalog
set required_fields=required_fields || array(select x from unnest(array['sra.packet_id','sra.packet_hash']) x where not (x=any(required_fields)))
where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and phase_id='A6_CAUSAL_FALSIFICATION_SPORTS_SEAL';

update public.protocol_phase_catalog
set required_fields=required_fields || array(select x from unnest(array[
  'contract_calibration.u0_5.certification_id','contract_calibration.u1_5.certification_id','contract_calibration.u2_5.certification_id'
]) x where not (x=any(required_fields)))
where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS';

update public.protocol_phase_catalog
set required_fields=required_fields || array(select x from unnest(array['market.offer_id','t5.material_change','t5.recompute_status']) x where not (x=any(required_fields)))
where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and phase_id='A8_MARKET_VALUE_EXECUTION';
