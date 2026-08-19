-- Generic declarative requirement enforcement for ChatGPT-driven runs.

create table if not exists public.protocol_phase_catalog (
  protocol_id text not null,
  phase_id text not null,
  conditional boolean not null default false,
  trigger_path text,
  required_fields text[] not null default '{}',
  min_source_calls integer not null default 0,
  min_evidence_ids integer not null default 0,
  required_documents text[] not null default '{}',
  required_phrases text[] not null default '{}',
  max_items jsonb not null default '{}'::jsonb,
  primary key(protocol_id, phase_id)
);

alter table public.protocol_phase_catalog enable row level security;

insert into public.protocol_phase_catalog(
  protocol_id,phase_id,conditional,trigger_path,required_fields,min_source_calls,min_evidence_ids,max_items
) values
(
 'NRFIMETRICA_V21_AI_ANALYST','TRIAGE',false,null,
 array['starters.away','starters.home','lineup_status.away','lineup_status.home','b1_b3.away','b1_b3.home','depth_plan.b4_b5_trigger','depth_plan.b6_b9_trigger','depth_plan.reason'],1,1,'{}'::jsonb
),
(
 'NRFIMETRICA_V21_AI_ANALYST','DEPTH_B4_B5',true,'b4_b5_trigger',
 array['b4_b5_trigger','trigger_reason','b4_b5.away','b4_b5.home','material_impact'],0,1,'{}'::jsonb
),
(
 'NRFIMETRICA_V21_AI_ANALYST','DEPTH_B6_B9',true,'b6_b9_trigger',
 array['b6_b9_trigger','trigger_reason','b6_b9.away','b6_b9.home','material_impact'],0,1,'{}'::jsonb
),
(
 'NRFIMETRICA_V21_AI_ANALYST','BILATERAL_FIRST_INNING_ANALYSIS',false,null,
 array[
 'away_pitcher.out_creation','away_pitcher.k_bb','away_pitcher.traffic','away_pitcher.damage','away_pitcher.hr_risk','away_pitcher.platoon','away_pitcher.arsenal','away_pitcher.command','away_pitcher.current_version','away_pitcher.restrictions',
 'home_pitcher.out_creation','home_pitcher.k_bb','home_pitcher.traffic','home_pitcher.damage','home_pitcher.hr_risk','home_pitcher.platoon','home_pitcher.arsenal','home_pitcher.command','home_pitcher.current_version','home_pitcher.restrictions',
 'away_offense.discipline','away_offense.contact','away_offense.damage','away_offense.platoon','away_offense.arsenal_access','away_offense.relevant_form',
 'home_offense.discipline','home_offense.contact','home_offense.damage','home_offense.platoon','home_offense.arsenal_access','home_offense.relevant_form','mechanisms','correlated_metrics_check'
 ],1,1,'{}'::jsonb
),
(
 'NRFIMETRICA_V21_AI_ANALYST','MATERIAL_CONTEXT',true,'context_material_trigger',
 array['context_material_trigger','material_context','materialization_mechanism'],0,1,'{}'::jsonb
),
(
 'NRFIMETRICA_V21_AI_ANALYST','RED_TEAM',true,'red_team_trigger',
 array['red_team_trigger','trigger_reason','strongest_countercase','countercase_evidence','resolution'],0,1,'{}'::jsonb
),
(
 'NRFIMETRICA_V21_AI_ANALYST','SYNTHESIS',false,null,
 array['central_nrfi_case','best_yrfi_rival','materialization_chain_nrfi','materialization_chain_yrfi','decisive_evidence','misleading_or_redundant_data','principal_risk','what_would_change','research_stop_reason','additional_information_can_change_decision','stress_test_or_rescue_attempt','counterevidence_resolution'],0,0,
 '{"governing_uncertainties":1,"breakpoints":2,"independent_causal_reasons":3}'::jsonb
),
(
 'NRFIMETRICA_V21_AI_ANALYST','VALIDATOR_CHALLENGE',false,null,
 array['claims_checked','unsupported_claims','contradictions_checked','metric_independence_check','both_routes_compared','cutoff_check','evidence_trace_check','causal_not_vote_check','validator_findings'],0,0,'{}'::jsonb
),
(
 'NRFIMETRICA_V21_AI_ANALYST','RECONSIDERATION',false,null,
 array['validator_findings_addressed','final_central_nrfi_case','final_best_yrfi_rival','decisive_factor','materiality','principal_risk','what_would_change','final_decision','reasoned_verdict'],0,0,'{}'::jsonb
)
on conflict (protocol_id,phase_id) do update set
  conditional=excluded.conditional,
  trigger_path=excluded.trigger_path,
  required_fields=excluded.required_fields,
  min_source_calls=excluded.min_source_calls,
  min_evidence_ids=excluded.min_evidence_ids,
  max_items=excluded.max_items;

create or replace function public.jsonb_path_nonempty(doc jsonb, dotted_path text)
returns boolean
language plpgsql
immutable
as $$
declare
  v jsonb;
begin
  v := doc #> string_to_array(dotted_path,'.');
  if v is null or v = 'null'::jsonb or v = '""'::jsonb or v = '[]'::jsonb or v = '{}'::jsonb then
    return false;
  end if;
  return true;
end;
$$;

create or replace function public.enforce_nrfimetrica_phase_requirements()
returns trigger
language plpgsql
as $$
declare
  c public.protocol_phase_catalog%rowtype;
  p text;
  max_pair record;
  v jsonb;
  distinct_sources integer;
  distinct_evidence integer;
  bad_source_rows integer;
  doc_name text;
  phrase text;
  est jsonb;
