-- Applied physically to Supabase project yejaollmavoudbxnbpll.
-- Deterministic hard gates for SO-MEDIA NRFI V0.2.

create or replace function public.nrfiprensa_json_has_key_recursive(js jsonb, forbidden text[])
returns boolean language plpgsql immutable as $$
declare k text; v jsonb;
begin
 if js is null then return false; end if;
 if jsonb_typeof(js)='object' then
   for k,v in select key,value from jsonb_each(js) loop
     if lower(k)=any(forbidden) then return true; end if;
     if jsonb_typeof(v) in ('object','array') and public.nrfiprensa_json_has_key_recursive(v,forbidden) then return true; end if;
   end loop;
 elsif jsonb_typeof(js)='array' then
   for v in select value from jsonb_array_elements(js) loop
     if jsonb_typeof(v) in ('object','array') and public.nrfiprensa_json_has_key_recursive(v,forbidden) then return true; end if;
   end loop;
 end if;
 return false;
end $$;

create or replace function public.nrfiprensa_enforce_evidence()
returns trigger language plpgsql as $$
declare fam_lane text; start_at timestamptz;
begin
 new.retrieved_at:=now();
 if new.as_of > now()+interval '1 minute' then raise exception 'NRFIPRENSA_FUTURE_AS_OF_FORBIDDEN' using errcode='23514'; end if;
 if not exists(select 1 from public.nrfiprensa_report_documents where run_id=new.run_id) then raise exception 'NRFIPRENSA_NEW_REPORT_REQUIRED_BEFORE_RESEARCH' using errcode='23514'; end if;
 select lane into fam_lane from public.nrfiprensa_source_families where source_family_id=new.source_family_id and run_id=new.run_id;
 if fam_lane is null or fam_lane<>new.lane then raise exception 'NRFIPRENSA_SOURCE_FAMILY_LANE_MISMATCH' using errcode='23514'; end if;
 select scheduled_start into start_at from public.nrfiprensa_games where run_id=new.run_id and game_id=new.game_id;
 if start_at is null then raise exception 'NRFIPRENSA_GAME_NOT_REGISTERED' using errcode='23514'; end if;
 if now()>=start_at then raise exception 'NRFIPRENSA_LIVE_EVIDENCE_CONTAMINATION_FORBIDDEN' using errcode='23514'; end if;
 if new.lane='B_ANALYST' and new.evidence_type not in ('ANALYSIS','SOCIAL_POST','VIDEO') then raise exception 'NRFIPRENSA_ANALYST_LANE_CANNOT_BE_FACTUAL_AUTHORITY' using errcode='23514'; end if;
 if new.lane='SOCIAL_TIP' and new.data_status in ('CONFIRMADO','CORROBORADO') then raise exception 'NRFIPRENSA_SOCIAL_TIP_REQUIRES_VERIFICATION_BEFORE_CONFIRMATION' using errcode='23514'; end if;
 if new.lane='TECHNICAL_DATA' and new.evidence_type<>'METRIC' then raise exception 'NRFIPRENSA_TECHNICAL_DATA_MUST_BE_METRIC' using errcode='23514'; end if;
 return new;
end $$;

drop trigger if exists trg_nrfiprensa_evidence_guard on public.nrfiprensa_evidence;
create trigger trg_nrfiprensa_evidence_guard before insert or update on public.nrfiprensa_evidence for each row execute function public.nrfiprensa_enforce_evidence();

