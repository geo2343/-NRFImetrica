-- @NRFImetrica forensic repair after PROCESS_INVALID audit, 2026-08-20.
-- Canonical production migration corresponding to Supabase migration
-- nrfimetrica_v18_forensic_process_repair.

create or replace function public.nrfimetrica_resolve_active_authority_hash_v18()
returns text language plpgsql set search_path=public,extensions,pg_temp as $$
declare a public.agent_registry%rowtype; pa public.protocol_authority%rowtype;
begin
  select * into a from public.agent_registry where agent_id='@NRFImetrica' and status='ACTIVE';
  if not found then raise exception 'NRFIM_AUTHORITY_AGENT_NOT_ACTIVE' using errcode='23514'; end if;
  select * into pa from public.protocol_authority where protocol_id=a.protocol_id and active;
  if not found then raise exception 'NRFIM_AUTHORITY_PROTOCOL_NOT_ACTIVE:%',a.protocol_id using errcode='23514'; end if;
  if coalesce(a.mother_document_sha256,'')='' or coalesce(pa.document_sha256,'')='' then raise exception 'NRFIM_AUTHORITY_HASH_MISSING' using errcode='23514'; end if;
  if a.mother_document_sha256 is distinct from pa.document_sha256 then raise exception 'NRFIM_AUTHORITY_CONFLICT:AGENT=%:PROTOCOL=%',a.mother_document_sha256,pa.document_sha256 using errcode='23514'; end if;
  return a.mother_document_sha256;
end $$;

create or replace function public.nrfimetrica_assert_run_authority_snapshot_v18(p_run_id text,p_protocol_id text default 'NRFIMETRICA_MOTHER_V3_AUTONOMOUS')
returns void language plpgsql set search_path=public,extensions,pg_temp as $$
declare expected_hash text; sealed_hash text; sealed_status text;
begin
  expected_hash:=public.nrfimetrica_resolve_active_authority_hash_v18();
  select rs.payload->>'mother_document_sha256',rs.status into sealed_hash,sealed_status from public.protocol_run_state rs where rs.run_id=p_run_id and rs.protocol_id=p_protocol_id and rs.stage_id='A0_CONSTITUTION_SEALED' order by rs.submitted_at desc limit 1;
  if sealed_hash is null then raise exception 'A0_MOTHER_CONSTITUTION_NOT_SEALED' using errcode='23514'; end if;
  if sealed_status<>'COMPLETE' then raise exception 'A0_MOTHER_CONSTITUTION_NOT_COMPLETE:%',sealed_status using errcode='23514'; end if;
  if sealed_hash is distinct from expected_hash then raise exception 'A0_AUTHORITY_SNAPSHOT_STALE_OR_CONFLICT:SEALED=%:ACTIVE=%',sealed_hash,expected_hash using errcode='23514'; end if;
end $$;

create or replace function public.nrfimetrica_seal_a0_authority_v18(p_run_id text)
returns jsonb language plpgsql set search_path=public,extensions,pg_temp as $$
declare r public.runs%rowtype; a public.agent_registry%rowtype; expected_hash text; payload_out jsonb;
begin
  select * into r from public.runs where run_id=p_run_id;
  if not found or r.system_version<>'NRFIM MOTHER V3' then raise exception 'A0_RUN_NOT_NRFIM_MOTHER_V3:%',p_run_id using errcode='23514'; end if;
  select * into a from public.agent_registry where agent_id='@NRFImetrica' and status='ACTIVE';
  if not found then raise exception 'A0_ACTIVE_AGENT_NOT_FOUND' using errcode='23514'; end if;
  expected_hash:=public.nrfimetrica_resolve_active_authority_hash_v18();
  payload_out:=jsonb_build_object('mother_document_sha256',expected_hash,'agent_registry_hash',a.mother_document_sha256,'protocol_authority_hash',expected_hash,'authority_resolution','DYNAMIC_AGENT_REGISTRY_PLUS_PROTOCOL_AUTHORITY','agent_id',a.agent_id,'agent_version',a.agent_version,'kernel_version',a.kernel_version,'protocol_id',a.protocol_id,'manual_phase_authorization_required',a.manual_phase_authorization_required,'sealed_at',clock_timestamp());
  if exists(select 1 from public.protocol_run_state where run_id=p_run_id and protocol_id=a.protocol_id and stage_id='A0_CONSTITUTION_SEALED') then perform public.nrfimetrica_assert_run_authority_snapshot_v18(p_run_id,a.protocol_id); return (select payload from public.protocol_run_state where run_id=p_run_id and protocol_id=a.protocol_id and stage_id='A0_CONSTITUTION_SEALED' order by submitted_at desc limit 1); end if;
  insert into public.protocol_run_state(run_id,protocol_id,stage_id,status,payload,evidence_ids,output_text,submitted_at) values(p_run_id,a.protocol_id,'A0_CONSTITUTION_SEALED','COMPLETE',payload_out,'{}','A0 authority sealed from dynamic canonical authority equality.',clock_timestamp());
  return payload_out;
