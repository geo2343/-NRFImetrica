-- Kernel 0.9 causal authority refinement.
-- Remove arbitrary process-count gates from sports-judgment persistence.
-- Sports judgment still requires real current-run data and bilateral causal reasoning.
-- Source-count/snapshot/claim-chain quality remains visible in PROCESS_AUDIT and may block execution,
-- but it no longer erases or prevents persistence of the sports verdict.

create or replace function public.enforce_sports_reasoning_packet()
returns trigger language plpgsql as $$
declare
  g record; eid text; n_basic_evidence integer:=0; n_families integer:=0;
  fa jsonb; has_against_nrfi boolean:=false; has_against_yrfi boolean:=false;
  proxy jsonb; prior_hash text; prior_version integer; family_id text;
begin
  select scheduled_start,cutoff_at into g from public.games where run_id=new.run_id and game_id=new.game_id;
  if not found then raise exception 'SPORTS_PACKET_GAME_NOT_REGISTERED' using errcode='23514'; end if;
  new.cutoff_at:=coalesce(g.cutoff_at,g.scheduled_start);
  new.updated_at:=clock_timestamp();

  if tg_op='UPDATE' and old.freeze_timestamp is not null and (
    new.packet_payload is distinct from old.packet_payload
    or new.top_1st_analysis is distinct from old.top_1st_analysis
    or new.bottom_1st_analysis is distinct from old.bottom_1st_analysis
    or new.central_nrfi_case is distinct from old.central_nrfi_case
    or new.best_yrfi_rival is distinct from old.best_yrfi_rival
    or new.falsification_attempts is distinct from old.falsification_attempts
    or new.causal_clusters is distinct from old.causal_clusters
    or new.sports_verdict is distinct from old.sports_verdict
  ) then raise exception 'SPORTS_PACKET_FROZEN_CREATE_NEW_VERSION' using errcode='23514'; end if;

  if new.version=1 then
    if coalesce(new.previous_packet_hash,'')<>'' then raise exception 'PACKET_V1_CANNOT_HAVE_PREVIOUS_HASH' using errcode='23514'; end if;
  else
    select version,packet_hash into prior_version,prior_hash
    from public.sports_reasoning_packets
    where run_id=new.run_id and game_id=new.game_id and version<new.version
    order by version desc limit 1;
    if prior_version is null or prior_version<>new.version-1 or coalesce(prior_hash,'')='' or new.previous_packet_hash is distinct from prior_hash then
      raise exception 'PACKET_VERSION_CHAIN_INVALID' using errcode='23514'; end if;
  end if;

  if coalesce(array_length(new.evidence_ids,1),0)>0 then
    select count(*),count(distinct source_family_id),max(retrieved_at)
      into n_basic_evidence,n_families,new.as_of_kernel
    from public.evidence
    where evidence_id=any(new.evidence_ids) and run_id=new.run_id and game_id=new.game_id;
  else new.as_of_kernel:=null; end if;
  new.source_family_count:=n_families;

  if new.status in ('ANALYSIS_COMPLETE','RESEARCH_INCOMPLETE','INFORMATION_UNAVAILABLE','NOT_EXECUTABLE') and new.analysis_completed_at is null then
    new.analysis_completed_at:=clock_timestamp(); end if;

  if new.status='ANALYSIS_COMPLETE' then
    if n_basic_evidence=0 then raise exception 'SPORTS_JUDGMENT_REQUIRES_CURRENT_RUN_GAME_DATA' using errcode='23514'; end if;
    if new.as_of_kernel is null or (g.scheduled_start is not null and new.as_of_kernel>=g.scheduled_start) then
      raise exception 'SPORTS_JUDGMENT_TEMPORAL_DATA_INVALID' using errcode='23514'; end if;
    if new.top_1st_analysis='{}'::jsonb or new.bottom_1st_analysis='{}'::jsonb then
      raise exception 'PACKET_BILATERAL_FIRST_INNING_ANALYSIS_REQUIRED' using errcode='23514'; end if;
    if new.central_nrfi_case='{}'::jsonb or new.best_yrfi_rival='{}'::jsonb then
      raise exception 'PACKET_NRFI_AND_YRFI_THESES_REQUIRED' using errcode='23514'; end if;
    if new.strongest_counterevidence='{}'::jsonb then raise exception 'PACKET_STRONGEST_COUNTEREVIDENCE_REQUIRED' using errcode='23514'; end if;
    if jsonb_typeof(new.falsification_attempts)<>'array' then raise exception 'PACKET_FALSIFICATION_ARRAY_REQUIRED' using errcode='23514'; end if;
    for fa in select value from jsonb_array_elements(new.falsification_attempts) loop
      if upper(coalesce(fa->>'against',''))='NRFI' then has_against_nrfi:=true; end if;
      if upper(coalesce(fa->>'against',''))='YRFI' then has_against_yrfi:=true; end if;
    end loop;
    if not has_against_nrfi or not has_against_yrfi then raise exception 'PACKET_FALSIFICATION_MUST_TEST_BOTH_THESES' using errcode='23514'; end if;
    if new.causal_clusters='{}'::jsonb or jsonb_typeof(new.causal_clusters) not in ('array','object') then
      raise exception 'PACKET_CAUSAL_CLUSTERS_REQUIRED' using errcode='23514'; end if;
    if new.dominant_factor='{}'::jsonb then raise exception 'PACKET_DOMINANT_CAUSAL_FACTOR_REQUIRED' using errcode='23514'; end if;
    if coalesce(new.why_research_stopped,'') not in ('COVERAGE_COMPLETE','DIMINISHING_RETURNS','CONTRADICTION_RESOLVED') then
      raise exception 'PACKET_INVALID_COMPLETE_STOP_REASON:%',coalesce(new.why_research_stopped,'') using errcode='23514'; end if;
    foreach family_id in array coalesce(new.saturation_family_ids,'{}') loop
      if not exists(select 1 from public.research_source_families f where f.source_family_id=family_id and f.run_id=new.run_id and f.game_id=new.game_id) then
        raise exception 'SATURATION_FAMILY_NOT_REGISTERED:%',family_id using errcode='23514'; end if;
    end loop;
    if not (new.dimensions_covered @> array['TOP_1ST','BOTTOM_1ST','STARTER_CURRENT_FORM','TOP_ORDER_MATCHUP','FIRST_INNING_SPECIFIC','COUNTEREVIDENCE']) then
      raise exception 'PACKET_REQUIRED_CAUSAL_DIMENSIONS_MISSING' using errcode='23514'; end if;
    if jsonb_typeof(new.full_game_proxies)<>'array' then raise exception 'FULL_GAME_PROXIES_MUST_BE_ARRAY' using errcode='23514'; end if;
    for proxy in select value from jsonb_array_elements(new.full_game_proxies) loop
      if trim(coalesce(proxy->>'justification',''))='' then raise exception 'FULL_GAME_PROXY_REQUIRES_FIRST_INNING_JUSTIFICATION' using errcode='23514'; end if;
    end loop;
    if new.sports_verdict is null or upper(new.sports_verdict) not in ('NRFI_LEAN','YRFI_LEAN','NO_PLAY','NEUTRAL') then
      raise exception 'PACKET_SPORTS_VERDICT_REQUIRED' using errcode='23514'; end if;
    if new.what_would_change='{}'::jsonb then raise exception 'PACKET_FALSIFIABLE_CHANGE_CONDITION_REQUIRED' using errcode='23514'; end if;
    if trim(coalesce(new.research_depth_justification,''))='' then raise exception 'PACKET_RESEARCH_DEPTH_JUSTIFICATION_REQUIRED' using errcode='23514'; end if;

    if new.freeze_timestamp is null then new.freeze_timestamp:=clock_timestamp(); end if;
    if coalesce(new.packet_hash,'')='' then
      new.packet_hash:=public.nrfim_sha256_text((jsonb_build_object(
        'packet_id',new.packet_id,'run_id',new.run_id,'game_id',new.game_id,'version',new.version,
        'previous_packet_hash',new.previous_packet_hash,'complexity_tier',new.complexity_tier,
        'sports_verdict',new.sports_verdict,'as_of_kernel',new.as_of_kernel,'evidence_ids',new.evidence_ids,
        'top_1st_analysis',new.top_1st_analysis,'bottom_1st_analysis',new.bottom_1st_analysis,
        'central_nrfi_case',new.central_nrfi_case,'best_yrfi_rival',new.best_yrfi_rival,
        'strongest_counterevidence',new.strongest_counterevidence,'falsification_attempts',new.falsification_attempts,
        'causal_clusters',new.causal_clusters,'dominant_factor',new.dominant_factor,
        'governing_uncertainty',new.governing_uncertainty,'what_would_change',new.what_would_change,
        'why_research_stopped',new.why_research_stopped,'dimensions_covered',new.dimensions_covered,
        'research_depth_justification',new.research_depth_justification,'known_unknowns',new.known_unknowns,
        'full_game_proxies',new.full_game_proxies,'packet_payload',new.packet_payload))::text); end if;
  end if;
  return new;
