-- @iainvestigadora V1.4 — consolidated connected-kernel migration
-- Mirrors production migrations applied on 2026-08-20:
-- register_iainvestigadora_v14_connected_kernel
-- harden_iainvestigadora_v14_semantics
-- fix_iainvestigadora_f5_slot_guard
-- bind_iainvestigadora_final_report_to_drive_readback

begin;

-- Authority + registry. Uses the existing shared architecture; no parallel tables.
insert into public.agent_registry(
  agent_id,agent_version,status,protocol_id,system_version,kernel_version,
  mother_document_sha256,manifest_path,activation_aliases,
  manual_phase_authorization_required,auto_advance,
  drive_root_folder_id,drive_execution_folder_id,drive_authority_folder_id,
  real_money_authority,metadata
) values (
  '@iainvestigadora','IAINVESTIGADORA-AGENT-1.4','ACTIVE','IAINVESTIGADORA_MLB_V14',
  'IAINVESTIGADORA-MLB-V1.4','IAINV-KERNEL-0.1-CONNECTED',
  '785a42e9906b307ed66f16a1f1fed8ec82aa484eb663bfc272da1f60bf47bfaa',
  'agents/iainvestigadora_agent.json',array['@iainvestigadora','Investiga'],false,true,
  '19CGotK0rnBeRTpUVsuV79RIIymnzkMf0','1uzKh24DMcVi6eQWgGcxO2YbC25O2SBIr','1g4drHfqSg1vQ71eovcaLzYBt80w5MVli',false,
  jsonb_build_object(
    'target_scope','ONE_EXPLICIT_MLB_GAME_PER_RUN',
    'audit_folder_id','1KPfrc7kttqzxY3-q21yKfFLhMZlu-xyC',
    'patch_document_id','1QlPCuxqNXnlprakP850L4PRqwxMX_L3lWsxVqQzLzqo',
    'analyzed_folder_id','1XzgJG2A6s8LsTLZv0b4nVEaaup5v12e9',
    'conditional_phases',jsonb_build_array('F6','F8','F11'),
    'handoff_destination','@ianalista',
    'real_run_validation','PENDING',
    'template_document_id','10FGletumsFxNMLsJ8lcL0RstnSy7ZtVYmVN3xHUz8Hk'
  )
) on conflict(agent_id) do update set
  agent_version=excluded.agent_version,status=excluded.status,protocol_id=excluded.protocol_id,
  system_version=excluded.system_version,kernel_version=excluded.kernel_version,
  mother_document_sha256=excluded.mother_document_sha256,manifest_path=excluded.manifest_path,
  activation_aliases=excluded.activation_aliases,manual_phase_authorization_required=false,
  auto_advance=true,drive_root_folder_id=excluded.drive_root_folder_id,
  drive_execution_folder_id=excluded.drive_execution_folder_id,
  drive_authority_folder_id=excluded.drive_authority_folder_id,
  real_money_authority=false,metadata=excluded.metadata,updated_at=clock_timestamp();

insert into public.protocol_authority(
  protocol_id,authority_name,document_sha256,document_lines,precedence_rule,
  latest_sovereign_patch,manual_phase_authorization_required,active
) values (
  'IAINVESTIGADORA_MLB_V14','@iainvestigadora — Constitución V1.3 + Patch Operativo V1.4',
  '785a42e9906b307ed66f16a1f1fed8ec82aa484eb663bfc272da1f60bf47bfaa',108,
  'CONSTITUCION_V1.3 > PATCH_OPERATIVO_V1.4 > MANUAL_V1.3 > FASES_V1.3 > PLANTILLA_V1.3',
  'PATCH_OPERATIVO_V1.4_KERNEL_CONNECTED',false,true
) on conflict(protocol_id) do update set
 authority_name=excluded.authority_name,document_sha256=excluded.document_sha256,
 document_lines=excluded.document_lines,precedence_rule=excluded.precedence_rule,
 latest_sovereign_patch=excluded.latest_sovereign_patch,
 manual_phase_authorization_required=false,active=true;

-- Phase catalog (F1-F12). Generic shared protocol gates read this catalog.
delete from public.protocol_phase_prerequisites where protocol_id='IAINVESTIGADORA_MLB_V14';
delete from public.protocol_phase_catalog where protocol_id='IAINVESTIGADORA_MLB_V14';

