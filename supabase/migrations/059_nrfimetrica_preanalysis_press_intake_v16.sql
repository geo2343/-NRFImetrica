-- @NRFImetrica Agent 1.11 / Kernel 1.6
-- PRE-ANALYSIS PRESS INTAKE
-- This migration modifies only @NRFImetrica. It does not modify @NRFIprensa.

create or replace function public.nrfim_json_has_key_recursive(obj jsonb, forbidden_keys text[])
returns boolean
language plpgsql
immutable
set search_path = public, pg_temp
as $$
declare
  k text;
  v jsonb;
begin
  if obj is null then return false; end if;
  if jsonb_typeof(obj)='object' then
    for k,v in select key,value from jsonb_each(obj) loop
      if lower(k)=any(forbidden_keys) then return true; end if;
      if public.nrfim_json_has_key_recursive(v,forbidden_keys) then return true; end if;
    end loop;
  elsif jsonb_typeof(obj)='array' then
    for v in select value from jsonb_array_elements(obj) loop
      if public.nrfim_json_has_key_recursive(v,forbidden_keys) then return true; end if;
    end loop;
  end if;
  return false;
end;
$$;

create table if not exists public.nrfimetrica_press_intakes (
  intake_id text primary key,
  run_id text not null references public.runs(run_id) on delete cascade,
  game_id text not null,
  source_agent text not null default '@NRFIprensa',
  source_run_id text,
  source_packet_id text not null,
  source_packet_hash text not null,
  packet_type text not null default 'PACK_P_CLEAN',
  received_at timestamptz not null default now(),
  source_as_of timestamptz,
  provenance_status text not null default 'PRODUCER_ADAPTER_PENDING',
  status text not null default 'RECEIVED_PENDING_VALIDATION',
  information_role text not null default 'INFORMATION_FOR_ANALYSIS',
  sports_authority text not null default 'NONE',
  probability_authority text not null default 'NONE',
  ranking_authority text not null default 'NONE',
  market_authority text not null default 'NONE',
  conclusion_authority text not null default 'NONE',
  contamination_status text not null default 'PENDING',
  no_material_delta boolean not null default false,
  payload jsonb not null default '{}'::jsonb,
  content_hash text not null default '',
  source_receipt jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (source_agent='@NRFIprensa'),
  check (source_packet_hash ~ '^[0-9a-f]{64}$'),
  check (content_hash='' or content_hash ~ '^[0-9a-f]{64}$'),
  check (packet_type in ('PACK_P_CLEAN','PRESS_DELTA_PACKET','NRFI_PRESS_METRICA_MATERIAL_DELTA_PACKET')),
  check (provenance_status in ('PRODUCER_ADAPTER_PENDING','DECLARED_SOURCE_PACKET','VERIFIED_SOURCE_PACKET')),
  check (status in ('RECEIVED_PENDING_VALIDATION','RECEIVED_VALIDATED','REJECTED_CONTAMINATION','STALE','SUPERSEDED')),
  check (information_role='INFORMATION_FOR_ANALYSIS'),
  check (sports_authority='NONE' and probability_authority='NONE' and ranking_authority='NONE' and market_authority='NONE' and conclusion_authority='NONE'),
  check (contamination_status in ('PENDING','PASS','FAIL')),
  unique(run_id,game_id,intake_id)
);

create unique index if not exists uq_nrfimetrica_press_one_validated_intake
on public.nrfimetrica_press_intakes(run_id,game_id)
where status='RECEIVED_VALIDATED';

