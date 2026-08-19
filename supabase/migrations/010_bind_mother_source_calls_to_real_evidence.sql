-- Defense-in-depth: every source call counted by the mother protocol must be
-- bound to a physical evidence row from the same run/game and available before
-- the phase submission. A7 press packets also cannot come from the future.

create or replace function public.enforce_nrfimetrica_mother_source_truth()
returns trigger
language plpgsql
as $$
declare
  x jsonb;
  eid text;
  sref text;
  rt timestamptz;
  evid public.evidence%rowtype;
  press_received timestamptz;
begin
  if new.protocol_id <> 'NRFIMETRICA_MOTHER_V3_AUTONOMOUS' then
    return new;
  end if;

  for x in select value from jsonb_array_elements(coalesce(new.source_calls,'[]'::jsonb)) loop
    eid := btrim(coalesce(x->>'evidence_id',''));
    sref := btrim(coalesce(x->>'source_ref',''));
    if eid='' then
      raise exception 'MOTHER_SOURCE_CALL_WITHOUT_EVIDENCE_ID' using errcode='23514';
    end if;
    if not (eid = any(new.evidence_ids)) then
      raise exception 'MOTHER_SOURCE_CALL_EVIDENCE_NOT_BOUND_TO_PHASE:%',eid using errcode='23514';
    end if;
    begin
      rt := (x->>'retrieved_at')::timestamptz;
    exception when others then
      raise exception 'MOTHER_SOURCE_CALL_RETRIEVED_AT_INVALID:%',eid using errcode='23514';
    end;
    if rt > new.submitted_at then
      raise exception 'MOTHER_SOURCE_CALL_FROM_FUTURE:%',eid using errcode='23514';
    end if;

    select * into evid from public.evidence e
    where e.evidence_id=eid and e.run_id=new.run_id
      and (e.game_id is null or e.game_id=new.game_id)
    limit 1;
    if not found then
      raise exception 'MOTHER_SOURCE_CALL_EVIDENCE_NOT_FOUND:%',eid using errcode='23514';
    end if;
    if coalesce(evid.data_available_at,evid.retrieved_at) > new.submitted_at then
      raise exception 'MOTHER_SOURCE_CALL_EVIDENCE_NOT_YET_AVAILABLE:%',eid using errcode='23514';
    end if;
    if sref<>'' and coalesce(evid.source_ref,'')<>'' and sref<>evid.source_ref then
      raise exception 'MOTHER_SOURCE_REF_MISMATCH:%',eid using errcode='23514';
    end if;
  end loop;

  if new.phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS' then
    begin
      press_received := (new.payload #>> '{nrfi_prensa,received_at}')::timestamptz;
    exception when others then
      raise exception 'A7_PRESS_RECEIVED_AT_INVALID' using errcode='23514';
    end;
    if press_received > new.submitted_at then
      raise exception 'A7_PRESS_PACKET_FROM_FUTURE' using errcode='23514';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_nrfimetrica_mother_source_truth on public.protocol_phase_state;
create trigger trg_enforce_nrfimetrica_mother_source_truth
before insert or update on public.protocol_phase_state
for each row execute function public.enforce_nrfimetrica_mother_source_truth();
