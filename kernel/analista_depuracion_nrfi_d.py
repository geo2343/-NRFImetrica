from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Iterable

AGENT_ID = "@AnalistaDepuracionRNFI_D"
AGENT_VERSION = "ANALISTADEPURACIONRNFI-D-AGENT-1.1"
KERNEL_VERSION = "ANALISTADEPURACIONRNFI-D-KERNEL-1.1.1"
CANONICAL_SOURCE_DOC_ID = "1ZsPlc2tOSzRH4_XQB0IpzwLGTQxeGASsjy8Cbzy3HLM"
CANONICAL_SOURCE_TEXT_SHA256 = "c46dc9a945d37e3e53e2a6e3879045c6c7de38b25ea5f92894fded5cbaff857b"
SOURCE_REQUIREMENTS = 1057
MAX_CANDIDATES = 4
REASONING_PLANE = "CHATGPT_AGENT_RUNTIME"
CONTROL_PLANE = "SUPABASE_KERNEL"

PHASE_ORDER = (
    "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9",
    "D1", "D2", "F10", "F11", "REPORT_D",
)

REQUIREMENT_COUNTS = {
    "F1": 27, "F2": 69, "F3": 80, "F4": 124, "F5": 145,
    "F6": 144, "F7": 152, "F8": 85, "F9": 93,
    "D1": 19, "D2": 20, "F10": 54, "F11": 45, "REPORT_D": 0,
}

SERVICE_ROLE_EDGE_ALLOWLIST = {
    "depurnrfi_d_create_run_v11",
    "depurnrfi_d_bind_actor_v11",
    "depurnrfi_d_assert_actor_v11",
    "depurnrfi_d_submit_command_v11",
    "depurnrfi_d_get_execution_plan_v11",
    "depurnrfi_d_get_state",
}

FORBIDDEN_D1_D2 = {
    "candidate", "candidate_a", "candidate_b", "candidate_c", "candidate_d",
    "top_4", "advances_to_deep_analysis", "eliminated", "final_nrfi",
    "bet", "probability", "edge", "fair_price", "lock",
}
FORBIDDEN_TERMINAL = {
    "final_nrfi", "final_nrfi_bet", "bet", "bet_size", "probability",
    "fair_price", "edge", "lock", "safe_game", "guaranteed", "rank_1_to_4",
}
CAUSAL_REQUIRED = {
    "possible_vs_governing_separated",
    "non_governing_adverse_route_not_auto_veto",
    "joint_materialization_checked",
    "upper_paths_not_summed_as_central",
}

class KernelViolation(ValueError):
    pass


def _walk_keys(value: Any) -> Iterable[str]:
    if isinstance(value, dict):
        for key, child in value.items():
            yield str(key).lower()
            yield from _walk_keys(child)
    elif isinstance(value, list):
        for child in value:
            yield from _walk_keys(child)


def has_forbidden_key(value: Any, forbidden: set[str]) -> bool:
    return any(key in forbidden for key in _walk_keys(value))


def next_phase(current: str) -> str | None:
    try:
        idx = PHASE_ORDER.index(current)
    except ValueError as exc:
        raise KernelViolation(f"UNKNOWN_PHASE:{current}") from exc
    return PHASE_ORDER[idx + 1] if idx + 1 < len(PHASE_ORDER) else None


def validate_literal_catalog(rows: list[dict[str, Any]]) -> None:
    if len(rows) != SOURCE_REQUIREMENTS:
        raise KernelViolation(f"LITERAL_CATALOG_COUNT_MISMATCH:{len(rows)}")
    for row in rows:
        if int(row.get("source_start_line", 0)) <= 0:
            raise KernelViolation("LITERAL_CATALOG_SOURCE_LINE_REQUIRED")
        if int(row.get("source_end_line", 0)) < int(row.get("source_start_line", 0)):
            raise KernelViolation("LITERAL_CATALOG_LINE_RANGE_INVALID")
        if row.get("source_text_sha256") != CANONICAL_SOURCE_TEXT_SHA256:
            raise KernelViolation("LITERAL_CATALOG_SOURCE_HASH_MISMATCH")
        if str(row.get("title", "")).startswith("Canonical source subsection "):
            raise KernelViolation("LITERAL_CATALOG_PLACEHOLDER_FORBIDDEN")


def validate_requirement_coverage(phase: str, requirement_ids: list[str]) -> None:
    expected = REQUIREMENT_COUNTS[phase]
    if len(requirement_ids) != expected or len(set(requirement_ids)) != expected:
        raise KernelViolation(
            f"REQUIREMENT_COVERAGE_FAIL:{phase}:expected={expected}:got={len(requirement_ids)}"
        )


