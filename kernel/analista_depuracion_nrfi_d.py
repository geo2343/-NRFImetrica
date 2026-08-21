from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Iterable

AGENT_ID = "@AnalistaDepuracionRNFI_D"
AGENT_VERSION = "ANALISTADEPURACIONRNFI-D-AGENT-1.1"
KERNEL_VERSION = "ANALISTADEPURACIONRNFI-D-KERNEL-1.1"
REASONING_PLANE = "CHATGPT_AGENT_RUNTIME"
CONTROL_PLANE = "SUPABASE_KERNEL"
SOURCE_REQUIREMENTS = 1057
MAX_CANDIDATES = 4

PHASE_ORDER = ("F1","F2","F3","F4","F5","F6","F7","F8","F9","D1","D2","F10","F11","REPORT_D")
REQUIREMENT_COUNTS = {"F1":27,"F2":69,"F3":80,"F4":124,"F5":145,"F6":144,"F7":152,"F8":85,"F9":93,"D1":19,"D2":20,"F10":54,"F11":45,"REPORT_D":0}

FORBIDDEN_D1_D2={"candidate","candidate_a","candidate_b","candidate_c","candidate_d","top_4","advances_to_deep_analysis","eliminated","final_nrfi","bet","probability","edge","fair_price","lock"}
FORBIDDEN_TERMINAL={"final_nrfi","final_nrfi_bet","bet","bet_size","probability","fair_price","edge","lock","safe_game","guaranteed","rank_1_to_4"}
CAUSAL_REQUIRED={"possible_vs_governing_separated","non_governing_adverse_route_not_auto_veto","joint_materialization_checked","upper_paths_not_summed_as_central"}
CAUSAL_TEXT_REQUIRED={"governing_route_basis","non_governing_route_review","joint_materialization_basis","upper_path_separation_basis"}

class KernelViolation(ValueError):
    pass

def _walk_keys(value:Any)->Iterable[str]:
    if isinstance(value,dict):
        for key,child in value.items():
            yield str(key).lower(); yield from _walk_keys(child)
    elif isinstance(value,list):
        for child in value: yield from _walk_keys(child)

def has_forbidden_key(value:Any, forbidden:set[str])->bool:
    return any(key in forbidden for key in _walk_keys(value))

def next_phase(current:str)->str|None:
    try: idx=PHASE_ORDER.index(current)
    except ValueError as exc: raise KernelViolation(f"UNKNOWN_PHASE:{current}") from exc
    return PHASE_ORDER[idx+1] if idx+1<len(PHASE_ORDER) else None

def validate_requirement_count(phase:str, count:int)->None:
    if count!=REQUIREMENT_COUNTS[phase]: raise KernelViolation(f"REQUIREMENT_COUNT_MISMATCH:{phase}")

def validate_attestation_batch(states:list[dict[str,Any]], expected:int)->None:
    if len(states)!=expected: raise KernelViolation("REQUIREMENT_ATTESTATION_GATE")
    unresolved=[x for x in states if x.get("state") not in {"VERIFIED","NOT_APPLICABLE"}]
    if unresolved: raise KernelViolation("REQUIREMENT_ATTESTATION_GATE")
    verified=[x for x in states if x.get("state")=="VERIFIED"]
    if verified:
        distinct={str(x.get("finding","")).strip() for x in verified if str(x.get("finding","")).strip()}
        if len(distinct)<min(5,max(1,(len(verified)+4)//5)): raise KernelViolation("BLANKET_ATTESTATION_DETECTED")
        evidence={e for x in verified for e in x.get("evidence_refs",[]) or []}
        if expected>=5 and len(evidence)<2: raise KernelViolation("EVIDENCE_DIVERSITY_TOO_LOW")
    if sum(1 for x in states if x.get("state")=="NOT_APPLICABLE")>expected//2: raise KernelViolation("NOT_APPLICABLE_ESCAPE_DETECTED")

def validate_causal_integrity(phase:str, output:dict[str,Any])->None:
    if phase not in {"F7","F8","F9","D1","D2","F10","F11"}: return
    c=output.get("causal_integrity")
    if not isinstance(c,dict): raise KernelViolation("CAUSAL_INTEGRITY_REQUIRED")
    for key in CAUSAL_REQUIRED:
        if c.get(key) is not True: raise KernelViolation(f"CAUSAL_GATE:{key}")
    for key in CAUSAL_TEXT_REQUIRED:
        if len(str(c.get(key,"" )).strip())<30: raise KernelViolation(f"CAUSAL_BASIS_REQUIRED:{key}")
    if phase in {"D1","D2","F10"}:
        if c.get("pruning_requires_what_changed") is not True or not c.get("what_changed_log"):
            raise KernelViolation("PRUNING_WHAT_CHANGED_REQUIRED")

def validate_phase_output(phase:str, output:dict[str,Any])->None:
    if not isinstance(output,dict): raise KernelViolation("PHASE_OUTPUT_OBJECT_REQUIRED")
    if output.get("phase_code")!=phase: raise KernelViolation("PHASE_CODE_REQUIRED")
    if len(str(output.get("phase_summary","" )).strip())<20: raise KernelViolation("PHASE_SUMMARY_REQUIRED")
    if phase in {"D1","D2"} and has_forbidden_key(output,FORBIDDEN_D1_D2): raise KernelViolation("PRE_F10_SELECTION_AUTHORITY_VIOLATION")
    if phase in {"F10","F11"} and has_forbidden_key(output,FORBIDDEN_TERMINAL): raise KernelViolation("BETTING_OR_FINAL_NRFI_AUTHORITY_FORBIDDEN")
    validate_causal_integrity(phase,output)
    if phase=="F10":
        count=int(output.get("ADVANCED_CANDIDATE_COUNT",output.get("candidate_count",-1)))
        if count<0 or count>MAX_CANDIDATES: raise KernelViolation("F10_MAX_FOUR_VIOLATION")
        if len(output.get("candidates",[]))!=count or not all(k in output for k in ("exclusion_ledger","best_excluded","comparison_basis")): raise KernelViolation("F10_COMPARATIVE_CLOSE_REQUIRED")
    if phase=="F11":
        count=int(output.get("CANDIDATE_COUNT",output.get("candidate_count",-1)))
        if count<0 or count>MAX_CANDIDATES or len(output.get("candidate_dossiers",[]))!=count: raise KernelViolation("F11_DOSSIER_GATE")
        if str(output.get("HANDOFF_COMPLETENESS_GATE","" )).upper()!="PASS": raise KernelViolation("F11_HANDOFF_COMPLETENESS_GATE_REQUIRED")
        if str(output.get("PRE_DEEP_ANALYSIS_POSITION_FROZEN","" )).lower() not in {"yes","true","1"}: raise KernelViolation("F11_PRE_DEEP_FREEZE_REQUIRED")

@dataclass(frozen=True)
class DialogueContract:
    user_mediated:bool=True
    one_authorization_per_d_response:bool=True
    authorization_bound_to_exact_inbound_hash:bool=True
    generation_proof_required:bool=True
    auto_chain_forbidden:bool=True
    d_closes_first:bool=True
    a_closes_system:bool=True
    post_turn_state:str="STOP_WAITING_USER_AUTHORIZATION"

DIALOGUE_CONTRACT=DialogueContract()
