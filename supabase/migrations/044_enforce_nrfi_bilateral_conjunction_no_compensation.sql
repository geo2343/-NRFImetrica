-- Migration 044 — bilateral NRFI conjunction / no compensation
-- Applied physically to Supabase project yejaollmavoudbxnbpll.

alter table public.sports_reasoning_packets add column if not exists top_half_verdict text;
alter table public.sports_reasoning_packets add column if not exists bottom_half_verdict text;

do $$ begin
  if not exists(select 1 from pg_constraint where conname='sports_reasoning_packets_top_half_verdict_check') then
    alter table public.sports_reasoning_packets add constraint sports_reasoning_packets_top_half_verdict_check
      check (top_half_verdict is null or top_half_verdict in ('NRFI_HALF_PASS','NRFI_HALF_ACCEPTABLE','NRFI_HALF_UNCERTAIN','NRFI_HALF_FAIL'));
  end if;
  if not exists(select 1 from pg_constraint where conname='sports_reasoning_packets_bottom_half_verdict_check') then
    alter table public.sports_reasoning_packets add constraint sports_reasoning_packets_bottom_half_verdict_check
      check (bottom_half_verdict is null or bottom_half_verdict in ('NRFI_HALF_PASS','NRFI_HALF_ACCEPTABLE','NRFI_HALF_UNCERTAIN','NRFI_HALF_FAIL'));
  end if;
end $$;

create or replace function public.nrfim_enforce_bilateral_conjunction()
returns trigger language plpgsql as $$
declare
  req text[]:=array['pitcher','opponent_top_order','splits','bb','hr','traffic','first_inning','current_form','matchup','material_run_path','data_quality','evidence_ids','half_verdict','rationale'];
  eid text; topv text; botv text;
begin
  if new.protocol_id<>'NRFIMETRICA_MOTHER_V3_AUTONOMOUS' or new.status<>'ANALYSIS_COMPLETE' then return new; end if;
  topv:=upper(coalesce(new.top_1st_analysis->>'half_verdict',new.top_half_verdict,''));
  botv:=upper(coalesce(new.bottom_1st_analysis->>'half_verdict',new.bottom_half_verdict,''));
  new.top_half_verdict:=nullif(topv,'');
  new.bottom_half_verdict:=nullif(botv,'');
  if topv not in ('NRFI_HALF_PASS','NRFI_HALF_ACCEPTABLE','NRFI_HALF_UNCERTAIN','NRFI_HALF_FAIL')
     or botv not in ('NRFI_HALF_PASS','NRFI_HALF_ACCEPTABLE','NRFI_HALF_UNCERTAIN','NRFI_HALF_FAIL') then
    raise exception 'NRFIM_BILATERAL_HALF_VERDICTS_REQUIRED' using errcode='23514';
  end if;
  if not (new.top_1st_analysis ?& req) or not (new.bottom_1st_analysis ?& req) then
    raise exception 'NRFIM_EACH_HALF_REQUIRES_PITCHER_TOPORDER_SPLITS_BB_HR_TRAFFIC_1ST_FORM_MATCHUP_RISK_EVIDENCE' using errcode='23514';
  end if;
  if jsonb_typeof(new.top_1st_analysis->'evidence_ids')<>'array' or jsonb_array_length(new.top_1st_analysis->'evidence_ids')=0
     or jsonb_typeof(new.bottom_1st_analysis->'evidence_ids')<>'array' or jsonb_array_length(new.bottom_1st_analysis->'evidence_ids')=0 then
    raise exception 'NRFIM_EACH_HALF_REQUIRES_OWN_EVIDENCE' using errcode='23514';
  end if;
  for eid in select jsonb_array_elements_text(new.top_1st_analysis->'evidence_ids') loop
    if not eid=any(coalesce(new.evidence_ids,'{}')) or not exists(select 1 from public.evidence e where e.evidence_id=eid and e.run_id=new.run_id and e.game_id=new.game_id) then
      raise exception 'NRFIM_TOP_HALF_EVIDENCE_NOT_CURRENT_RUN_GAME:%',eid using errcode='23514';
    end if;
  end loop;
  for eid in select jsonb_array_elements_text(new.bottom_1st_analysis->'evidence_ids') loop
    if not eid=any(coalesce(new.evidence_ids,'{}')) or not exists(select 1 from public.evidence e where e.evidence_id=eid and e.run_id=new.run_id and e.game_id=new.game_id) then
      raise exception 'NRFIM_BOTTOM_HALF_EVIDENCE_NOT_CURRENT_RUN_GAME:%',eid using errcode='23514';
    end if;
  end loop;
  if topv='NRFI_HALF_PASS' and upper(coalesce(new.top_1st_analysis->>'data_quality',''))<>'SUFFICIENT' then
    raise exception 'NRFIM_TOP_HALF_PASS_REQUIRES_SUFFICIENT_DATA' using errcode='23514';
  end if;
  if botv='NRFI_HALF_PASS' and upper(coalesce(new.bottom_1st_analysis->>'data_quality',''))<>'SUFFICIENT' then
    raise exception 'NRFIM_BOTTOM_HALF_PASS_REQUIRES_SUFFICIENT_DATA' using errcode='23514';
  end if;
  if new.sports_verdict='NRFI_LEAN' then
    if topv<>'NRFI_HALF_PASS' or botv<>'NRFI_HALF_PASS' then
      raise exception 'NRFIM_NRFI_LEAN_REQUIRES_TWO_INDEPENDENT_HALF_PASSES:NO_COMPENSATION:%/%',topv,botv using errcode='23514';
    end if;
    if upper(coalesce(new.central_nrfi_case->>'joint_condition',''))<>'TOP_AND_BOTTOM'
       or lower(coalesce(new.central_nrfi_case->>'no_compensation',''))<>'true' then
      raise exception 'NRFIM_NRFI_LEAN_REQUIRES_EXPLICIT_TOP_AND_BOTTOM_NO_COMPENSATION' using errcode='23514';
    end if;
  end if;
  new.packet_payload:=coalesce(new.packet_payload,'{}'::jsonb)||jsonb_build_object('bilateral_conjunction_rule',jsonb_build_object('version','BILATERAL-1.0','logic','TOP_1ST_NO_RUN AND BOTTOM_1ST_NO_RUN','top_half_verdict',topv,'bottom_half_verdict',botv,'no_compensation',true));
  return new;
