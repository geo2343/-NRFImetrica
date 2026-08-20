alter table public.mlb_v2_runs drop constraint if exists mlb_v2_runs_status_check;
alter table public.mlb_v2_runs add constraint mlb_v2_runs_status_check check (status = any (array['CREATED'::text,'RUNNING'::text,'BLOCKED'::text,'COMPLETE'::text,'INCOMPLETE_RESEARCH'::text,'VOID'::text,'SPORTS_FROZEN'::text]));

do $$ begin
  if not exists (select 1 from pg_constraint where conrelid='public.mlb_v2_missions'::regclass and conname='mlb_v2_missions_status_check') then
    alter table public.mlb_v2_missions add constraint mlb_v2_missions_status_check check (status = any (array['CREATED'::text,'RUNNING'::text,'BLOCKED'::text,'A9_SEALED'::text,'COMPLETED'::text,'VOID'::text]));
  end if;
end $$;

create or replace function public.mlb_v2_mission_guard()
returns trigger language plpgsql as $$
declare reg record;
begin
  select * into reg from public.mlb_v2_agent_registry where agent_id=new.agent_id;
  if not found or new.agent_id <> '@AnalistaaNRFI' then raise exception 'MLB_V2_MISSION_ANALISTA_ONLY'; end if;
  if reg.status <> 'KERNEL_CONNECTED' then raise exception 'MLB_V2_MISSION_AGENT_NOT_KERNEL_CONNECTED'; end if;
  if coalesce(new.metadata->>'kernel_version','') <> coalesce(reg.metadata->>'kernel_version','') then raise exception 'MLB_V2_MISSION_KERNEL_VERSION_MISMATCH'; end if;
  if new.scope_type='SLATE' and new.slate_date is null then raise exception 'MLB_V2_MISSION_SLATE_DATE_REQUIRED'; end if;
  new.updated_at=clock_timestamp();
  return new;
end $$;

drop trigger if exists trg_mlb_v2_mission_guard on public.mlb_v2_missions;
create trigger trg_mlb_v2_mission_guard before insert or update on public.mlb_v2_missions for each row execute function public.mlb_v2_mission_guard();

create or replace function public.mlb_v2_sports_freeze_insert_guard()
returns trigger language plpgsql as $$
declare ru record; a8 record; expected_packet_hash text;
begin
  select * into ru from public.mlb_v2_runs where run_id=new.analyst_run_id;
  if not found or ru.agent_id <> '@AnalistaaNRFI' then raise exception 'MLB_V2_FREEZE_ANALISTA_RUN_REQUIRED'; end if;
  select * into a8 from public.mlb_v2_phase_receipts where run_id=new.analyst_run_id and phase_id='A8' and terminal;
  if not found then raise exception 'MLB_V2_FREEZE_A8_TERMINAL_RECEIPT_REQUIRED'; end if;
  expected_packet_hash=encode(digest((a8.output_objects->'a8_final_sports_packet')::text,'sha256'),'hex');
  if new.sports_state is distinct from (a8.output_objects->>'sports_state') then raise exception 'MLB_V2_FREEZE_SPORTS_STATE_MISMATCH'; end if;
  if new.a8_output_hash is distinct from a8.output_hash then raise exception 'MLB_V2_FREEZE_A8_OUTPUT_HASH_MISMATCH'; end if;
  if new.sports_packet_hash is distinct from expected_packet_hash then raise exception 'MLB_V2_FREEZE_PACKET_HASH_MISMATCH'; end if;
  new.metadata=coalesce(new.metadata,'{}'::jsonb) || jsonb_build_object('created_by','A8_TERMINAL_RECEIPT','kernel_version',coalesce(ru.metadata->>'kernel_version',''));
  new.frozen_at=clock_timestamp();
  return new;
end $$;

drop trigger if exists trg_mlb_v2_sports_freeze_insert_guard on public.mlb_v2_sports_freezes;
create trigger trg_mlb_v2_sports_freeze_insert_guard before insert on public.mlb_v2_sports_freezes for each row execute function public.mlb_v2_sports_freeze_insert_guard();

create or replace function public.mlb_v2_terminal_receipt_immutable()
returns trigger language plpgsql as $$
begin
  if old.terminal and to_jsonb(new) is distinct from to_jsonb(old) then raise exception 'MLB_V2_TERMINAL_RECEIPT_IMMUTABLE'; end if;
  return new;
end $$;

