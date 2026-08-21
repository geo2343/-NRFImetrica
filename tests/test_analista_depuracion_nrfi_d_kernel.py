import pytest

from kernel.analista_depuracion_nrfi_d import (
    DIALOGUE_CONTRACT,
    PHASE_ORDER,
    REQUIREMENT_COUNTS,
    SOURCE_REQUIREMENTS,
    KernelViolation,
    next_phase,
    validate_phase_output,
    validate_requirement_coverage,
)


def test_requirement_total_matches_canonical_source():
    assert sum(REQUIREMENT_COUNTS[p] for p in PHASE_ORDER) == SOURCE_REQUIREMENTS
    assert SOURCE_REQUIREMENTS == 1057


def test_d_layers_are_mandatory_before_f10():
    assert next_phase("F9") == "D1"
    assert next_phase("D1") == "D2"
    assert next_phase("D2") == "F10"


def test_d1_cannot_select_candidates():
    with pytest.raises(KernelViolation, match="PRE_F10_SELECTION_AUTHORITY_VIOLATION"):
        validate_phase_output("D1", {"candidate": "GAME-X"})


def test_d2_cannot_select_candidates_nested():
    with pytest.raises(KernelViolation, match="PRE_F10_SELECTION_AUTHORITY_VIOLATION"):
        validate_phase_output("D2", {"audit": {"advances_to_deep_analysis": True}})


def test_f10_enforces_max_four():
    with pytest.raises(KernelViolation, match="F10_MAX_FOUR_VIOLATION"):
        validate_phase_output("F10", {"ADVANCED_CANDIDATE_COUNT": 5})
    validate_phase_output("F10", {"ADVANCED_CANDIDATE_COUNT": 4})


def test_f11_is_handoff_not_bet():
    with pytest.raises(KernelViolation, match="BETTING_OR_FINAL_NRFI_AUTHORITY_FORBIDDEN"):
        validate_phase_output(
            "F11",
            {
                "CANDIDATE_COUNT": 2,
                "HANDOFF_COMPLETENESS_GATE": "PASS",
                "PRE_DEEP_ANALYSIS_POSITION_FROZEN": "YES",
                "bet": "NRFI",
            },
        )


def test_f11_requires_completeness_and_freeze():
    with pytest.raises(KernelViolation, match="F11_HANDOFF_COMPLETENESS_GATE_REQUIRED"):
        validate_phase_output("F11", {"CANDIDATE_COUNT": 2})
    validate_phase_output(
        "F11",
        {
            "CANDIDATE_COUNT": 2,
            "HANDOFF_COMPLETENESS_GATE": "PASS",
            "PRE_DEEP_ANALYSIS_POSITION_FROZEN": "YES",
        },
    )


def test_requirement_coverage_is_exact():
    ids = [f"R{i}" for i in range(REQUIREMENT_COUNTS["F1"])]
    validate_requirement_coverage("F1", ids)
    with pytest.raises(KernelViolation, match="REQUIREMENT_COVERAGE_FAIL"):
        validate_requirement_coverage("F1", ids[:-1])


def test_dialogue_contract_is_manual_and_non_chaining():
    assert DIALOGUE_CONTRACT.user_mediated is True
    assert DIALOGUE_CONTRACT.one_authorization_per_d_response is True
    assert DIALOGUE_CONTRACT.auto_chain_forbidden is True
    assert DIALOGUE_CONTRACT.post_turn_state == "STOP_WAITING_USER_AUTHORIZATION"
    assert DIALOGUE_CONTRACT.d_closes_first is True
    assert DIALOGUE_CONTRACT.a_closes_system is True
