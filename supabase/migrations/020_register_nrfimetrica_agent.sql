create table if not exists public.agent_registry (
  agent_id text primary key,
  agent_version text not null,
  status text not null check (status in ('ACTIVE','DISABLED')),
  protocol_id text not null,
  system_version text not null,
  kernel_version text not null,
  mother_document_sha256 text not null,
  manifest_path text not null,
  activation_aliases text[] not null default '{}',
  manual_phase_authorization_required boolean not null default false,
  auto_advance boolean not null default true,
  drive_root_folder_id text not null,
  drive_execution_folder_id text not null,
  drive_authority_folder_id text not null,
  real_money_authority boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.agent_registry enable row level security;

insert into public.agent_registry(
  agent_id,agent_version,status,protocol_id,system_version,kernel_version,mother_document_sha256,
  manifest_path,activation_aliases,manual_phase_authorization_required,auto_advance,
  drive_root_folder_id,drive_execution_folder_id,drive_authority_folder_id,real_money_authority,metadata,updated_at
) values (
  '@NRFImetrica','MOTHER-V3-AGENT-1.0','ACTIVE','NRFIMETRICA_MOTHER_V3_AUTONOMOUS','NRFIM MOTHER V3',
  'NRFIM-KERNEL-0.5-MOTHER-ENFORCED','d16896eba602af272117a5c83b56245aa201979d394301781d424e705b3642d3',
  'agents/nrfimetrica_mother_v3_agent.json',array['@NRFImetrica','ejecuta @NRFImetrica','ejecutar NRFImetrica','corre NRFImetrica'],
  false,true,'1hkgDlFtP7XtOOEHtYrcz4Q2uc887-JVe','1IvwfaUWrXD540acN0-twJIgBPTcbzRSA',
  '1pnj7XTgDnAnT0vDDP6AI1k3MyyxHdb9t',false,
  jsonb_build_object(
    'mother_document_id','1U7UM5fkBAPt3FjZ7X7tKtxvudFyFpvM9FOs6A1C1ITw',
    'agent_mandate_document_id','1pChqvOgMvobJnIaTPCX2Nkg5VeBBXWaoATzj28lMYq4',
    'panel_document_id','1AKagj51B7VO5HTjsfVSZ43BHiNwA5jlVCPYfuIvFFm4',
    'execution_index_document_id','1skNUCUKEDUnUjc6Q9FYVXw3Shg6KUnJzmLeytb6Yk3Y',
    'behavior_when_component_missing','DO_NOT_SIMULATE; TERMINAL_RESOLUTION; CONTINUE_SLATE'
  ),now()
)
on conflict(agent_id) do update set
  agent_version=excluded.agent_version,
  status=excluded.status,
  protocol_id=excluded.protocol_id,
  system_version=excluded.system_version,
  kernel_version=excluded.kernel_version,
  mother_document_sha256=excluded.mother_document_sha256,
  manifest_path=excluded.manifest_path,
  activation_aliases=excluded.activation_aliases,
  manual_phase_authorization_required=excluded.manual_phase_authorization_required,
  auto_advance=excluded.auto_advance,
  drive_root_folder_id=excluded.drive_root_folder_id,
  drive_execution_folder_id=excluded.drive_execution_folder_id,
  drive_authority_folder_id=excluded.drive_authority_folder_id,
  real_money_authority=excluded.real_money_authority,
  metadata=excluded.metadata,
  updated_at=now();

create or replace function public.enforce_nrfimetrica_agent_identity()
returns trigger language plpgsql as $$
declare
  a public.agent_registry%rowtype;
  supplied text;
begin
  if new.system_version <> 'NRFIM MOTHER V3' then return new; end if;
  select * into a from public.agent_registry where agent_id='@NRFImetrica' and status='ACTIVE';
  if not found then
    raise exception 'NRFIMETRICA_AGENT_NOT_ACTIVE' using errcode='23514';
  end if;
  supplied:=coalesce(new.metadata->>'agent_id','');
  if supplied<>'' and supplied<>a.agent_id then
    raise exception 'MOTHER_V3_RUN_WRONG_AGENT:%',supplied using errcode='23514';
  end if;
  new.metadata:=coalesce(new.metadata,'{}'::jsonb) || jsonb_build_object(
    'agent_id',a.agent_id,
    'agent_version',a.agent_version,
    'protocol_id',a.protocol_id,
    'kernel_version',a.kernel_version,
    'mother_document_sha256',a.mother_document_sha256,
    'manual_phase_authorization_required',a.manual_phase_authorization_required,
    'auto_advance',a.auto_advance,
    'drive_execution_folder_id',a.drive_execution_folder_id
  );
  return new;
end $$;

drop trigger if exists trg_nrfimetrica_agent_identity on public.runs;
create trigger trg_nrfimetrica_agent_identity
before insert or update of system_version,metadata on public.runs
for each row execute function public.enforce_nrfimetrica_agent_identity();
