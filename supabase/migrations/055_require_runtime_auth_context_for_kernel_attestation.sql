create or replace function public.nrfim_request_role()
returns text language plpgsql stable as $$
declare r text; claims text;
begin
  r:=nullif(current_setting('request.jwt.claim.role',true),'');
  if r is not null then return r; end if;
  claims:=nullif(current_setting('request.jwt.claims',true),'');
  if claims is not null then
    begin return coalesce((claims::jsonb)->>'role',''); exception when others then return ''; end;
  end if;
  return '';
end $$;

create or replace function public.enforce_research_tool_event()
returns trigger language plpgsql as $$
declare prevh text; traceh text; q public.research_kernel_queries%rowtype; request_role text;
begin
  if tg_op<>'INSERT' then return new; end if;
  new.event_id:='RTE-'||replace(gen_random_uuid()::text,'-','');
  new.occurred_at:=clock_timestamp(); new.created_at:=new.occurred_at;
  new.custody_version:='SEMANTIC-CUSTODY-1.0';
  if coalesce(new.kernel_query_id,'')='' then raise exception 'RESEARCH_TOOL_EVENT_REQUIRES_KERNEL_QUERY' using errcode='23514'; end if;
  select * into q from public.research_kernel_queries where query_id=new.kernel_query_id;
  if not found or q.run_id<>new.run_id or q.game_id<>new.game_id or q.status<>'REQUESTED' then raise exception 'RESEARCH_TOOL_EVENT_KERNEL_QUERY_MISMATCH_OR_ALREADY_USED' using errcode='23514'; end if;
  if new.source_published_at is not null and new.source_published_at>new.occurred_at then raise exception 'SOURCE_PUBLISHED_TIMESTAMP_IN_FUTURE' using errcode='23514'; end if;
  if new.data_available_since_kernel is not null and new.data_available_since_kernel>new.occurred_at then raise exception 'DATA_AVAILABLE_TIMESTAMP_IN_FUTURE' using errcode='23514'; end if;
  request_role:=public.nrfim_request_role();
  new.kernel_attested := (
    new.retrieval_mode in ('KERNEL_SERVER_FETCH','KERNEL_PROVIDER_FETCH')
    and coalesce(new.response_hash,'')<>''
    and request_role='service_role'
  );
  new.event_hash:=public.nrfim_sha256_text(concat_ws('|',new.event_id,new.run_id,coalesce(new.game_id,''),new.kernel_query_id,new.tool_name,new.operation,new.retrieval_mode,coalesce(new.request_hash,''),coalesce(new.response_hash,''),new.kernel_attested::text,request_role,new.occurred_at::text));
  update public.runs set tool_call_count=coalesce(tool_call_count,0)+1 where run_id=new.run_id;
  select event_hash into prevh from public.trace_events where run_id=new.run_id order by occurred_at desc limit 1;
  traceh:=public.nrfim_sha256_text(concat_ws('|',new.event_id,new.run_id,coalesce(new.game_id,''),'RESEARCH_TOOL_CALL',new.event_hash,coalesce(prevh,''),new.occurred_at::text));
  insert into public.trace_events(event_id,run_id,game_id,task_id,event_type,status,occurred_at,input_hash,output_hash,tool_name,evidence_ids,prev_event_hash,event_hash,details)
  values('TRACE-'||new.event_id,new.run_id,new.game_id,'SPORTS_RESEARCH','RESEARCH_TOOL_CALL','COMPLETE',new.occurred_at,new.request_hash,new.response_hash,new.tool_name,'{}',prevh,traceh,jsonb_build_object('research_event_id',new.event_id,'kernel_query_id',new.kernel_query_id,'operation',new.operation,'retrieval_mode',new.retrieval_mode,'kernel_attested',new.kernel_attested,'request_role',request_role,'source_ref',new.source_ref,'source_url',new.source_url));
  return new;
end $$;

update public.agent_registry
set metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object(
  'kernel_attestation_requires_runtime_auth_context',true,
  'kernel_attestation_required_request_role','service_role',
  'direct_sql_cannot_self_attest_kernel_fetch',true,
  'database_migrations_required_through',55)
where agent_id='@NRFImetrica';
