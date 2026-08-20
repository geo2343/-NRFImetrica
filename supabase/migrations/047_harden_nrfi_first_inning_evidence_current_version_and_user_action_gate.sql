-- Mirror of physically applied migration: harden_nrfi_first_inning_evidence_current_version_and_user_action_gate

create table if not exists public.sports_evidence_annotations (
  annotation_id uuid primary key default gen_random_uuid(),
  evidence_id text not null references public.evidence(evidence_id) on delete cascade,
  run_id text not null,
  game_id text not null,
  half text not null check (half in ('TOP_1ST','BOTTOM_1ST','BOTH')),
  evidence_kind text not null check (evidence_kind in ('FIRST_INNING_DIRECT','CURRENT_VERSION_DIRECT','MATCHUP_DIRECT','FULL_GAME_PROXY','CONTEXT_ONLY')),
  quality text not null check (quality in ('HIGH','MEDIUM','LOW')),
  basis_text text not null,
  created_at timestamptz not null default clock_timestamp(),
  unique(evidence_id,half,evidence_kind)
);

create or replace function public.nrfim_validate_sports_evidence_annotation()
returns trigger language plpgsql as $$
declare e public.evidence%rowtype; c text;
begin
  select * into e from public.evidence where evidence_id=new.evidence_id;
  if not found or e.run_id<>new.run_id or e.game_id<>new.game_id then raise exception 'SPORTS_EVIDENCE_ANNOTATION_LINEAGE_MISMATCH:%',new.evidence_id using errcode='23514'; end if;
  if length(btrim(coalesce(new.basis_text,'')))<25 then raise exception 'SPORTS_EVIDENCE_ANNOTATION_BASIS_TOO_THIN:%',new.evidence_id using errcode='23514'; end if;
  if new.evidence_kind='FIRST_INNING_DIRECT' then
    c:=lower(coalesce(e.payload->>'claim',''));
    if c !~ '(first[- ]inning|1st[- ]inning|primera entrada|top of (the )?first|bottom of (the )?first)' then raise exception 'FIRST_INNING_DIRECT_REQUIRES_EXPLICIT_FIRST_INNING_CLAIM:%',new.evidence_id using errcode='23514'; end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_validate_sports_evidence_annotation on public.sports_evidence_annotations;
create trigger trg_validate_sports_evidence_annotation before insert or update on public.sports_evidence_annotations for each row execute function public.nrfim_validate_sports_evidence_annotation();