end $$;

drop trigger if exists trg_00_nrfim_bilateral_conjunction on public.sports_reasoning_packets;
create trigger trg_00_nrfim_bilateral_conjunction before insert or update on public.sports_reasoning_packets for each row execute function public.nrfim_enforce_bilateral_conjunction();

alter table public.nrfiprensa_f7q add column if not exists half_verdict text;
alter table public.nrfiprensa_f7q add column if not exists half_rationale text;

do $$ begin
  if not exists(select 1 from pg_constraint where conname='nrfiprensa_f7q_half_verdict_check') then
    alter table public.nrfiprensa_f7q add constraint nrfiprensa_f7q_half_verdict_check
      check (half_verdict is null or half_verdict in ('NRFI_HALF_PASS','NRFI_HALF_ACCEPTABLE','NRFI_HALF_UNCERTAIN','NRFI_HALF_FAIL'));
  end if;
end $$;

create or replace function public.nrfiprensa_enforce_half_independence()
returns trigger language plpgsql as $$
declare req text[]:=array['pitcher','opponent_top_order','splits','bb','hr','traffic','first_inning','current_form','matchup','material_run_path','data_quality','evidence_ids']; eid text; hv text;
begin
  hv:=upper(coalesce(new.half_verdict,new.metrics_payload->>'half_verdict',''));
  new.half_verdict:=nullif(hv,'');
  new.half_rationale:=coalesce(nullif(trim(new.half_rationale),''),nullif(trim(new.metrics_payload->>'half_rationale'),''));
  if hv not in ('NRFI_HALF_PASS','NRFI_HALF_ACCEPTABLE','NRFI_HALF_UNCERTAIN','NRFI_HALF_FAIL') then raise exception 'NRFIPRENSA_F7Q_REQUIRES_INDEPENDENT_HALF_VERDICT' using errcode='23514'; end if;
  if coalesce(new.half_rationale,'')='' then raise exception 'NRFIPRENSA_F7Q_REQUIRES_HALF_RATIONALE' using errcode='23514'; end if;
  if not (coalesce(new.metrics_payload,'{}'::jsonb) ?& req) then raise exception 'NRFIPRENSA_EACH_HALF_REQUIRES_PITCHER_TOPORDER_SPLITS_BB_HR_TRAFFIC_1ST_FORM_MATCHUP_RISK_EVIDENCE' using errcode='23514'; end if;
  if jsonb_typeof(new.metrics_payload->'evidence_ids')<>'array' or jsonb_array_length(new.metrics_payload->'evidence_ids')=0 then raise exception 'NRFIPRENSA_EACH_HALF_REQUIRES_OWN_EVIDENCE' using errcode='23514'; end if;
  for eid in select jsonb_array_elements_text(new.metrics_payload->'evidence_ids') loop
    if not exists(select 1 from public.nrfiprensa_evidence e where e.evidence_id=eid and e.run_id=new.run_id and e.game_id=new.game_id and e.lane='TECHNICAL_DATA') then raise exception 'NRFIPRENSA_HALF_TECHNICAL_EVIDENCE_INVALID:%',eid using errcode='23514'; end if;
  end loop;
  if hv='NRFI_HALF_PASS' then
    if upper(coalesce(new.metrics_payload->>'data_quality',''))<>'SUFFICIENT' then raise exception 'NRFIPRENSA_HALF_PASS_REQUIRES_SUFFICIENT_DATA' using errcode='23514'; end if;
    if not new.official_b1_b5 or new.osr_status in ('GOVERNING','UNCERTAIN') or new.q1<>'PASS' or new.q2<>'PASS' or new.q3<>'PASS' or new.q4<>'PASS' or new.q5<>'PASS' or new.q6<>'PASS' or new.q7<>'PASS' or new.q8<>'PASS' or new.q9<>'PASS' or new.q10<>'PASS' or new.q11<>'PASS' or new.q12<>'PASS' then
      raise exception 'NRFIPRENSA_HALF_PASS_REQUIRES_COMPLETE_INDEPENDENT_F7Q_PASS' using errcode='23514';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_00_nrfiprensa_half_independence on public.nrfiprensa_f7q;
