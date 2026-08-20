-- RUNTIME-INDEPENDENCE-1.0
-- Vercel remains an optional HTTP adapter and may not block core agent execution.

create table if not exists public.agent_runtime_policy (
  agent_id text primary key,
  policy_version text not null default 'RUNTIME-INDEPENDENCE-1.0',
  canonical_execution_route text not null,
  canonical_state_backend text not null,
  http_runtime_required boolean not null default false,
  preferred_http_runtime text,
  edge_function_slug text,
  vercel_role text not null default 'OPTIONAL_HTTP_ADAPTER_NON_BLOCKING',
  vercel_required boolean not null default false,
  vercel_failure_blocks_execution boolean not null default false,
  provider_failure_scope text not null default 'OPTIONAL_ADAPTER_ONLY',
  execution_status_source text not null default 'AGENT_AUTHORITY_AND_DOMAIN_GATES',
  notes jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default clock_timestamp(),
  constraint agent_runtime_policy_version_chk check (policy_version='RUNTIME-INDEPENDENCE-1.0'),
  constraint agent_runtime_vercel_role_chk check (vercel_role='OPTIONAL_HTTP_ADAPTER_NON_BLOCKING'),
  constraint agent_runtime_vercel_not_required_chk check (vercel_required=false),
  constraint agent_runtime_vercel_nonblocking_chk check (vercel_failure_blocks_execution=false)
);

insert into public.agent_runtime_policy(agent_id,canonical_execution_route,canonical_state_backend,http_runtime_required,preferred_http_runtime,edge_function_slug,notes) values
('@NRFImetrica','SUPABASE_EDGE_FUNCTIONS_PLUS_CONNECTED_KERNEL','SUPABASE',false,'SUPABASE_EDGE_FUNCTIONS','nrfimetrica-research',jsonb_build_object('edge_function_verified',true,'edge_function_version',1,'vercel_config_may_remain_for_compatibility',true)),
('@NRFiPrensa','CONNECTED_AGENT_KERNEL_PLUS_SUPABASE_PERSISTENCE','SUPABASE',false,null,null,jsonb_build_object('system_state','RESEARCH_ONLY_TRADING_HALT')),
('@DepuracionMLB','CONNECTED_AGENT_KERNEL_PLUS_SUPABASE_PERSISTENCE','SUPABASE',false,null,null,jsonb_build_object('preserve_agent_status','DISABLED','disable_reason_is_not_runtime_provider',true)),
('@investigacionNRFI','CONNECTED_AGENT_KERNEL_PLUS_SUPABASE_PERSISTENCE','SUPABASE',false,null,null,jsonb_build_object('legacy_api_paths_are_optional_http_compatibility_routes',true)),
('@ianalista','DRIVE_AUTHORITY_PLUS_CONNECTED_AGENT_EXECUTION','DRIVE_AND_CONNECTED_LAYERS',false,null,null,jsonb_build_object('do_not_fabricate_dedicated_runtime',true)),
('@iainvestigadora','CONNECTED_AGENT_KERNEL_PLUS_SHARED_SUPABASE_PERSISTENCE','SUPABASE',false,null,null,jsonb_build_object('legacy_api_route_optional',true)),
('@iaindependiente','CONNECTED_AGENT_KERNEL_PLUS_SHARED_SUPABASE_PERSISTENCE','SUPABASE',false,null,null,jsonb_build_object('clean_room_contract_unchanged',true)),
('@AuditorSistema','CONNECTED_AUDITOR_PLUS_SUPABASE_AUDIT_NAMESPACE','SUPABASE',false,null,null,jsonb_build_object('target_read_only_unchanged',true))
on conflict (agent_id) do update set
  policy_version=excluded.policy_version,
  canonical_execution_route=excluded.canonical_execution_route,
  canonical_state_backend=excluded.canonical_state_backend,
  http_runtime_required=excluded.http_runtime_required,
  preferred_http_runtime=excluded.preferred_http_runtime,
  edge_function_slug=excluded.edge_function_slug,
  vercel_role=excluded.vercel_role,
  vercel_required=excluded.vercel_required,
  vercel_failure_blocks_execution=excluded.vercel_failure_blocks_execution,
  provider_failure_scope=excluded.provider_failure_scope,
  execution_status_source=excluded.execution_status_source,
  notes=excluded.notes,
  updated_at=clock_timestamp();

