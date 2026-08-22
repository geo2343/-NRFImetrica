-- @Investigarfullunder — requirement ledger unification
-- Production target: Supabase project yejaollmavoudbxnbpll
-- Applied after IFU-EXHAUSTIVE-REPORT-1.0.

-- Detail status vocabulary must be identical to the canonical requirement-state vocabulary.
alter table public.fullunder_requirement_execution_detail
  drop constraint if exists fullunder_requirement_execution_status_check;
alter table public.fullunder_requirement_execution_detail
  add constraint fullunder_requirement_execution_status_check
  check (execution_status = any(array[
    'SATISFIED',
    'NOT_APPLICABLE_WITH_REASON',
    'UNRESOLVED_AFTER_DOCUMENTED_RECOVERY'
  ]));

-- SET_REQUIREMENT_DETAILS is the single legal write path. It writes the exhaustive
-- detail and canonical state atomically, and reuses the stronger pre-existing
-- structured evidence validator.
create or replace function public.fullunder_commit_requirement_details(p_run_id uuid, p_phase_id text, p_details jsonb)
returns integer
language plpgsql
security definer
set search_path to 'public','extensions'
as $fn$
declare
  v_item jsonb;
  v_req text;
  v_count integer := 0;
  v_status text;
  v_reason text;
begin
  if jsonb_typeof(p_details) <> 'array' or jsonb_array_length(p_details)=0 then
    raise exception 'FULLUNDER_REQUIREMENT_DETAILS_ARRAY_REQUIRED';
  end if;
  if exists(select 1 from public.fullunder_phase_receipts where run_id=p_run_id and phase_id=p_phase_id) then
    raise exception 'FULLUNDER_REQUIREMENT_DETAIL_PHASE_ALREADY_CLOSED';
  end if;

  perform set_config('fullunder.requirement_detail_gate','on',true);
  begin
    for v_item in select * from jsonb_array_elements(p_details) loop
      v_req := nullif(v_item->>'requirement_id','');
      v_status := nullif(v_item->>'execution_status','');
      v_reason := nullif(btrim(coalesce(v_item->>'reason','')),'');

      if v_req is null or v_status is null then raise exception 'FULLUNDER_REQUIREMENT_DETAIL_ID_STATUS_REQUIRED'; end if;
      if v_status not in ('SATISFIED','NOT_APPLICABLE_WITH_REASON','UNRESOLVED_AFTER_DOCUMENTED_RECOVERY') then
        raise exception 'FULLUNDER_REQUIREMENT_DETAIL_STATUS_INVALID % %',v_req,v_status;
      end if;
      if v_status in ('NOT_APPLICABLE_WITH_REASON','UNRESOLVED_AFTER_DOCUMENTED_RECOVERY') and v_reason is null then
        raise exception 'FULLUNDER_REQUIREMENT_DETAIL_REASON_REQUIRED %',v_req;
      end if;
      if not exists(select 1 from public.fullunder_requirement_catalog where requirement_id=v_req and phase_id=p_phase_id and active) then
        raise exception 'FULLUNDER_REQUIREMENT_DETAIL_PHASE_BINDING_INVALID %',v_req;
      end if;
      if char_length(btrim(coalesce(v_item->>'result_text',''))) < 100 then raise exception 'FULLUNDER_REQUIREMENT_DETAIL_RESULT_TOO_SHORT %',v_req; end if;
      if jsonb_typeof(coalesce(v_item->'data_payload','null'::jsonb)) <> 'object' or coalesce(v_item->'data_payload','{}'::jsonb)='{}'::jsonb then raise exception 'FULLUNDER_REQUIREMENT_DETAIL_DATA_REQUIRED %',v_req; end if;
      if jsonb_typeof(coalesce(v_item->'evidence_refs','null'::jsonb)) <> 'array' or jsonb_array_length(coalesce(v_item->'evidence_refs','[]'::jsonb))=0 then raise exception 'FULLUNDER_REQUIREMENT_DETAIL_EVIDENCE_REQUIRED %',v_req; end if;
      if jsonb_typeof(coalesce(v_item->'output_refs','null'::jsonb)) <> 'array' or jsonb_array_length(coalesce(v_item->'output_refs','[]'::jsonb))=0 then raise exception 'FULLUNDER_REQUIREMENT_DETAIL_OUTPUT_REQUIRED %',v_req; end if;
      if lower(v_item->>'result_text') ~ '(covered by the|covered by .*packet|accounted by|constitutional evidence packet|same evidence packet|requirements? accounted)' then raise exception 'FULLUNDER_REQUIREMENT_DETAIL_GENERIC_TEXT_FORBIDDEN %',v_req; end if;
      if v_status='UNRESOLVED_AFTER_DOCUMENTED_RECOVERY' and (
        not (v_item->'data_payload' ? 'recovery_attempts') or
        jsonb_typeof(v_item->'data_payload'->'recovery_attempts') <> 'array' or
        jsonb_array_length(v_item->'data_payload'->'recovery_attempts')=0
      ) then raise exception 'FULLUNDER_REQUIREMENT_DETAIL_UNRESOLVED_NEEDS_RECOVERY %',v_req; end if;

      -- Required evidence_refs shape is the pre-existing stronger atomic contract:
      -- [{evidence_id|issue_id, path:[...], support:"..."}, ...]
      -- It validates ownership, phase, physical JSON path and support text.
      if public.fullunder_requirement_support_is_valid(p_run_id,v_req,v_status,v_item->'evidence_refs',v_reason) is not true then
        raise exception 'FULLUNDER_REQUIREMENT_DETAIL_STRUCTURED_SUPPORT_INVALID %',v_req;
      end if;

      insert into public.fullunder_requirement_execution_detail(
        run_id,requirement_id,phase_id,execution_status,result_text,data_payload,evidence_refs,output_refs,updated_at
      ) values(
        p_run_id,v_req,p_phase_id,v_status,v_item->>'result_text',v_item->'data_payload',v_item->'evidence_refs',v_item->'output_refs',now()
      )
      on conflict(run_id,requirement_id) do update set
        phase_id=excluded.phase_id,
        execution_status=excluded.execution_status,
        result_text=excluded.result_text,
        data_payload=excluded.data_payload,
        evidence_refs=excluded.evidence_refs,
        output_refs=excluded.output_refs,
        updated_at=now();

      insert into public.fullunder_requirement_state(
        run_id,requirement_id,status,evidence_refs,output_refs,reason,checked_at
      ) values(
        p_run_id,v_req,v_status,v_item->'evidence_refs',v_item->'output_refs',v_reason,now()
      )
      on conflict(run_id,requirement_id) do update set
        status=excluded.status,
        evidence_refs=excluded.evidence_refs,
        output_refs=excluded.output_refs,
        reason=excluded.reason,
        checked_at=now();

      v_count := v_count + 1;
    end loop;
  exception when others then
    perform set_config('fullunder.requirement_detail_gate','off',true);
    raise;
  end;
  perform set_config('fullunder.requirement_detail_gate','off',true);
  return v_count;