end $$;

do $$
declare f text; original text; old_hash constant text:='44edaa44707293115f8d129b8903c1d8f7dfa5f6bd79674de29cee01091228d8';
begin
  f:=pg_get_functiondef('public.enforce_nrfimetrica_run_stage()'::regprocedure); original:=f;
  f:=replace(f,'if new.payload->>''mother_document_sha256''<>'''||old_hash||''' then raise exception ''A0_MOTHER_HASH_MISMATCH'' using errcode=''23514''; end if;','if new.payload->>''mother_document_sha256''<>public.nrfimetrica_resolve_active_authority_hash_v18() then raise exception ''A0_MOTHER_HASH_MISMATCH'' using errcode=''23514''; end if;');
  if f=original then raise exception 'V18_PATCH_FAILED:enforce_nrfimetrica_run_stage'; end if; execute f;
  f:=pg_get_functiondef('public.enforce_nrfimetrica_mother_semantics()'::regprocedure); original:=f;
  f:=replace(f,'if not exists(select 1 from public.protocol_run_state rs where rs.run_id=new.run_id and rs.protocol_id=p and rs.stage_id=''A0_CONSTITUTION_SEALED'' and rs.payload->>''mother_document_sha256''='''||old_hash||''') then raise exception ''A0_MOTHER_CONSTITUTION_NOT_SEALED'' using errcode=''23514''; end if;','if new.phase_id <> ''A0P_PRESS_INFORMATION_INTAKE'' then perform public.nrfimetrica_assert_run_authority_snapshot_v18(new.run_id,new.protocol_id); end if;');
  if f=original then raise exception 'V18_PATCH_FAILED:enforce_nrfimetrica_mother_semantics'; end if; execute f;
end $$;

create or replace view public.nrfimetrica_sports_reasoning_readiness_v18 with(security_invoker=true) as
select g.run_id,g.game_id,g.status as game_status,
exists(select 1 from public.protocol_phase_state s where s.run_id=g.run_id and s.game_id=g.game_id and s.protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and s.phase_id='A0P_PRESS_INFORMATION_INTAKE' and s.status in('COMPLETE','SKIPPED_NOT_TRIGGERED')) as press_preanalysis_resolved,
exists(select 1 from public.protocol_run_state rs where rs.run_id=g.run_id and rs.protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and rs.stage_id='A0_CONSTITUTION_SEALED' and rs.status='COMPLETE') as certification_authority_sealed,
exists(select 1 from public.sports_reasoning_packets p where p.run_id=g.run_id and p.game_id=g.game_id) as sports_packet_exists,
case when g.status='AUDIT_ONLY' then 'AUDIT_ONLY' when exists(select 1 from public.protocol_phase_state s where s.run_id=g.run_id and s.game_id=g.game_id and s.protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and s.phase_id='A0P_PRESS_INFORMATION_INTAKE' and s.status in('COMPLETE','SKIPPED_NOT_TRIGGERED')) then 'SPORTS_REASONING_ALLOWED' else 'SPORTS_PREANALYSIS_PENDING' end as sports_reasoning_route
from public.games g;

create table if not exists public.nrfimetrica_game_artifacts(artifact_id uuid primary key default gen_random_uuid(),run_id text not null,game_id text not null,artifact_kind text not null check(artifact_kind in('GAME_FOLDER','SPORTS_REASONING_PACKET','SOURCES_INDEX','CLAIM_EVIDENCE_MAP','TRACE_LOG','SNAPSHOT')),drive_file_id text not null,content_hash text,verified_at timestamptz,metadata jsonb not null default '{}'::jsonb,created_at timestamptz not null default clock_timestamp(),unique(run_id,game_id,artifact_kind,drive_file_id));
alter table public.nrfimetrica_game_artifacts enable row level security;
revoke insert,update,delete,truncate on public.nrfimetrica_game_artifacts from anon,authenticated;

create or replace function public.nrfimetrica_enforce_process_artifact_manifest_v18() returns trigger language plpgsql set search_path=public,extensions,pg_temp as $$
declare required_count integer; packet_hash text; packet_drive_id text;
begin
  if new.status<>'PASS' then return new; end if;
  select count(distinct artifact_kind) into required_count from public.nrfimetrica_game_artifacts where run_id=new.run_id and game_id=new.game_id and artifact_kind in('GAME_FOLDER','SPORTS_REASONING_PACKET','SOURCES_INDEX','CLAIM_EVIDENCE_MAP','TRACE_LOG') and verified_at is not null;
  if required_count<>5 then raise exception 'PROCESS_AUDIT_DRIVE_ARTIFACT_MANIFEST_INCOMPLETE:%/5',required_count using errcode='23514'; end if;
  select p.packet_hash,p.drive_file_id into packet_hash,packet_drive_id from public.sports_reasoning_packets p where p.packet_id=new.packet_id;
  if not exists(select 1 from public.nrfimetrica_game_artifacts a where a.run_id=new.run_id and a.game_id=new.game_id and a.artifact_kind='SPORTS_REASONING_PACKET' and a.drive_file_id=packet_drive_id and a.content_hash=packet_hash and a.verified_at is not null) then raise exception 'PROCESS_AUDIT_PACKET_DRIVE_MANIFEST_HASH_MISMATCH' using errcode='23514'; end if;
  return new;
end $$;
drop trigger if exists trg_02_nrfim_process_artifact_manifest_v18 on public.sports_process_audits;
create trigger trg_02_nrfim_process_artifact_manifest_v18 before insert on public.sports_process_audits for each row execute function public.nrfimetrica_enforce_process_artifact_manifest_v18();

create or replace function public.nrfimetrica_build_report_snapshot_v18(p_run_id text) returns jsonb language plpgsql stable set search_path=public,extensions,pg_temp as $$
declare result jsonb;
begin
select jsonb_build_object('run_id',p_run_id,
'summary',jsonb_build_object('sports_candidate_count',count(*) filter(where d.sports_status='SPORTS_CANDIDATE'),'sports_no_play_count',count(*) filter(where d.sports_status='NO_PLAY'),'sports_watchlist_count',count(*) filter(where d.sports_status='WATCHLIST'),'sports_audit_only_count',count(*) filter(where d.sports_status='AUDIT_ONLY'),'technical_block_count',count(*) filter(where d.execution_status='TECHNICAL_BLOCK'),'process_block_count',count(*) filter(where d.execution_status='PROCESS_BLOCK'),'process_verified_count',count(*) filter(where d.process_status='VERIFIED'),'process_failed_count',count(*) filter(where d.process_status='FAIL'),'process_incomplete_count',count(*) filter(where d.process_status='INCOMPLETE'),'execution_candidate_count',count(*) filter(where d.execution_status='EXECUTABLE'),'sports_shortlist_count',coalesce((select s.shortlist_count from public.nrfimetrica_sports_shortlists s where s.run_id=p_run_id order by s.created_at desc limit 1),0),'sports_shortlist_status',coalesce((select s.status from public.nrfimetrica_sports_shortlists s where s.run_id=p_run_id order by s.created_at desc limit 1),'NOT_AVAILABLE')),
'game_statuses',coalesce((select jsonb_agg(jsonb_build_object('game_id',x.game_id,'sports_status',x.sports_status,'process_status',x.process_status,'execution_status',x.execution_status,'sports_verdict',x.sports_verdict,'packet_id',x.packet_id,'packet_status',x.packet_status,'top_half_verdict',x.top_half_verdict,'bottom_half_verdict',x.bottom_half_verdict,'bilateral_nrfi_proven',x.bilateral_nrfi_proven,'drive_hash_verified',x.drive_hash_verified) order by g.scheduled_start,x.game_id) from public.nrfimetrica_game_dual_status x join public.games g on g.run_id=x.run_id and g.game_id=x.game_id where x.run_id=p_run_id),'[]'::jsonb),
'sports_candidates',coalesce((select jsonb_agg(jsonb_build_object('game_id',x.game_id,'sports_status',x.sports_status,'process_status',x.process_status,'execution_status',x.execution_status,'sports_verdict',x.sports_verdict,'packet_id',x.packet_id,'evidence_state',case when x.packet_id is null then 'MISSING' else 'PHYSICAL_PACKET' end) order by g.scheduled_start,x.game_id) from public.nrfimetrica_game_dual_status x join public.games g on g.run_id=x.run_id and g.game_id=x.game_id where x.run_id=p_run_id and x.sports_status='SPORTS_CANDIDATE'),'[]'::jsonb),
'final_sports_shortlist',coalesce((select case when s.optional_third is null then s.primary_candidates else s.primary_candidates||jsonb_build_array(s.optional_third) end from public.nrfimetrica_sports_shortlists s where s.run_id=p_run_id order by s.created_at desc limit 1),'[]'::jsonb),
'user_actions',coalesce((select jsonb_agg(jsonb_build_object('game_id',u.game_id,'user_action',u.user_action,'bet_allowed',u.bet_allowed) order by g.scheduled_start,u.game_id) from public.nrfimetrica_user_action u join public.games g on g.run_id=u.run_id and g.game_id=u.game_id where u.run_id=p_run_id),'[]'::jsonb)) into result from public.nrfimetrica_game_dual_status d where d.run_id=p_run_id;
return coalesce(result,jsonb_build_object('run_id',p_run_id,'summary','{}'::jsonb,'game_statuses','[]'::jsonb,'sports_candidates','[]'::jsonb,'final_sports_shortlist','[]'::jsonb,'user_actions','[]'::jsonb));
end $$;

create or replace function public.nrfimetrica_force_db_derived_final_report_v18() returns trigger language plpgsql set search_path=public,extensions,pg_temp as $$
declare snap jsonb; summary_existing jsonb;
begin
if new.protocol_id<>'NRFIMETRICA_MOTHER_V3_AUTONOMOUS' or new.stage_id<>'FINAL_REPORT' then return new; end if;
snap:=public.nrfimetrica_build_report_snapshot_v18(new.run_id); summary_existing:=coalesce(new.payload->'summary','{}'::jsonb);
new.payload:=jsonb_set(new.payload,'{summary}',summary_existing||(snap->'summary'),true); new.payload:=jsonb_set(new.payload,'{game_statuses}',snap->'game_statuses',true); new.payload:=jsonb_set(new.payload,'{sports_candidates}',snap->'sports_candidates',true); new.payload:=jsonb_set(new.payload,'{final_sports_shortlist}',snap->'final_sports_shortlist',true); new.payload:=jsonb_set(new.payload,'{physical_state_snapshot}',snap,true); new.payload:=jsonb_set(new.payload,'{report_source}','"DB_DERIVED_ONLY"'::jsonb,true); return new;
end $$;
drop trigger if exists trg_00a_nrfim_db_derived_final_report_v18 on public.protocol_run_state;
create trigger trg_00a_nrfim_db_derived_final_report_v18 before insert or update on public.protocol_run_state for each row execute function public.nrfimetrica_force_db_derived_final_report_v18();

update public.system_versions set contract_doc_id='MOTHER_SHA256:'||public.nrfimetrica_resolve_active_authority_hash_v18(),kernel_version='NRFIM-KERNEL-1.8-FORENSIC-REPAIR',calibration_status='SYSTEM_AUDIT_ONLY_NO_GAME_OVERRIDE' where system_version='NRFIM MOTHER V3';
update public.protocol_authority set latest_sovereign_patch='FORENSIC_RUNTIME_REPAIR — 2026-08-20',precedence_rule='V18_FORENSIC_REPAIR_PLUS_V17_SELF_AUDIT_HARDENING_PLUS_PREANALYSIS_PRESS_PLUS_CALIBRATE_SYSTEM_NOT_GAME' where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and active;
update public.agent_registry set agent_version='MOTHER-V3-AGENT-1.13',kernel_version='NRFIM-KERNEL-1.8-FORENSIC-REPAIR',metadata=(coalesce(metadata,'{}'::jsonb)-'refactor_state'-'refactor_started_at')||jsonb_build_object('database_migrations_required_through',73,'github_migrations_through',73,'forensic_repair_state','ACTIVE_AFTER_PROCESS_INVALID_REPAIR','a0_authority_resolution','DYNAMIC_AGENT_REGISTRY_PLUS_PROTOCOL_AUTHORITY','sports_reasoning_independent_of_certification_chain',true,'a0p_allowed_without_a0_for_sports_preanalysis',true,'a1_a8_still_require_valid_a0',true,'packet_required_for_every_game_resolution',true,'no_play_same_research_burden',true,'report_source','DB_DERIVED_ONLY','no_packet_report_state','WATCHLIST_PROCESS_MISSING_DO_NOT_BET','drive_game_artifacts_required',true,'process_auditor','KERNEL_PROCESS_AUDITOR_0.3','real_money_authority',false,'economic_firewall_preserved',true,'ai_probability_fabrication_forbidden',true),updated_at=clock_timestamp() where agent_id='@NRFImetrica';

revoke all on function public.nrfimetrica_resolve_active_authority_hash_v18() from public,anon,authenticated;
revoke all on function public.nrfimetrica_assert_run_authority_snapshot_v18(text,text) from public,anon,authenticated;
revoke all on function public.nrfimetrica_seal_a0_authority_v18(text) from public,anon,authenticated;
revoke all on function public.nrfimetrica_build_report_snapshot_v18(text) from public,anon,authenticated;
revoke all on function public.nrfimetrica_force_db_derived_final_report_v18() from public,anon,authenticated;
revoke all on function public.nrfimetrica_enforce_process_artifact_manifest_v18() from public,anon,authenticated;