create trigger trg_00_nrfiprensa_half_independence before insert or update on public.nrfiprensa_f7q for each row execute function public.nrfiprensa_enforce_half_independence();

create or replace function public.nrfiprensa_enforce_positive_bilateral_conjunction()
returns trigger language plpgsql as $$
declare cnt integer; sm text;
begin
  if new.phase_id<>'F8' then return new; end if;
  sm:=upper(coalesce(new.payload->>'so_media_status',''));
  if sm='SO_MEDIA_POSITIVE_NRFI' then
    select count(*) into cnt from public.nrfiprensa_f7q q where q.run_id=new.run_id and q.game_id=new.game_id and q.half_verdict='NRFI_HALF_PASS';
    if cnt<>2 then raise exception 'NRFIPRENSA_POSITIVE_REQUIRES_TWO_INDEPENDENT_HALF_PASSES:NO_COMPENSATION:%',cnt using errcode='23514'; end if;
    new.payload:=coalesce(new.payload,'{}'::jsonb)||jsonb_build_object('bilateral_conjunction_rule',jsonb_build_object('version','BILATERAL-1.0','logic','TOP_1ST_NO_RUN AND BOTTOM_1ST_NO_RUN','no_compensation',true));
  end if;
  return new;
end $$;

drop trigger if exists trg_00_nrfiprensa_positive_bilateral on public.nrfiprensa_phase_state;
create trigger trg_00_nrfiprensa_positive_bilateral before insert or update on public.nrfiprensa_phase_state for each row execute function public.nrfiprensa_enforce_positive_bilateral_conjunction();

create or replace function public.nrfiprensa_enforce_final_bilateral_conjunction()
returns trigger language plpgsql as $$
declare cnt integer;
begin
  if new.status='PASS' then
    select count(*) into cnt from public.nrfiprensa_f7q q where q.run_id=new.run_id and q.game_id=new.game_id and q.half_verdict='NRFI_HALF_PASS';
    if cnt<>2 then raise exception 'NRFIPRENSA_FINAL_SEAL_REQUIRES_TWO_INDEPENDENT_HALF_PASSES:NO_COMPENSATION:%',cnt using errcode='23514'; end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_00_nrfiprensa_final_bilateral on public.nrfiprensa_final_seals;
create trigger trg_00_nrfiprensa_final_bilateral before insert or update on public.nrfiprensa_final_seals for each row execute function public.nrfiprensa_enforce_final_bilateral_conjunction();

alter table public.nrfiprensa_authority add column if not exists metadata jsonb not null default '{}'::jsonb;
update public.nrfiprensa_authority set agent_version='V0.2-AGENT-1.1',kernel_version='NRFIPRENSA-KERNEL-0.2-BILATERAL-CONJUNCTION',metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('bilateral_independent_half_approval_required',true,'no_compensation_between_halves',true,'half_pass_status','NRFI_HALF_PASS','positive_requires_two_half_passes',true),updated_at=now() where agent_id='@NRFiPrensa';
update public.agent_registry set agent_version='MOTHER-V3-AGENT-1.6',kernel_version='NRFIM-KERNEL-1.1-BILATERAL-CONJUNCTION',metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('database_migrations_required_through',44,'bilateral_independent_half_approval_required',true,'no_compensation_between_halves',true,'nrfi_lean_requires_top_half_pass',true,'nrfi_lean_requires_bottom_half_pass',true) where agent_id='@NRFImetrica';
