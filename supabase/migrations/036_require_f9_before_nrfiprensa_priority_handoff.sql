-- Applied physically to Supabase project yejaollmavoudbxnbpll.
-- Adds F9 confrontation as a prerequisite for any REVIEW_PRIORITY handoff.

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
    if not exists(select 1 from public.nrfiprensa_phase_state where run_id=new.run_id and game_id=new.game_id and phase_id='F9') then raise exception 'NRFIPRENSA_REVIEW_PRIORITY_REQUIRES_F9_CONFRONTATION' using errcode='23514'; end if;
    select status into seal from public.nrfiprensa_final_seals where run_id=new.run_id and game_id=new.game_id;
    if seal<>'PASS' then raise exception 'NRFIPRENSA_REVIEW_PRIORITY_REQUIRES_FINAL_PREGAME_SEAL_PASS:%',coalesce(seal,'NULL') using errcode='23514'; end if;
    select count(*) into n from public.nrfiprensa_handoffs where run_id=new.run_id and disposition like 'REVIEW_PRIORITY_%' and handoff_id<>new.handoff_id;
    if n>=3 then raise exception 'NRFIPRENSA_MAX_THREE_TRANSFER_CANDIDATES' using errcode='23514'; end if;
    if new.transfer_state not in ('TRANSFER_HIGH','TRANSFER_MATERIAL','READY_FOR_IA_REVIEW') then raise exception 'NRFIPRENSA_REVIEW_PRIORITY_TRANSFER_STATE_INVALID' using errcode='23514'; end if;
  elsif new.disposition='HOLD_DYNAMIC' then
    if new.transfer_state not in ('UNRESOLVED_PREGAME','REOPEN_REQUIRED') then raise exception 'NRFIPRENSA_HOLD_MUST_REMAIN_NO_BET_UNRESOLVED_OR_REOPEN' using errcode='23514'; end if;
  end if;
  return new;
end $$;
