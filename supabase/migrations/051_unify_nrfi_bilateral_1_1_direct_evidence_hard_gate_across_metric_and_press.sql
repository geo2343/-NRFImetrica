-- Migration 051 — unify BILATERAL-1.1 direct-evidence hard gate across @NRFImetrica and @NRFiPrensa
-- Applied physically to Supabase project yejaollmavoudbxnbpll.

create table if not exists public.nrfiprensa_evidence_annotations (
  annotation_id uuid primary key default gen_random_uuid(),
  evidence_id text not null references public.nrfiprensa_evidence(evidence_id) on delete cascade,
  run_id text not null,game_id text not null,
  half text not null check (half in ('TOP_1ST','BOTTOM_1ST','BOTH')),
  evidence_kind text not null check (evidence_kind in ('FIRST_INNING_DIRECT','CURRENT_VERSION_DIRECT','MATCHUP_DIRECT','CONTEXT_ONLY')),
  quality text not null check (quality in ('HIGH','MEDIUM','LOW')),
  basis_text text not null,created_at timestamptz not null default clock_timestamp(),
  unique(evidence_id,half,evidence_kind)
);

create or replace function public.nrfiprensa_validate_evidence_annotation()
returns trigger language plpgsql as $$
declare e public.nrfiprensa_evidence%rowtype; c text;
begin
  select * into e from public.nrfiprensa_evidence where evidence_id=new.evidence_id;
  if not found or e.run_id<>new.run_id or e.game_id<>new.game_id then raise exception 'NRFIPRENSA_EVIDENCE_ANNOTATION_LINEAGE_MISMATCH:%',new.evidence_id using errcode='23514'; end if;
  if length(btrim(coalesce(new.basis_text,'')))<25 then raise exception 'NRFIPRENSA_EVIDENCE_ANNOTATION_BASIS_TOO_THIN:%',new.evidence_id using errcode='23514'; end if;
  if new.evidence_kind='FIRST_INNING_DIRECT' then
    c:=lower(coalesce(e.payload->>'claim',e.payload->>'fact',e.source_title,''));
    if c !~ '(first[- ]inning|1st[- ]inning|primera entrada|top of (the )?first|bottom of (the )?first)' then raise exception 'NRFIPRENSA_FIRST_INNING_DIRECT_REQUIRES_EXPLICIT_FIRST_INNING_CLAIM:%',new.evidence_id using errcode='23514'; end if;
  end if;
  return new;
end $$;
drop trigger if exists trg_nrfiprensa_validate_evidence_annotation on public.nrfiprensa_evidence_annotations;
create trigger trg_nrfiprensa_validate_evidence_annotation before insert or update on public.nrfiprensa_evidence_annotations for each row execute function public.nrfiprensa_validate_evidence_annotation();

create or replace function public.nrfiprensa_enforce_half_independence()
returns trigger language plpgsql as $$
declare
  req text[]:=array['pitcher','opponent_top_order','splits','bb','hr','traffic','first_inning','current_form','matchup','material_run_path','data_quality','evidence_ids','first_inning_evidence_ids','current_version_evidence_ids','current_version_status','material_run_path_status','uncertainty_flags'];
  eid text; hv text; cv text; mr text; flag text; severe boolean; half_name text;
