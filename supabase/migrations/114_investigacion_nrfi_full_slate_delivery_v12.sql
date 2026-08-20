-- @investigacionNRFI v1.2 — FULL-SLATE-DELIVERY
-- Mirrors the production migration applied to Supabase.

alter table public.investigacion_nrfi_runs
  add column if not exists official_slate_count integer not null default 0,
  add column if not exists finalized_game_count integer not null default 0,
  add column if not exists nonfinal_game_count integer not null default 0,
  add column if not exists slate_universe_hash text,
  add column if not exists slate_complete boolean not null default false,
  add column if not exists delivery_contract_version text not null default 'DAILY-SLATE-REPORT-V2';

alter table public.investigacion_nrfi_games
  add column if not exists official_slate_member boolean not null default true,
  add column if not exists slate_disposition text not null default 'UNCLASSIFIED';

alter table public.investigacion_nrfi_drive_appends
  add column if not exists slate_row_count integer not null default 0,
  add column if not exists excluded_game_summary_count integer not null default 0,
  add column if not exists delivery_contract_version text not null default 'LEGACY';

create or replace function public.investigacion_nrfi_guard_game_disposition()
returns trigger
language plpgsql
security definer
set search_path to 'public','extensions'
as $$
begin
  if new.research_status='PROCESSED' and not coalesce(new.finalized_verified,false) then
    raise exception 'NONFINAL_GAME_CANNOT_BE_PROCESSED';
  end if;
  if new.research_status='EXCLUDED' and coalesce(btrim(new.exclusion_reason),'')='' then
    raise exception 'EXCLUSION_REASON_REQUIRED';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_investigacion_nrfi_guard_game_disposition on public.investigacion_nrfi_games;
create trigger trg_investigacion_nrfi_guard_game_disposition
before insert or update of research_status, finalized_verified, exclusion_reason
on public.investigacion_nrfi_games
for each row execute function public.investigacion_nrfi_guard_game_disposition();

create or replace function public.investigacion_nrfi_sync_run_accounting(p_daily_run_id text)
returns public.investigacion_nrfi_runs
language plpgsql
security definer
set search_path to 'public','extensions'
as $$
declare out_run public.investigacion_nrfi_runs%rowtype;
begin
  update public.investigacion_nrfi_runs r set
    expected_finalized_count=(select count(*) from public.investigacion_nrfi_games g where g.daily_run_id=p_daily_run_id and g.official_slate_member=true),
    official_slate_count=(select count(*) from public.investigacion_nrfi_games g where g.daily_run_id=p_daily_run_id and g.official_slate_member=true),
    finalized_game_count=(select count(*) from public.investigacion_nrfi_games g where g.daily_run_id=p_daily_run_id and g.official_slate_member=true and g.finalized_verified=true),
    nonfinal_game_count=(select count(*) from public.investigacion_nrfi_games g where g.daily_run_id=p_daily_run_id and g.official_slate_member=true and g.finalized_verified=false),
    processed_count=(select count(*) from public.investigacion_nrfi_games g where g.daily_run_id=p_daily_run_id and g.official_slate_member=true and g.research_status='PROCESSED'),
    excluded_count=(select count(*) from public.investigacion_nrfi_games g where g.daily_run_id=p_daily_run_id and g.official_slate_member=true and g.research_status='EXCLUDED'),
    slate_complete=(
      (select count(*) from public.investigacion_nrfi_games g where g.daily_run_id=p_daily_run_id and g.official_slate_member=true) > 0
      and not exists(select 1 from public.investigacion_nrfi_games g where g.daily_run_id=p_daily_run_id and g.official_slate_member=true and g.research_status='PENDING')
      and not exists(select 1 from public.investigacion_nrfi_games g where g.daily_run_id=p_daily_run_id and g.official_slate_member=true and g.research_status<>'EXCLUDED' and g.finalized_verified=false)
    )
  where r.daily_run_id=p_daily_run_id returning * into out_run;
  if out_run.daily_run_id is null then raise exception 'DAILY_RUN_NOT_FOUND'; end if;
  return out_run;
end;
$$;

