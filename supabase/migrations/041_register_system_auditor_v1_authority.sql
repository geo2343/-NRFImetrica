-- @AuditorSistema V1.0 — canonical authority registry
create table if not exists public.system_auditor_authority (
  protocol_id text primary key,
  agent_id text not null,
  agent_version text not null,
  kernel_version text not null,
  status text not null,
  read_only_target boolean not null,
  migrations_required_through integer not null,
  drive_root_id text not null,
  authority_folder_id text not null,
  audits_folder_id text not null,
  constitution_document_id text not null,
  mode_agent_document_id text not null,
  notion_page_id text not null,
  github_repository text not null,
  metadata jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

insert into public.system_auditor_authority(
  protocol_id,agent_id,agent_version,kernel_version,status,read_only_target,
  migrations_required_through,drive_root_id,authority_folder_id,audits_folder_id,
  constitution_document_id,mode_agent_document_id,notion_page_id,github_repository,metadata
) values (
  'SYSTEM_AUDITOR_V1','@AuditorSistema','AUDITOR-SYSTEM-1.0','SYSTEM-AUDITOR-KERNEL-1.0',
  'ACTIVE_PROCESS_AUDITOR',true,41,
  '1h7JtnEKxWx0aLOpeGJ5wSBEQgpT4VtoV','10nvObjcQ-Kipwif9iF8LuJJy34ds26QP','1v3lOUkPdtiX1PVQ9q3v9SqBSSwIuT0T6',
  '14aQX2Q8Dvf8ocYS8k55cjEaId1xUMthFnRsNP7w0prU','1BH0Ie5Y3Fdlchf3Muy-BF2ZhCgaXq2QGArsysN4FAb4',
  '3c1d50b4-5372-81dc-bfdf-f714cdb6f38a','geo2343/-NRFImetrica',
  jsonb_build_object('menu',jsonb_build_object('1','@NRFiPrensa','2','@NRFImetrica'),'audit_layers','P0-P12','initial_adversarial_tests','PASS_5_OF_5','may_repair_target_during_audit',false)
)
on conflict(protocol_id) do update set
  agent_id=excluded.agent_id,agent_version=excluded.agent_version,kernel_version=excluded.kernel_version,
  status=excluded.status,read_only_target=excluded.read_only_target,migrations_required_through=excluded.migrations_required_through,
  drive_root_id=excluded.drive_root_id,authority_folder_id=excluded.authority_folder_id,audits_folder_id=excluded.audits_folder_id,
  constitution_document_id=excluded.constitution_document_id,mode_agent_document_id=excluded.mode_agent_document_id,
  notion_page_id=excluded.notion_page_id,github_repository=excluded.github_repository,metadata=excluded.metadata,updated_at=now();
