import pytest

from kernel.analista_depuracion_nrfi_d import (
    AGENT_VERSION,
    CANONICAL_SOURCE_TEXT_SHA256,
    CONTROL_CONTRACT,
    DIALOGUE_CONTRACT,
    KERNEL_VERSION,
    PHASE_ORDER,
    REQUIREMENT_COUNTS,
    SERVICE_ROLE_EDGE_ALLOWLIST,
    SOURCE_REQUIREMENTS,
    KernelViolation,
    next_phase,
    validate_causal_integrity,
    validate_phase_output,
    validate_requirement_coverage,
)


def test_version_and_canonical_source_are_v11_final():
    assert AGENT_VERSION == "ANALISTADEPURACIONRNFI-D-AGENT-1.1"
    assert KERNEL_VERSION == "ANALISTADEPURACIONRNFI-D-KERNEL-1.1.1"
    assert CANONICAL_SOURCE_TEXT_SHA256 == "c46dc9a945d37e3e53e2a6e3879045c6c7de38b25ea5f92894fded5cbaff857b"


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


def test_v11_causal_integrity_is_fail_closed():
    with pytest.raises(KernelViolation, match="CAUSAL_INTEGRITY_REQUIRED"):
        validate_causal_integrity("D1", {})
    validate_causal_integrity(
        "D1",
        {
            "causal_integrity": {
                "possible_vs_governing_separated": True,
                "non_governing_adverse_route_not_auto_veto": True,
                "joint_materialization_checked": True,
                "upper_paths_not_summed_as_central": True,
                "governing_route_basis": "The governing route is identified from current bilateral evidence and mechanism transfer.",
                "non_governing_route_review": "The adverse alternative remains documented but is not treated as an automatic veto without materialization.",
                "joint_materialization_basis": "Joint occurrence requirements are checked explicitly before combining linked adverse mechanisms.",
                "upper_path_separation_basis": "Upper-tail paths remain scenarios and are not summed into the central causal route.",
                "pruning_requires_what_changed": True,
                "what_changed_log": ["A previously plausible route lost governing status after contradictory evidence was resolved."],
            }
        },
    )


def test_service_role_surface_is_least_privilege():
    assert len(SERVICE_ROLE_EDGE_ALLOWLIST) == 6
    assert "depurnrfi_d_submit_phase" not in SERVICE_ROLE_EDGE_ALLOWLIST
    assert "depurnrfi_d_submit_command_v11" in SERVICE_ROLE_EDGE_ALLOWLIST
    assert CONTROL_CONTRACT.old_v1_submit_revoked is True
    assert CONTROL_CONTRACT.direct_anon_rpc is False
    assert CONTROL_CONTRACT.direct_authenticated_rpc is False


def test_dialogue_contract_is_manual_and_non_chaining():
    assert DIALOGUE_CONTRACT.user_mediated is True
    assert DIALOGUE_CONTRACT.one_authorization_per_d_response is True
    assert DIALOGUE_CONTRACT.auto_chain_forbidden is True
    assert DIALOGUE_CONTRACT.generation_proof_required is True
    assert DIALOGUE_CONTRACT.post_turn_state == "STOP_WAITING_USER_AUTHORIZATION"
    assert DIALOGUE_CONTRACT.d_closes_first is True
    assert DIALOGUE_CONTRACT.a_closes_system is True
