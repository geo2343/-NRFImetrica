-- Fix PL/pgSQL ambiguity between local evidence variable and evidence.evidence_id.
create or replace function public.enforce_nrfimetrica_sports_shortlist()
returns trigger language plpgsql as $$
declare
  p text:='NRFIMETRICA_MOTHER_V3_AUTONOMOUS';
  pool integer; non_audit integer; i jsonb; gid text; rankn integer; seen text[]:='{}'; selected text[]:='{}'; excluded text[]:='{}';
  ev_id text; expected_excluded integer;
begin
  if new.protocol_id<>p then return new; end if;
  select count(*) filter(where sports_status='SPORTS_CANDIDATE'), count(*) filter(where sports_status<>'AUDIT_ONLY')
    into pool,non_audit from public.nrfimetrica_game_dual_status where run_id=new.run_id;
  new.candidate_pool_count:=pool;
  if jsonb_typeof(new.primary_candidates)<>'array' then raise exception 'SHORTLIST_PRIMARY_CANDIDATES_MUST_BE_ARRAY' using errcode='23514'; end if;
  if jsonb_typeof(new.excluded_candidates)<>'array' then raise exception 'SHORTLIST_EXCLUDED_CANDIDATES_MUST_BE_ARRAY' using errcode='23514'; end if;
  if pool=0 then
    new.shortlist_count:=0;
    if non_audit=0 then new.status:='NO_PREGAME_OPPORTUNITY'; else new.status:='NO_SPORTS_CANDIDATES'; end if;
    if jsonb_array_length(new.primary_candidates)<>0 or new.optional_third is not null then raise exception 'SHORTLIST_CANNOT_SELECT_WHEN_POOL_ZERO' using errcode='23514'; end if;
    return new;
  end if;
  if pool=1 then
    if jsonb_array_length(new.primary_candidates)<>1 or new.optional_third is not null then raise exception 'SHORTLIST_SINGLE_POOL_MUST_RETURN_SINGLE_CANDIDATE' using errcode='23514'; end if;
    new.shortlist_count:=1; new.status:='INSUFFICIENT_POTABLE_SHORTLIST';
  else
    if jsonb_array_length(new.primary_candidates)<>2 then raise exception 'SHORTLIST_REQUIRES_EXACTLY_TWO_PRIMARY_CANDIDATES' using errcode='23514'; end if;
    if new.optional_third is not null and pool<3 then raise exception 'SHORTLIST_THIRD_REQUIRES_POOL_AT_LEAST_THREE' using errcode='23514'; end if;
    new.shortlist_count:=2 + case when new.optional_third is null then 0 else 1 end;
    if new.shortlist_count>3 then raise exception 'SHORTLIST_MAX_THREE' using errcode='23514'; end if;
    new.status:='SHORTLIST_READY';
  end if;
  rankn:=0;
  for i in select value from jsonb_array_elements(new.primary_candidates) loop
    rankn:=rankn+1; gid:=i->>'game_id';
    if coalesce(gid,'')='' or gid=any(seen) then raise exception 'SHORTLIST_PRIMARY_ID_INVALID_OR_DUPLICATE:%',coalesce(gid,'NULL') using errcode='23514'; end if;
    if not exists(select 1 from public.nrfimetrica_game_dual_status d where d.run_id=new.run_id and d.game_id=gid and d.sports_status='SPORTS_CANDIDATE') then raise exception 'SHORTLIST_PRIMARY_NOT_SPORTS_CANDIDATE:%',gid using errcode='23514'; end if;
    if coalesce((i->>'rank')::integer,-1)<>rankn then raise exception 'SHORTLIST_PRIMARY_RANK_INVALID:%/%',gid,rankn using errcode='23514'; end if;
    if length(trim(coalesce(i->>'central_argument','')))<80 then raise exception 'SHORTLIST_CENTRAL_ARGUMENT_TOO_THIN:%',gid using errcode='23514'; end if;
    if length(trim(coalesce(i->>'dominant_suppression_mechanism','')))<40 then raise exception 'SHORTLIST_DOMINANT_MECHANISM_REQUIRED:%',gid using errcode='23514'; end if;
    if length(trim(coalesce(i->>'strongest_risk','')))<30 then raise exception 'SHORTLIST_STRONGEST_RISK_REQUIRED:%',gid using errcode='23514'; end if;
    if length(trim(coalesce(i->>'why_it_survives_risk','')))<50 then raise exception 'SHORTLIST_RISK_SURVIVAL_ARGUMENT_REQUIRED:%',gid using errcode='23514'; end if;
    if length(trim(coalesce(i->>'why_above_next_best','')))<50 then raise exception 'SHORTLIST_RELATIVE_COMPARISON_REQUIRED:%',gid using errcode='23514'; end if;
    if jsonb_typeof(coalesce(i->'evidence_ids','[]'::jsonb))<>'array' or jsonb_array_length(coalesce(i->'evidence_ids','[]'::jsonb))=0 then raise exception 'SHORTLIST_EVIDENCE_REQUIRED:%',gid using errcode='23514'; end if;
    for ev_id in select jsonb_array_elements_text(i->'evidence_ids') loop
      if not exists(select 1 from public.evidence e where e.evidence_id=ev_id and e.run_id=new.run_id and e.game_id=gid and upper(coalesce(e.evidence_scope,''))='SPORTS_REASONING') then raise exception 'SHORTLIST_EVIDENCE_INVALID:%:%',gid,ev_id using errcode='23514'; end if;
    end loop;
    seen:=array_append(seen,gid); selected:=array_append(selected,gid);
  end loop;
  if new.optional_third is not null then
    i:=new.optional_third; gid:=i->>'game_id';
    if coalesce(gid,'')='' or gid=any(seen) then raise exception 'SHORTLIST_THIRD_ID_INVALID_OR_DUPLICATE:%',coalesce(gid,'NULL') using errcode='23514'; end if;
    if not exists(select 1 from public.nrfimetrica_game_dual_status d where d.run_id=new.run_id and d.game_id=gid and d.sports_status='SPORTS_CANDIDATE') then raise exception 'SHORTLIST_THIRD_NOT_SPORTS_CANDIDATE:%',gid using errcode='23514'; end if;
    if coalesce((i->>'rank')::integer,-1)<>3 then raise exception 'SHORTLIST_THIRD_RANK_MUST_BE_3' using errcode='23514'; end if;
    if length(trim(coalesce(i->>'central_argument','')))<80 or length(trim(coalesce(i->>'why_third_is_worth_including','')))<60 or length(trim(coalesce(i->>'why_not_primary_two','')))<50 then raise exception 'SHORTLIST_THIRD_REQUIRES_EXCEPTIONAL_ARGUMENT:%',gid using errcode='23514'; end if;
    if jsonb_typeof(coalesce(i->'evidence_ids','[]'::jsonb))<>'array' or jsonb_array_length(coalesce(i->'evidence_ids','[]'::jsonb))=0 then raise exception 'SHORTLIST_THIRD_EVIDENCE_REQUIRED:%',gid using errcode='23514'; end if;
    for ev_id in select jsonb_array_elements_text(i->'evidence_ids') loop
      if not exists(select 1 from public.evidence e where e.evidence_id=ev_id and e.run_id=new.run_id and e.game_id=gid and upper(coalesce(e.evidence_scope,''))='SPORTS_REASONING') then raise exception 'SHORTLIST_THIRD_EVIDENCE_INVALID:%:%',gid,ev_id using errcode='23514'; end if;
    end loop;
    seen:=array_append(seen,gid); selected:=array_append(selected,gid);
  end if;
  expected_excluded:=pool-new.shortlist_count;
  if jsonb_array_length(new.excluded_candidates)<>expected_excluded then raise exception 'SHORTLIST_EXCLUDED_COUNT_MISMATCH:%/%',jsonb_array_length(new.excluded_candidates),expected_excluded using errcode='23514'; end if;
  for i in select value from jsonb_array_elements(new.excluded_candidates) loop
    gid:=i->>'game_id';
    if coalesce(gid,'')='' or gid=any(seen) then raise exception 'SHORTLIST_EXCLUDED_ID_INVALID_OR_DUPLICATE:%',coalesce(gid,'NULL') using errcode='23514'; end if;
    if not exists(select 1 from public.nrfimetrica_game_dual_status d where d.run_id=new.run_id and d.game_id=gid and d.sports_status='SPORTS_CANDIDATE') then raise exception 'SHORTLIST_EXCLUDED_NOT_IN_POOL:%',gid using errcode='23514'; end if;
    if length(trim(coalesce(i->>'why_not_top_two','')))<50 or length(trim(coalesce(i->>'material_weakness_vs_selected','')))<40 then raise exception 'SHORTLIST_EXCLUSION_REQUIRES_RELATIVE_SPORTS_ARGUMENT:%',gid using errcode='23514'; end if;
    seen:=array_append(seen,gid); excluded:=array_append(excluded,gid);
  end loop;
  if coalesce(array_length(seen,1),0)<>pool then raise exception 'SHORTLIST_MUST_ACCOUNT_FOR_ENTIRE_SPORTS_CANDIDATE_POOL:%/%',coalesce(array_length(seen,1),0),pool using errcode='23514'; end if;
  if length(trim(coalesce(new.comparative_conclusion,'')))<120 then raise exception 'SHORTLIST_COMPARATIVE_CONCLUSION_TOO_THIN' using errcode='23514'; end if;
  return new;
end $$;

update public.agent_registry set metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('database_migrations_required_through',32,'sports_shortlist_evidence_validation_fix',true) where agent_id='@NRFImetrica';