end $$;

create or replace view public.nrfimetrica_game_dual_status as
with latest_packet as (
  select distinct on (s.run_id,s.game_id)
    s.run_id,s.game_id,s.packet_id,s.status as packet_status,s.sports_verdict,
    s.process_audit_status,s.packet_hash,s.drive_content_hash,s.drive_verified_at,s.evidence_ids
  from public.sports_reasoning_packets s order by s.run_id,s.game_id,s.version desc
),
base as (
  select lp.*,
    exists(select 1 from public.evidence e where e.run_id=lp.run_id and e.game_id=lp.game_id and e.evidence_id=any(coalesce(lp.evidence_ids,'{}'))) as basic_data_present
  from latest_packet lp
),
a8 as (
  select run_id,game_id,payload from public.protocol_phase_state
  where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and phase_id='A8_MARKET_VALUE_EXECUTION'
),
res as (
  select run_id,game_id,resolution_code,authority_level,reason from public.protocol_game_resolution
  where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS'
)
select
  g.run_id,g.game_id,g.status as game_status,b.packet_id,b.packet_status,b.sports_verdict,b.process_audit_status,
  (b.drive_verified_at is not null and b.drive_content_hash=b.packet_hash) as drive_hash_verified,
  case
    when g.status='AUDIT_ONLY' then 'AUDIT_ONLY'
    when b.sports_verdict='NRFI_LEAN' and b.basic_data_present then 'SPORTS_CANDIDATE'
    when b.sports_verdict in ('YRFI_LEAN','NO_PLAY','NEUTRAL') and b.basic_data_present then 'NO_PLAY'
    else 'WATCHLIST'
  end as sports_status,
  case
    when upper(coalesce(a8.payload->>'final_verdict','')) in ('APOSTAR','SOLO_SI_CUOTA') then 'EXECUTABLE'
    when g.status='AUDIT_ONLY' then 'AUDIT_ONLY'
    when b.sports_verdict='NRFI_LEAN' and b.basic_data_present and res.resolution_code in (
      'A4_ENGINE_NOT_INTEGRATED','A4_TRUE_MODEL_FAILURE','A6_INDEPENDENT_AUDIT_UNAVAILABLE',
      'A7_NOT_ELIGIBLE','A7_RESEARCH_ONLY','A7_CALIBRATION_UNCERTIFIED','A7_MODEL_AUDIT_REQUIRED','A7_PRESS_UNAVAILABLE') then 'TECHNICAL_BLOCK'
    when b.sports_verdict='NRFI_LEAN' and b.basic_data_present and not (
      b.packet_status='ANALYSIS_COMPLETE' and b.process_audit_status='PASS'
      and b.drive_verified_at is not null and b.drive_content_hash=b.packet_hash) then 'PROCESS_BLOCK'
    when b.sports_verdict='NRFI_LEAN' and b.basic_data_present then 'PENDING'
    when b.sports_verdict in ('YRFI_LEAN','NO_PLAY','NEUTRAL') and b.basic_data_present then 'NOT_APPLICABLE'
    else 'WATCHLIST'
  end as execution_status,
  res.resolution_code as technical_resolution_code,res.reason as technical_resolution_reason,
  case
    when g.status='AUDIT_ONLY' then 'NOT_APPLICABLE'
    when b.packet_id is null then 'MISSING'
    when b.packet_status='ANALYSIS_COMPLETE' and b.process_audit_status='PASS'
      and b.drive_verified_at is not null and b.drive_content_hash=b.packet_hash then 'VERIFIED'
    when b.packet_status='PROCESS_FAIL' or b.process_audit_status='FAIL' then 'FAIL'
    when b.process_audit_status='REVIEW' then 'REVIEW'
    when b.drive_verified_at is null or b.drive_content_hash is distinct from b.packet_hash then 'UNVERIFIED'
    when b.packet_status in ('RESEARCH_INCOMPLETE','INFORMATION_UNAVAILABLE','WITHDRAWN_POST_FREEZE') then 'INCOMPLETE'
    else 'PENDING'
  end as process_status
from public.games g
left join base b on b.run_id=g.run_id and b.game_id=g.game_id
left join a8 on a8.run_id=g.run_id and a8.game_id=g.game_id
left join res on res.run_id=g.run_id and res.game_id=g.game_id;

update public.agent_registry set metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object(
  'sports_candidate_requires_process_pass',false,
  'sports_candidate_requires_drive_hash_match',false,
  'sports_candidate_requires_basic_current_run_data',true,
  'source_family_floors_are_process_quality_not_sports_decision',true,
  'arbitrary_text_length_gates_removed_from_sports_judgment',true,
  'database_migrations_required_through',30)
where agent_id='@NRFImetrica';