create table if not exists public.nrfimetrica_press_items (
  item_id text primary key,
  intake_id text not null references public.nrfimetrica_press_intakes(intake_id) on delete cascade,
  run_id text not null,
  game_id text not null,
  press_evidence_id text not null,
  delta_class text not null,
  object_name text not null,
  half_affected text not null,
  fact text not null,
  source_original text not null,
  source_family_id text,
  author text,
  published_at timestamptz,
  as_of timestamptz not null,
  fact_status text not null,
  fact_confidence text not null,
  current_version_relevance text not null,
  lineup_version_id text,
  freshness_status text not null,
  contradictory_evidence jsonb not null default '[]'::jsonb,
  source_url text not null,
  press_note text,
  previous_state text,
  new_state text,
  changed_object text,
  materiality_question text not null,
  created_at timestamptz not null default now(),
  unique(intake_id,press_evidence_id),
  check (delta_class in ('STARTER_STATUS_DELTA','VELOCITY_DELTA','ARSENAL_DELTA','COMMAND_DELTA','MECHANICAL_DELTA','HEALTH_DELTA','ROLE_DELTA','LINEUP_DELTA','BATTER_HEALTH_DELTA','CATCHER_DELTA','ROOF_WEATHER_DELTA','UMPIRE_CONTEXT_DELTA','OTHER_MATERIAL_DELTA')),
  check (half_affected in ('TOP_1ST','BOTTOM_1ST','SHARED')),
  check (fact_status in ('CONFIRMED','CORROBORATED','PENDING')),
  check (fact_confidence in ('HIGH','MEDIUM','LOW')),
  check (current_version_relevance in ('YES','NO','POSSIBLE')),
  check (freshness_status in ('CURRENT','REVALIDATION_REQUIRED','STALE'))
);

create table if not exists public.nrfimetrica_press_item_dispositions (
  disposition_id text primary key,
  intake_id text not null references public.nrfimetrica_press_intakes(intake_id) on delete cascade,
  item_id text not null references public.nrfimetrica_press_items(item_id) on delete cascade,
  run_id text not null,
  game_id text not null,
  sports_packet_id text not null references public.sports_reasoning_packets(packet_id) on delete cascade,
  disposition text not null,
  materiality_if_true text not null default 'UNKNOWN',
  reasoning text not null,
  claim_ids text[] not null default '{}'::text[],
  decided_at timestamptz not null default now(),
  unique(item_id,sports_packet_id),
  check (disposition in ('INTEGRATED_GOVERNING','INTEGRATED_MATERIAL','INTEGRATED_MODULATOR','CONTEXT_ONLY','DESCRIPTIVE_ONLY','REFUTED_BY_METRICS','STALE','DUPLICATE_EXISTING_INFORMATION','NOT_NRFI_RELEVANT','UNRESOLVED')),
  check (materiality_if_true in ('GOVERNING','MATERIAL','MODULATOR','CONTEXT','NONE','UNKNOWN')),
  check (length(btrim(reasoning))>=12)
);

create or replace function public.nrfimetrica_enforce_press_intake()
returns trigger
language plpgsql
set search_path = public, extensions, pg_temp
as $$
declare
  start_at timestamptz;
  forbidden text[]:=array[
    'external_picks','picks','consensus','odds','line_movement','movement','review_priority','shortlist',
    'jrc','jrc_status','so_media_status','f8_conclusion','candidate_rank','p_nrfi','model_probability','edge','ev','stake',
    'bet_amount','final_pick','nrfi_materiality','materiality_answer','press_verdict','best_press_nrfi_case',
    'best_press_yrfi_case','press_vulnerable_half','press_breakpoints','external_analyst_arguments','recommendation',
    'ranking','priority','reformulated_verdict','contrast_effect','coincidences','omitted_risks'
  ];
