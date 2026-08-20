-- Supabase migration mirror: @AuditorSistema V1.1 Adapter 05 — @ianalista
-- Applied physically to project yejaollmavoudbxnbpll as 20260820125747.
-- Current Drive V5.2/MDC-R1 values are LOCATORS only. Every audit must resolve
-- the authority that governed the TARGET_RUN at target time.

insert into public.system_audit_registry(
  system_id,display_name,adapter_version,target_project_id,target_namespace,
  authority,drive_root_id,notion_page_id,active
)
values(
  '@ianalista','IA ANALISTA MLB / @ianalista','ADAPTER-1.0',null,null,
  jsonb_build_object(
    'authority_resolution','RESOLVE_TARGET_TIME_CANONICAL_AUTHORITY',
    'current_drive_version_locator','V5.2',
    'sovereign_patch_locator','MDC-R1-2026-08-19',
    'market_locator','MLB_FULL_GAME_UNDER_PREGAME',
    'phase_map',jsonb_build_array('A1','A2','A3','A4','A5','A6','A7','A8_CONDITIONAL'),
    'constitution_document_id','1vWW42-MlFqUCDTV4UKwBfi7v2eO_zTomO3M3641w3Ec',
    'panel_document_id','1Pvc_oEKalglMjNx6JHmIRkeGi6a4DTMAfbkmIiV-EN0',
    'hard_gates_document_id','1Jk-q51sh2aehZRyOtfvbDCDfEtN8AWNj99BrA_lYfQA',
    'authority_folder_id','1H_4rAuZxA9lfUFStWXwrI5HwEgqPrSRb',
    'phases_folder_id','1nnARlNoZTb1Mco-L_r7I80n50E2vAFQP',
    'note','Adapter metadata locates current sources only; resolve TARGET_TIME authority.'
  ),
  '10XgQfFmTzfoAK4aRo14RDJafTPAFJ1Q4',null,true
)
on conflict(system_id) do update set
  display_name=excluded.display_name,
  adapter_version=excluded.adapter_version,
  target_project_id=excluded.target_project_id,
  target_namespace=excluded.target_namespace,
  authority=excluded.authority,
  drive_root_id=excluded.drive_root_id,
  active=true,
  updated_at=now();

