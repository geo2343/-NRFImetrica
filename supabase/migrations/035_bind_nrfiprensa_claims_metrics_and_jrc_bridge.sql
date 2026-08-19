-- Applied physically to Supabase project yejaollmavoudbxnbpll.

create table if not exists public.nrfiprensa_claims (
 claim_id text primary key, run_id text not null, game_id text not null,
 claim_kind text not null check (claim_kind in ('FACTUAL','ANALYST_ARGUMENT')), claim_text text not null, evidence_ids text[] not null,
 data_status text not null check (data_status in ('CONFIRMADO','CORROBORADO','PENDIENTE','NO_RESUELTO','NO_APLICA')),
 fact_confidence text check (fact_confidence in ('K3','K2','K1','K0') or fact_confidence is null), materiality text check (materiality in ('M3','M2','M1','M0') or materiality is null),
 as_of timestamptz not null default now(), claim_hash text not null check (claim_hash ~ '^[0-9a-f]{64}$'),
 foreign key(run_id,game_id) references public.nrfiprensa_games(run_id,game_id) on delete cascade);

create table if not exists public.nrfiprensa_claim_evaluations (
 claim_id text primary key references public.nrfiprensa_claims(claim_id) on delete cascade, run_id text not null, game_id text not null,
 metric_question text not null, baseline text not null, recent_window text not null, denominator text not null, split_context text not null, technical_evidence_ids text[] not null,
 f6_result text not null check (f6_result in ('CONFIRMADA','PARCIALMENTE_CONFIRMADA','NO_CONFIRMADA','CONTRADICHA','NO_COMPROBABLE')),
 f7_materiality text not null check (f7_materiality in ('GOVERNING_NRFI','MATERIAL_NRFI','SECONDARY_NRFI','DESCRIPTIVE_ONLY','REFUTED_AS_NRFI_SIGNAL','UNCERTAIN')),
 half text check (half in ('TOP','BOTTOM','BOTH') or half is null), mechanism text not null, owner text, limitations text not null, as_of timestamptz not null default now(),
 foreign key(run_id,game_id) references public.nrfiprensa_games(run_id,game_id) on delete cascade);

create or replace function public.nrfiprensa_validate_evidence_ids(p_run text,p_game text,p_ids text[],technical_only boolean default false)
returns boolean language plpgsql stable as $$
declare eid text;
begin
 if p_ids is null or array_length(p_ids,1) is null then return false; end if;
 foreach eid in array p_ids loop
   if not exists(select 1 from public.nrfiprensa_evidence e where e.evidence_id=eid and e.run_id=p_run and e.game_id=p_game and (not technical_only or e.lane='TECHNICAL_DATA')) then return false; end if;
 end loop; return true;
end $$;

create or replace function public.nrfiprensa_enforce_claim()
returns trigger language plpgsql as $$
declare bad integer;
begin
 new.as_of:=now();
 if not public.nrfiprensa_validate_evidence_ids(new.run_id,new.game_id,new.evidence_ids,false) then raise exception 'NRFIPRENSA_CLAIM_EVIDENCE_INVALID_OR_EMPTY' using errcode='23514'; end if;
 if new.claim_kind='FACTUAL' then
   select count(*) into bad from unnest(new.evidence_ids) eid join public.nrfiprensa_evidence e on e.evidence_id=eid where e.lane not in ('A_FACTUAL','TECHNICAL_DATA');
   if bad>0 then raise exception 'NRFIPRENSA_FACTUAL_CLAIM_CANNOT_USE_ANALYST_OR_SOCIAL_AS_FACT' using errcode='23514'; end if;
 elsif new.claim_kind='ANALYST_ARGUMENT' then
   if not exists(select 1 from unnest(new.evidence_ids) eid join public.nrfiprensa_evidence e on e.evidence_id=eid where e.lane='B_ANALYST') then raise exception 'NRFIPRENSA_ANALYST_ARGUMENT_REQUIRES_LANE_B_EVIDENCE' using errcode='23514'; end if;
 end if; return new;
end $$;

drop trigger if exists trg_nrfiprensa_claim_guard on public.nrfiprensa_claims;
create trigger trg_nrfiprensa_claim_guard before insert or update on public.nrfiprensa_claims for each row execute function public.nrfiprensa_enforce_claim();

