-- Complete V2.1 adaptive depth gates.

insert into public.protocol_decision_gates(protocol_id, decision, phase_id) values
  ('NRFIMETRICA_V21_AI_ANALYST','NRFI_CANDIDATE','DEPTH_B4_B5'),
  ('NRFIMETRICA_V21_AI_ANALYST','NRFI_CANDIDATE','DEPTH_B6_B9'),
  ('NRFIMETRICA_V21_AI_ANALYST','NRFI_REJECTED','DEPTH_B4_B5'),
  ('NRFIMETRICA_V21_AI_ANALYST','NRFI_REJECTED','DEPTH_B6_B9')
on conflict do nothing;

insert into public.protocol_phase_prerequisites(protocol_id, phase_id, prerequisite_phase_id) values
  ('NRFIMETRICA_V21_AI_ANALYST','DEPTH_B4_B5','TRIAGE'),
  ('NRFIMETRICA_V21_AI_ANALYST','DEPTH_B6_B9','DEPTH_B4_B5'),
  ('NRFIMETRICA_V21_AI_ANALYST','BILATERAL_FIRST_INNING_ANALYSIS','DEPTH_B4_B5'),
  ('NRFIMETRICA_V21_AI_ANALYST','BILATERAL_FIRST_INNING_ANALYSIS','DEPTH_B6_B9')
on conflict do nothing;