insert into public.protocol_phase_catalog(protocol_id,phase_id,conditional,trigger_path,required_fields,min_source_calls,min_evidence_ids,required_documents,required_phrases,max_items) values
('IAINVESTIGADORA_MLB_V14','F1',false,null,array['target_binding.game_id','snapshot.pregame_as_of','game_identity.away_team','game_identity.home_team','game_identity.venue','game_identity.scheduled_start','actors.starters.away.state','actors.starters.home.state','actors.lineups.away.state','actors.lineups.home.state','actors.catchers.away.state','actors.catchers.home.state','phase_execution_receipt'],1,1,'{}','{}','{}'),
('IAINVESTIGADORA_MLB_V14','F2',false,null,array['target_binding.game_id','starters.away.identity','starters.away.hand','starters.away.health_state','starters.away.restriction_state','starters.away.arsenal','starters.away.process','starters.away.as_of','starters.home.identity','starters.home.hand','starters.home.health_state','starters.home.restriction_state','starters.home.arsenal','starters.home.process','starters.home.as_of','current_version','phase_execution_receipt'],1,1,'{}','{}','{}'),
('IAINVESTIGADORA_MLB_V14','F3',false,null,array['target_binding.game_id','early_horizon.away.windows','early_horizon.away.stability','early_horizon.away.first_inning','early_horizon.away.as_of','early_horizon.home.windows','early_horizon.home.stability','early_horizon.home.first_inning','early_horizon.home.as_of','phase_execution_receipt'],1,1,'{}','{}','{}'),
('IAINVESTIGADORA_MLB_V14','F4',false,null,array['target_binding.game_id','offense.away.identity','offense.away.hand_split','offense.away.top_order','offense.away.damage_profile','offense.away.traffic_profile','offense.away.as_of','offense.home.identity','offense.home.hand_split','offense.home.top_order','offense.home.damage_profile','offense.home.traffic_profile','offense.home.as_of','phase_execution_receipt'],1,1,'{}','{}','{}'),
('IAINVESTIGADORA_MLB_V14','F5',false,null,array['target_binding.game_id','sentinel_coverage.away','sentinel_coverage.home','matchups','deep_dive_justification','phase_execution_receipt'],1,1,'{}','{}','{}'),
('IAINVESTIGADORA_MLB_V14','F6',true,'trigger_material_evaluation.trigger_material',array['target_binding.game_id','trigger_material_evaluation','comparables','phase_execution_receipt'],1,1,'{}','{}','{}'),
('IAINVESTIGADORA_MLB_V14','F7',false,null,array['target_binding.game_id','bullpen.away.availability_state','bullpen.away.recent_usage','bullpen.away.key_arms','bullpen.home.availability_state','bullpen.home.recent_usage','bullpen.home.key_arms','availability_as_of','phase_execution_receipt'],1,1,'{}','{}','{}'),
('IAINVESTIGADORA_MLB_V14','F8',true,'trigger_material_evaluation.trigger_material',array['target_binding.game_id','trigger_material_evaluation','conversion','phase_execution_receipt'],1,1,'{}','{}','{}'),
('IAINVESTIGADORA_MLB_V14','F9',false,null,array['target_binding.game_id','environment.venue.name','environment.conditions.weather_state','environment.conditions.roof_state','environment.conditions.as_of','phase_execution_receipt'],1,1,'{}','{}','{}'),
('IAINVESTIGADORA_MLB_V14','F10',false,null,array['target_binding.game_id','human_information_state','deltas_state','quarantine_state','phase_execution_receipt'],1,1,'{}','{}','{}'),
('IAINVESTIGADORA_MLB_V14','F11',true,'trigger_material_evaluation.trigger_material',array['target_binding.game_id','trigger_material_evaluation','genealogies','phase_execution_receipt'],1,1,'{}','{}','{}'),
('IAINVESTIGADORA_MLB_V14','F12',false,null,array['target_binding.game_id','final_pregame_snapshot','phase_receipt_ledger','mandatory_phases_not_run','core_mission_complete','drive_report_complete','chat_report_complete','ready_for_handoff','final_sports_store','phase_execution_receipt'],0,0,'{}','{}','{}');

insert into public.protocol_phase_prerequisites(protocol_id,phase_id,prerequisite_phase_id) values
('IAINVESTIGADORA_MLB_V14','F2','F1'),('IAINVESTIGADORA_MLB_V14','F3','F2'),
('IAINVESTIGADORA_MLB_V14','F4','F3'),('IAINVESTIGADORA_MLB_V14','F5','F4'),
('IAINVESTIGADORA_MLB_V14','F6','F5'),('IAINVESTIGADORA_MLB_V14','F7','F6'),
('IAINVESTIGADORA_MLB_V14','F8','F7'),('IAINVESTIGADORA_MLB_V14','F9','F8'),
('IAINVESTIGADORA_MLB_V14','F10','F9'),('IAINVESTIGADORA_MLB_V14','F11','F10'),
('IAINVESTIGADORA_MLB_V14','F12','F11');

-- Extend the shared Drive artifact taxonomy without creating a parallel table.
alter table public.research_drive_artifacts drop constraint if exists research_drive_artifacts_artifact_type_check;
alter table public.research_drive_artifacts add constraint research_drive_artifacts_artifact_type_check
check (artifact_type = any(array['PACKET'::text,'EVIDENCE_SNAPSHOT'::text,'RUN_MANIFEST'::text,'FINAL_REPORT'::text,'IAINV_FINAL_REPORT'::text]));