create or replace function public.nrfiprensa_enforce_claim_evaluation()
returns trigger language plpgsql as $$
declare c public.nrfiprensa_claims%rowtype;
begin
 new.as_of:=now(); select * into c from public.nrfiprensa_claims where claim_id=new.claim_id;
 if not found or c.run_id<>new.run_id or c.game_id<>new.game_id then raise exception 'NRFIPRENSA_EVALUATION_CLAIM_LINEAGE_MISMATCH' using errcode='23514'; end if;
 if new.f6_result<>'NO_COMPROBABLE' and not public.nrfiprensa_validate_evidence_ids(new.run_id,new.game_id,new.technical_evidence_ids,true) then raise exception 'NRFIPRENSA_F6_REQUIRES_TECHNICAL_EVIDENCE' using errcode='23514'; end if;
 if trim(new.denominator)='' or trim(new.recent_window)='' or trim(new.split_context)='' then raise exception 'NRFIPRENSA_SAMPLE_WINDOW_SPLIT_DENOMINATOR_REQUIRED' using errcode='23514'; end if;
 return new;
end $$;

drop trigger if exists trg_nrfiprensa_claim_evaluation_guard on public.nrfiprensa_claim_evaluations;
create trigger trg_nrfiprensa_claim_evaluation_guard before insert or update on public.nrfiprensa_claim_evaluations for each row execute function public.nrfiprensa_enforce_claim_evaluation();

create or replace function public.nrfiprensa_validate_phase_evidence()
returns trigger language plpgsql as $$
begin
 if new.phase_id in ('F1','F2','F3','F5','F6','F7','F8') then
   if not public.nrfiprensa_validate_evidence_ids(new.run_id,new.game_id,new.evidence_ids,false) then raise exception 'NRFIPRENSA_PHASE_REQUIRES_CURRENT_RUN_GAME_EVIDENCE:%',new.phase_id using errcode='23514'; end if;
 elsif array_length(new.evidence_ids,1) is not null and not public.nrfiprensa_validate_evidence_ids(new.run_id,new.game_id,new.evidence_ids,false) then raise exception 'NRFIPRENSA_PHASE_EVIDENCE_LINEAGE_INVALID:%',new.phase_id using errcode='23514'; end if;
 return new;
end $$;

drop trigger if exists trg_nrfiprensa_phase_evidence_guard on public.nrfiprensa_phase_state;
create trigger trg_nrfiprensa_phase_evidence_guard before insert or update on public.nrfiprensa_phase_state for each row execute function public.nrfiprensa_validate_phase_evidence();

create or replace function public.nrfiprensa_enforce_handoff_claim_burden()
returns trigger language plpgsql as $$
declare unresolved integer;
begin
 if new.disposition like 'REVIEW_PRIORITY_%' then
   select count(*) into unresolved from public.nrfiprensa_claims c where c.run_id=new.run_id and c.game_id=new.game_id and c.materiality in ('M2','M3') and not exists(select 1 from public.nrfiprensa_claim_evaluations x where x.claim_id=c.claim_id and x.run_id=c.run_id and x.game_id=c.game_id);
   if unresolved>0 then raise exception 'NRFIPRENSA_REVIEW_PRIORITY_HAS_UNEVALUATED_MATERIAL_CLAIMS:%',unresolved using errcode='23514'; end if;
 end if; return new;
end $$;

drop trigger if exists trg_nrfiprensa_handoff_claim_burden on public.nrfiprensa_handoffs;
create trigger trg_nrfiprensa_handoff_claim_burden before insert or update on public.nrfiprensa_handoffs for each row execute function public.nrfiprensa_enforce_handoff_claim_burden();

create or replace function public.nrfiprensa_enforce_f9_jrc_bridge()
returns trigger language plpgsql as $$
declare jrun text; jgame text; f8time timestamptz;
begin
 if new.phase_id<>'F9' then return new; end if;
 if upper(coalesce(new.payload->>'jrc_status',''))='JRC_NOT_AVAILABLE' then return new; end if;
 jrun:=new.payload->>'jrc_run_id'; jgame:=coalesce(new.payload->>'jrc_game_id',new.game_id);
 if coalesce(jrun,'')='' then raise exception 'NRFIPRENSA_F9_REQUIRES_JRC_RUN_OR_JRC_NOT_AVAILABLE' using errcode='23514'; end if;
 select submitted_at into f8time from public.nrfiprensa_phase_state where run_id=new.run_id and game_id=new.game_id and phase_id='F8' and frozen=true;
 if f8time is null then raise exception 'NRFIPRENSA_F9_NO_F8_FREEZE' using errcode='23514'; end if;
 if not exists(select 1 from public.sports_reasoning_packets p where p.run_id=jrun and p.game_id=jgame and p.freeze_timestamp is not null and p.created_at>=f8time) then raise exception 'NRFIPRENSA_F9_JRC_PACKET_NOT_PHYSICALLY_AVAILABLE_AFTER_F8_FREEZE' using errcode='23514'; end if;
 return new;
end $$;

drop trigger if exists trg_nrfiprensa_f9_jrc_bridge on public.nrfiprensa_phase_state;
create trigger trg_nrfiprensa_f9_jrc_bridge before insert or update on public.nrfiprensa_phase_state for each row execute function public.nrfiprensa_enforce_f9_jrc_bridge();
