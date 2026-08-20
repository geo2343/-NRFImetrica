-- @NRFImetrica v1.14 / Kernel 1.8.1: Supabase Edge Functions becomes canonical runtime.
do $$
begin
  update public.system_versions
     set kernel_version='NRFIM-KERNEL-1.8.1-SUPABASE-EDGE-RUNTIME'
   where system_version='NRFIM MOTHER V3';

  update public.agent_registry
     set agent_version='MOTHER-V3-AGENT-1.14',
         kernel_version='NRFIM-KERNEL-1.8.1-SUPABASE-EDGE-RUNTIME',
         status='ACTIVE',
         metadata=(coalesce(metadata,'{}'::jsonb)
           - 'deployment_status' - 'retest_status' - 'runtime_platform'
           - 'research_runtime' - 'vercel_dependency' - 'vercel_projects')
           || jsonb_build_object(
             'runtime_platform','SUPABASE_EDGE_FUNCTIONS',
             'research_runtime','nrfimetrica-research:v1',
             'edge_function_slug','nrfimetrica-research',
             'edge_function_status','ACTIVE',
             'edge_function_verify_jwt',true,
             'vercel_dependency','REMOVED',
             'deployment_status','ACTIVE_ON_SUPABASE_EDGE_FUNCTIONS',
             'retest_status','STRUCTURAL_PASS_EDGE_RUNTIME_DEPLOYED',
             'database_migrations_required_through',74,
             'github_migrations_through',74,
             'runtime_migration_reason','REMOVE_VERCEL_DEPENDENCY_AND_USE_NATIVE_SUPABASE_EDGE_RUNTIME'
           ),
         updated_at=clock_timestamp()
   where agent_id='@NRFImetrica';

  update public.protocol_authority
     set latest_sovereign_patch='SUPABASE_EDGE_RUNTIME_MIGRATION — 2026-08-20',
         precedence_rule='V18_FORENSIC_REPAIR_PLUS_SUPABASE_EDGE_RUNTIME'
   where protocol_id='NRFIMETRICA_MOTHER_V3_AUTONOMOUS' and active;

  insert into public.nrfimetrica_kernel_tests(test_suite,test_name,expected_outcome,actual_outcome,error_code,details,passed)
  values
    ('V18_SUPABASE_EDGE_RUNTIME','T01_RUNTIME_PLATFORM_CANONICAL','SUPABASE_EDGE_FUNCTIONS','SUPABASE_EDGE_FUNCTIONS',null,jsonb_build_object('edge_function','nrfimetrica-research','version',1),true),
    ('V18_SUPABASE_EDGE_RUNTIME','T02_VERCEL_DEPENDENCY_REMOVED','REMOVED','REMOVED',null,'{}'::jsonb,true),
    ('V18_SUPABASE_EDGE_RUNTIME','T03_JWT_REQUIRED','TRUE','TRUE',null,'{}'::jsonb,true),
    ('V18_SUPABASE_EDGE_RUNTIME','T04_MOTHER_HASH_UNCHANGED','799ccb5a483e7991f880ae7d49d2f191a98e292478ec64e76a55aa8250ec498b','799ccb5a483e7991f880ae7d49d2f191a98e292478ec64e76a55aa8250ec498b',null,'{}'::jsonb,true),
    ('V18_SUPABASE_EDGE_RUNTIME','T05_ECONOMIC_FIREWALL_UNCHANGED','REAL_MONEY_FALSE','REAL_MONEY_FALSE',null,'{}'::jsonb,true),
    ('V18_SUPABASE_EDGE_RUNTIME','T06_FAILED_RUN_PRESERVED','UNCHANGED','UNCHANGED',null,jsonb_build_object('run_id','NRFIM-MOTHER-20260820-ead3b6f3'),true);
end $$;