create or replace function public.investigacion_nrfi_semantic_completeness(p_daily_run_id text)
returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions'
as $$
declare
  r public.investigacion_nrfi_runs%rowtype;
  target_count integer;
  processed_count integer;
  f1_ready integer := 0;
  f2_ready integer := 0;
  f3_ready integer := 0;
  f4_ready integer := 0;
  packet_ok boolean := false;
  report_ok boolean := false;
  min_report_chars integer := 0;
  rec record;
  s jsonb;
  f1_ok boolean;
  f2_ok boolean;
  f3_ok boolean;
  f4_ok boolean;
  f5_ok boolean;
begin
  perform public.investigacion_nrfi_sync_run_accounting(p_daily_run_id);
  select * into r from public.investigacion_nrfi_runs where daily_run_id=p_daily_run_id;
  if not found then raise exception 'DAILY_RUN_NOT_FOUND'; end if;

  select count(*) into target_count from public.investigacion_nrfi_games where daily_run_id=p_daily_run_id and official_slate_member=true and research_status <> 'EXCLUDED';
  select count(*) into processed_count from public.investigacion_nrfi_games where daily_run_id=p_daily_run_id and official_slate_member=true and research_status='PROCESSED';

  for rec in select game_pk from public.investigacion_nrfi_games where daily_run_id=p_daily_run_id and official_slate_member=true and research_status <> 'EXCLUDED' loop
    s := public.investigacion_nrfi_game_semantic_ready(p_daily_run_id, rec.game_pk);
    if coalesce((s->>'f1')::boolean,false) then f1_ready := f1_ready + 1; end if;
    if coalesce((s->>'f2')::boolean,false) then f2_ready := f2_ready + 1; end if;
    if coalesce((s->>'f3')::boolean,false) then f3_ready := f3_ready + 1; end if;
    if coalesce((s->>'f4')::boolean,false) then f4_ready := f4_ready + 1; end if;
  end loop;

  f1_ok := target_count>0 and f1_ready=target_count;
  f2_ok := target_count>0 and f2_ready=target_count;
  f3_ok := target_count>0 and f3_ready=target_count;
  f4_ok := target_count>0 and f4_ready=target_count;

  select exists(
    select 1 from public.investigacion_nrfi_evidence_packets p
    where p.daily_run_id=p_daily_run_id
      and p.future_game_count=0 and p.postgame_leak_count=0
      and p.packet_payload ?& array['PITCHER_HISTORY','TEAM_HISTORY','TOP_ORDER_HISTORY','PROCESS_HISTORY','EVENT_PATHS','CONTEXT','PRESS_HISTORY_PREGAME','POSTGAME_EXPLANATORY_SEPARATE','SAMPLE_RELIABILITY','DATA_COVERAGE','SOURCE_LINEAGE','UNCERTAINTY','COMPARABLE_COHORTS']
  ) into packet_ok;
  f5_ok := packet_ok;

  min_report_chars := greatest(20000, target_count * 3000);
  select exists(
    select 1 from public.investigacion_nrfi_drive_appends d
    where d.daily_run_id=p_daily_run_id and d.verified=true and d.report_contract_verified=true
      and d.delivery_contract_version='DAILY-SLATE-REPORT-V2'
      and d.slate_row_count=r.official_slate_count
      and d.game_block_count=target_count
      and d.excluded_game_summary_count=r.excluded_count
      and d.phase_section_count>=5
      and d.daily_block_character_count>=min_report_chars
      and d.required_section_markers @> '{"DAILY_HEADER":true,"EXECUTION_SUMMARY":true,"SLATE_LEDGER":true,"SLATE_STATISTICAL_SUMMARY":true,"F1_F5_SYNTHESIS":true,"GAME_BLOCKS":true,"CROSS_GAME_FINDINGS":true,"DATA_GAPS_AND_LIMITATIONS":true,"SOURCE_AND_EVIDENCE_LEDGER":true,"AUDIT_TRAIL":true,"DAILY_CLOSURE":true}'::jsonb
  ) into report_ok;

  return jsonb_build_object(
    'official_slate_count',r.official_slate_count,
    'finalized_game_count',r.finalized_game_count,
    'nonfinal_game_count',r.nonfinal_game_count,
    'slate_complete',r.slate_complete,
    'target_games',target_count,
    'processed_games',processed_count,
    'excluded_games',r.excluded_count,
    'f1_ready_games',f1_ready,
    'f2_ready_games',f2_ready,
    'f3_ready_games',f3_ready,
    'f4_ready_games',f4_ready,
    'f1_pass',f1_ok,
    'f2_pass',f2_ok,
    'f3_pass',f3_ok,
    'f4_pass',f4_ok,
    'f5_pass',f5_ok,
    'report_contract_pass',report_ok,
    'report_contract_version','DAILY-SLATE-REPORT-V2',
    'minimum_daily_block_characters',min_report_chars,
    'all_games_processed_or_excluded',r.slate_complete,
    'pass',(r.slate_complete and target_count>0 and processed_count=target_count and f1_ok and f2_ok and f3_ok and f4_ok and f5_ok and report_ok)
  );
