create table if not exists public.mlb_v2_security_incidents (
  incident_id uuid primary key default gen_random_uuid(),
  detected_at timestamptz not null default clock_timestamp(),
  agent_id text,
  run_id text,
  action text not null,
  error_code text,
  error_message text not null,
  payload_fingerprint text,
  severity text not null default 'HIGH' check (severity = any (array['INFO'::text,'LOW'::text,'MEDIUM'::text,'HIGH'::text,'CRITICAL'::text])),
  source_layer text not null default 'EDGE_KERNEL',
  metadata jsonb not null default '{}'::jsonb
);

create index if not exists idx_mlb_v2_security_incidents_agent on public.mlb_v2_security_incidents(agent_id,detected_at desc);
create index if not exists idx_mlb_v2_security_incidents_run on public.mlb_v2_security_incidents(run_id,detected_at desc);

alter table public.mlb_v2_security_incidents enable row level security;
revoke all on table public.mlb_v2_security_incidents from anon, authenticated;
grant all on table public.mlb_v2_security_incidents to service_role;