insert into public.system_audit_adapter_checks(
  system_id,check_id,layer_id,title,rule_text,default_severity,required,target_objects
) values
('@ianalista','IA-P0-EXACT-INPUT','P0','Exact analyst target/input','Prove the exact @ianalista RUN, GAME_ID and user-supplied investigadora dossier/game reference. A directly supplied dossier may not be silently replaced.','CRITICAL',true,'["Drive target report","GAME_ID","RUN_ID","user request"]'::jsonb),
('@ianalista','SYS-P0-TARGET-IDENTITY','P0','Exact target identity','Before P1, prove that the audited system/RUN/game-or-slate/report is exactly the object requested by the user.','CRITICAL',true,'["system_audit_runs","target physical run/report"]'::jsonb),
('@ianalista','SYS-P1-TARGET-TIME-AUTHORITY','P1','Target-time authority resolution','Resolve and freeze the authority that actually governed the target RUN at its time; adapter metadata is a locator, not permanent authority.','CRITICAL',true,'["authority_snapshot","Drive authority","Notion/GitHub/DB if present"]'::jsonb),
('@ianalista','IA-P2-RUN-CONTINUITY','P2','Single-run continuity and dossier identity','Resume the same GAME_ID/RUN/dossier when authority requires continuity; never silently duplicate or substitute it.','MAJOR',true,'["RUN_ID","GAME_ID","active dossier","Drive folders"]'::jsonb),
('@ianalista','IA-P3-PREGAME-INTEGRITY','P3','Pregame identity and temporal integrity','A1 must verify game/object identity, date, teams, GAME_ID and SNAPSHOT_AS_OF; true hard invalidation is limited to unidentifiable target or Pregame-invalid temporal contamination.','CRITICAL',true,'["A1","GAME_ID","SNAPSHOT_AS_OF","input dossier"]'::jsonb),
('@ianalista','IA-P4-MISSING-DATA-CONTINUITY','P4','Missing-data continuity MDC-R1','Missing baseball data alone cannot create BLOCKED, RETURN_TO_INVESTIGADORA, NO_PLAY, WATCHLIST or A7_NO_SEAL. Material gaps require targeted recovery, then visible conditioned uncertainty if still unavailable.','CRITICAL',true,'["targeted recovery evidence","conditioned data gaps","A1-A7 states"]'::jsonb),
('@ianalista','IA-P4-NO-FULL-REINVESTIGATION','P4','Selective recovery not duplicate investigation','Recover the exact missing material object when needed; do not default to repeating investigadora F1-F12.','MAJOR',true,'["tool/evidence trace","recovery scope","input dossier"]'::jsonb),
('@ianalista','IA-P5-A1-A7-SEQUENCE','P5','A1-A7 autonomous phase execution','Execute governing A1-A7 outputs/dependencies; A8 is conditional and cannot be made mandatory without contract input.','CRITICAL',true,'["A1","A2","A3","A4","A5","A6","A7","A8"]'::jsonb),
('@ianalista','IA-P5-CAUSAL-ARCHITECTURE','P5','Causal Full Game architecture','Connect starters, offenses, transition, reachable bullpen, environment and threshold causally rather than by metric voting or correlated-signal counting.','CRITICAL',true,'["A2","A3","A4","A5","analysis report"]'::jsonb),
('@ianalista','IA-P6-GATES-G1-G7','P6','Hard gates G1-G7 obeyed','Evaluate G1-G7 according to target-time authority. A later gate cannot silently rescue an earlier material failure; missing external data alone cannot become terminal sports rejection.','CRITICAL',true,'["G1","G2","G3","G4","G5","G6","G7"]'::jsonb),
('@ianalista','IA-P6-CHALLENGER','P6','Symmetric internal Challenger','A6 must execute the compact symmetric internal Challenger, expose strongest rival/breakpoints and resolve governing challenges without impersonating IA INDEPENDIENTE.','CRITICAL',true,'["A6","challenger artifacts","breakpoint resolution"]'::jsonb),
('@ianalista','IA-P7-STATE-SEPARATION','P7','Sports/process/data-gap state separation','Keep external data unavailability, analyst nonexecution, sports judgment and contractual state distinct.','CRITICAL',true,'["analysis states","data gaps","sports verdict","contract state"]'::jsonb),
('@ianalista','IA-P7-NOPLAY-BURDEN','P7','No Play must be demonstrated','No Play/WATCHLIST requires causal rigor comparable to a positive sports thesis and cannot be an easy consequence of uncertainty or missing statistics.','CRITICAL',true,'["A6","A7","rival thesis","breakpoints"]'::jsonb),
('@ianalista','IA-P8-DRIVE-DOSSIER-DELIVERY','P8','Unique Drive dossier and direct-link delivery','Preserve the required human-readable dossier/report, correct Drive structure and direct Google Doc link at closure.','MAJOR',true,'["Drive final report","run folder","chat delivery"]'::jsonb),
('@ianalista','IA-P9-CROSS-AUTHORITY-CONSISTENCY','P9','Cross-layer authority consistency','Reconcile available physical layers. Absence of a dedicated DB/Kernel layer may not be fabricated as present.','MAJOR',true,'["Drive","Supabase if present","GitHub if present","Notion if present"]'::jsonb),
('@ianalista','SYS-P10-FORENSIC-REPLAY','P10','Read-only forensic replay when needed','If needed, reconstruct expected process using only target-time authority/data and never write to target.','MAJOR',true,'["system_audit_forensic_replays"]'::jsonb),
('@ianalista','IA-P10-ADVERSARIAL-FALSE-COMPLETION','P10','Attack false completion','Attempt to disprove ANALYST_CORE_MISSION_COMPLETE/A7 by seeking unresolved governing work, orphan material objects, hidden uncertainty, unresolved Challenger breakpoints or false data-gap terminalization.','CRITICAL',true,'["A6","A7","gates","final report"]'::jsonb),
('@ianalista','IA-P11-ANALYST-CORE-CLOSE','P11','Analyst core close and conditional contract','A7 seals only with ANALYST_CORE_MISSION_COMPLETE=PASS. Properly modeled external gaps may remain. No contract closes A8 as CONTRACT_NOT_PROVIDED/NOT_APPLICABLE without degrading A7.','CRITICAL',true,'["A7","ANALYST_CORE_MISSION_COMPLETE","A8","CONTRACT_INPUT"]'::jsonb),
('@ianalista','SYS-P11-TRACE-COMPLETE','P11','Total execution trace','Reconstruct request→authority→run→inputs→evidence→phases→gates→states→closure→delivery and separate root from downstream failures.','CRITICAL',true,'["system_audit_execution_trace"]'::jsonb),
('@ianalista','SYS-P12-FORENSIC-CHAT-REPORT','P12','Detailed forensic chat report','Produce the full human-readable forensic report required by V1.1.','CRITICAL',true,'["system_audit_chat_reports"]'::jsonb),
('@ianalista','SYS-P12-COMPLIANCE-ONLY-CORRECTIONS','P12','Compliance-only corrections','Every correction must restore an explicit target-authority requirement; the auditor must not redesign the target.','MAJOR',true,'["system_audit_findings","system_audit_chat_reports"]'::jsonb)
on conflict(system_id,check_id) do update set
  layer_id=excluded.layer_id,
  title=excluded.title,
  rule_text=excluded.rule_text,
  default_severity=excluded.default_severity,
  required=excluded.required,
  target_objects=excluded.target_objects;

update public.system_auditor_authority
set migrations_required_through=54,
    metadata=jsonb_set(
      jsonb_set(
        jsonb_set(
          jsonb_set(coalesce(metadata,'{}'::jsonb),'{menu}',
            '{"1":"@NRFiPrensa","2":"@NRFImetrica","3":"@DepuracionMLB","4":"@investigacionNRFI","5":"@ianalista"}'::jsonb,true),
          '{target_menu}',
            '{"1":"@NRFiPrensa","2":"@NRFImetrica","3":"@DepuracionMLB","4":"@investigacionNRFI","5":"@ianalista"}'::jsonb,true),
        '{ianalista_adapter}','"ADAPTER-1.0"'::jsonb,true),
      '{database_migrations_required_through}','54'::jsonb,true),
    updated_at=now()
where protocol_id='SYSTEM_AUDITOR_V1_1';