end;
$$;

create or replace function public.investigacion_nrfi_derive_audit(p_daily_run_id text)
returns public.investigacion_nrfi_audits
language plpgsql
security definer
set search_path to 'public','extensions'
as $$
declare
  r public.investigacion_nrfi_runs%rowtype;
  out_row public.investigacion_nrfi_audits%rowtype;
  completed text[];
  missing text[];
  temporal_ok boolean;
  trace_ok boolean;
  drive_ok boolean;
  universe_ok boolean;
  ledger_expected integer;
  ledger_processed integer;
  ledger_excluded integer;
  ledger_pending integer;
  ledger_nonfinal_unexcluded integer;
  semantic jsonb;
  semantic_ok boolean;
  report_ok boolean;
begin
  perform public.investigacion_nrfi_sync_run_accounting(p_daily_run_id);
  select * into r from public.investigacion_nrfi_runs where daily_run_id=p_daily_run_id;
  if not found then raise exception 'DAILY_RUN_NOT_FOUND'; end if;
  select count(*),count(*) filter(where research_status='PROCESSED'),count(*) filter(where research_status='EXCLUDED'),count(*) filter(where research_status='PENDING'),count(*) filter(where finalized_verified=false and research_status<>'EXCLUDED')
  into ledger_expected,ledger_processed,ledger_excluded,ledger_pending,ledger_nonfinal_unexcluded
  from public.investigacion_nrfi_games where daily_run_id=p_daily_run_id and official_slate_member=true;
  select coalesce(array_agg(phase_id order by phase_id),'{}'::text[]) into completed from public.investigacion_nrfi_phase_state where daily_run_id=p_daily_run_id and status='COMPLETE';
  select coalesce(array_agg(pid),'{}'::text[]) into missing from unnest(array['F1_FORENSIC_CAPTURE','F2_DEEP_RECONSTRUCTION','F3_FEATURE_FACTORY','F4_HISTORICAL_PRESS_RELIABILITY','F5_QUERYABLE_INTELLIGENCE']) pid where not (pid=any(completed));
  universe_ok := r.official_slate_count>0 and r.official_slate_count=ledger_expected and ledger_pending=0 and ledger_nonfinal_unexcluded=0 and ledger_expected=ledger_processed+ledger_excluded and r.processed_count=ledger_processed and r.excluded_count=ledger_excluded and r.slate_complete=true;
  select not exists(select 1 from public.investigacion_nrfi_evidence e where e.daily_run_id=p_daily_run_id and e.temporal_lane='PREGAME_EVIDENCE' and (e.available_at is null or e.first_pitch_at is null or e.available_at>=e.first_pitch_at)) into temporal_ok;
  select case when ledger_expected=0 then false else exists(select 1 from public.investigacion_nrfi_evidence e where e.daily_run_id=p_daily_run_id) and not exists(select 1 from public.investigacion_nrfi_evidence e left join public.investigacion_nrfi_tool_events t on t.event_id=e.tool_event_id left join public.investigacion_nrfi_source_families f on f.source_family_id=e.source_family_id where e.daily_run_id=p_daily_run_id and (t.event_id is null or f.source_family_id is null)) end into trace_ok;
  select exists(select 1 from public.investigacion_nrfi_drive_appends d where d.daily_run_id=p_daily_run_id and d.verified=true and d.delivery_contract_version='DAILY-SLATE-REPORT-V2') into drive_ok;
  semantic := public.investigacion_nrfi_semantic_completeness(p_daily_run_id);
  semantic_ok := coalesce((semantic->>'pass')::boolean,false);
  report_ok := coalesce((semantic->>'report_contract_pass')::boolean,false);

  insert into public.investigacion_nrfi_audits(
    daily_run_id,phases_expected,phases_executed,mandatory_phases_not_run,universe_accounting_pass,temporal_integrity_pass,evidence_trace_pass,drive_append_pass,audit_status,details,derived_at,
    semantic_completeness_pass,f1_semantic_pass,f2_semantic_pass,f3_semantic_pass,f4_semantic_pass,f5_semantic_pass,report_contract_pass,semantic_details
  ) values(
    p_daily_run_id,5,cardinality(completed),missing,universe_ok,temporal_ok,trace_ok,drive_ok,
    case when cardinality(missing)=0 and universe_ok and temporal_ok and trace_ok and drive_ok and semantic_ok then 'PASS' else 'FAIL' end,
    jsonb_build_object('official_slate_count',r.official_slate_count,'ledger_expected',ledger_expected,'ledger_processed',ledger_processed,'ledger_excluded',ledger_excluded,'ledger_pending',ledger_pending,'nonfinal_unexcluded',ledger_nonfinal_unexcluded,'slate_complete',r.slate_complete,'delivery_contract_version',r.delivery_contract_version,'agent_id','@investigacionNRFI'),now(),
    semantic_ok,coalesce((semantic->>'f1_pass')::boolean,false),coalesce((semantic->>'f2_pass')::boolean,false),coalesce((semantic->>'f3_pass')::boolean,false),coalesce((semantic->>'f4_pass')::boolean,false),coalesce((semantic->>'f5_pass')::boolean,false),report_ok,semantic
  ) on conflict(daily_run_id) do update set
    phases_executed=excluded.phases_executed,mandatory_phases_not_run=excluded.mandatory_phases_not_run,universe_accounting_pass=excluded.universe_accounting_pass,
    temporal_integrity_pass=excluded.temporal_integrity_pass,evidence_trace_pass=excluded.evidence_trace_pass,drive_append_pass=excluded.drive_append_pass,audit_status=excluded.audit_status,
    details=excluded.details,derived_at=excluded.derived_at,semantic_completeness_pass=excluded.semantic_completeness_pass,f1_semantic_pass=excluded.f1_semantic_pass,
    f2_semantic_pass=excluded.f2_semantic_pass,f3_semantic_pass=excluded.f3_semantic_pass,f4_semantic_pass=excluded.f4_semantic_pass,f5_semantic_pass=excluded.f5_semantic_pass,
    report_contract_pass=excluded.report_contract_pass,semantic_details=excluded.semantic_details
  returning * into out_row;
  return out_row;
