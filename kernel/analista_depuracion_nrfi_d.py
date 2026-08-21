from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Iterable

AGENT_ID = "@AnalistaDepuracionRNFI_D"
AGENT_VERSION = "ANALISTADEPURACIONRNFI-D-AGENT-1.0"
KERNEL_VERSION = "ANALISTADEPURACIONRNFI-D-KERNEL-1.0"
SOURCE_SHA256 = "121f80c4569de1f87c438f96fbd48364a1756afee17a38f3f1f33698a67caea9"
SOURCE_REQUIREMENTS = 1057
MAX_CANDIDATES = 4

PHASE_ORDER = (
    "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9",
    "D1", "D2", "F10", "F11", "REPORT_D",
)

REQUIREMENT_COUNTS = {
    "F1": 27, "F2": 69, "F3": 80, "F4": 124, "F5": 145,
    "F6": 144, "F7": 152, "F8": 85, "F9": 93,
    "D1": 19, "D2": 20, "F10": 54, "F11": 45, "REPORT_D": 0,
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


def validate_requirement_coverage(phase: str, requirement_ids: list[str]) -> None:
    expected = REQUIREMENT_COUNTS[phase]
    if len(requirement_ids) != expected or len(set(requirement_ids)) != expected:
        raise KernelViolation(
            f"REQUIREMENT_COVERAGE_FAIL:{phase}:expected={expected}:got={len(requirement_ids)}"
        )


def validate_phase_output(phase: str, output: dict[str, Any]) -> None:
    if not isinstance(output, dict):
        raise KernelViolation("PHASE_OUTPUT_OBJECT_REQUIRED")

    if phase in {"D1", "D2"} and has_forbidden_key(output, FORBIDDEN_D1_D2):
        raise KernelViolation(f"PRE_F10_SELECTION_AUTHORITY_VIOLATION:{phase}")

    if phase in {"F10", "F11"} and has_forbidden_key(output, FORBIDDEN_TERMINAL):
        raise KernelViolation(f"BETTING_OR_FINAL_NRFI_AUTHORITY_FORBIDDEN:{phase}")

    if phase == "F10":
        raw = output.get("ADVANCED_CANDIDATE_COUNT", output.get("candidate_count"))
        if raw is None:
            raise KernelViolation("F10_CANDIDATE_COUNT_REQUIRED")
        count = int(raw)
        if count < 0 or count > MAX_CANDIDATES:
            raise KernelViolation("F10_MAX_FOUR_VIOLATION")

    if phase == "F11":
        raw = output.get("CANDIDATE_COUNT", output.get("candidate_count"))
        if raw is None:
            raise KernelViolation("F11_CANDIDATE_COUNT_REQUIRED")
        count = int(raw)
        if count < 0 or count > MAX_CANDIDATES:
            raise KernelViolation("F11_MAX_FOUR_VIOLATION")
        if str(output.get("HANDOFF_COMPLETENESS_GATE", output.get("handoff_completeness_gate", ""))).upper() != "PASS":
            raise KernelViolation("F11_HANDOFF_COMPLETENESS_GATE_REQUIRED")
        frozen = str(output.get("PRE_DEEP_ANALYSIS_POSITION_FROZEN", output.get("pre_deep_analysis_position_frozen", ""))).lower()
        if frozen not in {"yes", "true", "1"}:
            raise KernelViolation("F11_PRE_DEEP_FREEZE_REQUIRED")


@dataclass(frozen=True)
class DialogueContract:
    user_mediated: bool = True
    one_authorization_per_d_response: bool = True
    auto_chain_forbidden: bool = True
    complete_chat_payload_required: bool = True
    d_closes_first: bool = True
    a_closes_system: bool = True
    post_turn_state: str = "STOP_WAITING_USER_AUTHORIZATION"
    d_closing_state: str = "D_DIALOGUE_PARTICIPATION_COMPLETE_STOP"


DIALOGUE_CONTRACT = DialogueContract()