drop trigger if exists trg_mlb_v2_terminal_phase_receipt_immutable on public.mlb_v2_phase_receipts;
create trigger trg_mlb_v2_terminal_phase_receipt_immutable before update on public.mlb_v2_phase_receipts for each row execute function public.mlb_v2_terminal_receipt_immutable();

drop trigger if exists trg_mlb_v2_terminal_mission_receipt_immutable on public.mlb_v2_mission_phase_receipts;
create trigger trg_mlb_v2_terminal_mission_receipt_immutable before update on public.mlb_v2_mission_phase_receipts for each row execute function public.mlb_v2_terminal_receipt_immutable();

create or replace function public.mlb_v2_finalization_immutable()
returns trigger language plpgsql as $$ begin raise exception 'MLB_V2_FINALIZATION_IMMUTABLE'; end $$;
drop trigger if exists trg_mlb_v2_finalization_immutable on public.mlb_v2_mission_finalizations;
create trigger trg_mlb_v2_finalization_immutable before update or delete on public.mlb_v2_mission_finalizations for each row execute function public.mlb_v2_finalization_immutable();

create or replace function public.mlb_v2_run_state_guard()
returns trigger language plpgsql as $$
declare expected_phase text; h record; a8 record;
begin
  if new.phase_cursor is distinct from old.phase_cursor and new.phase_cursor is not null then
    select pc.phase_id into expected_phase
    from public.mlb_v2_phase_receipts pr
    join public.mlb_v2_phase_catalog pc on pc.agent_id=new.agent_id and pc.phase_id=pr.phase_id
    where pr.run_id=new.run_id and pr.terminal and coalesce(pc.metadata->>'scope','RUN')='RUN'
    order by pc.phase_order desc limit 1;
    if expected_phase is null or new.phase_cursor <> expected_phase then raise exception 'MLB_V2_PHASE_CURSOR_NOT_DERIVED expected=% got=%',coalesce(expected_phase,'NONE'),new.phase_cursor; end if;
  end if;
  if new.status='SPORTS_FROZEN' and old.status is distinct from 'SPORTS_FROZEN' then
    if new.agent_id <> '@AnalistaaNRFI' then raise exception 'MLB_V2_SPORTS_FROZEN_ANALISTA_ONLY'; end if;
    select * into a8 from public.mlb_v2_phase_receipts where run_id=new.run_id and phase_id='A8' and terminal;
    if not found then raise exception 'MLB_V2_SPORTS_FROZEN_REQUIRES_A8_TERMINAL'; end if;
  end if;
  if new.ready_for_analyst and not old.ready_for_analyst then
    if new.agent_id <> '@InvestigadoraNRFI' then raise exception 'MLB_V2_READY_FOR_ANALYST_INVESTIGADORA_ONLY'; end if;
    select * into h from public.mlb_v2_handoffs where run_id=new.run_id and status='READY_FOR_ANALYST' and destination_agent='@AnalistaaNRFI';
    if not found then raise exception 'MLB_V2_READY_FOR_ANALYST_REQUIRES_VALID_HANDOFF'; end if;
  end if;
  if new.agent_id='@InvestigadoraNRFI' and new.status='COMPLETE' and old.status is distinct from 'COMPLETE' then
    select * into h from public.mlb_v2_handoffs where run_id=new.run_id and status='READY_FOR_ANALYST' and destination_agent='@AnalistaaNRFI';
    if not found then raise exception 'MLB_V2_INVESTIGADORA_COMPLETE_REQUIRES_HANDOFF'; end if;
  end if;
  if new.agent_id='@AnalistaaNRFI' and new.status='COMPLETE' then raise exception 'MLB_V2_ANALYST_RUN_COMPLETION_BELONGS_TO_MISSION'; end if;
  return new;
end $$;

drop trigger if exists trg_mlb_v2_run_state_guard on public.mlb_v2_runs;
create trigger trg_mlb_v2_run_state_guard before update on public.mlb_v2_runs for each row execute function public.mlb_v2_run_state_guard();

update public.mlb_v2_agent_registry
set agent_version='ANALISTAANRFI-AGENT-2.2',
    metadata=metadata || jsonb_build_object('kernel_version','MLB-V2-KERNEL-0.3-HARDENED','audit_hardening','2026-08-20','sports_freeze_insert_guard',true,'terminal_receipt_immutable',true,'run_state_derivation_guard',true),
    updated_at=clock_timestamp()
where agent_id='@AnalistaaNRFI';
