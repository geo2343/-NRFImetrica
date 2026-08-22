-- @Investigarfullunder — IFU-EXHAUSTIVE-REPORT-1.0
-- Production target: Supabase project yejaollmavoudbxnbpll
-- Purpose: prevent compressed/generic handoffs from satisfying the 889-requirement protocol.

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
  v_ref text;
  v_status text;
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
      if v_req is null or v_status is null then
        raise exception 'FULLUNDER_REQUIREMENT_DETAIL_ID_STATUS_REQUIRED';
      end if;
      if not exists(select 1 from public.fullunder_requirement_catalog where requirement_id=v_req and phase_id=p_phase_id and active) then
        raise exception 'FULLUNDER_REQUIREMENT_DETAIL_PHASE_BINDING_INVALID %',v_req;
      end if;
      if char_length(btrim(coalesce(v_item->>'result_text',''))) < 100 then
        raise exception 'FULLUNDER_REQUIREMENT_DETAIL_RESULT_TOO_SHORT %',v_req;
      end if;
      if jsonb_typeof(coalesce(v_item->'data_payload','null'::jsonb)) <> 'object' or coalesce(v_item->'data_payload','{}'::jsonb)='{}'::jsonb then
        raise exception 'FULLUNDER_REQUIREMENT_DETAIL_DATA_REQUIRED %',v_req;
      end if;
      if jsonb_typeof(coalesce(v_item->'evidence_refs','null'::jsonb)) <> 'array' or jsonb_array_length(coalesce(v_item->'evidence_refs','[]'::jsonb))=0 then
        raise exception 'FULLUNDER_REQUIREMENT_DETAIL_EVIDENCE_REQUIRED %',v_req;
      end if;
      if jsonb_typeof(coalesce(v_item->'output_refs','null'::jsonb)) <> 'array' or jsonb_array_length(coalesce(v_item->'output_refs','[]'::jsonb))=0 then
        raise exception 'FULLUNDER_REQUIREMENT_DETAIL_OUTPUT_REQUIRED %',v_req;
      end if;
      if lower(v_item->>'result_text') ~ '(covered by the|covered by .*packet|accounted by|constitutional evidence packet|same evidence packet|requirements? accounted)' then
        raise exception 'FULLUNDER_REQUIREMENT_DETAIL_GENERIC_TEXT_FORBIDDEN %',v_req;
      end if;
      if v_status like 'UNRESOLVED%' and (
        not (v_item->'data_payload' ? 'recovery_attempts') or
        jsonb_typeof(v_item->'data_payload'->'recovery_attempts') <> 'array' or
        jsonb_array_length(v_item->'data_payload'->'recovery_attempts')=0
      ) then
        raise exception 'FULLUNDER_REQUIREMENT_DETAIL_UNRESOLVED_NEEDS_RECOVERY %',v_req;
      end if;
      for v_ref in select jsonb_array_elements_text(v_item->'evidence_refs') loop
        begin
          if not exists(select 1 from public.fullunder_evidence where evidence_id=v_ref::uuid and run_id=p_run_id and phase_id=p_phase_id) then
            raise exception 'FULLUNDER_REQUIREMENT_DETAIL_EVIDENCE_REF_INVALID % %',v_req,v_ref;
          end if;
        exception when invalid_text_representation then
          raise exception 'FULLUNDER_REQUIREMENT_DETAIL_EVIDENCE_REF_NOT_UUID % %',v_req,v_ref;
        end;
      end loop;

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

revoke all on function public.fullunder_commit_requirement_details(uuid,text,jsonb) from public, anon, authenticated;
grant execute on function public.fullunder_commit_requirement_details(uuid,text,jsonb) to service_role;

insert into public.fullunder_capability_policy(phase_id,action,allowed)
select 'F'||g::text,'SET_REQUIREMENT_DETAILS',true from generate_series(1,8) g
on conflict(phase_id,action) do update set allowed=excluded.allowed;

