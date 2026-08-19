-- Non-competitive exits cannot be used as easy escape routes.

insert into public.protocol_decision_gates(protocol_id, decision, phase_id) values
  ('NRFIMETRICA_V21_AI_ANALYST','RESEARCH_ONLY_DATA','TRIAGE'),
  ('NRFIMETRICA_V21_AI_ANALYST','RESEARCH_ONLY_MODEL','TRIAGE'),
  ('NRFIMETRICA_V21_AI_ANALYST','LOCAL_DATA_BLOCK','TRIAGE')
on conflict do nothing;

create or replace function public.enforce_nrfimetrica_protocol_before_decision()
returns trigger
language plpgsql
as $$
declare
  v_protocol text := 'NRFIMETRICA_V21_AI_ANALYST';
  v_required integer;
  v_completed integer;
begin
  select count(*) into v_required
  from public.protocol_decision_gates
  where protocol_id = v_protocol
    and decision = new.decision;

  if v_required > 0 then
    select count(*) into v_completed
    from public.protocol_decision_gates g
    join public.protocol_phase_state s
      on s.protocol_id = g.protocol_id
     and s.phase_id = g.phase_id
     and s.run_id = new.run_id
     and s.game_id = new.game_id
     and s.status in ('COMPLETE','SKIPPED_NOT_TRIGGERED')
    where g.protocol_id = v_protocol
      and g.decision = new.decision;

    if v_completed <> v_required then
      raise exception 'PROTOCOL_GATES_INCOMPLETE:%/%', v_completed, v_required
        using errcode = '23514';
    end if;
  end if;

  if new.decision in ('NRFI_CANDIDATE','NRFI_REJECTED') then
    if not exists (
      select 1
      from public.protocol_phase_state s
      where s.run_id = new.run_id
        and s.game_id = new.game_id
        and s.phase_id = 'RECONSIDERATION'
        and s.status = 'COMPLETE'
        and s.payload->>'final_decision' = new.decision
    ) then
      raise exception 'FINAL_DECISION_DOES_NOT_MATCH_RECONSIDERATION'
        using errcode = '23514';
    end if;
  end if;

  if new.decision in ('RESEARCH_ONLY_DATA','RESEARCH_ONLY_MODEL','LOCAL_DATA_BLOCK') then
    if length(btrim(coalesce(new.decisive_factor,''))) < 8
       or length(btrim(coalesce(new.materiality,''))) < 8
       or length(btrim(coalesce(new.what_would_change,''))) < 8 then
      raise exception 'NONCOMPETITIVE_EXIT_REQUIRES_CAUSE_MATERIALITY_AND_REVERSAL_CONDITION'
        using errcode = '23514';
    end if;
  end if;

  if new.decision in ('RESEARCH_ONLY_DATA','LOCAL_DATA_BLOCK') then
    if not exists (
      select 1 from public.recoveries r
      where r.run_id = new.run_id
        and (r.game_id = new.game_id or r.game_id is null)
        and r.attempt = 1
    ) then
      raise exception 'DATA_BLOCK_REQUIRES_ONE_REAL_RECOVERY_ATTEMPT'
        using errcode = '23514';
    end if;
  end if;

  if new.decision = 'AUDIT_ONLY' then
    if not exists (
      select 1 from public.games g
      where g.run_id = new.run_id
        and g.game_id = new.game_id
        and g.status = 'AUDIT_ONLY'
    ) then
      raise exception 'AUDIT_ONLY_NOT_AUTHORIZED_FOR_PREGAME_GAME'
        using errcode = '23514';
    end if;
  end if;

  return new;
end;
$$;