create or replace function public.nrfiprensa_enforce_phase()
returns trigger language plpgsql as $$
declare start_at timestamptz; rt text; f8_frozen boolean; cnt integer; sm text;
begin
 new.submitted_at:=now();
 if not exists(select 1 from public.nrfiprensa_report_documents where run_id=new.run_id) then raise exception 'NRFIPRENSA_NEW_REPORT_REQUIRED_BEFORE_PHASES' using errcode='23514'; end if;
 select scheduled_start into start_at from public.nrfiprensa_games where run_id=new.run_id and game_id=new.game_id;
 if start_at is null then raise exception 'NRFIPRENSA_GAME_NOT_REGISTERED' using errcode='23514'; end if;
 if new.phase_id<>'F10' and now()>=start_at then raise exception 'NRFIPRENSA_PHASE_AFTER_FIRST_PITCH_FORBIDDEN:%',new.phase_id using errcode='23514'; end if;
 if public.nrfiprensa_json_has_key_recursive(new.payload,array['p_nrfi','model_probability','edge','ev','stake','bet_amount','execution_authority','final_pick']) then raise exception 'NRFIPRENSA_QUANTIFICATION_OR_EXECUTION_FIREWALL' using errcode='23514'; end if;
 if new.phase_id='F1' and not exists(select 1 from public.nrfiprensa_phase_state where run_id=new.run_id and game_id=new.game_id and phase_id='F0') then raise exception 'NRFIPRENSA_F1_REQUIRES_F0' using errcode='23514'; end if;
 if new.phase_id='F2' and not exists(select 1 from public.nrfiprensa_phase_state where run_id=new.run_id and game_id=new.game_id and phase_id='F1') then raise exception 'NRFIPRENSA_F2_REQUIRES_F1' using errcode='23514'; end if;
 if new.phase_id='F3' and (not exists(select 1 from public.nrfiprensa_phase_state where run_id=new.run_id and game_id=new.game_id and phase_id='F1') or not exists(select 1 from public.nrfiprensa_phase_state where run_id=new.run_id and game_id=new.game_id and phase_id='F2')) then raise exception 'NRFIPRENSA_F3_REQUIRES_F1_F2' using errcode='23514'; end if;
 if new.phase_id='F4' and not exists(select 1 from public.nrfiprensa_phase_state where run_id=new.run_id and game_id=new.game_id and phase_id='F3') then raise exception 'NRFIPRENSA_F4_REQUIRES_F3' using errcode='23514'; end if;
 if new.phase_id='F6' and not exists(select 1 from public.nrfiprensa_phase_state where run_id=new.run_id and game_id=new.game_id and phase_id='F5') then raise exception 'NRFIPRENSA_F6_REQUIRES_F5' using errcode='23514'; end if;
 if new.phase_id='F7' and not exists(select 1 from public.nrfiprensa_phase_state where run_id=new.run_id and game_id=new.game_id and phase_id='F6') then raise exception 'NRFIPRENSA_F7_REQUIRES_F6' using errcode='23514'; end if;
 if new.phase_id='F8' then
   if not exists(select 1 from public.nrfiprensa_phase_state where run_id=new.run_id and game_id=new.game_id and phase_id='F7') then raise exception 'NRFIPRENSA_F8_REQUIRES_F7' using errcode='23514'; end if;
   select count(*) into cnt from public.nrfiprensa_f7q where run_id=new.run_id and game_id=new.game_id;
   if cnt<>2 then raise exception 'NRFIPRENSA_F8_REQUIRES_BILATERAL_F7Q:%',cnt using errcode='23514'; end if;
   select status into rt from public.nrfiprensa_red_team where run_id=new.run_id and game_id=new.game_id;
   if rt is null then raise exception 'NRFIPRENSA_F8_REQUIRES_RED_TEAM' using errcode='23514'; end if;
   if public.nrfiprensa_json_has_key_recursive(new.payload,array['jrc','jrc_status','convergence','shared_evidence','independent_evidence']) then raise exception 'NRFIPRENSA_F8_CLEAN_ROOM_JRC_CONTAMINATION' using errcode='23514'; end if;
   sm:=upper(coalesce(new.payload->>'so_media_status',''));
   if sm='SO_MEDIA_STRONG_NRFI' then raise exception 'NRFIPRENSA_STRONG_DISABLED_WHILE_RESEARCH_ONLY' using errcode='23514'; end if;
   if sm='SO_MEDIA_POSITIVE_NRFI' then
     if rt not in ('RED_TEAM_CLEAR','RED_TEAM_MATERIAL') then raise exception 'NRFIPRENSA_POSITIVE_BLOCKED_BY_RED_TEAM:%',rt using errcode='23514'; end if;
     if exists(select 1 from public.nrfiprensa_f7q where run_id=new.run_id and game_id=new.game_id and (official_b1_b5=false or osr_status='GOVERNING' or q5<>'PASS' or q6<>'PASS' or q11<>'PASS')) then raise exception 'NRFIPRENSA_POSITIVE_REQUIRES_LINEUP_OSR_Q5_Q6_Q11_PASS' using errcode='23514'; end if;
   end if;
   if not new.frozen then raise exception 'NRFIPRENSA_F8_MUST_FREEZE_BEFORE_JRC' using errcode='23514'; end if;
 end if;
 if new.phase_id='F9' then
   select frozen into f8_frozen from public.nrfiprensa_phase_state where run_id=new.run_id and game_id=new.game_id and phase_id='F8';
   if coalesce(f8_frozen,false)=false then raise exception 'NRFIPRENSA_F9_REQUIRES_F8_FROZEN' using errcode='23514'; end if;
   if upper(coalesce(new.payload->>'convergence','')) in ('C3','C4') and coalesce(new.payload->>'owner','')='' then raise exception 'NRFIPRENSA_C3_C4_REQUIRE_OWNER' using errcode='23514'; end if;
 end if;
 return new;
