-- @investigacionNRFI — RLS + function permission hardening

alter table public.investigacion_nrfi_volumes enable row level security;
alter table public.investigacion_nrfi_runs enable row level security;
alter table public.investigacion_nrfi_games enable row level security;
alter table public.investigacion_nrfi_tool_events enable row level security;
alter table public.investigacion_nrfi_source_families enable row level security;
alter table public.investigacion_nrfi_evidence enable row level security;
alter table public.investigacion_nrfi_phase_state enable row level security;
alter table public.investigacion_nrfi_trace enable row level security;
alter table public.investigacion_nrfi_drive_appends enable row level security;
alter table public.investigacion_nrfi_audits enable row level security;

revoke all on table public.investigacion_nrfi_volumes from anon, authenticated;
revoke all on table public.investigacion_nrfi_runs from anon, authenticated;
revoke all on table public.investigacion_nrfi_games from anon, authenticated;
revoke all on table public.investigacion_nrfi_tool_events from anon, authenticated;
revoke all on table public.investigacion_nrfi_source_families from anon, authenticated;
revoke all on table public.investigacion_nrfi_evidence from anon, authenticated;
revoke all on table public.investigacion_nrfi_phase_state from anon, authenticated;
revoke all on table public.investigacion_nrfi_trace from anon, authenticated;
revoke all on table public.investigacion_nrfi_drive_appends from anon, authenticated;
revoke all on table public.investigacion_nrfi_audits from anon, authenticated;

revoke all on function public.investigacion_nrfi_adversarial_selftest() from public, anon, authenticated;
revoke all on function public.investigacion_nrfi_authorize_rollover(text) from public, anon, authenticated;
revoke all on function public.investigacion_nrfi_close_daily_run(text) from public, anon, authenticated;
revoke all on function public.investigacion_nrfi_derive_audit(text) from public, anon, authenticated;
revoke all on function public.investigacion_nrfi_sync_run_accounting(text) from public, anon, authenticated;

grant execute on function public.investigacion_nrfi_authorize_rollover(text) to service_role;
grant execute on function public.investigacion_nrfi_close_daily_run(text) to service_role;
grant execute on function public.investigacion_nrfi_derive_audit(text) to service_role;
grant execute on function public.investigacion_nrfi_sync_run_accounting(text) to service_role;

alter function public.investigacion_nrfi_capacity_state(integer) set search_path = public, extensions;
alter function public.investigacion_nrfi_guard_volume_creation() set search_path = public, extensions;
alter function public.investigacion_nrfi_guard_evidence_temporality() set search_path = public, extensions;
alter function public.investigacion_nrfi_guard_run_volume() set search_path = public, extensions;
alter function public.investigacion_nrfi_payload_has_forbidden_keys(jsonb) set search_path = public, extensions;
alter function public.investigacion_nrfi_guard_phase_state() set search_path = public, extensions;
alter function public.investigacion_nrfi_trace_hash_guard() set search_path = public, extensions;
alter function public.investigacion_nrfi_guard_drive_append() set search_path = public, extensions;
alter function public.investigacion_nrfi_game_accounting_trigger() set search_path = public, extensions;
alter function public.investigacion_nrfi_sync_run_accounting(text) set search_path = public, extensions;
alter function public.investigacion_nrfi_derive_audit(text) set search_path = public, extensions;
alter function public.investigacion_nrfi_close_daily_run(text) set search_path = public, extensions;
alter function public.investigacion_nrfi_authorize_rollover(text) set search_path = public, extensions;
alter function public.investigacion_nrfi_adversarial_selftest() set search_path = public, extensions;
