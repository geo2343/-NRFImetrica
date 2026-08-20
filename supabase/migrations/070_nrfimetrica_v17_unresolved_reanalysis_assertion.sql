update public.agent_registry set status='DISABLED',metadata=(coalesce(metadata,'{}'::jsonb)-'database_migrations_required_through')||jsonb_build_object('database_migrations_required_through',70,'terminal_validation_state','V17_SELF_AUDIT_PENDING') where agent_id='@NRFImetrica';

create or replace function public.nrfimetrica_assert_press_reanalysis_gate_v16(a7 jsonb)
returns void
language plpgsql
immutable
set search_path=public,pg_temp
as $$
declare unresolved integer;
begin
  unresolved:=coalesce((a7 #>> '{press_integration,unresolved_count}')::integer,0);
  if unresolved>0 and lower(coalesce(a7 #>> '{press_integration,reanalysis_required}','false')) not in ('true','1','yes') then raise exception 'A7_UNRESOLVED_PRESS_ITEM_REQUIRES_REANALYSIS' using errcode='23514'; end if;
  if (lower(coalesce(a7 #>> '{press_integration,reanalysis_required}','false')) in ('true','1','yes') or unresolved>0) and upper(coalesce(a7->>'release_token',''))='ISSUED' then raise exception 'A7_RELEASE_BLOCKED_PENDING_CAUSAL_REANALYSIS' using errcode='23514'; end if;
end;
$$;

revoke execute on function public.nrfimetrica_assert_press_reanalysis_gate_v16(jsonb) from public,anon,authenticated;
grant execute on function public.nrfimetrica_assert_press_reanalysis_gate_v16(jsonb) to service_role;
