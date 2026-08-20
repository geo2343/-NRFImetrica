-- 058 — Seal the externally verified MOTHER hash refresh and reactivate @NRFImetrica.
-- Historical RUN/evidence hashes remain immutable; only live authority surfaces and
-- hard-coded A0 guards are moved to the new canonical complete-text export hash.

do $$
declare
  r record;
  ddl text;
  old_hash constant text := 'd16896eba602af272117a5c83b56245aa201979d394301781d424e705b3642d3';
  new_hash constant text := '391fbdfdf78965f9454307267f7e3d048abc7ccb4329e29870ad58aeabcb55f1';
begin
  for r in
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and p.prokind='f'
      and pg_get_functiondef(p.oid) like '%'||old_hash||'%'
  loop
    ddl := replace(pg_get_functiondef(r.oid), old_hash, new_hash);
    execute ddl;
  end loop;
end $$;

update public.agent_registry
set status='ACTIVE',
    agent_version='MOTHER-V3-AGENT-1.10',
    kernel_version='NRFIM-KERNEL-1.5-CALIBRATION-SEPARATION',
    mother_document_sha256='391fbdfdf78965f9454307267f7e3d048abc7ccb4329e29870ad58aeabcb55f1',
    metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object(
      'database_migrations_required_through',58,
      'mother_export_sha256','391fbdfdf78965f9454307267f7e3d048abc7ccb4329e29870ad58aeabcb55f1',
      'mother_export_lines',21237,
      'authority_hash_refresh','PASS',
      'mother_hash_external_readback','PASS',
      'calibration_separation_amendment_readback','PASS',
      'refactor_state','ACTIVE_VALIDATED')
where agent_id='@NRFImetrica';

update public.protocol_authority
set document_sha256='391fbdfdf78965f9454307267f7e3d048abc7ccb4329e29870ad58aeabcb55f1',
    document_lines=21237,
    latest_sovereign_patch='CALIBRATION_SEPARATION_AMENDMENT — 2026-08-20',
    precedence_rule='CALIBRATION_SEPARATION_AMENDMENT_OVER_LEGACY_A7_CALIBRATED_P_SEMANTICS'
where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS';

update public.system_versions
set contract_doc_id='MOTHER_SHA256:391fbdfdf78965f9454307267f7e3d048abc7ccb4329e29870ad58aeabcb55f1',
    kernel_version='NRFIM-KERNEL-1.5-CALIBRATION-SEPARATION',
    calibration_status='SYSTEM_AUDIT_ONLY_NOT_CERTIFIED'
where system_version='NRFIM MOTHER V3';
