-- GLOBAL_AGENT_INVENTORY V0.1
-- Authority: physical identity inventory above KENDEL membership.
-- GLOBAL_EXISTENCE != KENDEL_MEMBERSHIP.

create table if not exists public.global_agent_inventory (
  inventory_id text primary key,
  observed_name text not null,
  canonical_name text,
  entity_kind text not null default 'AGENT_CANDIDATE'
    check (entity_kind in ('AGENT','AGENT_CANDIDATE','AUDITOR','SYSTEM','MODULE','RUN_ARTIFACT')),
  domain text,
  kendel_membership text not null default 'UNCLASSIFIED'
    check (kendel_membership in ('KENDEL_CANONICAL','KENDEL_AUXILIARY','KENDEL_LEGACY','NON_KENDEL','UNCLASSIFIED')),
  lifecycle_state text not null default 'DISCOVERED'
    check (lifecycle_state in ('DISCOVERED','DOCUMENT_ONLY','STRUCTURED','RUNTIME_PRESENT','CERTIFIED','SUPERSEDED','ARCHIVED','EMPTY_PLACEHOLDER','UNKNOWN')),
  drive_ids text[] not null default '{}'::text[],
  source_evidence jsonb not null default '[]'::jsonb,
  aliases text[] not null default '{}'::text[],
  first_observed_at timestamptz,
  last_observed_at timestamptz not null default now(),
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.global_agent_inventory enable row level security;
revoke all on table public.global_agent_inventory from anon, authenticated;
grant select,insert,update,delete on table public.global_agent_inventory to service_role;

create or replace view public.global_agent_inventory_kendel as
select *
from public.global_agent_inventory
where kendel_membership in ('KENDEL_CANONICAL','KENDEL_AUXILIARY','KENDEL_LEGACY');

create or replace view public.global_agent_inventory_non_kendel as
select *
from public.global_agent_inventory
where kendel_membership='NON_KENDEL';

comment on table public.global_agent_inventory is
'Global inventory of physically observed AI agents/systems/auditors/candidates. This table does not confer KENDEL membership or operational certification.';