update public.agent_registry
set metadata=(coalesce(metadata,'{}'::jsonb)
  - 'vercel_state' - 'vercel_deployment_verified' - 'vercel_block_reason'
  - 'runtime_deployment_block_reason' - 'runtime_deployment_block_source' - 'runtime_deployment_block_contexts')
  || jsonb_build_object(
    'runtime_policy_version','RUNTIME-INDEPENDENCE-1.0',
    'vercel_role','OPTIONAL_HTTP_ADAPTER_NON_BLOCKING',
    'vercel_required',false,
    'vercel_failure_blocks_execution',false,
    'vercel_unavailability_effect','NON_BLOCKING',
    'http_runtime_required',false,
    'execution_governed_by_agent_status_and_domain_gates',true
  ),
  updated_at=clock_timestamp()
where agent_id in ('@NRFImetrica','@investigacionNRFI','@iainvestigadora','@iaindependiente','@DepuracionMLB');

update public.agent_registry
set metadata=(metadata - 'runtime_deployment_status' - 'operational_retest_status')
  || jsonb_build_object(
    'runtime_deployment_status','ACTIVE_ON_SUPABASE_EDGE_FUNCTIONS',
    'operational_retest_status','STRUCTURAL_PASS_SUPABASE_EDGE_RUNTIME_VERIFIED',
    'optional_provider_observations',jsonb_build_object('vercel',jsonb_build_object('role','OPTIONAL_HTTP_ADAPTER','effect','NON_BLOCKING','historical_issue','BUILD_RATE_LIMIT_OR_PROJECT_VISIBILITY'))
  ),
  updated_at=clock_timestamp()
where agent_id='@NRFImetrica';

update public.agent_registry
set metadata=metadata || jsonb_build_object(
  'optional_provider_observations',jsonb_build_object('vercel',jsonb_build_object('role','OPTIONAL_HTTP_ADAPTER','effect','NON_BLOCKING','last_known_state','BUILD_RATE_LIMIT_OR_NO_PROJECT_VISIBLE'))
), updated_at=clock_timestamp()
where agent_id in ('@investigacionNRFI','@iainvestigadora');

update public.nrfiprensa_authority
set metadata=coalesce(metadata,'{}'::jsonb) || jsonb_build_object(
  'runtime_policy_version','RUNTIME-INDEPENDENCE-1.0',
  'vercel_role','OPTIONAL_HTTP_ADAPTER_NON_BLOCKING',
  'vercel_required',false,
  'vercel_failure_blocks_execution',false,
  'http_runtime_required',false
)
where agent_id='@NRFiPrensa';

update public.system_auditor_authority
set metadata=coalesce(metadata,'{}'::jsonb) || jsonb_build_object(
  'runtime_policy_version','RUNTIME-INDEPENDENCE-1.0',
  'vercel_role','OPTIONAL_HTTP_ADAPTER_NON_BLOCKING',
  'vercel_required',false,
  'vercel_failure_blocks_execution',false,
  'runtime_provider_coupling_is_auditable_failure',true
)
where agent_id='@AuditorSistema';

update public.system_audit_registry
set authority=coalesce(authority,'{}'::jsonb) || jsonb_build_object(
  'runtime_policy_version','RUNTIME-INDEPENDENCE-1.0',
  'vercel_role','OPTIONAL_HTTP_ADAPTER_NON_BLOCKING',
  'vercel_required',false,
  'vercel_failure_blocks_execution',false
), updated_at=clock_timestamp();

insert into public.system_audit_adapter_checks(system_id,check_id,layer_id,title,rule_text,default_severity,required,target_objects)
select r.system_id,'P1-RUNTIME-INDEPENDENCE','P1','Runtime provider independence',
'Vercel is an optional HTTP adapter, not a prerequisite for core execution. Vercel unavailability, project invisibility, deployment failure, or build rate limits may block only an explicitly Vercel-specific deployment operation; they must not by themselves block the target agent run when its canonical execution route remains available.',
'MAJOR',true,jsonb_build_array('agent_runtime_policy','target_authority_snapshot','target_run_state','provider_status_metadata')
from public.system_audit_registry r
on conflict (system_id,check_id) do update set
  layer_id=excluded.layer_id,
  title=excluded.title,
  rule_text=excluded.rule_text,
  default_severity=excluded.default_severity,
  required=excluded.required,
  target_objects=excluded.target_objects;

create or replace view public.agent_runtime_effective_policy as
select agent_id,policy_version,canonical_execution_route,canonical_state_backend,http_runtime_required,preferred_http_runtime,edge_function_slug,vercel_role,vercel_required,vercel_failure_blocks_execution,provider_failure_scope,execution_status_source,notes,updated_at
from public.agent_runtime_policy;