end
$fn$;

revoke all on function public.fullunder_commit_requirement_details(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.fullunder_commit_requirement_details(uuid,text,jsonb) to service_role;

-- Disable the legacy separate state-write action so detail/state cannot diverge.
update public.fullunder_capability_policy
set allowed=false
where phase_id in ('F1','F2','F3','F4','F5','F6','F7','F8')
  and action='SET_REQUIREMENT_STATES';

create or replace function public.fullunder_requirement_ledgers_consistent(p_run_id uuid, p_phase_id text default null)
returns jsonb
language sql
security definer
set search_path to 'public','extensions'
as $fn$
with x as (
  select d.requirement_id,
         d.execution_status as detail_status,
         s.status as state_status,
         d.evidence_refs as detail_evidence,
         s.evidence_refs as state_evidence,
         d.output_refs as detail_outputs,
         s.output_refs as state_outputs
  from public.fullunder_requirement_execution_detail d
  join public.fullunder_requirement_catalog c on c.requirement_id=d.requirement_id and c.active
  left join public.fullunder_requirement_state s on s.run_id=d.run_id and s.requirement_id=d.requirement_id
  where d.run_id=p_run_id and (p_phase_id is null or c.phase_id=p_phase_id)
), agg as (
  select count(*) as detail_count,
         count(*) filter(where state_status is null) as missing_state,
         count(*) filter(where state_status is distinct from detail_status) as status_mismatch,
         count(*) filter(where state_evidence is distinct from detail_evidence) as evidence_mismatch,
         count(*) filter(where state_outputs is distinct from detail_outputs) as output_mismatch
  from x
)
select jsonb_build_object(
  'pass',missing_state=0 and status_mismatch=0 and evidence_mismatch=0 and output_mismatch=0,
  'run_id',p_run_id,'phase_id',p_phase_id,'detail_count',detail_count,
  'missing_state',missing_state,'status_mismatch',status_mismatch,
  'evidence_mismatch',evidence_mismatch,'output_mismatch',output_mismatch
)
from agg;
$fn$;

revoke all on function public.fullunder_requirement_ledgers_consistent(uuid,text) from public,anon,authenticated;
grant execute on function public.fullunder_requirement_ledgers_consistent(uuid,text) to service_role;

create or replace function public.fullunder_phase_requirement_ledger_consistency_gate()
returns trigger
language plpgsql
security definer
set search_path to 'public','extensions'
as $fn$
declare v jsonb;
begin
  v:=public.fullunder_requirement_ledgers_consistent(new.run_id,new.phase_id);
  if coalesce((v->>'pass')::boolean,false) is not true then
    raise exception 'FULLUNDER_REQUIREMENT_LEDGER_MISMATCH %',v::text;
  end if;
  return new;
end
$fn$;

revoke all on function public.fullunder_phase_requirement_ledger_consistency_gate() from public,anon,authenticated;
grant execute on function public.fullunder_phase_requirement_ledger_consistency_gate() to service_role;

drop trigger if exists aa_fullunder_phase_requirement_ledger_consistency_t on public.fullunder_phase_receipts;
create trigger aa_fullunder_phase_requirement_ledger_consistency_t
before insert or update on public.fullunder_phase_receipts
for each row execute function public.fullunder_phase_requirement_ledger_consistency_gate();

-- Observed rollback smoke after production application:
-- SET_REQUIREMENT_DETAILS(SATISFIED + structured evidence ref) -> COMMITTED
-- detail/state consistency -> PASS, missing/status/evidence/output mismatch all 0
-- legacy SET_REQUIREMENT_STATES -> REJECT FULLUNDER_CAPABILITY_ACTION_FORBIDDEN
-- fixture residue -> 0
