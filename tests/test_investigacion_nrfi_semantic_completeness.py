import pytest

from kernel.investigacion_nrfi import (
    InvestigacionNRFIProtocolViolation,
    validate_evidence_packet,
    validate_feature_contract,
    validate_report_contract,
    validate_semantic_snapshot,
)


def _feature(family: str, window: str = "GAME"):
    return {"feature_family": family, "feature_window": window}


def test_feature_contract_requires_every_family_and_sequence_window():
    features = [
        _feature("RESULTS"),
        _feature("EXPOSURE"),
        _feature("OUT_CREATION"),
        _feature("TRAFFIC"),
        _feature("DAMAGE"),
        _feature("PITCHER_PROCESS"),
        _feature("TOP_ORDER"),
        _feature("CONTEXT"),
    ]
    features += [_feature("SEQUENCE", w) for w in ("L3", "L5", "L10", "L15", "SEASON", "CAREER")]
    with pytest.raises(InvestigacionNRFIProtocolViolation, match="FEATURE_CONTRACT_INCOMPLETE"):
        validate_feature_contract(features)


def test_feature_contract_passes_all_nine_families_and_seven_windows():
    features = [
        _feature("RESULTS"), _feature("EXPOSURE"), _feature("OUT_CREATION"),
        _feature("TRAFFIC"), _feature("DAMAGE"), _feature("PITCHER_PROCESS"),
        _feature("TOP_ORDER"), _feature("CONTEXT"),
    ]
    features += [_feature("SEQUENCE", w) for w in ("L3", "L5", "L10", "L15", "L20", "SEASON", "CAREER")]
    validate_feature_contract(features)


def test_evidence_packet_cannot_be_summary_only():
    with pytest.raises(InvestigacionNRFIProtocolViolation, match="EVIDENCE_PACKET_REQUIRED_KEYS_MISSING"):
        validate_evidence_packet({"PITCHER_HISTORY": {}, "EVENT_PATHS": {}})


def test_semantic_snapshot_false_cannot_close():
    snapshot = {
        "f1_pass": True,
        "f2_pass": False,
        "f3_pass": True,
        "f4_pass": True,
        "f5_pass": True,
        "report_contract_pass": True,
        "pass": False,
    }
    with pytest.raises(InvestigacionNRFIProtocolViolation, match="SEMANTIC_COMPLETENESS_FAIL"):
        validate_semantic_snapshot(snapshot)


def test_report_contract_blocks_short_or_missing_game_blocks():
    markers = {k: True for k in ("EXECUTION_SUMMARY", "F1", "F2", "F3", "F4", "F5", "DAILY_CLOSURE", "GAME_BLOCKS")}
    with pytest.raises(InvestigacionNRFIProtocolViolation, match="REPORT_GAME_BLOCK_COUNT_MISMATCH"):
        validate_report_contract(
            nonexcluded_games=15,
            game_block_count=14,
            phase_section_count=5,
            daily_block_character_count=40000,
            markers=markers,
            report_contract_verified=True,
        )
    with pytest.raises(InvestigacionNRFIProtocolViolation, match="REPORT_BLOCK_ANTI_EMPTY_FLOOR_FAIL"):
        validate_report_contract(
            nonexcluded_games=15,
            game_block_count=15,
            phase_section_count=5,
            daily_block_character_count=10000,
            markers=markers,
            report_contract_verified=True,
        )