begin
  select * into c
  from public.protocol_phase_catalog
  where protocol_id=new.protocol_id and phase_id=new.phase_id;

  if not found then
    raise exception 'UNKNOWN_PROTOCOL_PHASE:%:%', new.protocol_id, new.phase_id using errcode='23514';
  end if;

  if new.status='SKIPPED_NOT_TRIGGERED' then
    if not c.conditional then
      raise exception 'NONCONDITIONAL_PHASE_CANNOT_BE_SKIPPED:%', new.phase_id using errcode='23514';
    end if;
    if length(btrim(coalesce(new.skip_reason,''))) < 12 then
      raise exception 'CONDITIONAL_SKIP_REQUIRES_MATERIAL_REASON:%', new.phase_id using errcode='23514';
    end if;
    if c.trigger_path is not null and lower(coalesce(new.payload #>> string_to_array(c.trigger_path,'.'),'false')) in ('true','1','yes') then
      raise exception 'TRIGGERED_PHASE_CANNOT_BE_SKIPPED:%', new.phase_id using errcode='23514';
    end if;
    return new;
  end if;

  foreach p in array c.required_fields loop
    if not public.jsonb_path_nonempty(new.payload,p) then
      raise exception 'REQUIRED_FIELD_MISSING:%:%', new.phase_id,p using errcode='23514';
    end if;
  end loop;

  if jsonb_typeof(new.source_calls) <> 'array' then
    raise exception 'SOURCE_CALLS_MUST_BE_ARRAY:%', new.phase_id using errcode='23514';
  end if;

  select count(*) into bad_source_rows
  from jsonb_array_elements(new.source_calls) x
  where length(btrim(coalesce(x->>'source_ref',''))) = 0
     or length(btrim(coalesce(x->>'evidence_id',''))) = 0
     or length(btrim(coalesce(x->>'retrieved_at',''))) = 0;
  if bad_source_rows > 0 then
    raise exception 'SOURCE_CALL_MISSING_REAL_TRACE_FIELDS:%', new.phase_id using errcode='23514';
  end if;

  select count(distinct x->>'evidence_id') into distinct_sources
  from jsonb_array_elements(new.source_calls) x
  where length(btrim(coalesce(x->>'evidence_id',''))) > 0;
  if distinct_sources < c.min_source_calls then
    raise exception 'MIN_SOURCE_CALLS_NOT_MET:%:%/%', new.phase_id,distinct_sources,c.min_source_calls using errcode='23514';
  end if;

  select count(distinct e) into distinct_evidence from unnest(new.evidence_ids) e where length(btrim(e))>0;
  if distinct_evidence < c.min_evidence_ids then
    raise exception 'MIN_EVIDENCE_NOT_MET:%:%/%', new.phase_id,distinct_evidence,c.min_evidence_ids using errcode='23514';
  end if;

  foreach doc_name in array c.required_documents loop
    if not (doc_name = any(new.documents_analyzed)) then
      raise exception 'REQUIRED_DOCUMENT_MISSING:%:%', new.phase_id,doc_name using errcode='23514';
    end if;
    if not exists (
      select 1 from jsonb_array_elements(new.source_calls) x
      where coalesce(x->>'document',x->>'document_id','') = doc_name
    ) then
      raise exception 'REQUIRED_DOCUMENT_WITHOUT_REAL_TRACE:%:%', new.phase_id,doc_name using errcode='23514';
    end if;
  end loop;

  foreach phrase in array c.required_phrases loop
    if position(phrase in new.output_text)=0 then
      raise exception 'REQUIRED_PHRASE_MISSING:%:%', new.phase_id,phrase using errcode='23514';
    end if;
  end loop;

  for max_pair in select key,value from jsonb_each(c.max_items) loop
    v := new.payload #> string_to_array(max_pair.key,'.');
    if v is not null and jsonb_typeof(v)='array' and jsonb_array_length(v) > (max_pair.value #>> '{}')::integer then
      raise exception 'MAX_ITEMS_EXCEEDED:%:%:%', new.phase_id,max_pair.key,(max_pair.value #>> '{}') using errcode='23514';
    end if;
  end loop;

  if new.payload ? 'ai_estimate' then
    est := new.payload->'ai_estimate';
    if est ? 'percent' then
      if coalesce(est->>'kind','') <> 'AI_JUDGMENT_UNCALIBRATED' then
        raise exception 'AI_PERCENT_MUST_BE_UNCALIBRATED_JUDGMENT' using errcode='23514';
      end if;
      if (est->>'percent')::numeric < 0 or (est->>'percent')::numeric > 100 then
        raise exception 'AI_ESTIMATE_PERCENT_OUT_OF_RANGE' using errcode='23514';
      end if;
    end if;
    if (est ? 'edge' and est->'edge' <> 'null'::jsonb)
       or (est ? 'ev' and est->'ev' <> 'null'::jsonb)
       or (est ? 'calibrated_probability' and est->'calibrated_probability' <> 'null'::jsonb)
       or (est ? 'real_money_authority' and est->'real_money_authority' <> 'null'::jsonb) then
      raise exception 'AI_ESTIMATE_FORBIDDEN_CALIBRATED_OR_MONEY_FIELD' using errcode='23514';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_nrfimetrica_phase_requirements on public.protocol_phase_state;
create trigger trg_enforce_nrfimetrica_phase_requirements
before insert or update on public.protocol_phase_state
for each row execute function public.enforce_nrfimetrica_phase_requirements();