end $$;

drop trigger if exists trg_nrfiprensa_phase_guard on public.nrfiprensa_phase_state;
create trigger trg_nrfiprensa_phase_guard before insert or update on public.nrfiprensa_phase_state for each row execute function public.nrfiprensa_enforce_phase();

create or replace function public.nrfiprensa_enforce_final_seal()
returns trigger language plpgsql as $$
declare g public.nrfiprensa_games%rowtype; rt text; cnt integer;
begin
 new.as_of_final:=now(); select * into g from public.nrfiprensa_games where run_id=new.run_id and game_id=new.game_id;
 if not found then raise exception 'NRFIPRENSA_SEAL_GAME_NOT_FOUND' using errcode='23514'; end if;
 if new.status='PASS' then
   if now()>=g.scheduled_start or g.pregame_state<>'PREGAME' then raise exception 'NRFIPRENSA_FINAL_PASS_REQUIRES_CURRENT_PREGAME' using errcode='23514'; end if;
   if g.away_pitcher_status not in ('CONFIRMED','OPENER') or g.home_pitcher_status not in ('CONFIRMED','OPENER') then raise exception 'NRFIPRENSA_FINAL_PASS_REQUIRES_CONFIRMED_FIRST_INNING_PITCHERS' using errcode='23514'; end if;
   if not new.away_starter_current or not new.home_starter_current or not new.official_lineups_match or not new.scratches_revalidated or not new.restrictions_revalidated then raise exception 'NRFIPRENSA_FINAL_PASS_FRESHNESS_LOCK_FAIL' using errcode='23514'; end if;
   select count(*) into cnt from public.nrfiprensa_f7q where run_id=new.run_id and game_id=new.game_id and official_b1_b5=true and q1='PASS' and q2='PASS' and q3='PASS' and q4='PASS' and q5='PASS' and q6='PASS' and q7='PASS' and q8='PASS' and q9='PASS' and q10='PASS' and q11='PASS' and q12='PASS' and osr_status<>'GOVERNING';
   if cnt<>2 then raise exception 'NRFIPRENSA_FINAL_PASS_REQUIRES_TWO_COMPLETE_F7Q_HALVES:%',cnt using errcode='23514'; end if;
   select status into rt from public.nrfiprensa_red_team where run_id=new.run_id and game_id=new.game_id;
   if rt not in ('RED_TEAM_CLEAR','RED_TEAM_MATERIAL') then raise exception 'NRFIPRENSA_FINAL_PASS_RED_TEAM_UNRESOLVED:%',coalesce(rt,'NULL') using errcode='23514'; end if;
   if not exists(select 1 from public.nrfiprensa_phase_state where run_id=new.run_id and game_id=new.game_id and phase_id='F8' and frozen=true) then raise exception 'NRFIPRENSA_FINAL_PASS_REQUIRES_F8_FROZEN' using errcode='23514'; end if;
 end if; return new;
end $$;

drop trigger if exists trg_nrfiprensa_final_seal_guard on public.nrfiprensa_final_seals;
create trigger trg_nrfiprensa_final_seal_guard before insert or update on public.nrfiprensa_final_seals for each row execute function public.nrfiprensa_enforce_final_seal();

