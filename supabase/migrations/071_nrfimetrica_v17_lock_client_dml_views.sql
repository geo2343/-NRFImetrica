-- @NRFImetrica v1.7 terminal-audit hardening. Keep agent DISABLED.
revoke insert, update, delete, truncate on public.nrfimetrica_game_dual_status from anon, authenticated;
revoke insert, update, delete, truncate on public.nrfimetrica_user_action from anon, authenticated;

grant select on public.nrfimetrica_game_dual_status to anon, authenticated, service_role;
grant select on public.nrfimetrica_user_action to anon, authenticated, service_role;

update public.agent_registry
set status='DISABLED',
    metadata=(coalesce(metadata,'{}'::jsonb)
      - 'database_migrations_required_through'
      - 'github_migrations_through'
      - 'terminal_validation_state'
      - 'github_parity_state')
      || jsonb_build_object(
        'database_migrations_required_through',71,
        'github_migrations_through',71,
        'terminal_validation_state','V17_POST_071_TERMINAL_AUDIT_PENDING',
        'github_parity_state','MIGRATION_071_VERSIONED',
        'client_dml_view_surface','LOCKED_READ_ONLY'
      ),
    updated_at=clock_timestamp()
where agent_id='@NRFImetrica';
