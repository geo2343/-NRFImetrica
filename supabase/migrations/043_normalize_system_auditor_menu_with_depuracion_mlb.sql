update public.system_auditor_authority
set migrations_required_through=43,
    metadata=(coalesce(metadata,'{}'::jsonb)-'menu') || jsonb_build_object(
      'menu',jsonb_build_object('1','@NRFiPrensa','2','@NRFImetrica','3','@DepuracionMLB'),
      'target_menu',jsonb_build_object('1','@NRFiPrensa','2','@NRFImetrica','3','@DepuracionMLB')
    ),
    updated_at=now()
where protocol_id='SYSTEM_AUDITOR_V1';
