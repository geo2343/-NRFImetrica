-- Research-only continuation for CONTROLLED_REAL.
-- This does NOT grant real-money authority. A7 release and A8 remain governed
-- by ACTIVE_TRUSTED / certified controls in the Mother V3 semantic gates.

create or replace function public.enforce_nrfimetrica_trusted_components()
returns trigger
language plpgsql
as $$
declare
  run_mode text;
  reg_status text;
  ex public.numeric_engine_executions%rowtype;
  audit_ex public.independent_audit_executions%rowtype;
  packet public.nrfiprensa_packets%rowtype;
  a4_status text;
  audit_status text;
begin
  if new.protocol_id<>'NRFIMETRICA_MOTHER_V3_AUTONOMOUS' then return new; end if;
  select mode into run_mode from public.runs where run_id=new.run_id;

  if new.phase_id='A4_NUMERIC_STATE_ENGINE' then
    select e.* into ex from public.numeric_engine_executions e
    where e.execution_id=new.payload #>> '{numeric_engine,execution_id}' limit 1;
    if not found or ex.run_id<>new.run_id or ex.game_id<>new.game_id or ex.provenance_status<>'PASS' then
      raise exception 'A4_TRUSTED_NUMERIC_EXECUTION_REQUIRED' using errcode='23514';
    end if;
    select status into reg_status from public.numeric_engine_registry where engine_id=ex.engine_id;
    a4_status:=upper(coalesce(new.payload->>'a4_numeric_provenance_status',''));

    if run_mode='DIAGNOSTIC' then
      if reg_status not in ('DIAGNOSTIC_TRUSTED','ACTIVE_TRUSTED') then
        raise exception 'A4_NUMERIC_ENGINE_NOT_TRUSTED_FOR_DIAGNOSTIC:%',coalesce(reg_status,'NONE') using errcode='23514';
      end if;
    elsif a4_status in ('A4_RESEARCH_READY_FULL','A4_RESEARCH_READY_REDUCED','A4_RESEARCH_READY_BOOTSTRAP','A4_RESEARCH_READY_HIGH_UNCERTAINTY') then
      if reg_status not in ('DIAGNOSTIC_TRUSTED','ACTIVE_TRUSTED') then
        raise exception 'A4_RESEARCH_ENGINE_NOT_TRUSTED:%',coalesce(reg_status,'NONE') using errcode='23514';
      end if;
    else
      if reg_status is distinct from 'ACTIVE_TRUSTED' then
        raise exception 'A4_NUMERIC_ENGINE_NOT_ACTIVE_TRUSTED_FOR_EXECUTION:%',coalesce(reg_status,'NONE') using errcode='23514';
      end if;
    end if;

    if ex.model_version is distinct from new.payload #>> '{numeric_engine,model_version}'
       or ex.transition_version is distinct from new.payload #>> '{numeric_engine,transition_version}'
       or ex.input_freeze_id is distinct from new.payload #>> '{numeric_engine,input_freeze_id}' then
      raise exception 'A4_TRUSTED_EXECUTION_METADATA_MISMATCH' using errcode='23514';
    end if;
    if ex.executed_at>new.submitted_at then
      raise exception 'A4_NUMERIC_EXECUTION_FROM_FUTURE' using errcode='23514';
    end if;

  elsif new.phase_id='A6_CAUSAL_FALSIFICATION_SPORTS_SEAL' then
    select a.* into audit_ex from public.independent_audit_executions a
    where a.audit_execution_id=new.payload #>> '{independent_audit,audit_execution_id}' limit 1;
    if not found or audit_ex.run_id<>new.run_id or audit_ex.game_id<>new.game_id then
      raise exception 'A6_TRUSTED_INDEPENDENT_AUDIT_EXECUTION_REQUIRED' using errcode='23514';
    end if;
    select status into reg_status from public.independent_auditor_registry where auditor_id=audit_ex.auditor_id;
    audit_status:=upper(coalesce(new.payload #>> '{independent_audit,status}',''));

    if run_mode='DIAGNOSTIC' then
      if reg_status not in ('DIAGNOSTIC_TRUSTED','ACTIVE_TRUSTED') then
        raise exception 'A6_AUDITOR_NOT_TRUSTED_FOR_DIAGNOSTIC:%',coalesce(reg_status,'NONE') using errcode='23514';
      end if;
    elsif audit_status='CONDITIONED' then
      if reg_status not in ('DIAGNOSTIC_TRUSTED','ACTIVE_TRUSTED') then
        raise exception 'A6_RESEARCH_AUDITOR_NOT_TRUSTED:%',coalesce(reg_status,'NONE') using errcode='23514';
      end if;
    else
      if reg_status is distinct from 'ACTIVE_TRUSTED' then
        raise exception 'A6_AUDITOR_NOT_ACTIVE_TRUSTED_FOR_PASS:%',coalesce(reg_status,'NONE') using errcode='23514';
      end if;
    end if;

    if audit_ex.auditor_id is distinct from new.payload #>> '{independent_audit,auditor_id}'
       or audit_ex.primary_analyst_id is distinct from new.payload->>'primary_analyst_id'
       or audit_ex.status not in ('PASS','CONDITIONED') then
      raise exception 'A6_TRUSTED_AUDIT_METADATA_MISMATCH' using errcode='23514';
    end if;
    if audit_ex.executed_at>new.submitted_at then
      raise exception 'A6_AUDIT_EXECUTION_FROM_FUTURE' using errcode='23514';
    end if;

  elsif new.phase_id='A7_CALIBRATION_ELIGIBILITY_PRESS' then
    select n.* into packet from public.nrfiprensa_packets n
    where n.packet_id=new.payload #>> '{nrfi_prensa,packet_id}' limit 1;
    if not found or packet.run_id<>new.run_id or packet.game_id<>new.game_id or packet.source_agent<>'@NRFIprensa' then
      raise exception 'A7_TRUSTED_NRFIPRENSA_PACKET_REQUIRED' using errcode='23514';
    end if;
    if run_mode='DIAGNOSTIC' then
      if packet.status<>'DIAGNOSTIC_VERIFIED' then
        raise exception 'A7_NRFIPRENSA_PACKET_NOT_DIAGNOSTIC_VERIFIED' using errcode='23514';
      end if;
    else
      if packet.status<>'VERIFIED' then
        raise exception 'A7_NRFIPRENSA_PACKET_NOT_VERIFIED' using errcode='23514';
      end if;
    end if;
    if packet.content_hash is distinct from new.payload #>> '{nrfi_prensa,packet_hash}' then
      raise exception 'A7_NRFIPRENSA_PACKET_HASH_MISMATCH' using errcode='23514';
    end if;
    if packet.generated_at>new.submitted_at then
      raise exception 'A7_NRFIPRENSA_PACKET_FROM_FUTURE' using errcode='23514';
    end if;
  end if;
  return new;
end;
$$;

-- Mother semantic gate must recognize research-only A4 states so A5/A6 may
-- continue analytically. These states are explicitly not A4_NUMERIC_PROVENANCE_PASS.
do $$
declare f text;
begin
  select pg_get_functiondef(p.oid) into f
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='enforce_nrfimetrica_mother_semantics';

  if f is null then raise exception 'MOTHER_SEMANTICS_FUNCTION_NOT_FOUND'; end if;

  f:=regexp_replace(
    f,
    $rx$if upper\(coalesce\(new\.payload->>'a4_numeric_provenance_status',''\)\) not in \([^;]*\) then\s*raise exception 'A4_STATUS_INVALID'[^;]*;\s*end if;$rx$,
    $rep$if upper(coalesce(new.payload->>'a4_numeric_provenance_status','')) not in (
      'A4_NUMERIC_PROVENANCE_PASS','A4_RESEARCH_READY_FULL','A4_RESEARCH_READY_REDUCED','A4_RESEARCH_READY_BOOTSTRAP','A4_RESEARCH_READY_HIGH_UNCERTAINTY',
      'A4_REOPEN_A3','A4_REOPEN_A2','A4_REOPEN_A1','A4_TRUE_MODEL_FAILURE'
    ) then
      raise exception 'A4_STATUS_INVALID' using errcode='23514';
    end if;$rep$,
    'n'
  );
  execute f;
end $$;

-- Safety invariant: CONTROLLED_REAL release remains strict. The existing Mother
-- semantics requires A4_NUMERIC_PROVENANCE_PASS and independent audit PASS for
-- A7 release, and A8 requires that issued A7 release. Calibration authority for
-- CONTROLLED_REAL remains ACTIVE_TRUSTED.

update public.agent_registry
set metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object(
  'controlled_real_research_fallback',true,
  'research_fallback_a4_allowed',true,
  'research_fallback_a6_conditioned_allowed',true,
  'research_fallback_may_issue_a7_release',false,
  'research_fallback_may_execute_a8',false,
  'database_migrations_required_through',28
)
where agent_id='@NRFImetrica';