begin
  if tg_op='INSERT' and coalesce(new.intake_id,'')='' then
    new.intake_id:='PINT-'||replace(gen_random_uuid()::text,'-','');
  end if;
  select scheduled_start into start_at from public.games where run_id=new.run_id and game_id=new.game_id;
  if start_at is null then raise exception 'PRESS_INTAKE_GAME_NOT_REGISTERED' using errcode='23514'; end if;
  if new.received_at>clock_timestamp()+interval '1 minute' then raise exception 'PRESS_INTAKE_FROM_FUTURE' using errcode='23514'; end if;
  if new.received_at>=start_at then raise exception 'PRESS_INTAKE_LIVE_CONTAMINATION_FORBIDDEN' using errcode='23514'; end if;
  if jsonb_typeof(new.payload)<>'object' then raise exception 'PRESS_INTAKE_PAYLOAD_OBJECT_REQUIRED' using errcode='23514'; end if;
  new.content_hash:=public.nrfim_sha256_text(new.payload::text);
  if public.nrfim_json_has_key_recursive(new.payload,forbidden) then
    new.contamination_status:='FAIL';
    if new.status='RECEIVED_VALIDATED' then raise exception 'PRESS_INTAKE_INTERPRETIVE_OR_MARKET_CONTAMINATION' using errcode='23514'; end if;
    new.status:='REJECTED_CONTAMINATION';
  end if;
  if new.status='RECEIVED_VALIDATED' then
    if new.provenance_status<>'VERIFIED_SOURCE_PACKET' then raise exception 'PRESS_INTAKE_VALIDATED_REQUIRES_VERIFIED_SOURCE_PACKET' using errcode='23514'; end if;
    if new.contamination_status<>'PASS' then raise exception 'PRESS_INTAKE_VALIDATED_REQUIRES_CONTAMINATION_PASS' using errcode='23514'; end if;
    if new.source_receipt='{}'::jsonb then raise exception 'PRESS_INTAKE_VALIDATED_REQUIRES_SOURCE_RECEIPT' using errcode='23514'; end if;
    if coalesce(new.source_receipt->>'source_packet_hash','')<>new.source_packet_hash then raise exception 'PRESS_INTAKE_SOURCE_RECEIPT_HASH_MISMATCH' using errcode='23514'; end if;
    if coalesce(new.source_receipt->>'parsed_payload_hash','')<>new.content_hash then raise exception 'PRESS_INTAKE_PARSED_PAYLOAD_HASH_MISMATCH' using errcode='23514'; end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_nrfimetrica_press_intake_guard on public.nrfimetrica_press_intakes;
create trigger trg_nrfimetrica_press_intake_guard before insert or update on public.nrfimetrica_press_intakes
for each row execute function public.nrfimetrica_enforce_press_intake();

create or replace function public.nrfimetrica_enforce_press_item()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare i public.nrfimetrica_press_intakes%rowtype;
begin
  if tg_op='INSERT' and coalesce(new.item_id,'')='' then new.item_id:='PITEM-'||replace(gen_random_uuid()::text,'-',''); end if;
  select * into i from public.nrfimetrica_press_intakes where intake_id=new.intake_id;
  if not found or i.run_id<>new.run_id or i.game_id<>new.game_id then raise exception 'PRESS_ITEM_INTAKE_IDENTITY_MISMATCH' using errcode='23514'; end if;
  if i.status<>'RECEIVED_VALIDATED' or i.contamination_status<>'PASS' then raise exception 'PRESS_ITEM_REQUIRES_VALIDATED_CLEAN_INTAKE' using errcode='23514'; end if;
  if new.as_of>i.received_at+interval '1 minute' then raise exception 'PRESS_ITEM_ASOF_AFTER_INTAKE' using errcode='23514'; end if;
  if new.published_at is not null and new.published_at>i.received_at+interval '1 minute' then raise exception 'PRESS_ITEM_PUBLICATION_FROM_FUTURE' using errcode='23514'; end if;
  if length(btrim(new.fact))<8 or length(btrim(new.source_original))<3 or length(btrim(new.source_url))<8 then raise exception 'PRESS_ITEM_FACT_AND_SOURCE_REQUIRED' using errcode='23514'; end if;
  if length(btrim(new.materiality_question))<12 then raise exception 'PRESS_ITEM_MATERIALITY_QUESTION_REQUIRED' using errcode='23514'; end if;
  return new;
end;
$$;

drop trigger if exists trg_nrfimetrica_press_item_guard on public.nrfimetrica_press_items;
create trigger trg_nrfimetrica_press_item_guard before insert or update on public.nrfimetrica_press_items
for each row execute function public.nrfimetrica_enforce_press_item();