create or replace function public.iainv_json_has_forbidden_key(j jsonb)
returns boolean language plpgsql immutable set search_path='public','extensions' as $$
declare k text; v jsonb; e jsonb;
begin
  if j is null then return false; end if;
  if jsonb_typeof(j)='object' then
    for k,v in select key,value from jsonb_each(j) loop
      if lower(k)=any(array['pick','stake','odds','ev','edge','bet_recommendation','sports_verdict','probability','authoritative_probability','real_money_authority']) then return true; end if;
      if jsonb_typeof(v) in ('object','array') and public.iainv_json_has_forbidden_key(v) then return true; end if;
    end loop;
  elsif jsonb_typeof(j)='array' then
    for e in select value from jsonb_array_elements(j) loop
      if jsonb_typeof(e) in ('object','array') and public.iainv_json_has_forbidden_key(e) then return true; end if;
    end loop;
  end if;
  return false;
end $$;

create or replace function public.iainv_enforce_run_identity()
returns trigger language plpgsql set search_path='public','extensions' as $$
declare a public.agent_registry%rowtype;
begin
  if new.system_version <> 'IAINVESTIGADORA-MLB-V1.4' then return new; end if;
  select * into a from public.agent_registry where agent_id='@iainvestigadora' and status='ACTIVE';
  if not found then raise exception 'IAINV_AGENT_NOT_ACTIVE' using errcode='23514'; end if;
  if tg_op='INSERT' then
    new.invocation_id:=coalesce(nullif(new.invocation_id,''),'IAINV-INV-'||replace(gen_random_uuid()::text,'-',''));
    new.clean_room_mode:=true; new.historical_reports_as_analysis_input:=false;
    new.status:=coalesce(nullif(new.status,''),'OPEN');
    new.metadata:=coalesce(new.metadata,'{}'::jsonb)||jsonb_build_object('agent_id',a.agent_id,'agent_version',a.agent_version,'protocol_id',a.protocol_id,'kernel_version',a.kernel_version,'mother_document_sha256',a.mother_document_sha256,'target_scope','ONE_EXPLICIT_MLB_GAME_PER_RUN','drive_execution_folder_id',a.drive_execution_folder_id,'handoff_destination','@ianalista');
  else
    if old.invocation_id is not null and new.invocation_id is distinct from old.invocation_id then raise exception 'IAINV_INVOCATION_ID_IMMUTABLE' using errcode='23514'; end if;
    if not new.clean_room_mode then raise exception 'IAINV_CLEAN_ROOM_REQUIRED' using errcode='23514'; end if;
    if new.historical_reports_as_analysis_input then raise exception 'IAINV_PRIOR_REPORT_REASONING_REUSE_FORBIDDEN' using errcode='23514'; end if;
    if coalesce(new.metadata->>'agent_id','')<>'@iainvestigadora' then raise exception 'IAINV_RUN_AGENT_IDENTITY_MISMATCH' using errcode='23514'; end if;
  end if;
  return new;
end $$;

create or replace function public.iainv_enforce_single_target()
returns trigger language plpgsql set search_path='public','extensions' as $$
declare sv text; rd date; existing_game text;
begin
  select system_version,run_date into sv,rd from public.runs where run_id=new.run_id;
  if sv is distinct from 'IAINVESTIGADORA-MLB-V1.4' then return new; end if;
  select game_id into existing_game from public.games where run_id=new.run_id and game_id<>new.game_id limit 1;
  if existing_game is not null then raise exception 'IAINV_SINGLE_TARGET_VIOLATION_EXISTING:%',existing_game using errcode='23514'; end if;
  if nullif(btrim(coalesce(new.game_id,'')),'') is null then raise exception 'IAINV_GAME_ID_REQUIRED' using errcode='23514'; end if;
  if nullif(btrim(coalesce(new.away_team,'')),'') is null or nullif(btrim(coalesce(new.home_team,'')),'') is null then raise exception 'IAINV_TEAMS_REQUIRED' using errcode='23514'; end if;
  if new.scheduled_start is null then raise exception 'IAINV_SCHEDULED_START_REQUIRED' using errcode='23514'; end if;
  if (new.scheduled_start at time zone 'America/Santo_Domingo')::date is distinct from rd then raise exception 'IAINV_TARGET_DATE_MISMATCH' using errcode='23514'; end if;
  new.cutoff_at:=coalesce(new.cutoff_at,new.scheduled_start); new.status:=coalesce(nullif(new.status,''),'PREGAME_TARGET');
  return new;
end $$;

create or replace function public.iainv_enforce_report_document_single()
returns trigger language plpgsql set search_path='public','extensions' as $$
declare r public.runs%rowtype; n integer;
begin
  select * into r from public.runs where run_id=new.run_id;
  if not found or r.system_version<>'IAINVESTIGADORA-MLB-V1.4' then return new; end if;
  select count(*) into n from public.run_report_documents where run_id=new.run_id and report_document_id<>new.report_document_id;
  if n>0 then raise exception 'IAINV_SINGLE_DOSSIER_ONLY' using errcode='23514'; end if;
  if not r.clean_room_mode then raise exception 'IAINV_REPORT_REQUIRES_CLEAN_ROOM_RUN' using errcode='23514'; end if;
  return new;