def validate_causal_integrity(phase: str, output: dict[str, Any]) -> None:
    if phase not in {"F7", "F8", "F9", "D1", "D2", "F10", "F11"}:
        return
    causal = output.get("causal_integrity")
    if not isinstance(causal, dict):
        raise KernelViolation(f"CAUSAL_INTEGRITY_REQUIRED:{phase}")
    for key in CAUSAL_REQUIRED:
        if causal.get(key) is not True:
            raise KernelViolation(f"CAUSAL_INTEGRITY_REQUIRED:{key}")
    for key in (
        "governing_route_basis",
        "non_governing_route_review",
        "joint_materialization_basis",
        "upper_path_separation_basis",
    ):
        if len(str(causal.get(key, "")).strip()) < 30:
            raise KernelViolation(f"CAUSAL_BASIS_REQUIRED:{key}")
    if phase in {"D1", "D2", "F10"}:
        if causal.get("pruning_requires_what_changed") is not True:
            raise KernelViolation("PRUNING_WHAT_CHANGED_REQUIRED")
        if not isinstance(causal.get("what_changed_log"), list) or not causal["what_changed_log"]:
            raise KernelViolation("WHAT_CHANGED_LOG_REQUIRED")


def validate_phase_output(phase: str, output: dict[str, Any], *, require_v11_shape: bool = False) -> None:
    if not isinstance(output, dict):
        raise KernelViolation("PHASE_OUTPUT_OBJECT_REQUIRED")
    if phase in {"D1", "D2"} and has_forbidden_key(output, FORBIDDEN_D1_D2):
        raise KernelViolation(f"PRE_F10_SELECTION_AUTHORITY_VIOLATION:{phase}")
    if phase in {"F10", "F11"} and has_forbidden_key(output, FORBIDDEN_TERMINAL):
        raise KernelViolation(f"BETTING_OR_FINAL_NRFI_AUTHORITY_FORBIDDEN:{phase}")
    if require_v11_shape:
        if output.get("phase_code") != phase:
            raise KernelViolation("PHASE_CODE_REQUIRED")
        if len(str(output.get("phase_summary", "")).strip()) < 20:
            raise KernelViolation("PHASE_SUMMARY_REQUIRED")
        if not isinstance(output.get("source_ledger_refs"), list) or not output["source_ledger_refs"]:
            raise KernelViolation("SOURCE_LEDGER_REFS_REQUIRED")
        validate_causal_integrity(phase, output)
    if phase == "F10":
        raw = output.get("ADVANCED_CANDIDATE_COUNT", output.get("candidate_count"))
        if raw is None:
            raise KernelViolation("F10_CANDIDATE_COUNT_REQUIRED")
        count = int(raw)
        if not 0 <= count <= MAX_CANDIDATES:
            raise KernelViolation("F10_MAX_FOUR_VIOLATION")
        if require_v11_shape and len(output.get("candidates", [])) != count:
            raise KernelViolation("F10_CANDIDATE_ARRAY_MISMATCH")
    if phase == "F11":
        raw = output.get("CANDIDATE_COUNT", output.get("candidate_count"))
        if raw is None:
            raise KernelViolation("F11_CANDIDATE_COUNT_REQUIRED")
        count = int(raw)
        if not 0 <= count <= MAX_CANDIDATES:
            raise KernelViolation("F11_MAX_FOUR_VIOLATION")
        if str(output.get("HANDOFF_COMPLETENESS_GATE", "")).upper() != "PASS":
            raise KernelViolation("F11_HANDOFF_COMPLETENESS_GATE_REQUIRED")
        if str(output.get("PRE_DEEP_ANALYSIS_POSITION_FROZEN", "")).lower() not in {"yes", "true", "1"}:
            raise KernelViolation("F11_PRE_DEEP_FREEZE_REQUIRED")
        if require_v11_shape and len(output.get("candidate_dossiers", [])) != count:
            raise KernelViolation("F11_DOSSIER_ARRAY_MISMATCH")


@dataclass(frozen=True)
class ControlContract:
    semantic_requirement_attestations: bool = True
    e1_receipts: bool = True
    state_version: bool = True
    idempotency: bool = True
    real_drive_readback_external_only: bool = True
    old_v1_submit_revoked: bool = True
    direct_anon_rpc: bool = False
    direct_authenticated_rpc: bool = False


@dataclass(frozen=True)
class DialogueContract:
    user_mediated: bool = True
    one_authorization_per_d_response: bool = True
    auto_chain_forbidden: bool = True
    generation_proof_required: bool = True
    complete_chat_payload_required: bool = True
    d_closes_first: bool = True
    a_closes_system: bool = True
    post_turn_state: str = "STOP_WAITING_USER_AUTHORIZATION"
    d_closing_state: str = "D_DIALOGUE_PARTICIPATION_COMPLETE_STOP"


CONTROL_CONTRACT = ControlContract()
DIALOGUE_CONTRACT = DialogueContract()
