-- Defense-in-depth for NRFImetrica V2.1 decisions.
-- These constraints make core doctrine enforceable even if a caller bypasses the HTTP validator.

alter table public.decisions
  add constraint decisions_allowed_v21
  check (decision in (
    'NRFI_CANDIDATE',
    'NRFI_REJECTED',
    'RESEARCH_ONLY_DATA',
    'RESEARCH_ONLY_MODEL',
    'LOCAL_DATA_BLOCK',
    'AUDIT_ONLY'
  ));

alter table public.decisions
  add constraint decisions_competitive_burden_v21
  check (
    decision not in ('NRFI_CANDIDATE','NRFI_REJECTED')
    or (
      central_nrfi_case is not null
      and central_nrfi_case <> '{}'::jsonb
      and best_yrfi_rival is not null
      and best_yrfi_rival <> '{}'::jsonb
      and length(btrim(decisive_factor)) > 0
      and length(btrim(materiality)) > 0
      and length(btrim(what_would_change)) > 0
    )
  );

alter table public.decisions
  add constraint decisions_no_uncertified_numeric_v21
  check (
    numeric_status = 'NOT_EXECUTED'
    and raw_p_nrfi is null
    and coalesce(model_version, 'NOT_INTEGRATED') = 'NOT_INTEGRATED'
    and coalesce(calibration_status, 'NOT_CERTIFIED') = 'NOT_CERTIFIED'
  );