begin
  hv:=upper(coalesce(new.half_verdict,new.metrics_payload->>'half_verdict',''));
  new.half_verdict:=nullif(hv,'');
  new.half_rationale:=coalesce(nullif(trim(new.half_rationale),''),nullif(trim(new.metrics_payload->>'half_rationale'),''));
  half_name:=case when new.half='TOP' then 'TOP_1ST' else 'BOTTOM_1ST' end;
  if hv not in ('NRFI_HALF_PASS','NRFI_HALF_ACCEPTABLE','NRFI_HALF_UNCERTAIN','NRFI_HALF_FAIL') then raise exception 'NRFIPRENSA_F7Q_REQUIRES_INDEPENDENT_HALF_VERDICT' using errcode='23514'; end if;
  if coalesce(new.half_rationale,'')='' then raise exception 'NRFIPRENSA_F7Q_REQUIRES_HALF_RATIONALE' using errcode='23514'; end if;
  if not (coalesce(new.metrics_payload,'{}'::jsonb) ?& req) then raise exception 'NRFIPRENSA_EACH_HALF_REQUIRES_DIRECT_1ST_CURRENT_VERSION_AND_CAUSAL_FIELDS' using errcode='23514'; end if;
  if jsonb_typeof(new.metrics_payload->'evidence_ids')<>'array' or jsonb_array_length(new.metrics_payload->'evidence_ids')=0 or jsonb_typeof(new.metrics_payload->'first_inning_evidence_ids')<>'array' or jsonb_array_length(new.metrics_payload->'first_inning_evidence_ids')=0 or jsonb_typeof(new.metrics_payload->'current_version_evidence_ids')<>'array' or jsonb_array_length(new.metrics_payload->'current_version_evidence_ids')=0 or jsonb_typeof(new.metrics_payload->'uncertainty_flags')<>'array' then raise exception 'NRFIPRENSA_HALF_EVIDENCE_ARRAYS_REQUIRED:%',half_name using errcode='23514'; end if;
  cv:=upper(coalesce(new.metrics_payload->>'current_version_status','')); mr:=upper(coalesce(new.metrics_payload->>'material_run_path_status',''));
  if cv not in ('STABLE','CONDITIONED','UNKNOWN') then raise exception 'NRFIPRENSA_CURRENT_VERSION_STATUS_INVALID:%:%',half_name,cv using errcode='23514'; end if;
  if mr not in ('LOW','CONTROLLED','MATERIAL','HIGH') then raise exception 'NRFIPRENSA_MATERIAL_RUN_PATH_STATUS_INVALID:%:%',half_name,mr using errcode='23514'; end if;
  for eid in select jsonb_array_elements_text(new.metrics_payload->'evidence_ids') loop
    if not exists(select 1 from public.nrfiprensa_evidence e where e.evidence_id=eid and e.run_id=new.run_id and e.game_id=new.game_id and e.lane='TECHNICAL_DATA') then raise exception 'NRFIPRENSA_HALF_TECHNICAL_EVIDENCE_INVALID:%',eid using errcode='23514'; end if;
  end loop;
  for eid in select jsonb_array_elements_text(new.metrics_payload->'first_inning_evidence_ids') loop
    if not exists(select 1 from public.nrfiprensa_evidence_annotations a where a.evidence_id=eid and a.run_id=new.run_id and a.game_id=new.game_id and a.half in (half_name,'BOTH') and a.evidence_kind='FIRST_INNING_DIRECT' and a.quality in ('HIGH','MEDIUM')) then raise exception 'NRFIPRENSA_DIRECT_FIRST_INNING_EVIDENCE_REQUIRED:%:%',half_name,eid using errcode='23514'; end if;
  end loop;
  for eid in select jsonb_array_elements_text(new.metrics_payload->'current_version_evidence_ids') loop
    if not exists(select 1 from public.nrfiprensa_evidence_annotations a where a.evidence_id=eid and a.run_id=new.run_id and a.game_id=new.game_id and a.half in (half_name,'BOTH') and a.evidence_kind='CURRENT_VERSION_DIRECT' and a.quality in ('HIGH','MEDIUM')) then raise exception 'NRFIPRENSA_CURRENT_VERSION_DIRECT_EVIDENCE_REQUIRED:%:%',half_name,eid using errcode='23514'; end if;
  end loop;
  severe:=false;
  for flag in select upper(value) from jsonb_array_elements_text(new.metrics_payload->'uncertainty_flags') loop
    if flag in ('MLB_DEBUT','POST_LONG_IL','ROLE_UNSTABLE','OPENER_BULK_UNCERTAINTY','FIRST_INNING_SAMPLE_ABSENT','STARTER_IDENTITY_UNCERTAIN') then severe:=true; end if;
  end loop;
  if hv='NRFI_HALF_PASS' then
    if upper(coalesce(new.metrics_payload->>'data_quality',''))<>'SUFFICIENT' or cv<>'STABLE' or mr in ('MATERIAL','HIGH') or severe then raise exception 'NRFIPRENSA_HALF_PASS_BLOCKED_BY_DATA_VERSION_OR_MATERIAL_RISK:%:CV=%:RISK=%:SEVERE=%',half_name,cv,mr,severe using errcode='23514'; end if;
    if not new.official_b1_b5 or new.osr_status in ('GOVERNING','UNCERTAIN') or new.q1<>'PASS' or new.q2<>'PASS' or new.q3<>'PASS' or new.q4<>'PASS' or new.q5<>'PASS' or new.q6<>'PASS' or new.q7<>'PASS' or new.q8<>'PASS' or new.q9<>'PASS' or new.q10<>'PASS' or new.q11<>'PASS' or new.q12<>'PASS' then raise exception 'NRFIPRENSA_HALF_PASS_REQUIRES_COMPLETE_INDEPENDENT_F7Q_PASS' using errcode='23514'; end if;
  end if;
  new.metrics_payload:=coalesce(new.metrics_payload,'{}'::jsonb)||jsonb_build_object('bilateral_rule_version','BILATERAL-1.1','no_compensation',true,'direct_first_inning_evidence_required',true,'current_version_direct_evidence_required',true,'severe_uncertainty_veto',true);
  return new;