end;
$$;

update public.agent_registry
set agent_version='INVESTIGACION-NRFI-AGENT-1.2',
    kernel_version='INVESTIGACION-NRFI-KERNEL-0.3-FULL-SLATE-DELIVERY',
    metadata=coalesce(metadata,'{}'::jsonb) || jsonb_build_object(
      'full_slate_enforcement',true,
      'official_slate_ledger_required',true,
      'nonfinal_game_processing_blocked',true,
      'delivery_contract_version','DAILY-SLATE-REPORT-V2',
      'organized_daily_report_required',true,
      'minimum_report_characters_formula','max(20000, processed_games*3000)',
      'sovereign_patch','FULL-SLATE-DELIVERY-1.2'
    ),
    updated_at=now()
where agent_id='@investigacionNRFI';

revoke execute on function public.investigacion_nrfi_guard_game_disposition() from public, anon, authenticated;
revoke execute on function public.investigacion_nrfi_sync_run_accounting(text) from public, anon, authenticated;
revoke execute on function public.investigacion_nrfi_semantic_completeness(text) from public, anon, authenticated;
revoke execute on function public.investigacion_nrfi_derive_audit(text) from public, anon, authenticated;
grant execute on function public.investigacion_nrfi_sync_run_accounting(text) to service_role;
grant execute on function public.investigacion_nrfi_semantic_completeness(text) to service_role;
grant execute on function public.investigacion_nrfi_derive_audit(text) to service_role;