create or replace function public.nrfim_latest_bilateral_nrfi_valid(p_run text,p_game text)
returns boolean language sql stable as $$
with s as (
  select * from public.sports_reasoning_packets where run_id=p_run and game_id=p_game order by version desc limit 1
)
select coalesce((select s.status='ANALYSIS_COMPLETE' and s.sports_verdict='NRFI_LEAN'
  and s.top_half_verdict='NRFI_HALF_PASS' and s.bottom_half_verdict='NRFI_HALF_PASS'
  and upper(coalesce(s.packet_payload #>> '{bilateral_conjunction_rule,version}',''))='BILATERAL-1.1'
  and lower(coalesce(s.packet_payload #>> '{bilateral_conjunction_rule,no_compensation}','false'))='true'
  and exists(select 1 from public.sports_evidence_annotations a where a.run_id=s.run_id and a.game_id=s.game_id and a.evidence_id=any(coalesce(s.evidence_ids,'{}')) and a.half in ('TOP_1ST','BOTH') and a.evidence_kind='FIRST_INNING_DIRECT' and a.quality in ('HIGH','MEDIUM'))
  and exists(select 1 from public.sports_evidence_annotations a where a.run_id=s.run_id and a.game_id=s.game_id and a.evidence_id=any(coalesce(s.evidence_ids,'{}')) and a.half in ('TOP_1ST','BOTH') and a.evidence_kind='CURRENT_VERSION_DIRECT' and a.quality in ('HIGH','MEDIUM'))
  and exists(select 1 from public.sports_evidence_annotations a where a.run_id=s.run_id and a.game_id=s.game_id and a.evidence_id=any(coalesce(s.evidence_ids,'{}')) and a.half in ('BOTTOM_1ST','BOTH') and a.evidence_kind='FIRST_INNING_DIRECT' and a.quality in ('HIGH','MEDIUM'))
  and exists(select 1 from public.sports_evidence_annotations a where a.run_id=s.run_id and a.game_id=s.game_id and a.evidence_id=any(coalesce(s.evidence_ids,'{}')) and a.half in ('BOTTOM_1ST','BOTH') and a.evidence_kind='CURRENT_VERSION_DIRECT' and a.quality in ('HIGH','MEDIUM')) from s),false)
$$;

create or replace function public.nrfim_enforce_bilateral_conjunction()
returns trigger language plpgsql as $$
declare
  req text[]:=array['pitcher','opponent_top_order','splits','bb','hr','traffic','first_inning','current_form','matchup','material_run_path','data_quality','evidence_ids','half_verdict','rationale','first_inning_evidence_ids','current_version_evidence_ids','current_version_status','material_run_path_status','uncertainty_flags'];
  eid text; topv text; botv text; h jsonb; half_name text; cv text; mr text; flag text; severe boolean;
begin
  if new.protocol_id<>'NRFIMETRICA_MOTHER_V3_AUTONOMOUS' or new.status<>'ANALYSIS_COMPLETE' then return new; end if;
  topv:=upper(coalesce(new.top_1st_analysis->>'half_verdict',new.top_half_verdict,''));
  botv:=upper(coalesce(new.bottom_1st_analysis->>'half_verdict',new.bottom_half_verdict,''));
  new.top_half_verdict:=nullif(topv,''); new.bottom_half_verdict:=nullif(botv,'');
  if topv not in ('NRFI_HALF_PASS','NRFI_HALF_ACCEPTABLE','NRFI_HALF_UNCERTAIN','NRFI_HALF_FAIL') or botv not in ('NRFI_HALF_PASS','NRFI_HALF_ACCEPTABLE','NRFI_HALF_UNCERTAIN','NRFI_HALF_FAIL') then raise exception 'NRFIM_BILATERAL_HALF_VERDICTS_REQUIRED' using errcode='23514'; end if;
  if not (new.top_1st_analysis ?& req) or not (new.bottom_1st_analysis ?& req) then raise exception 'NRFIM_EACH_HALF_REQUIRES_DIRECT_1ST_CURRENT_VERSION_AND_CAUSAL_FIELDS' using errcode='23514'; end if;
  for h,half_name in select new.top_1st_analysis,'TOP_1ST' union all select new.bottom_1st_analysis,'BOTTOM_1ST' loop
    if jsonb_typeof(h->'evidence_ids')<>'array' or jsonb_array_length(h->'evidence_ids')=0 or jsonb_typeof(h->'first_inning_evidence_ids')<>'array' or jsonb_array_length(h->'first_inning_evidence_ids')=0 or jsonb_typeof(h->'current_version_evidence_ids')<>'array' or jsonb_array_length(h->'current_version_evidence_ids')=0 or jsonb_typeof(h->'uncertainty_flags')<>'array' then raise exception 'NRFIM_HALF_EVIDENCE_ARRAYS_REQUIRED:%',half_name using errcode='23514'; end if;
    cv:=upper(coalesce(h->>'current_version_status','')); mr:=upper(coalesce(h->>'material_run_path_status',''));
    if cv not in ('STABLE','CONDITIONED','UNKNOWN') then raise exception 'NRFIM_CURRENT_VERSION_STATUS_INVALID:%:%',half_name,cv using errcode='23514'; end if;
    if mr not in ('LOW','CONTROLLED','MATERIAL','HIGH') then raise exception 'NRFIM_MATERIAL_RUN_PATH_STATUS_INVALID:%:%',half_name,mr using errcode='23514'; end if;
    for eid in select jsonb_array_elements_text(h->'evidence_ids') loop
      if not eid=any(coalesce(new.evidence_ids,'{}')) or not exists(select 1 from public.evidence e where e.evidence_id=eid and e.run_id=new.run_id and e.game_id=new.game_id) then raise exception 'NRFIM_HALF_EVIDENCE_NOT_CURRENT_RUN_GAME:%:%',half_name,eid using errcode='23514'; end if;
    end loop;
    for eid in select jsonb_array_elements_text(h->'first_inning_evidence_ids') loop
      if not exists(select 1 from public.sports_evidence_annotations a where a.evidence_id=eid and a.run_id=new.run_id and a.game_id=new.game_id and a.half in (half_name,'BOTH') and a.evidence_kind='FIRST_INNING_DIRECT' and a.quality in ('HIGH','MEDIUM')) then raise exception 'NRFIM_DIRECT_FIRST_INNING_EVIDENCE_REQUIRED:%:%',half_name,eid using errcode='23514'; end if;
    end loop;
    for eid in select jsonb_array_elements_text(h->'current_version_evidence_ids') loop
      if not exists(select 1 from public.sports_evidence_annotations a where a.evidence_id=eid and a.run_id=new.run_id and a.game_id=new.game_id and a.half in (half_name,'BOTH') and a.evidence_kind='CURRENT_VERSION_DIRECT' and a.quality in ('HIGH','MEDIUM')) then raise exception 'NRFIM_CURRENT_VERSION_DIRECT_EVIDENCE_REQUIRED:%:%',half_name,eid using errcode='23514'; end if;
    end loop;
    severe:=false;
    for flag in select upper(value) from jsonb_array_elements_text(h->'uncertainty_flags') loop
      if flag in ('MLB_DEBUT','POST_LONG_IL','ROLE_UNSTABLE','OPENER_BULK_UNCERTAINTY','FIRST_INNING_SAMPLE_ABSENT','STARTER_IDENTITY_UNCERTAIN') then severe:=true; end if;
    end loop;
    if upper(coalesce(h->>'half_verdict',''))='NRFI_HALF_PASS' and (upper(coalesce(h->>'data_quality',''))<>'SUFFICIENT' or cv<>'STABLE' or mr in ('MATERIAL','HIGH') or severe) then raise exception 'NRFIM_HALF_PASS_BLOCKED_BY_DATA_VERSION_OR_MATERIAL_RISK:%:CV=%:RISK=%:SEVERE=%',half_name,cv,mr,severe using errcode='23514'; end if;
  end loop;
  if new.sports_verdict='NRFI_LEAN' then
    if topv<>'NRFI_HALF_PASS' or botv<>'NRFI_HALF_PASS' then raise exception 'NRFIM_NRFI_LEAN_REQUIRES_TWO_INDEPENDENT_HALF_PASSES:NO_COMPENSATION:%/%',topv,botv using errcode='23514'; end if;
    if upper(coalesce(new.central_nrfi_case->>'joint_condition',''))<>'TOP_AND_BOTTOM' or lower(coalesce(new.central_nrfi_case->>'no_compensation',''))<>'true' then raise exception 'NRFIM_NRFI_LEAN_REQUIRES_EXPLICIT_TOP_AND_BOTTOM_NO_COMPENSATION' using errcode='23514'; end if;
  end if;
  new.packet_payload:=coalesce(new.packet_payload,'{}'::jsonb)||jsonb_build_object('bilateral_conjunction_rule',jsonb_build_object('version','BILATERAL-1.1','logic','TOP_1ST_NO_RUN AND BOTTOM_1ST_NO_RUN','top_half_verdict',topv,'bottom_half_verdict',botv,'no_compensation',true,'direct_first_inning_evidence_required',true,'current_version_direct_evidence_required',true,'severe_uncertainty_veto',true));
  return new;
end $$;

create or replace function public.nrfim_enforce_downstream_bilateral_gate()
returns trigger language plpgsql as $$
declare seal text; refv text;
begin
  if new.protocol_id<>'NRFIMETRICA_MOTHER_V3_AUTONOMOUS' then return new; end if;
  if new.phase_id='A6_CAUSAL_FALSIFICATION_SPORTS_SEAL' then
    seal:=upper(coalesce(new.payload #>> '{sports_seal,status}',''));
    if seal like '%NRFI%' and not public.nrfim_latest_bilateral_nrfi_valid(new.run_id,new.game_id) then raise exception 'A6_NRFI_SEAL_REQUIRES_BILATERAL_1_1_VALID_PACKET' using errcode='23514'; end if;
  elsif new.phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS' then
    refv:=upper(coalesce(new.payload->>'reformulated_verdict',''));
    if refv like 'NRFI_LEAN%' and not public.nrfim_latest_bilateral_nrfi_valid(new.run_id,new.game_id) then raise exception 'A7_NRFI_LEAN_REQUIRES_BILATERAL_1_1_VALID_PACKET' using errcode='23514'; end if;
  elsif new.phase_id='A8_MARKET_VALUE_EXECUTION' then
    if not public.nrfim_latest_bilateral_nrfi_valid(new.run_id,new.game_id) then raise exception 'A8_EXECUTION_REQUIRES_BILATERAL_1_1_VALID_PACKET' using errcode='23514'; end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_015_nrfim_downstream_bilateral_gate on public.protocol_phase_state;
create trigger trg_015_nrfim_downstream_bilateral_gate before insert or update on public.protocol_phase_state for each row execute function public.nrfim_enforce_downstream_bilateral_gate();

create or replace view public.nrfimetrica_user_action as
select d.*,public.nrfim_latest_bilateral_nrfi_valid(d.run_id,d.game_id) as bilateral_1_1_valid,
case when d.execution_status='EXECUTABLE' and public.nrfim_latest_bilateral_nrfi_valid(d.run_id,d.game_id) then 'BET_APPROVED'
     when d.sports_verdict='NRFI_LEAN' and not public.nrfim_latest_bilateral_nrfi_valid(d.run_id,d.game_id) then 'REANALYSIS_REQUIRED_DO_NOT_BET'
     when d.sports_status='SPORTS_CANDIDATE' then 'RESEARCH_CANDIDATE_DO_NOT_BET'
     else 'DO_NOT_BET' end as user_action,
(d.execution_status='EXECUTABLE' and public.nrfim_latest_bilateral_nrfi_valid(d.run_id,d.game_id)) as bet_allowed
from public.nrfimetrica_game_dual_status d;
