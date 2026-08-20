-- 057 — The sovereign MOTHER document changed when the calibration-separation
-- amendment was inserted directly into the document. Propagate the new complete
-- text-export SHA-256 to live authority surfaces without rewriting historical RUNs.

UPDATE public.agent_registry
SET status='DISABLED',
    mother_document_sha256='391fbdfdf78965f9454307267f7e3d048abc7ccb4329e29870ad58aeabcb55f1',
    metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object(
      'database_migrations_required_through',57,
      'mother_export_sha256','391fbdfdf78965f9454307267f7e3d048abc7ccb4329e29870ad58aeabcb55f1',
      'mother_export_lines',21236,
      'authority_hash_refresh','PENDING_EXTERNAL_READBACK')
WHERE agent_id='@NRFImetrica';

UPDATE public.protocol_authority
SET document_sha256='391fbdfdf78965f9454307267f7e3d048abc7ccb4329e29870ad58aeabcb55f1',
    document_lines=21236,
    latest_sovereign_patch='CALIBRATION_SEPARATION_AMENDMENT — 2026-08-20'
WHERE protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS';

UPDATE public.system_versions
SET contract_doc_id='MOTHER_SHA256:391fbdfdf78965f9454307267f7e3d048abc7ccb4329e29870ad58aeabcb55f1',
    kernel_version='NRFIM-KERNEL-1.5-CALIBRATION-SEPARATION',
    calibration_status='SYSTEM_AUDIT_ONLY_NOT_CERTIFIED'
WHERE system_version='NRFIM MOTHER V3';
