alter table public.calibration_certifications
add column if not exists authority_class text not null default 'DISABLED'
check (authority_class in ('ACTIVE_TRUSTED','DIAGNOSTIC_TRUSTED','DISABLED'));

create or replace function public.enforce_nrfimetrica_calibration_authority_class()
returns trigger language plpgsql as $$
declare
  run_mode text; target_key text; cert_id text; cls text; expected text;
begin
  if new.protocol_id<>'NRFIMETRICA_MOTHER_V3_AUTONOMOUS' or new.phase_id<>'A7_CALIBRATION_ELIGIBILITY_PRESS' then return new; end if;
  select mode into run_mode from public.runs where run_id=new.run_id;
  expected:=case when run_mode='DIAGNOSTIC' then 'DIAGNOSTIC_TRUSTED' else 'ACTIVE_TRUSTED' end;
  foreach target_key in array array['u0_5','u1_5','u2_5'] loop
    if upper(coalesce(new.payload #>> array['contract_calibration',target_key,'status'],'')) in ('CERTIFIED','CERTIFIED_CONDITIONED') then
      cert_id:=new.payload #>> array['contract_calibration',target_key,'certification_id'];
      select authority_class into cls from public.calibration_certifications where certification_id=cert_id;
      if cls is distinct from expected then
        raise exception 'A7_CALIBRATION_NOT_TRUSTED_FOR_RUN_MODE:%:%/%',target_key,coalesce(cls,'NONE'),expected using errcode='23514';
      end if;
    end if;
  end loop;
  return new;
end $$;

drop trigger if exists trg_05_nrfimetrica_calibration_authority_class on public.protocol_phase_state;
create trigger trg_05_nrfimetrica_calibration_authority_class before insert or update on public.protocol_phase_state
for each row execute function public.enforce_nrfimetrica_calibration_authority_class();
