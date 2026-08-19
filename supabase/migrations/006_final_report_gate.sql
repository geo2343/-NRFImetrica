-- Final report gate: a real controlled run cannot close until the AI report
-- has been checked against the actual persisted run state.

create table if not exists public.run_report_state (
  run_id text primary key references public.runs(run_id) on delete cascade,
  status text not null check (status = 'COMPLETE'),
  report_hash text not null,
  document_ref text,
  validated_summary jsonb not null,
  final_verdict_hash text not null,
  validated_at timestamptz not null default now()
);

alter table public.run_report_state enable row level security;

create or replace function public.require_final_report_before_close()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'CLOSED'
     and old.status is distinct from 'CLOSED'
     and coalesce(new.mode, '') <> 'DIAGNOSTIC' then
    if not exists (
      select 1 from public.run_report_state r
      where r.run_id = new.run_id
        and r.status = 'COMPLETE'
    ) then
      raise exception 'FINAL_REPORT_GATE_INCOMPLETE'
        using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_require_final_report_before_close on public.runs;
create trigger trg_require_final_report_before_close
before update of status on public.runs
for each row execute function public.require_final_report_before_close();