create or replace function public.nrfimetrica_enforce_press_disposition()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  it public.nrfimetrica_press_items%rowtype;
  sp public.sports_reasoning_packets%rowtype;
  cid text;
begin
  if tg_op='INSERT' and coalesce(new.disposition_id,'')='' then new.disposition_id:='PDISP-'||replace(gen_random_uuid()::text,'-',''); end if;
  select * into it from public.nrfimetrica_press_items where item_id=new.item_id;
  select * into sp from public.sports_reasoning_packets where packet_id=new.sports_packet_id;
  if not found then raise exception 'PRESS_DISPOSITION_SPORTS_PACKET_NOT_FOUND' using errcode='23514'; end if;
  if it.item_id is null or it.intake_id<>new.intake_id or it.run_id<>new.run_id or it.game_id<>new.game_id then raise exception 'PRESS_DISPOSITION_ITEM_IDENTITY_MISMATCH' using errcode='23514'; end if;
  if sp.run_id<>new.run_id or sp.game_id<>new.game_id then raise exception 'PRESS_DISPOSITION_PACKET_IDENTITY_MISMATCH' using errcode='23514'; end if;
  if sp.freeze_timestamp is not null then raise exception 'PRESS_DISPOSITION_AFTER_PACKET_FREEZE_FORBIDDEN' using errcode='23514'; end if;
  if new.disposition in ('INTEGRATED_GOVERNING','INTEGRATED_MATERIAL','INTEGRATED_MODULATOR','REFUTED_BY_METRICS') and coalesce(array_length(new.claim_ids,1),0)=0 then raise exception 'PRESS_DISPOSITION_MATERIAL_ACTION_REQUIRES_CLAIM_IDS' using errcode='23514'; end if;
  foreach cid in array coalesce(new.claim_ids,'{}') loop
    if not exists(select 1 from public.sports_reasoning_claims c where c.claim_id=cid and c.packet_id=new.sports_packet_id and c.run_id=new.run_id and c.game_id=new.game_id) then raise exception 'PRESS_DISPOSITION_CLAIM_NOT_IN_PACKET:%',cid using errcode='23514'; end if;
  end loop;
  return new;
end;
$$;

drop trigger if exists trg_nrfimetrica_press_disposition_guard on public.nrfimetrica_press_item_dispositions;
create trigger trg_nrfimetrica_press_disposition_guard before insert or update on public.nrfimetrica_press_item_dispositions
for each row execute function public.nrfimetrica_enforce_press_disposition();

insert into public.protocol_phase_catalog(protocol_id,phase_id,conditional,trigger_path,required_fields,min_source_calls,min_evidence_ids,required_documents,required_phrases,max_items)
values('NRFIMETRICA_MOTHER_V3_AUTONOMOUS','A0P_PRESS_INFORMATION_INTAKE',true,'press_packet_available',
 array['press_packet_available','intake_id','intake_status','information_role','sports_authority','probability_authority','ranking_authority','market_authority','conclusion_authority','contamination_status','phase_result'],
 0,0,'{}','{INFORMACIÓN EXTERNA PARA ANALIZAR; NO DETERMINA VEREDICTO, PROBABILIDAD, RANKING NI DECISIÓN.}','{}'::jsonb)
on conflict(protocol_id,phase_id) do update set conditional=excluded.conditional,trigger_path=excluded.trigger_path,required_fields=excluded.required_fields,min_source_calls=excluded.min_source_calls,min_evidence_ids=excluded.min_evidence_ids,required_documents=excluded.required_documents,required_phrases=excluded.required_phrases,max_items=excluded.max_items;

insert into public.protocol_phase_prerequisites(protocol_id,phase_id,prerequisite_phase_id)
values('NRFIMETRICA_MOTHER_V3_AUTONOMOUS','A1_DATA_INTEGRITY_FREEZE','A0P_PRESS_INFORMATION_INTAKE')
on conflict do nothing;