create or replace function public.nrfiprensa_enforce_handoff()
returns trigger language plpgsql as $$
declare n integer; seal text; start_at timestamptz;
begin
 new.as_of:=now();
 if public.nrfiprensa_json_has_key_recursive(new.pack_a,array['p_nrfi','model_probability','edge','ev','stake','bet_amount','execution_authority','final_pick']) then raise exception 'NRFIPRENSA_PACK_A_EXECUTION_FIREWALL' using errcode='23514'; end if;
 if public.nrfiprensa_json_has_key_recursive(new.pack_i,array['external_picks','picks','consensus','odds','line_movement','movement','review_priority','shortlist','jrc','jrc_status','so_media_status','f8_conclusion','candidate_rank']) then raise exception 'NRFIPRENSA_PACK_I_CLEAN_ROOM_CONTAMINATION' using errcode='23514'; end if;
 select scheduled_start into start_at from public.nrfiprensa_games where run_id=new.run_id and game_id=new.game_id;
 if new.disposition like 'REVIEW_PRIORITY_%' then
   if now()>=start_at then raise exception 'NRFIPRENSA_REVIEW_PRIORITY_AFTER_FIRST_PITCH_FORBIDDEN' using errcode='23514'; end if;
   select status into seal from public.nrfiprensa_final_seals where run_id=new.run_id and game_id=new.game_id;
   if seal<>'PASS' then raise exception 'NRFIPRENSA_REVIEW_PRIORITY_REQUIRES_FINAL_PREGAME_SEAL_PASS:%',coalesce(seal,'NULL') using errcode='23514'; end if;
   select count(*) into n from public.nrfiprensa_handoffs where run_id=new.run_id and disposition like 'REVIEW_PRIORITY_%' and handoff_id<>new.handoff_id;
   if n>=3 then raise exception 'NRFIPRENSA_MAX_THREE_TRANSFER_CANDIDATES' using errcode='23514'; end if;
   if new.transfer_state not in ('TRANSFER_HIGH','TRANSFER_MATERIAL','READY_FOR_IA_REVIEW') then raise exception 'NRFIPRENSA_REVIEW_PRIORITY_TRANSFER_STATE_INVALID' using errcode='23514'; end if;
 elsif new.disposition='HOLD_DYNAMIC' and new.transfer_state not in ('UNRESOLVED_PREGAME','REOPEN_REQUIRED') then raise exception 'NRFIPRENSA_HOLD_MUST_REMAIN_NO_BET_UNRESOLVED_OR_REOPEN' using errcode='23514'; end if;
 return new;
end $$;

drop trigger if exists trg_nrfiprensa_handoff_guard on public.nrfiprensa_handoffs;
create trigger trg_nrfiprensa_handoff_guard before insert or update on public.nrfiprensa_handoffs for each row execute function public.nrfiprensa_enforce_handoff();
create unique index if not exists uq_nrfiprensa_priority_per_run on public.nrfiprensa_handoffs(run_id,disposition) where disposition in ('REVIEW_PRIORITY_1','REVIEW_PRIORITY_2','REVIEW_PRIORITY_3');

alter table public.nrfiprensa_report_documents drop constraint if exists nrfiprensa_report_content_hash_chk;
alter table public.nrfiprensa_report_documents add constraint nrfiprensa_report_content_hash_chk check (content_hash is null or content_hash ~ '^[0-9a-f]{64}$');

create or replace function public.nrfiprensa_enforce_run_close()
returns trigger language plpgsql as $$
declare games_n integer; f10_n integer; missing_artifacts integer;
begin
 if new.status='CLOSED' and old.status is distinct from 'CLOSED' then
   select count(*) into games_n from public.nrfiprensa_games where run_id=new.run_id;
   select count(distinct game_id) into f10_n from public.nrfiprensa_phase_state where run_id=new.run_id and phase_id='F10';
   if games_n=0 or f10_n<>games_n then raise exception 'NRFIPRENSA_CLOSE_REQUIRES_F10_DISPOSITION_FOR_ALL_GAMES:%/%',f10_n,games_n using errcode='23514'; end if;
   if not exists(select 1 from public.nrfiprensa_report_documents where run_id=new.run_id and status='FINAL_VERIFIED' and content_hash is not null) then raise exception 'NRFIPRENSA_CLOSE_REQUIRES_FINAL_VERIFIED_REPORT' using errcode='23514'; end if;
   select count(*) into missing_artifacts from public.nrfiprensa_handoffs h where h.run_id=new.run_id and h.disposition like 'REVIEW_PRIORITY_%' and not exists(select 1 from public.nrfiprensa_drive_artifacts a where a.run_id=h.run_id and a.game_id=h.game_id and a.artifact_type='HANDOFF' and a.verified=true and a.content_hash=h.content_hash);
   if missing_artifacts>0 then raise exception 'NRFIPRENSA_CLOSE_REQUIRES_VERIFIED_HANDOFF_ARTIFACTS:%',missing_artifacts using errcode='23514'; end if;
   new.closed_at:=now();
 end if; return new;
end $$;

drop trigger if exists trg_nrfiprensa_run_close_guard on public.nrfiprensa_runs;
create trigger trg_nrfiprensa_run_close_guard before update on public.nrfiprensa_runs for each row execute function public.nrfiprensa_enforce_run_close();
