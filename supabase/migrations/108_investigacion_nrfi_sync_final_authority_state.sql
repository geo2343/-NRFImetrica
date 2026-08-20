-- @investigacionNRFI — synchronize canonical registry with final connected/security state

update public.agent_registry
set metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
  'active_volume_id', 'INVESTIGACIONNRFI-VOL-01',
  'active_volume_doc_id', '12PSuZwQKxb4oFiEqaH4fB8twnS74KhiPDUHMGpso6Us',
  'mother_document_id', '1Hqj6s11F2dEf_UUeto38rP90f5Q5eemnBi0B0PWnQuY',
  'single_living_report', true,
  'new_volume_requires_user_authorization', true,
  'real_money_authority', false,
  'connected_kernel', true,
  'game_ledger_enforcement', true,
  'e1_phase_enforcement', true,
  'temporal_custody', true,
  'drive_readback_gate', true,
  'database_security_hardened', true,
  'supabase_access_mode', 'SERVICE_ROLE_ONLY',
  'adversarial_selftest', 'PASS',
  'command_registry_sync', 'PASS',
  'vercel_deployment_verified', false,
  'vercel_block_reason', 'BUILD_RATE_LIMIT / NO_PROJECT_VISIBLE',
  'real_daily_run_validation', 'PENDING_USER_DATE'
),
updated_at = now()
where agent_id = '@investigacionNRFI';

update public.protocol_authority
set latest_sovereign_patch = 'CONNECTED-KERNEL-SECURITY-HARDENING-2'
where protocol_id = 'INVESTIGACION_NRFI_HISTORICAL_V1';