create or replace function public.nrfimetrica_enforce_press_intake_phase()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare i public.nrfimetrica_press_intakes%rowtype; cnt integer;
begin
  if new.protocol_id<>'NRFIMETRICA_MOTHER_V3_AUTONOMOUS' or new.phase_id<>'A0P_PRESS_INFORMATION_INTAKE' then return new; end if;
  if new.status='SKIPPED_NOT_TRIGGERED' then
    if lower(coalesce(new.payload->>'press_packet_available','false')) not in ('false','0','no') then raise exception 'A0P_SKIP_REQUIRES_PRESS_PACKET_UNAVAILABLE' using errcode='23514'; end if;
    return new;
  end if;
  if new.status<>'COMPLETE' then raise exception 'A0P_MUST_COMPLETE_OR_SKIP_NOT_TRIGGERED' using errcode='23514'; end if;
  if lower(coalesce(new.payload->>'press_packet_available','false')) not in ('true','1','yes') then raise exception 'A0P_COMPLETE_REQUIRES_PRESS_PACKET_AVAILABLE' using errcode='23514'; end if;
  select * into i from public.nrfimetrica_press_intakes where intake_id=new.payload->>'intake_id';
  if not found or i.run_id<>new.run_id or i.game_id<>new.game_id then raise exception 'A0P_INTAKE_IDENTITY_MISMATCH' using errcode='23514'; end if;
  if i.status<>'RECEIVED_VALIDATED' or i.contamination_status<>'PASS' then raise exception 'A0P_REQUIRES_VALIDATED_CLEAN_INTAKE' using errcode='23514'; end if;
  if i.information_role<>'INFORMATION_FOR_ANALYSIS' or i.sports_authority<>'NONE' or i.probability_authority<>'NONE' or i.ranking_authority<>'NONE' or i.market_authority<>'NONE' or i.conclusion_authority<>'NONE' then raise exception 'A0P_PRESS_INPUT_HAS_FORBIDDEN_AUTHORITY' using errcode='23514'; end if;
  if new.payload->>'intake_status' is distinct from i.status or new.payload->>'information_role' is distinct from i.information_role or new.payload->>'sports_authority' is distinct from i.sports_authority or new.payload->>'probability_authority' is distinct from i.probability_authority or new.payload->>'ranking_authority' is distinct from i.ranking_authority or new.payload->>'market_authority' is distinct from i.market_authority or new.payload->>'conclusion_authority' is distinct from i.conclusion_authority or new.payload->>'contamination_status' is distinct from i.contamination_status then raise exception 'A0P_PHASE_FIELDS_DIFFER_FROM_INTAKE' using errcode='23514'; end if;
  select count(*) into cnt from public.nrfimetrica_press_items where intake_id=i.intake_id;
  if cnt=0 and not i.no_material_delta then raise exception 'A0P_VALIDATED_PACKET_REQUIRES_ITEMS_OR_NO_MATERIAL_DELTA' using errcode='23514'; end if;
  return new;
end;
$$;

drop trigger if exists trg_001_nrfimetrica_press_intake_phase on public.protocol_phase_state;
create trigger trg_001_nrfimetrica_press_intake_phase before insert or update on public.protocol_phase_state
for each row execute function public.nrfimetrica_enforce_press_intake_phase();

alter table public.nrfimetrica_press_intakes enable row level security;
alter table public.nrfimetrica_press_items enable row level security;
alter table public.nrfimetrica_press_item_dispositions enable row level security;
revoke all on public.nrfimetrica_press_intakes from anon, authenticated;
revoke all on public.nrfimetrica_press_items from anon, authenticated;
revoke all on public.nrfimetrica_press_item_dispositions from anon, authenticated;
grant select,insert,update,delete on public.nrfimetrica_press_intakes to service_role;
grant select,insert,update,delete on public.nrfimetrica_press_items to service_role;
grant select,insert,update,delete on public.nrfimetrica_press_item_dispositions to service_role;
