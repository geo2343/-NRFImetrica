-- Mirror of physically applied migration: sync_nrfimetrica_audit_authority_with_agent_registry
create or replace function public.sync_nrfimetrica_audit_authority_from_agent()
returns trigger language plpgsql as $$
begin
  if new.agent_id='@NRFImetrica' then
    update public.system_audit_registry
    set authority=coalesce(authority,'{}'::jsonb)||jsonb_build_object(
      'agent_version',new.agent_version,'kernel_version',new.kernel_version,'system_version',new.system_version,
      'real_money_authority',new.real_money_authority,'bilateral_rule_version',new.metadata->>'bilateral_rule_version',
      'required_authority_view',new.metadata->>'required_authority_view'),updated_at=clock_timestamp()
    where system_id='@NRFImetrica';
  end if;
  return new;
end $$;
drop trigger if exists trg_sync_nrfimetrica_audit_authority on public.agent_registry;
create trigger trg_sync_nrfimetrica_audit_authority after insert or update of agent_version,kernel_version,system_version,real_money_authority,metadata on public.agent_registry for each row execute function public.sync_nrfimetrica_audit_authority_from_agent();
update public.system_audit_registry r
set authority=r.authority||jsonb_build_object('agent_version',a.agent_version,'kernel_version',a.kernel_version,'system_version',a.system_version,'real_money_authority',a.real_money_authority,'bilateral_rule_version',a.metadata->>'bilateral_rule_version','required_authority_view',a.metadata->>'required_authority_view'),updated_at=clock_timestamp()
from public.agent_registry a where r.system_id='@NRFImetrica' and a.agent_id='@NRFImetrica';
