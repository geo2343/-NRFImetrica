-- Applied physically after adversarial testing exposed PostgreSQL NULL comparison bypass.
-- Missing seal/starter/red-team state must fail closed, never evaluate as SQL NULL.

create or replace function public.nrfiprensa_enforce_final_seal()
returns trigger language plpgsql as $$
declare g public.nrfiprensa_games%rowtype; rt text; cnt integer;
begin
  new.as_of_final:=now();
  select * into g from public.nrfiprensa_games where run_id=new.run_id and game_id=new.game_id;
  if not found then raise exception 'NRFIPRENSA_SEAL_GAME_NOT_FOUND' using errcode='23514'; end if;
  if new.status='PASS' then
    if now()>=g.scheduled_start or coalesce(g.pregame_state,'')<>'PREGAME' then raise exception 'NRFIPRENSA_FINAL_PASS_REQUIRES_CURRENT_PREGAME' using errcode='23514'; end if;
    if coalesce(g.away_pitcher_status,'') not in ('CONFIRMED','OPENER') or coalesce(g.home_pitcher_status,'') not in ('CONFIRMED','OPENER') then raise exception 'NRFIPRENSA_FINAL_PASS_REQUIRES_CONFIRMED_FIRST_INNING_PITCHERS' using errcode='23514'; end if;
    if not coalesce(new.away_starter_current,false) or not coalesce(new.home_starter_current,false) or not coalesce(new.official_lineups_match,false) or not coalesce(new.scratches_revalidated,false) or not coalesce(new.restrictions_revalidated,false) then raise exception 'NRFIPRENSA_FINAL_PASS_FRESHNESS_LOCK_FAIL' using errcode='23514'; end if;
    select count(*) into cnt from public.nrfiprensa_f7q where run_id=new.run_id and game_id=new.game_id and official_b1_b5=true and q1='PASS' and q2='PASS' and q3='PASS' and q4='PASS' and q5='PASS' and q6='PASS' and q7='PASS' and q8='PASS' and q9='PASS' and q10='PASS' and q11='PASS' and q12='PASS' and osr_status<>'GOVERNING';
    if cnt<>2 then raise exception 'NRFIPRENSA_FINAL_PASS_REQUIRES_TWO_COMPLETE_F7Q_HALVES:%',cnt using errcode='23514'; end if;
    select status into rt from public.nrfiprensa_red_team where run_id=new.run_id and game_id=new.game_id;
    if coalesce(rt,'') not in ('RED_TEAM_CLEAR','RED_TEAM_MATERIAL') then raise exception 'NRFIPRENSA_FINAL_PASS_RED_TEAM_UNRESOLVED:%',coalesce(rt,'NULL') using errcode='23514'; end if;
    if not exists(select 1 from public.nrfiprensa_phase_state where run_id=new.run_id and game_id=new.game_id and phase_id='F8' and frozen=true) then raise exception 'NRFIPRENSA_FINAL_PASS_REQUIRES_F8_FROZEN' using errcode='23514'; end if;
  end if;
  return new;
end $$;

create or replace function public.nrfiprensa_enforce_handoff()
returns trigger language plpgsql as $$
declare n integer; seal text; start_at timestamptz;
begin
  new.as_of:=now();
  if public.nrfiprensa_json_has_key_recursive(new.pack_a,array['p_nrfi','model_probability','edge','ev','stake','bet_amount','execution_authority','final_pick']) then raise exception 'NRFIPRENSA_PACK_A_EXECUTION_FIREWALL' using errcode='23514'; end if;
  if public.nrfiprensa_json_has_key_recursive(new.pack_i,array['external_picks','picks','consensus','odds','line_movement','movement','review_priority','shortlist','jrc','jrc_status','so_media_status','f8_conclusion','candidate_rank']) then raise exception 'NRFIPRENSA_PACK_I_CLEAN_ROOM_CONTAMINATION' using errcode='23514'; end if;
  select scheduled_start into start_at from public.nrfiprensa_games where run_id=new.run_id and game_id=new.game_id;
  if start_at is null then raise exception 'NRFIPRENSA_HANDOFF_GAME_NOT_FOUND' using errcode='23514'; end if;
  if new.disposition like 'REVIEW_PRIORITY_%' then
    if now()>=start_at then raise exception 'NRFIPRENSA_REVIEW_PRIORITY_AFTER_FIRST_PITCH_FORBIDDEN' using errcode='23514'; end if;
    if not exists(select 1 from public.nrfiprensa_phase_state where run_id=new.run_id and game_id=new.game_id and phase_id='F9') then raise exception 'NRFIPRENSA_REVIEW_PRIORITY_REQUIRES_F9_CONFRONTATION' using errcode='23514'; end if;
    select status into seal from public.nrfiprensa_final_seals where run_id=new.run_id and game_id=new.game_id;
    if coalesce(seal,'')<>'PASS' then raise exception 'NRFIPRENSA_REVIEW_PRIORITY_REQUIRES_FINAL_PREGAME_SEAL_PASS:%',coalesce(seal,'NULL') using errcode='23514'; end if;
    select count(*) into n from public.nrfiprensa_handoffs where run_id=new.run_id and disposition like 'REVIEW_PRIORITY_%' and handoff_id<>new.handoff_id;
    if n>=3 then raise exception 'NRFIPRENSA_MAX_THREE_TRANSFER_CANDIDATES' using errcode='23514'; end if;
    if new.transfer_state not in ('TRANSFER_HIGH','TRANSFER_MATERIAL','READY_FOR_IA_REVIEW') then raise exception 'NRFIPRENSA_REVIEW_PRIORITY_TRANSFER_STATE_INVALID' using errcode='23514'; end if;
  elsif new.disposition='HOLD_DYNAMIC' then
    if new.transfer_state not in ('UNRESOLVED_PREGAME','REOPEN_REQUIRED') then raise exception 'NRFIPRENSA_HOLD_MUST_REMAIN_NO_BET_UNRESOLVED_OR_REOPEN' using errcode='23514'; end if;
  end if;
  return new;
end $$;
