do $$
declare audit_total integer; audit_pass integer;
begin
  select count(*),count(*) filter(where passed) into audit_total,audit_pass
  from public.nrfimetrica_kernel_tests
  where test_suite='V16_TERMINAL_AUDIT';

  if audit_total<>10 or audit_pass<>10 then
    raise exception 'NRFIM_V16_TERMINAL_AUDIT_NOT_10_OF_10:%/%',audit_pass,audit_total using errcode='23514';
  end if;

  if not exists(
    select 1 from public.agent_registry
    where agent_id='@NRFImetrica'
      and status='DISABLED'
      and agent_version='MOTHER-V3-AGENT-1.11'
      and kernel_version='NRFIM-KERNEL-1.6-PREANALYSIS-COGNITIVE-GUARD'
      and mother_document_sha256='44edaa44707293115f8d129b8903c1d8f7dfa5f6bd79674de29cee01091228d8'
  ) then
    raise exception 'NRFIM_V16_PREACTIVATION_IDENTITY_MISMATCH' using errcode='23514';
  end if;

  if not exists(
    select 1 from public.protocol_authority
    where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS'
      and active
      and document_sha256='44edaa44707293115f8d129b8903c1d8f7dfa5f6bd79674de29cee01091228d8'
  ) then
    raise exception 'NRFIM_V16_PROTOCOL_AUTHORITY_MISMATCH' using errcode='23514';
  end if;
end $$;

update public.agent_registry
set status='ACTIVE',
    metadata=(coalesce(metadata,'{}'::jsonb)
      - 'refactor_state' - 'terminal_validation_state' - 'github_parity_state'
      - 'database_migrations_required_through' - 'github_migrations_through')
      || jsonb_build_object(
        'refactor_state','ACTIVE_VALIDATED_V16',
        'terminal_validation_state','PASS_10_OF_10',
        'github_parity_state','MIGRATION_066_APPLIED',
        'database_migrations_required_through',66,
        'github_migrations_through',66,
        'activated_at',now()::text,
        'real_money_authority',false,
        'calibrate_system_not_game',true,
        'game_probability_source','A5_GAME_CAUSAL_ONLY',
        'conservative_probability_source','GAME_SPECIFIC_STRESS_TEST_ONLY',
        'press_intake_role','OPTIONAL_INFORMATION_ONLY',
        'press_sports_authority','NONE',
        'press_probability_authority','NONE',
        'press_ranking_authority','NONE',
        'press_market_authority','NONE',
        'press_conclusion_authority','NONE',
        'notion_role','CONSULTATION_ONLY_NO_WRITE_AUTHORITY',
        'nrfiprensa_write_scope','NONE',
        'receiver_side_only',true
      ),
    updated_at=now()
where agent_id='@NRFImetrica';