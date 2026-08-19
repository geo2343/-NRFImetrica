-- Ensure prerequisite order is checked before phase-specific semantics so a
-- skipped phase fails explicitly as an order violation.

create or replace function public.enforce_nrfimetrica_mother_phase_order_first()
returns trigger
language plpgsql
as $$
declare
  missing_count integer;
begin
  if new.protocol_id <> 'NRFIMETRICA_MOTHER_V3_AUTONOMOUS' then
    return new;
  end if;

  select count(*) into missing_count
  from public.protocol_phase_prerequisites p
  where p.protocol_id=new.protocol_id
    and p.phase_id=new.phase_id
    and not exists (
      select 1 from public.protocol_phase_state s
      where s.run_id=new.run_id and s.game_id=new.game_id
        and s.protocol_id=new.protocol_id
        and s.phase_id=p.prerequisite_phase_id
        and s.status in ('COMPLETE','SKIPPED_NOT_TRIGGERED')
    );

  if missing_count>0 then
    raise exception 'MOTHER_PHASE_PREREQUISITES_INCOMPLETE:%:%',new.phase_id,missing_count using errcode='23514';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_00_nrfimetrica_mother_phase_order on public.protocol_phase_state;
create trigger trg_00_nrfimetrica_mother_phase_order
before insert or update on public.protocol_phase_state
for each row execute function public.enforce_nrfimetrica_mother_phase_order_first();
