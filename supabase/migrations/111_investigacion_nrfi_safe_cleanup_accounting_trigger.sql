-- Prevent ON DELETE CASCADE cleanup from trying to resync a run already deleted.
create or replace function public.investigacion_nrfi_game_accounting_trigger()
returns trigger
language plpgsql
set search_path = public, extensions
as $$
declare v_run_id text;
begin
  v_run_id := coalesce(new.daily_run_id,old.daily_run_id);
  if exists(select 1 from public.investigacion_nrfi_runs where daily_run_id=v_run_id) then
    perform public.investigacion_nrfi_sync_run_accounting(v_run_id);
  end if;
  return coalesce(new,old);
end;
$$;
revoke all on function public.investigacion_nrfi_game_accounting_trigger() from public,anon,authenticated;
