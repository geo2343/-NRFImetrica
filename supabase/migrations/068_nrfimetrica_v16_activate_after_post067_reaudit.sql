-- @NRFImetrica Agent 1.11 / Kernel 1.6
-- Activation is allowed only after the post-067 terminal re-audit passes exactly 12/12.
-- Scope: @NRFImetrica only. Does not modify @NRFIprensa or Notion.

do $$
declare total_n integer; pass_n integer; r public.agent_registry%rowtype;
begin
  select count(*),count(*) filter(where passed) into total_n,pass_n
  from public.nrfimetrica_kernel_tests where test_suite='V16_POST_067_AUDIT';
  if total_n<>12 or pass_n<>12 then
    raise exception 'NRFIM_V16_POST_067_AUDIT_NOT_12_OF_12:%/%',pass_n,total_n using errcode='23514';
  end if;

  select * into r from public.agent_registry where agent_id='@NRFImetrica';
  if not found or r.status<>'DISABLED' then raise exception 'NRFIM_V16_ACTIVATION_REQUIRES_DISABLED_PRESTATE' using errcode='23514'; end if;
  if r.agent_version<>'MOTHER-V3-AGENT-1.11' or r.kernel_version<>'NRFIM-KERNEL-1.6-PREANALYSIS-COGNITIVE-GUARD' then raise exception 'NRFIM_V16_ACTIVATION_IDENTITY_MISMATCH' using errcode='23514'; end if;
  if r.mother_document_sha256<>'44edaa44707293115f8d129b8903c1d8f7dfa5f6bd79674de29cee01091228d8' then raise exception 'NRFIM_V16_ACTIVATION_MOTHER_HASH_MISMATCH' using errcode='23514'; end if;
  if r.metadata->>'database_migrations_required_through'<>'67' or r.metadata->>'github_migrations_through'<>'67' then raise exception 'NRFIM_V16_ACTIVATION_PRESTATE_MIGRATION_MISMATCH' using errcode='23514'; end if;
  if not exists(select 1 from public.protocol_authority where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and active and document_sha256=r.mother_document_sha256) then raise exception 'NRFIM_V16_ACTIVATION_PROTOCOL_AUTHORITY_MISMATCH' using errcode='23514'; end if;

  update public.agent_registry
  set status='ACTIVE',
      metadata=(coalesce(metadata,'{}'::jsonb)-'database_migrations_required_through'-'github_migrations_through'-'github_parity_state'-'terminal_validation_state'-'refactor_state')
        || jsonb_build_object(
          'database_migrations_required_through',68,
          'github_migrations_through',68,
          'github_parity_state','MIGRATION_068_APPLIED',
          'terminal_validation_state','PASS_12_OF_12_POST_067',
          'refactor_state','ACTIVE_VALIDATED_V16_POST_067',
          'real_money_authority',false,
          'calibrate_system_not_game',true,
          'game_probability_source','A5_GAME_CAUSAL_ONLY',
          'conservative_probability_source','GAME_SPECIFIC_STRESS_TEST_ONLY',
          'press_intake_role','INFORMATION_FOR_ANALYSIS_ONLY',
          'press_sports_authority','NONE',
          'press_probability_authority','NONE',
          'press_ranking_authority','NONE',
          'press_market_authority','NONE',
          'press_conclusion_authority','NONE',
          'notion_role','CONSULTATION_ONLY_NO_WRITE_AUTHORITY',
          'nrfiprensa_write_scope','NONE',
          'receiver_side_only',true,
          'migration_sequence_duplicate_062','RESOLVED',
          'post_067_audit_total',12,
          'post_067_audit_passed',12
        ),
      updated_at=now()
  where agent_id='@NRFImetrica';
end $$;