end $$;

drop trigger if exists trg_00_nrfiprensa_half_independence on public.nrfiprensa_f7q;
create trigger trg_00_nrfiprensa_half_independence before insert or update on public.nrfiprensa_f7q for each row execute function public.nrfiprensa_enforce_half_independence();

create or replace function public.nrfiprensa_latest_bilateral_valid(p_run text,p_game text)
returns boolean language sql stable as $$
select coalesce((select count(*)=2 from public.nrfiprensa_f7q q where q.run_id=p_run and q.game_id=p_game and q.half_verdict='NRFI_HALF_PASS' and upper(coalesce(q.metrics_payload->>'bilateral_rule_version',''))='BILATERAL-1.1' and lower(coalesce(q.metrics_payload->>'no_compensation','false'))='true'),false)
$$;

create or replace function public.nrfiprensa_enforce_positive_bilateral_conjunction()
returns trigger language plpgsql as $$
declare sm text;
begin
  if new.phase_id<>'F8' then return new; end if;
  sm:=upper(coalesce(new.payload->>'so_media_status',''));
  if sm='SO_MEDIA_POSITIVE_NRFI' then
    if not public.nrfiprensa_latest_bilateral_valid(new.run_id,new.game_id) then raise exception 'NRFIPRENSA_POSITIVE_REQUIRES_TWO_BILATERAL_1_1_HALF_PASSES:NO_COMPENSATION' using errcode='23514'; end if;
    new.payload:=coalesce(new.payload,'{}'::jsonb)||jsonb_build_object('bilateral_conjunction_rule',jsonb_build_object('version','BILATERAL-1.1','logic','TOP_1ST_NO_RUN AND BOTTOM_1ST_NO_RUN','no_compensation',true,'direct_first_inning_evidence_required',true,'current_version_direct_evidence_required',true,'severe_uncertainty_veto',true));
  end if;
  return new;
end $$;

create or replace function public.nrfiprensa_enforce_final_bilateral_conjunction()
returns trigger language plpgsql as $$
begin
  if new.status='PASS' and not public.nrfiprensa_latest_bilateral_valid(new.run_id,new.game_id) then raise exception 'NRFIPRENSA_FINAL_SEAL_REQUIRES_TWO_BILATERAL_1_1_HALF_PASSES:NO_COMPENSATION' using errcode='23514'; end if;
  return new;
end $$;

update public.agent_registry set agent_version='MOTHER-V3-AGENT-1.7',kernel_version='NRFIM-KERNEL-1.2-BILATERAL-1.1-HARD-GATE',metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('database_migrations_required_through',51,'bilateral_rule_version','BILATERAL-1.1','canonical_version_monotonic_reconciled',true) where agent_id='@NRFImetrica';
update public.nrfiprensa_authority set agent_version='V0.2-AGENT-1.2',kernel_version='NRFIPRENSA-KERNEL-0.3-BILATERAL-1.1-HARD-GATE',metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('database_migrations_required_through',51,'bilateral_rule_version','BILATERAL-1.1','direct_first_inning_evidence_per_half_required',true,'current_version_direct_evidence_per_half_required',true,'severe_uncertainty_veto',true),updated_at=now() where agent_id='@NRFiPrensa';
update public.system_auditor_authority set migrations_required_through=51,metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('bilateral_rule_version','BILATERAL-1.1','press_direct_evidence_hard_gate',true,'metric_direct_evidence_hard_gate',true),updated_at=now() where protocol_id='SYSTEM_AUDITOR_V1';