end $$;

create or replace function public.iainv_enforce_drive_artifact()
returns trigger language plpgsql set search_path='public','extensions' as $$
declare r public.runs%rowtype; st jsonb; expected_drive text; expected_hash text; d public.run_report_documents%rowtype; gcount integer; readback_count integer;
begin
  if new.artifact_type<>'IAINV_FINAL_REPORT' then return new; end if;
  select * into r from public.runs where run_id=new.run_id;
  if not found or r.system_version<>'IAINVESTIGADORA-MLB-V1.4' then raise exception 'IAINV_FINAL_REPORT_WRONG_RUN' using errcode='23514'; end if;
  select count(*) into gcount from public.games where run_id=new.run_id;
  if gcount<>1 then raise exception 'IAINV_FINAL_REPORT_REQUIRES_ONE_TARGET' using errcode='23514'; end if;
  select payload into st from public.protocol_run_state where run_id=new.run_id and protocol_id='IAINVESTIGADORA_MLB_V14' and stage_id='IAINV_FINAL_REPORT_PREPARED' and status='COMPLETE';
  if st is null then raise exception 'IAINV_FINAL_REPORT_PREP_STAGE_REQUIRED' using errcode='23514'; end if;
  expected_drive:=st->>'drive_file_id'; expected_hash:=st->>'report_hash';
  if new.drive_file_id is distinct from expected_drive or new.content_hash is distinct from expected_hash then raise exception 'IAINV_FINAL_REPORT_DRIVE_OR_HASH_MISMATCH' using errcode='23514'; end if;
  select * into d from public.run_report_documents where run_id=new.run_id and drive_file_id=new.drive_file_id;
  if not found then raise exception 'IAINV_RUN_REPORT_DOCUMENT_NOT_REGISTERED' using errcode='23514'; end if;
  if new.game_id is distinct from (select game_id from public.games where run_id=new.run_id limit 1) then raise exception 'IAINV_FINAL_REPORT_GAME_MISMATCH' using errcode='23514'; end if;
  select count(*) into readback_count from public.research_tool_events t where t.run_id=new.run_id and t.game_id=new.game_id and t.kernel_attested=true and t.tool_name in ('Google_Drive.get_document_text','Google_Drive.fetch','Google_Drive.find_document_text_range') and coalesce(t.source_ref,'')=new.drive_file_id and coalesce(t.response_hash,'')=new.content_hash and t.occurred_at<=clock_timestamp();
  if readback_count<1 then raise exception 'IAINV_FINAL_REPORT_REQUIRES_GOOGLE_DRIVE_READBACK_EVENT' using errcode='23514'; end if;
  return new;
end $$;

-- The phase gate combines E1 receipts, target lock, source/evidence temporal integrity,
-- sentinel 1-9 coverage, conditional-phase burden, F10 quarantine and F12 dossier/handoff gates.
create or replace function public.iainv_enforce_phase_semantics()
returns trigger language plpgsql set search_path='public','extensions' as $$
declare
 p constant text:='IAINVESTIGADORA_MLB_V14'; r public.runs%rowtype; g public.games%rowtype;
 receipt jsonb; k text; sc jsonb; eid text; ev public.evidence%rowtype; elem jsonb;
 slots int[]; slot_no int; prior_count integer; bad_unresolved integer;
 report_count integer; art_count integer; report_hash text; art_hash text;
 required_receipt_keys text[]:=array['PHASE_ID','STATUS','START_AS_OF','END_AS_OF','INPUT_OBJECTS','OPERATIONS_PERFORMED','OUTPUT_OBJECTS','SOURCES_OR_EVIDENCE','AUDITOR_RESULT','NEXT_PHASE','UNRESOLVED_GOVERNING_OBJECTS','REOPEN_TRIGGER'];
