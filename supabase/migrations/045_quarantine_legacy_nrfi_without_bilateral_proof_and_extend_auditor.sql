-- Migration 045 — quarantine legacy NRFI without bilateral proof and extend @AuditorSistema

create table if not exists public.nrfi_bilateral_legacy_review(
  system_id text not null,
  run_id text not null,
  game_id text not null,
  object_id text not null,
  prior_verdict text,
  review_status text not null check (review_status in ('REQUIRES_BILATERAL_REEVALUATION','REEVALUATED_PASS','REEVALUATED_FAIL')),
  reason text not null,
  detected_at timestamptz not null default now(),
  reviewed_at timestamptz,
  primary key(system_id,object_id)
);

insert into public.nrfi_bilateral_legacy_review(system_id,run_id,game_id,object_id,prior_verdict,review_status,reason)
select '@NRFImetrica',p.run_id,p.game_id,p.packet_id,p.sports_verdict,'REQUIRES_BILATERAL_REEVALUATION',
       'Legacy NRFI_LEAN predates BILATERAL-1.0 or lacks two explicit independent NRFI_HALF_PASS verdicts; prior confidence withdrawn until fresh bilateral review.'
from public.sports_reasoning_packets p
where p.sports_verdict='NRFI_LEAN'
  and (p.top_half_verdict is distinct from 'NRFI_HALF_PASS' or p.bottom_half_verdict is distinct from 'NRFI_HALF_PASS')
on conflict(system_id,object_id) do nothing;

insert into public.nrfi_bilateral_legacy_review(system_id,run_id,game_id,object_id,prior_verdict,review_status,reason)
select '@NRFiPrensa',s.run_id,s.game_id,s.run_id||'|'||s.game_id||'|F8',upper(coalesce(s.payload->>'so_media_status','')),
       'REQUIRES_BILATERAL_REEVALUATION',
       'Legacy positive NRFI media conclusion lacks two explicit independent NRFI_HALF_PASS records under BILATERAL-1.0.'
from public.nrfiprensa_phase_state s
where s.phase_id='F8'
  and upper(coalesce(s.payload->>'so_media_status',''))='SO_MEDIA_POSITIVE_NRFI'
  and (select count(*) from public.nrfiprensa_f7q q where q.run_id=s.run_id and q.game_id=s.game_id and q.half_verdict='NRFI_HALF_PASS')<>2
on conflict(system_id,object_id) do nothing;

insert into public.system_audit_adapter_checks(system_id,check_id,layer_id,title,rule_text,default_severity,required,target_objects)
values
('@NRFImetrica','NM-P5-BILATERAL-NO-COMP','P5','Bilateral conjunction / no compensation',
 'For every NRFI_LEAN, TOP_1ST and BOTTOM_1ST must each independently be NRFI_HALF_PASS with own current-run evidence and sufficient data. ACCEPTABLE, UNCERTAIN or FAIL on either half forbids NRFI_LEAN; one dominant pitcher cannot compensate the other half.',
 'CRITICAL',true,'["sports_reasoning_packets","evidence","nrfi_bilateral_legacy_review"]'::jsonb),
('@NRFiPrensa','PR-P5-BILATERAL-NO-COMP','P5','Bilateral conjunction / no compensation',
 'SO_MEDIA_POSITIVE_NRFI and Final Pregame Seal PASS require exactly two independent F7-Q halves, TOP and BOTTOM, each NRFI_HALF_PASS with complete F7-Q, sufficient data and own technical evidence. No cross-half compensation is legal.',
 'CRITICAL',true,'["nrfiprensa_f7q","nrfiprensa_phase_state","nrfiprensa_final_seals","nrfi_bilateral_legacy_review"]'::jsonb)
on conflict(system_id,check_id) do update
set rule_text=excluded.rule_text,default_severity=excluded.default_severity,required=excluded.required,target_objects=excluded.target_objects;

update public.system_auditor_authority
set migrations_required_through=45,
    metadata=(coalesce(metadata,'{}'::jsonb)-'menu'-'target_menu')||jsonb_build_object(
      'menu',jsonb_build_object('1','@NRFiPrensa','2','@NRFImetrica','3','@DepuracionMLB'),
      'target_menu',jsonb_build_object('1','@NRFiPrensa','2','@NRFImetrica','3','@DepuracionMLB'),
      'bilateral_no_compensation_audit_required',true),
    updated_at=now()
where protocol_id='SYSTEM_AUDITOR_V1';

update public.agent_registry
set metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('database_migrations_required_through',45,'legacy_nrfi_without_bilateral_proof_quarantined',true)
where agent_id='@NRFImetrica';

update public.nrfiprensa_authority
set metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('database_migrations_required_through',45,'legacy_positive_without_bilateral_proof_quarantined',true),updated_at=now()
where agent_id='@NRFiPrensa';
