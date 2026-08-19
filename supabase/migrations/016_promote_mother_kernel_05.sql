update public.system_versions
set kernel_version='NRFIM-KERNEL-0.5-MOTHER-ENFORCED',
    model_version='NO_ACTIVE_TRUSTED_NUMERIC_MODEL',
    calibration_status='NOT_CERTIFIED'
where system_version='NRFIM MOTHER V3';