begin
 if new.protocol_id<>p then return new; end if;
 if public.iainv_json_has_forbidden_key(new.payload) then raise exception 'IAINV_FORBIDDEN_DECISION_FIELD' using errcode='23514'; end if;
 select * into r from public.runs where run_id=new.run_id;
 if not found or r.system_version<>'IAINVESTIGADORA-MLB-V1.4' or coalesce(r.metadata->>'agent_id','')<>'@iainvestigadora' then raise exception 'IAINV_RUN_IDENTITY_INVALID' using errcode='23514'; end if;
 select * into g from public.games where run_id=new.run_id and game_id=new.game_id;
 if not found then raise exception 'IAINV_TARGET_GAME_NOT_REGISTERED' using errcode='23514'; end if;
 if (select count(*) from public.games where run_id=new.run_id)<>1 then raise exception 'IAINV_RUN_MUST_HAVE_EXACTLY_ONE_TARGET' using errcode='23514'; end if;
 if coalesce(new.payload #>> '{target_binding,game_id}','')<>new.game_id then raise exception 'IAINV_TARGET_BINDING_MISMATCH' using errcode='23514'; end if;
 receipt:=new.payload->'phase_execution_receipt';
 if receipt is null or jsonb_typeof(receipt)<>'object' then raise exception 'IAINV_E1_RECEIPT_REQUIRED:%',new.phase_id using errcode='23514'; end if;
 foreach k in array required_receipt_keys loop
   if not(receipt ? k) then raise exception 'IAINV_E1_RECEIPT_FIELD_MISSING:%:%',new.phase_id,k using errcode='23514'; end if;
   if k not in ('UNRESOLVED_GOVERNING_OBJECTS','REOPEN_TRIGGER') and jsonb_typeof(receipt->k)='string' and coalesce(btrim(receipt->>k),'')='' then raise exception 'IAINV_E1_RECEIPT_FIELD_EMPTY:%:%',new.phase_id,k using errcode='23514'; end if;
 end loop;
 if receipt->>'PHASE_ID'<>new.phase_id then raise exception 'IAINV_E1_PHASE_ID_MISMATCH' using errcode='23514'; end if;
 if new.status='COMPLETE' and upper(coalesce(receipt->>'STATUS',''))<>'EXECUTED' then raise exception 'IAINV_E1_STATUS_MUST_BE_EXECUTED' using errcode='23514'; end if;
 if new.status='SKIPPED_NOT_TRIGGERED' and upper(coalesce(receipt->>'STATUS',''))<>'NOT_APPLICABLE' then raise exception 'IAINV_E1_SKIPPED_STATUS_MUST_BE_NOT_APPLICABLE' using errcode='23514'; end if;
 for sc in select value from jsonb_array_elements(coalesce(new.source_calls,'[]'::jsonb)) loop
   eid:=btrim(coalesce(sc->>'evidence_id',''));
   if eid='' or not(eid=any(new.evidence_ids)) then raise exception 'IAINV_SOURCE_CALL_NOT_BOUND_TO_PHASE' using errcode='23514'; end if;
   select * into ev from public.evidence where evidence_id=eid and run_id=new.run_id and game_id=new.game_id;
   if not found then raise exception 'IAINV_EVIDENCE_WRONG_RUN_OR_GAME:%',eid using errcode='23514'; end if;
   if coalesce(ev.data_available_since,ev.data_available_at,ev.retrieved_at)>g.cutoff_at then raise exception 'IAINV_POST_CUTOFF_EVIDENCE_FORBIDDEN:%',eid using errcode='23514'; end if;
   if ev.retrieved_at>new.submitted_at then raise exception 'IAINV_EVIDENCE_FROM_FUTURE:%',eid using errcode='23514'; end if;
 end loop;
 if new.phase_id='F1' then
   if coalesce(new.payload #>> '{game_identity,away_team}','')<>coalesce(g.away_team,'') or coalesce(new.payload #>> '{game_identity,home_team}','')<>coalesce(g.home_team,'') then raise exception 'IAINV_F1_TEAM_IDENTITY_MISMATCH' using errcode='23514'; end if;
   if coalesce(new.payload #>> '{game_identity,scheduled_start}','')='' then raise exception 'IAINV_F1_START_REQUIRED' using errcode='23514'; end if;
 elsif new.phase_id='F5' then
   if jsonb_typeof(new.payload #> '{sentinel_coverage,away}')<>'array' or jsonb_array_length(new.payload #> '{sentinel_coverage,away}')<>9 then raise exception 'IAINV_F5_AWAY_SENTINEL_1_9_REQUIRED' using errcode='23514'; end if;
   slots:='{}'; for elem in select value from jsonb_array_elements(new.payload #> '{sentinel_coverage,away}') loop
     if jsonb_typeof(elem)<>'object' or coalesce(elem->>'slot','')='' or coalesce(elem->>'player_state','')='' then raise exception 'IAINV_F5_AWAY_SENTINEL_SLOT_STRUCTURE_REQUIRED' using errcode='23514'; end if;
     slot_no:=(elem->>'slot')::int; slots:=array_append(slots,slot_no);
   end loop;
   if cardinality(slots)<>9 or not slots @> array[1,2,3,4,5,6,7,8,9] then raise exception 'IAINV_F5_AWAY_SENTINEL_SLOTS_1_9_REQUIRED' using errcode='23514'; end if;
   if jsonb_typeof(new.payload #> '{sentinel_coverage,home}')<>'array' or jsonb_array_length(new.payload #> '{sentinel_coverage,home}')<>9 then raise exception 'IAINV_F5_HOME_SENTINEL_1_9_REQUIRED' using errcode='23514'; end if;
   slots:='{}'; for elem in select value from jsonb_array_elements(new.payload #> '{sentinel_coverage,home}') loop
     if jsonb_typeof(elem)<>'object' or coalesce(elem->>'slot','')='' or coalesce(elem->>'player_state','')='' then raise exception 'IAINV_F5_HOME_SENTINEL_SLOT_STRUCTURE_REQUIRED' using errcode='23514'; end if;
     slot_no:=(elem->>'slot')::int; slots:=array_append(slots,slot_no);
   end loop;
   if cardinality(slots)<>9 or not slots @> array[1,2,3,4,5,6,7,8,9] then raise exception 'IAINV_F5_HOME_SENTINEL_SLOTS_1_9_REQUIRED' using errcode='23514'; end if;
 elsif new.phase_id in ('F6','F8','F11') then
   if new.status='SKIPPED_NOT_TRIGGERED' then
     if lower(coalesce(new.payload #>> '{trigger_material_evaluation,trigger_material}','')) not in ('false','0','no') then raise exception 'IAINV_CONDITIONAL_SKIP_REQUIRES_TRIGGER_FALSE:%',new.phase_id using errcode='23514'; end if;
     if length(btrim(coalesce(new.payload #>> '{trigger_material_evaluation,why_not_applicable}','')))<20 then raise exception 'IAINV_CONDITIONAL_SKIP_REASON_TOO_WEAK:%',new.phase_id using errcode='23514'; end if;
   else
     if lower(coalesce(new.payload #>> '{trigger_material_evaluation,trigger_material}','')) not in ('true','1','yes') then raise exception 'IAINV_CONDITIONAL_EXECUTION_REQUIRES_TRIGGER_TRUE:%',new.phase_id using errcode='23514'; end if;
   end if;
 elsif new.phase_id='F10' then
   if upper(coalesce(new.payload->>'quarantine_state','')) not in ('PASS','INTACT','ACTIVE') then raise exception 'IAINV_F10_QUARANTINE_NOT_INTACT' using errcode='23514'; end if;
 elsif new.phase_id='F12' then
   select count(*) into prior_count from public.protocol_phase_state s where s.run_id=new.run_id and s.game_id=new.game_id and s.protocol_id=p and s.phase_id in ('F1','F2','F3','F4','F5','F6','F7','F8','F9','F10','F11') and s.status in ('COMPLETE','SKIPPED_NOT_TRIGGERED');
   if prior_count<>11 then raise exception 'IAINV_F12_PRIOR_PHASE_LEDGER_INCOMPLETE:%',prior_count using errcode='23514'; end if;
   select count(*) into bad_unresolved from public.protocol_phase_state s where s.run_id=new.run_id and s.game_id=new.game_id and s.protocol_id=p and s.phase_id<>'F12' and jsonb_typeof(s.payload #> '{phase_execution_receipt,UNRESOLVED_GOVERNING_OBJECTS}')='array' and jsonb_array_length(s.payload #> '{phase_execution_receipt,UNRESOLVED_GOVERNING_OBJECTS}')>0;
   if bad_unresolved>0 then raise exception 'IAINV_F12_GOVERNING_OBJECTS_UNRESOLVED:%',bad_unresolved using errcode='23514'; end if;
   if upper(coalesce(new.payload->>'mandatory_phases_not_run',''))<>'NONE' then raise exception 'IAINV_F12_MANDATORY_PHASES_NOT_RUN' using errcode='23514'; end if;
   if lower(coalesce(new.payload->>'core_mission_complete','')) not in ('true','pass','1','yes') then raise exception 'IAINV_F12_CORE_MISSION_NOT_PASS' using errcode='23514'; end if;
   if upper(coalesce(new.payload->>'drive_report_complete',''))<>'PASS' or upper(coalesce(new.payload->>'chat_report_complete',''))<>'PASS' then raise exception 'IAINV_F12_DELIVERY_INCOMPLETE' using errcode='23514'; end if;
   if lower(coalesce(new.payload->>'ready_for_handoff','')) not in ('true','1','yes') then raise exception 'IAINV_F12_NOT_READY_FOR_HANDOFF' using errcode='23514'; end if;
   select count(*),max(content_hash) into report_count,report_hash from public.run_report_documents where run_id=new.run_id and status='FINAL_VERIFIED';
   if report_count<>1 then raise exception 'IAINV_F12_REQUIRES_ONE_FINAL_VERIFIED_DOSSIER:%',report_count using errcode='23514'; end if;
   select count(*),max(content_hash) into art_count,art_hash from public.research_drive_artifacts where run_id=new.run_id and game_id=new.game_id and artifact_type='IAINV_FINAL_REPORT';
   if art_count<>1 or art_hash is distinct from report_hash then raise exception 'IAINV_F12_DRIVE_ARTIFACT_NOT_VERIFIED' using errcode='23514'; end if;
   if not exists(select 1 from public.protocol_run_state rs where rs.run_id=new.run_id and rs.protocol_id=p and rs.stage_id='IAINV_FINAL_REPORT_PREPARED' and rs.status='COMPLETE') then raise exception 'IAINV_F12_FINAL_REPORT_NOT_PREPARED' using errcode='23514'; end if;
 end if;
 return new;
end $$;

create or replace function public.iainv_prepare_final_report(p_run_id text,p_drive_file_id text,p_report_hash text,p_chat_report_complete boolean default true)
returns jsonb language plpgsql security definer set search_path='public','extensions' as $$
declare r public.runs%rowtype; gid text; phase_count integer; doc_count integer; out_payload jsonb;
begin
 select * into r from public.runs where run_id=p_run_id;
 if not found or r.system_version<>'IAINVESTIGADORA-MLB-V1.4' then raise exception 'IAINV_RUN_NOT_FOUND' using errcode='23514'; end if;
 select game_id into gid from public.games where run_id=p_run_id;
 if gid is null or (select count(*) from public.games where run_id=p_run_id)<>1 then raise exception 'IAINV_TARGET_NOT_UNIQUE' using errcode='23514'; end if;
 select count(*) into phase_count from public.protocol_phase_state where run_id=p_run_id and game_id=gid and protocol_id='IAINVESTIGADORA_MLB_V14' and phase_id in ('F1','F2','F3','F4','F5','F6','F7','F8','F9','F10','F11') and status in ('COMPLETE','SKIPPED_NOT_TRIGGERED');
 if phase_count<>11 then raise exception 'IAINV_CANNOT_PREPARE_REPORT_BEFORE_F1_F11:%',phase_count using errcode='23514'; end if;
 select count(*) into doc_count from public.run_report_documents where run_id=p_run_id and drive_file_id=p_drive_file_id;
 if doc_count<>1 then raise exception 'IAINV_REPORT_DOCUMENT_MUST_BE_REGISTERED_ONCE' using errcode='23514'; end if;
 if length(btrim(coalesce(p_report_hash,'')))<32 then raise exception 'IAINV_REPORT_HASH_REQUIRED' using errcode='23514'; end if;
 out_payload:=jsonb_build_object('drive_file_id',p_drive_file_id,'report_hash',p_report_hash,'chat_report_complete',p_chat_report_complete,'prepared_at',clock_timestamp(),'game_id',gid);
 insert into public.protocol_run_state(run_id,protocol_id,stage_id,status,payload,evidence_ids,output_text,submitted_at)
 values(p_run_id,'IAINVESTIGADORA_MLB_V14','IAINV_FINAL_REPORT_PREPARED','COMPLETE',out_payload,'{}','Final dossier prepared for Drive readback.',clock_timestamp())
 on conflict(run_id,protocol_id,stage_id) do update set status='COMPLETE',payload=excluded.payload,output_text=excluded.output_text,submitted_at=excluded.submitted_at;
 return out_payload;
end $$;

create or replace function public.iainv_derive_audit(p_run_id text)
returns jsonb language plpgsql security definer set search_path='public','extensions' as $$
declare gid text; target_count integer; phase_count integer; missing text[]; late_count integer; unresolved_count integer; report_count integer; f12 jsonb; pass boolean; result jsonb;
begin
 if not exists(select 1 from public.runs where run_id=p_run_id and system_version='IAINVESTIGADORA-MLB-V1.4') then raise exception 'IAINV_RUN_NOT_FOUND' using errcode='23514'; end if;
 select count(*),max(game_id) into target_count,gid from public.games where run_id=p_run_id;
 select count(*) into phase_count from public.protocol_phase_state where run_id=p_run_id and game_id=gid and protocol_id='IAINVESTIGADORA_MLB_V14' and phase_id in ('F1','F2','F3','F4','F5','F6','F7','F8','F9','F10','F11','F12') and status in ('COMPLETE','SKIPPED_NOT_TRIGGERED');
 select coalesce(array_agg(x),'{}'::text[]) into missing from unnest(array['F1','F2','F3','F4','F5','F6','F7','F8','F9','F10','F11','F12']) x where not exists(select 1 from public.protocol_phase_state s where s.run_id=p_run_id and s.game_id=gid and s.protocol_id='IAINVESTIGADORA_MLB_V14' and s.phase_id=x and s.status in ('COMPLETE','SKIPPED_NOT_TRIGGERED'));
 select count(*) into late_count from public.evidence e join public.games g on g.run_id=e.run_id and g.game_id=e.game_id where e.run_id=p_run_id and e.game_id=gid and coalesce(e.data_available_since,e.data_available_at,e.retrieved_at)>g.cutoff_at and exists(select 1 from public.protocol_phase_state s where s.run_id=p_run_id and s.game_id=gid and s.protocol_id='IAINVESTIGADORA_MLB_V14' and e.evidence_id=any(s.evidence_ids));
 select count(*) into unresolved_count from public.protocol_phase_state s where s.run_id=p_run_id and s.game_id=gid and s.protocol_id='IAINVESTIGADORA_MLB_V14' and jsonb_typeof(s.payload #> '{phase_execution_receipt,UNRESOLVED_GOVERNING_OBJECTS}')='array' and jsonb_array_length(s.payload #> '{phase_execution_receipt,UNRESOLVED_GOVERNING_OBJECTS}')>0;
 select count(*) into report_count from public.run_report_documents where run_id=p_run_id and status='FINAL_VERIFIED';
 select payload into f12 from public.protocol_phase_state where run_id=p_run_id and game_id=gid and protocol_id='IAINVESTIGADORA_MLB_V14' and phase_id='F12' and status='COMPLETE';
 pass:=target_count=1 and phase_count=12 and cardinality(missing)=0 and late_count=0 and unresolved_count=0 and report_count=1 and f12 is not null and upper(coalesce(f12->>'drive_report_complete',''))='PASS' and upper(coalesce(f12->>'chat_report_complete',''))='PASS' and lower(coalesce(f12->>'core_mission_complete','')) in ('true','pass','1','yes') and lower(coalesce(f12->>'ready_for_handoff','')) in ('true','1','yes');
 result:=jsonb_build_object('pass',pass,'target_count',target_count,'phase_count',phase_count,'mandatory_phases_not_run',missing,'late_governing_evidence_count',late_count,'unresolved_governing_object_count',unresolved_count,'final_verified_dossier_count',report_count,'core_mission_complete',coalesce(f12->>'core_mission_complete','false'),'ready_for_handoff',coalesce(f12->>'ready_for_handoff','false'));
 return result;
end $$;

create or replace function public.iainv_close_run(p_run_id text)
returns jsonb language plpgsql security definer set search_path='public','extensions' as $$
declare a jsonb; gid text; out_payload jsonb;
begin
 a:=public.iainv_derive_audit(p_run_id); select game_id into gid from public.games where run_id=p_run_id;
 if coalesce((a->>'pass')::boolean,false) then
   update public.runs set status='COMPLETE',closed_at=clock_timestamp(),metadata=metadata||jsonb_build_object('core_mission_complete',true,'f12_audit','PASS','handoff_destination','@ianalista') where run_id=p_run_id;
   update public.games set status='RESEARCH_COMPLETE' where run_id=p_run_id and game_id=gid;
   out_payload:=a||jsonb_build_object('handoff_destination','@ianalista','handoff_status','READY');
   insert into public.protocol_run_state(run_id,protocol_id,stage_id,status,payload,evidence_ids,output_text,submitted_at)
   values(p_run_id,'IAINVESTIGADORA_MLB_V14','IAINV_HANDOFF_READY','COMPLETE',out_payload,'{}','FINAL SPORTS STORE ready for @ianalista.',clock_timestamp())
   on conflict(run_id,protocol_id,stage_id) do update set status='COMPLETE',payload=excluded.payload,output_text=excluded.output_text,submitted_at=excluded.submitted_at;
 else
   update public.runs set status='INCOMPLETE_RESEARCH',metadata=metadata||jsonb_build_object('core_mission_complete',false,'f12_audit','FAIL') where run_id=p_run_id;
   out_payload:=a||jsonb_build_object('handoff_status','BLOCKED','reason','INCOMPLETE_RESEARCH — NO HANDOFF');
 end if;
 return out_payload;
end $$;

-- Triggers are protocol-scoped inside their functions; shared agents remain isolated.
drop trigger if exists trg_01_iainv_run_identity on public.runs;
create trigger trg_01_iainv_run_identity before insert or update on public.runs for each row execute function public.iainv_enforce_run_identity();
drop trigger if exists trg_01_iainv_single_target on public.games;
create trigger trg_01_iainv_single_target before insert or update on public.games for each row execute function public.iainv_enforce_single_target();
drop trigger if exists trg_050_iainv_phase_semantics on public.protocol_phase_state;
create trigger trg_050_iainv_phase_semantics before insert or update on public.protocol_phase_state for each row execute function public.iainv_enforce_phase_semantics();
drop trigger if exists trg_01_iainv_single_report_document on public.run_report_documents;
create trigger trg_01_iainv_single_report_document before insert or update on public.run_report_documents for each row execute function public.iainv_enforce_report_document_single();
drop trigger if exists trg_02_iainv_drive_artifact on public.research_drive_artifacts;
create trigger trg_02_iainv_drive_artifact before insert or update on public.research_drive_artifacts for each row execute function public.iainv_enforce_drive_artifact();

-- Production authority: never public/anon/authenticated.
revoke all on function public.iainv_prepare_final_report(text,text,text,boolean) from public,anon,authenticated;
revoke all on function public.iainv_derive_audit(text) from public,anon,authenticated;
revoke all on function public.iainv_close_run(text) from public,anon,authenticated;
grant execute on function public.iainv_prepare_final_report(text,text,text,boolean) to service_role;
grant execute on function public.iainv_derive_audit(text) to service_role;
grant execute on function public.iainv_close_run(text) to service_role;

commit;
