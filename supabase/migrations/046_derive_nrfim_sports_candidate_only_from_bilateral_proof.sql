-- Migration 046 — derive SPORTS_CANDIDATE only from bilateral proof

create or replace view public.nrfimetrica_game_dual_status as
with latest_packet as (
  select distinct on (s.run_id,s.game_id)
    s.run_id,s.game_id,s.packet_id,s.status as packet_status,s.sports_verdict,s.process_audit_status,
    s.packet_hash,s.drive_content_hash,s.drive_verified_at,s.evidence_ids,s.top_half_verdict,s.bottom_half_verdict
  from public.sports_reasoning_packets s
  order by s.run_id,s.game_id,s.version desc
), base as (
  select lp.*,
    exists(select 1 from public.evidence e where e.run_id=lp.run_id and e.game_id=lp.game_id and e.evidence_id=any(coalesce(lp.evidence_ids,'{}'))) as basic_data_present,
    (lp.top_half_verdict='NRFI_HALF_PASS' and lp.bottom_half_verdict='NRFI_HALF_PASS' and not exists(
      select 1 from public.nrfi_bilateral_legacy_review r
      where r.system_id='@NRFImetrica' and r.object_id=lp.packet_id and r.review_status='REQUIRES_BILATERAL_REEVALUATION'
    )) as bilateral_nrfi_proven
  from latest_packet lp
), a8 as (
  select run_id,game_id,payload from public.protocol_phase_state
  where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and phase_id='A8_MARKET_VALUE_EXECUTION'
), res as (
  select run_id,game_id,resolution_code,authority_level,reason from public.protocol_game_resolution
  where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS'
)
select g.run_id,g.game_id,g.status as game_status,b.packet_id,b.packet_status,b.sports_verdict,b.process_audit_status,
  b.drive_verified_at is not null and b.drive_content_hash=b.packet_hash as drive_hash_verified,
  case
    when g.status='AUDIT_ONLY' then 'AUDIT_ONLY'
    when b.sports_verdict='NRFI_LEAN' and b.basic_data_present and b.bilateral_nrfi_proven then 'SPORTS_CANDIDATE'
    when b.sports_verdict in ('YRFI_LEAN','NO_PLAY','NEUTRAL') and b.basic_data_present then 'NO_PLAY'
    else 'WATCHLIST'
  end as sports_status,
  case
    when upper(coalesce(a8.payload->>'final_verdict','')) in ('APOSTAR','SOLO_SI_CUOTA') and coalesce(b.bilateral_nrfi_proven,false) then 'EXECUTABLE'
    when g.status='AUDIT_ONLY' then 'AUDIT_ONLY'
    when b.sports_verdict='NRFI_LEAN' and b.basic_data_present and not coalesce(b.bilateral_nrfi_proven,false) then 'WATCHLIST'
    when b.sports_verdict='NRFI_LEAN' and b.basic_data_present and b.bilateral_nrfi_proven and res.resolution_code in ('A4_ENGINE_NOT_INTEGRATED','A4_TRUE_MODEL_FAILURE','A6_INDEPENDENT_AUDIT_UNAVAILABLE','A7_NOT_ELIGIBLE','A7_RESEARCH_ONLY','A7_CALIBRATION_UNCERTIFIED','A7_MODEL_AUDIT_REQUIRED','A7_PRESS_UNAVAILABLE') then 'TECHNICAL_BLOCK'
    when b.sports_verdict='NRFI_LEAN' and b.basic_data_present and b.bilateral_nrfi_proven and not (b.packet_status='ANALYSIS_COMPLETE' and b.process_audit_status='PASS' and b.drive_verified_at is not null and b.drive_content_hash=b.packet_hash) then 'PROCESS_BLOCK'
    when b.sports_verdict='NRFI_LEAN' and b.basic_data_present and b.bilateral_nrfi_proven then 'PENDING'
    when b.sports_verdict in ('YRFI_LEAN','NO_PLAY','NEUTRAL') and b.basic_data_present then 'NOT_APPLICABLE'
    else 'WATCHLIST'
  end as execution_status,
  res.resolution_code as technical_resolution_code,res.reason as technical_resolution_reason,
  case
    when g.status='AUDIT_ONLY' then 'NOT_APPLICABLE'
    when b.packet_id is null then 'MISSING'
    when b.packet_status='ANALYSIS_COMPLETE' and b.process_audit_status='PASS' and b.drive_verified_at is not null and b.drive_content_hash=b.packet_hash then 'VERIFIED'
    when b.packet_status='PROCESS_FAIL' or b.process_audit_status='FAIL' then 'FAIL'
    when b.process_audit_status='REVIEW' then 'REVIEW'
    when b.drive_verified_at is null or b.drive_content_hash is distinct from b.packet_hash then 'UNVERIFIED'
    when b.packet_status in ('RESEARCH_INCOMPLETE','INFORMATION_UNAVAILABLE','WITHDRAWN_POST_FREEZE') then 'INCOMPLETE'
    else 'PENDING'
  end as process_status,
  b.top_half_verdict,b.bottom_half_verdict,coalesce(b.bilateral_nrfi_proven,false) as bilateral_nrfi_proven,
  case when b.sports_verdict='NRFI_LEAN' and not coalesce(b.bilateral_nrfi_proven,false)
       then 'REQUIRES_BILATERAL_REEVALUATION' else 'CURRENT_RULE_OK' end as bilateral_rule_status
from public.games g
left join base b on b.run_id=g.run_id and b.game_id=g.game_id
left join a8 on a8.run_id=g.run_id and a8.game_id=g.game_id
left join res on res.run_id=g.run_id and res.game_id=g.game_id;

update public.agent_registry
set metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object(
  'database_migrations_required_through',46,
  'sports_candidate_requires_bilateral_proof',true,
  'legacy_nrfi_lean_visible_as_watchlist_until_reevaluated',true)
where agent_id='@NRFImetrica';

update public.nrfiprensa_authority
set metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('database_migrations_required_through',46),updated_at=now()
where agent_id='@NRFiPrensa';

update public.system_auditor_authority
set migrations_required_through=46,updated_at=now()
where protocol_id='SYSTEM_AUDITOR_V1';
