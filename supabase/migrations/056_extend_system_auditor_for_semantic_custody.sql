insert into public.system_audit_adapter_checks(system_id,check_id,layer_id,title,rule_text,default_severity,required,target_objects) values
('@NRFImetrica','NM-P4-KERNEL-ATTESTATION','P4','Kernel-attested extraction','Every factual sports evidence object must descend from a KERNEL_RESEARCH_QUERY and a tool event whose kernel_attested=true under authenticated runtime context; discovery-only events and direct-SQL forged retrievals are not evidence.','CRITICAL',true,jsonb_build_array('research_kernel_queries','research_tool_events','evidence','trace_events')),
('@NRFImetrica','NM-P4-SOURCE-FAMILY-DERIVED','P4','Kernel-derived source independence','SOURCE_FAMILY_ID must be derived by the Kernel. Same origin, exact content, and >=0.80 extracted-text similarity must not inflate independent-family counts.','CRITICAL',true,jsonb_build_array('research_source_families','evidence')),
('@NRFImetrica','NM-P5-ADAPTIVE-CONTRADICTION','P5','Adaptive depth by contradiction','New SEMANTIC-CUSTODY packets require saturation; material contradictions raise the independent-family floor and an OPEN GOVERNING contradiction forbids ANALYSIS_COMPLETE. Family counts are process controls, never sports votes.','CRITICAL',true,jsonb_build_array('sports_reasoning_packets','evidence','research_source_families')),
('@NRFImetrica','NM-P5-YRFI-MATERIALIZATION','P5','Adversarial YRFI materialization','BEST_YRFI_RIVAL must contain a specific materialization path tied to a half, vulnerability activator, evidence IDs and concrete PA-event steps; one-swing paths also require batter profile and pitch/zone vulnerability.','CRITICAL',true,jsonb_build_array('sports_reasoning_packets','sports_reasoning_claims','evidence')),
('@NRFImetrica','NM-P5-FIRST-INNING-MATERIALITY','P5','First-inning materiality without single-metric gate','Both TOP_1ST and BOTTOM_1ST require evidence-backed first-inning factors. Full-game data may only act as an explicit first-inning modifier and cannot be the sole dominant basis.','CRITICAL',true,jsonb_build_array('sports_reasoning_packets','evidence')),
('@NRFImetrica','NM-P5-REFUTABILITY','P5','Observable refutability','WHAT_WOULD_CHANGE must be observable and time-bounded; metric thresholds must identify metric, operator and threshold. Vague more-information conditions fail.','MAJOR',true,jsonb_build_array('sports_reasoning_packets')),
('@NRFImetrica','NM-P10-DIRECT-SQL-SPOOF','P10','Direct SQL attestation spoof','Attempt to forge KERNEL_SERVER_FETCH through direct SQL must produce kernel_attested=false and must be unable to create sports evidence.','CRITICAL',true,jsonb_build_array('research_tool_events','evidence','nrfim_request_role'))
on conflict(system_id,check_id) do update set layer_id=excluded.layer_id,title=excluded.title,rule_text=excluded.rule_text,default_severity=excluded.default_severity,required=excluded.required,target_objects=excluded.target_objects;

update public.system_auditor_authority
set agent_version='AUDITOR-SYSTEM-1.1',kernel_version='SYSTEM-AUDITOR-KERNEL-1.1-SEMANTIC-CUSTODY',migrations_required_through=56,
metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object(
  'nrfimetrica_semantic_custody_adapter',true,
  'nrfimetrica_process_auditor','KERNEL_PROCESS_AUDITOR_0.3',
  'kernel_attested_evidence_check_required',true,
  'adaptive_contradiction_check_required',true,
  'yrfi_materialization_check_required',true,
  'first_inning_materiality_check_required',true,
  'direct_sql_spoof_test_required',true,
  'database_migrations_required_through',56),updated_at=clock_timestamp()
where agent_id='@AuditorSistema';

update public.system_audit_registry
set adapter_version='ADAPTER-1.1-SEMANTIC-CUSTODY',
authority=coalesce(authority,'{}'::jsonb)||jsonb_build_object(
  'semantic_custody_version','SEMANTIC-CUSTODY-1.0',
  'process_auditor','KERNEL_PROCESS_AUDITOR_0.3',
  'kernel_version','NRFIM-KERNEL-1.4-DETERMINISTIC-SEMANTIC-CUSTODY',
  'agent_version','MOTHER-V3-AGENT-1.9',
  'database_migrations_required_through',56),updated_at=clock_timestamp()
where system_id='@NRFImetrica';
