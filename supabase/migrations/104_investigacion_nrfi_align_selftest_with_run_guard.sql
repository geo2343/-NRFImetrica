create or replace function public.investigacion_nrfi_adversarial_selftest()
returns jsonb
language plpgsql security definer set search_path=public,extensions as $$
declare
  results jsonb := '{}'::jsonb;
  test_run text := 'TEST-INVNRFI-SELFTEST';
  orig1 text := 'TEST-INVNRFI-ORIG-1';
  orig2 text := 'TEST-INVNRFI-ORIG-2';
  audit_row public.investigacion_nrfi_audits%rowtype;
  close_row public.investigacion_nrfi_runs%rowtype;
  h1 text;
  h2prev text;
  receipt_f1 jsonb;
  receipt_f2 jsonb;
begin
  delete from public.investigacion_nrfi_runs where daily_run_id in (test_run,orig1,orig2);
  delete from public.investigacion_nrfi_source_families where source_family_id='TEST-FAMILY';

  insert into public.investigacion_nrfi_runs(daily_run_id,run_date,run_type,volume_id,expected_finalized_count)
  values(test_run,'1901-01-02','ORIGINAL','INVESTIGACIONNRFI-VOL-01',1);

  receipt_f1 := jsonb_build_object(
    'PHASE_ID','F1_FORENSIC_CAPTURE','START_AS_OF',now()::text,'END_AS_OF',now()::text,
    'INPUT_OBJECTS',jsonb_build_array('x'),'OPERATIONS_PERFORMED',jsonb_build_array('x'),
    'OUTPUT_OBJECTS',jsonb_build_array('x'),'SOURCES_OR_EVIDENCE',jsonb_build_array('x'),
    'AUDITOR_RESULT','PASS','NEXT_PHASE','F2_DEEP_RECONSTRUCTION');
  receipt_f2 := jsonb_build_object(
    'PHASE_ID','F2_DEEP_RECONSTRUCTION','START_AS_OF',now()::text,'END_AS_OF',now()::text,
    'INPUT_OBJECTS',jsonb_build_array('x'),'OPERATIONS_PERFORMED',jsonb_build_array('x'),
    'OUTPUT_OBJECTS',jsonb_build_array('x'),'SOURCES_OR_EVIDENCE',jsonb_build_array('x'),
    'AUDITOR_RESULT','PASS','NEXT_PHASE','F3_FEATURE_FACTORY');

  begin
    insert into public.investigacion_nrfi_phase_state(daily_run_id,phase_id,status,started_at,payload,receipt)
    values(test_run,'F2_DEEP_RECONSTRUCTION','COMPLETE',now(),
      jsonb_build_object('reconstruction',jsonb_build_object('processed_game_count',1,'first_inning_integrity','PASS','exact_event_sequence_preserved',true)),receipt_f2);
    results := results || jsonb_build_object('INV_R01_PHASE_ORDER','FAIL_NOT_BLOCKED');
  exception when others then
    results := results || jsonb_build_object('INV_R01_PHASE_ORDER',case when sqlerrm like '%PREREQUISITES_INCOMPLETE%' then 'PASS_BLOCKED:PREREQUISITES_INCOMPLETE' else 'FAIL_WRONG_BLOCK:'||sqlerrm end);
  end;

  begin
    insert into public.investigacion_nrfi_phase_state(daily_run_id,phase_id,status,started_at,receipt)
    values(test_run,'F1_FORENSIC_CAPTURE','COMPLETE',now(),'{}'::jsonb);
    results := results || jsonb_build_object('INV_R02_E1_RECEIPT','FAIL_NOT_BLOCKED');
  exception when others then results := results || jsonb_build_object('INV_R02_E1_RECEIPT','PASS_BLOCKED:'||sqlerrm); end;

  begin
    insert into public.investigacion_nrfi_phase_state(daily_run_id,phase_id,status,started_at,payload,receipt)
    values(test_run,'F1_FORENSIC_CAPTURE','COMPLETE',now(),
      jsonb_build_object('universe',jsonb_build_object('expected_finalized_game_count',1,'accounted_game_count',1),'identity_integrity','PASS','temporal_lane_integrity','PASS','pick','NRFI'),receipt_f1);
    results := results || jsonb_build_object('INV_R12_FORBIDDEN_MARKET_KEY','FAIL_NOT_BLOCKED');
  exception when others then results := results || jsonb_build_object('INV_R12_FORBIDDEN_MARKET_KEY','PASS_BLOCKED:'||sqlerrm); end;

  insert into public.investigacion_nrfi_tool_events(event_id,daily_run_id,tool_name,source_ref) values('TEST-TOOL',test_run,'test.tool','test.source');
  insert into public.investigacion_nrfi_source_families(source_family_id,canonical_origin,family_hash) values('TEST-FAMILY','test-origin',encode(extensions.digest('test-origin','sha256'),'hex'));
  begin
    insert into public.investigacion_nrfi_evidence(evidence_id,daily_run_id,tool_event_id,source_family_id,temporal_lane,epistemic_lane,retrieved_at,available_at,first_pitch_at,payload_hash,snapshot_hash)
    values('TEST-EVID-LATE',test_run,'TEST-TOOL','TEST-FAMILY','PREGAME_EVIDENCE','OBSERVED','1901-01-03 10:00+00','1901-01-03 10:00+00','1901-01-03 09:00+00','x','y');
    results := results || jsonb_build_object('INV_R03_TEMPORAL','FAIL_NOT_BLOCKED');
  exception when others then results := results || jsonb_build_object('INV_R03_TEMPORAL','PASS_BLOCKED:'||sqlerrm); end;

  begin
    insert into public.investigacion_nrfi_drive_appends(daily_run_id,volume_id,drive_document_id,block_marker,verified)
    values(test_run,'INVESTIGACIONNRFI-VOL-01','12PSuZwQKxb4oFiEqaH4fB8twnS74KhiPDUHMGpso6Us','TEST-MARKER',true);
    results := results || jsonb_build_object('INV_R07_DRIVE_PROOF','FAIL_NOT_BLOCKED');
  exception when others then results := results || jsonb_build_object('INV_R07_DRIVE_PROOF','PASS_BLOCKED:'||sqlerrm); end;

  audit_row := public.investigacion_nrfi_derive_audit(test_run);
  if audit_row.audit_status='FAIL' and cardinality(audit_row.mandatory_phases_not_run)=5 and audit_row.drive_append_pass=false then results := results || jsonb_build_object('INV_R05_EMPTY_CLOSE_AUDIT','PASS_FAIL_DERIVED'); else results := results || jsonb_build_object('INV_R05_EMPTY_CLOSE_AUDIT','FAIL_BAD_AUDIT'); end if;
  close_row := public.investigacion_nrfi_close_daily_run(test_run);
  if close_row.status='INCOMPLETE_REPAIR_REQUIRED' and close_row.core_mission_complete=false then results := results || jsonb_build_object('INV_R06_CLOSE_WITHOUT_PROOF','PASS_INCOMPLETE'); else results := results || jsonb_build_object('INV_R06_CLOSE_WITHOUT_PROOF','FAIL_CLOSED'); end if;

  insert into public.investigacion_nrfi_runs(daily_run_id,run_date,run_type,volume_id) values(orig1,'1901-01-01','ORIGINAL','INVESTIGACIONNRFI-VOL-01');
  begin
    insert into public.investigacion_nrfi_runs(daily_run_id,run_date,run_type,volume_id) values(orig2,'1901-01-01','ORIGINAL','INVESTIGACIONNRFI-VOL-01');
    results := results || jsonb_build_object('INV_R09_DUPLICATE_DATE','FAIL_NOT_BLOCKED');
  exception when unique_violation then results := results || jsonb_build_object('INV_R09_DUPLICATE_DATE','PASS_BLOCKED'); end;

  begin
    insert into public.investigacion_nrfi_volumes(volume_id,sequence_no,status,drive_document_id,drive_document_url,previous_volume_id)
    values('TEST-VOL-02',2,'OPEN','test','https://example.invalid','INVESTIGACIONNRFI-VOL-01');
    results := results || jsonb_build_object('INV_R10_ROLLOVER_AUTH','FAIL_NOT_BLOCKED');
  exception when others then results := results || jsonb_build_object('INV_R10_ROLLOVER_AUTH','PASS_BLOCKED:'||sqlerrm); end;

  insert into public.investigacion_nrfi_trace(event_id,daily_run_id,event_type,details) values('TEST-TRACE-1',test_run,'SELFTEST_ONE','{}');
  select event_hash into h1 from public.investigacion_nrfi_trace where event_id='TEST-TRACE-1';
  insert into public.investigacion_nrfi_trace(event_id,daily_run_id,event_type,details) values('TEST-TRACE-2',test_run,'SELFTEST_TWO','{}');
  select prev_event_hash into h2prev from public.investigacion_nrfi_trace where event_id='TEST-TRACE-2';
  if h1 is not null and h2prev=h1 then results := results || jsonb_build_object('INV_TRACE_CHAIN','PASS_CHAINED'); else results := results || jsonb_build_object('INV_TRACE_CHAIN','FAIL_CHAIN'); end if;

  delete from public.investigacion_nrfi_runs where daily_run_id in (test_run,orig1,orig2);
  delete from public.investigacion_nrfi_source_families where source_family_id='TEST-FAMILY';
  return results;
end;
$$;