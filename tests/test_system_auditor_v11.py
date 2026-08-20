import pytest

from kernel import system_auditor as auditor


def valid_identity(**overrides):
    data = {
        "requested_reference": "the analysis just requested by the user",
        "requested_agent": "@NRFImetrica",
        "resolved_agent": "@NRFImetrica",
        "target_run_id": "RUN-123",
        "target_scope": "RUN",
        "target_report_locator": "DRIVE-REPORT-123",
        "target_match_basis": "physical RUN id, report id and timestamps reconcile",
    }
    data.update(overrides)
    return data


def test_menu_contains_four_current_adapters():
    assert auditor.TARGET_MENU["1"] == "@NRFiPrensa"
    assert auditor.TARGET_MENU["2"] == "@NRFImetrica"
    assert auditor.TARGET_MENU["3"] == "@DepuracionMLB"
    assert auditor.TARGET_MENU["4"] == "@investigacionNRFI"


def test_p1_cannot_advance_without_target_lock():
    assert auditor.may_advance_to_layer("P0", "UNRESOLVED") is True
    assert auditor.may_advance_to_layer("P1", "UNRESOLVED") is False
    assert auditor.may_advance_to_layer("P12", "AMBIGUOUS") is False
    assert auditor.may_advance_to_layer("P1", "CONFIRMED") is True


def test_wrong_agent_invalidates_target_lock():
    with pytest.raises(ValueError, match="REQUESTED_AGENT_MISMATCH"):
        auditor.validate_target_lock(
            target_system="@NRFImetrica",
            target_run_id="RUN-123",
            target_lock_status="CONFIRMED",
            target_identity=valid_identity(requested_agent="@NRFiPrensa"),
            target_match_reason="The physical identifiers deliberately conflict to test the wrong-target gate.",
        )


def test_ambiguity_forbids_confirmed_target():
    with pytest.raises(ValueError, match="CONFIRMED_TARGET_HAS_AMBIGUITY"):
        auditor.validate_target_lock(
            target_system="@NRFImetrica",
            target_run_id="RUN-123",
            target_lock_status="CONFIRMED",
            target_identity=valid_identity(),
            target_ambiguity=["RUN-123", "RUN-124"],
            target_match_reason="Two materially plausible runs remain and therefore the auditor must not guess.",
        )


def test_valid_target_lock_passes():
    assert auditor.validate_target_lock(
        target_system="@NRFImetrica",
        target_run_id="RUN-123",
        target_lock_status="CONFIRMED",
        target_identity=valid_identity(),
        target_match_reason="The requested agent, physical RUN, report locator and timestamps all reconcile exactly.",
    )


def test_game_scope_requires_game_id():
    with pytest.raises(ValueError, match="GAME_SCOPE_REQUIRES_GAME_ID"):
        auditor.validate_target_lock(
            target_system="@NRFImetrica",
            target_run_id="RUN-123",
            target_lock_status="CONFIRMED",
            target_identity=valid_identity(target_scope="GAME"),
            target_match_reason="The user asked for one game but no physical game identifier was resolved for the target.",
        )


def test_chat_report_requires_all_forensic_sections_and_depth():
    sections = {key: {} for key in auditor.FORENSIC_CHAT_REQUIRED_SECTIONS}
    report = "Detailed forensic audit narrative. " * 60
    assert auditor.validate_forensic_chat_report(report, sections)
    sections.pop("propagation_map")
    with pytest.raises(ValueError, match="MISSING"):
        auditor.validate_forensic_chat_report(report, sections)


def test_major_finding_requires_existing_authority_rule_and_retest():
    assert auditor.validate_finding(
        authority_rule_ref="Mandato F7-R / Red Team",
        failure_mode="PARTIALLY_EXECUTED",
        severity="MAJOR",
        required_correction="Reexecute F7-R exactly with the mandatory objects required by that rule.",
        retest_requirement="Verify the new F7-R object against every mandatory field in the same authority.",
    )


def test_replay_is_strictly_read_only():
    assert auditor.forensic_replay_allowed(target_write_performed=False, data_cutoff_present=True)
    assert not auditor.forensic_replay_allowed(target_write_performed=True, data_cutoff_present=True)
    assert not auditor.forensic_replay_allowed(target_write_performed=False, data_cutoff_present=False)
    assert auditor.may_write_target() is False
    assert auditor.may_redesign_target() is False