-- Patch the existing command bus without opening direct table writes.
do $patch$
declare v_def text;
begin
  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='fullunder_submit_command_impl';
  if position('if v_action=''SET_REQUIREMENT_STATES'' then' in v_def)=0 then
    raise exception 'FULLUNDER_COMMAND_IMPL_PATCH_ANCHOR_MISSING';
  end if;
  v_def := replace(v_def,
    'if v_action=''SET_REQUIREMENT_STATES'' then',
    'if v_action=''SET_REQUIREMENT_DETAILS'' then
        select public.fullunder_commit_requirement_details(v_run,v_phase,v_payload->''details'') into v_stale;
        v_result:=jsonb_build_object(''details_committed'',v_stale,''phase_id'',v_phase);
      elsif v_action=''SET_REQUIREMENT_STATES'' then');
  execute v_def;
end
$patch$;

create or replace function public.fullunder_run_readiness_invariant()
returns trigger
language plpgsql
security definer
set search_path to 'public','extensions'
as $fn$
declare
  v_audit jsonb;
  v_appendix public.fullunder_artifacts%rowtype;
  v_wd jsonb;
  i integer;
begin
  if new.ready_for_analyst or new.status='COMPLETED' then
    if not new.ready_for_analyst or new.status<>'COMPLETED' then
      raise exception 'FULLUNDER_READY_COMPLETED_MUST_BE_ATOMIC';
    end if;
    v_audit := public.fullunder_requirement_detail_audit(new.run_id,null);
    if coalesce((v_audit->>'pass')::boolean,false) is not true then
      raise exception 'FULLUNDER_READY_REQUIREMENT_DETAIL_INCOMPLETE %',v_audit::text;
    end if;
    for i in 1..8 loop
      v_wd := public.fullunder_execution_watchdog(new.run_id,'F'||i::text);
      if coalesce((v_wd->>'pass')::boolean,false) is not true then
        raise exception 'FULLUNDER_READY_PHASE_WATCHDOG_FAILED F% %',i,v_wd::text;
      end if;
    end loop;
    select * into v_appendix from public.fullunder_artifacts
      where run_id=new.run_id and artifact_type='FULL_REQUIREMENT_EXECUTION_APPENDIX'
      order by created_at desc limit 1;
    if not found then raise exception 'FULLUNDER_READY_EXHAUSTIVE_APPENDIX_REQUIRED'; end if;
    if not v_appendix.readback_pass or v_appendix.readback_hash is null or v_appendix.readback_hash<>v_appendix.content_hash then
      raise exception 'FULLUNDER_READY_EXHAUSTIVE_APPENDIX_READBACK_INVALID';
    end if;
    if v_appendix.content_hash<>public.fullunder_requirement_execution_appendix_hash(new.run_id) then
      raise exception 'FULLUNDER_READY_EXHAUSTIVE_APPENDIX_HASH_MISMATCH';
    end if;
    if not exists(select 1 from public.fullunder_handoffs where run_id=new.run_id and ready_for_analyst) then
      raise exception 'FULLUNDER_READY_REQUIRES_VALID_HANDOFF';
    end if;
  end if;
  return new;
end
$fn$;

drop trigger if exists zzz_fullunder_run_readiness_invariant_t on public.fullunder_runs;
create trigger zzz_fullunder_run_readiness_invariant_t
before update of status,ready_for_analyst on public.fullunder_runs
for each row execute function public.fullunder_run_readiness_invariant();

-- Existing phase and handoff exhaustive gates remain authoritative:
--   fullunder_phase_requirement_detail_gate
--   fullunder_handoff_exhaustive_report_gate
--   fullunder_chat_handoff_exhaustive_gate
--   fullunder_requirement_detail_write_guard
--   fullunder_requirement_detail_audit
--   fullunder_build_requirement_execution_appendix

-- Production correction applied to the legacy CHC@SEA run:
-- run_id 58739976-4be5-47bb-9e21-06715facf0ff
-- COMPLETED / ready_for_analyst=true -> INVALIDATED_REQUIREMENT_REBUILD / false
-- because requirement_detail_audit was 0/889.

-- Patch-level observed tests (all executed with rollback fixtures where applicable):
-- 1. legal command-bus detail write -> PASS
-- 2. generic reusable detail text -> REJECT
-- 3. direct requirement-detail write -> REJECT
-- 4. premature F1 close at 0/93 -> REJECT
-- 5. restore invalid legacy READY at 0/889 -> REJECT
