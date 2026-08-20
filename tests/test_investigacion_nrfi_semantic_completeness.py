import unittest

from kernel.investigacion_nrfi import (
    REPORT_CONTRACT_VERSION,
    InvestigacionNRFIProtocolViolation,
    validate_evidence_packet,
    validate_feature_contract,
    validate_full_slate_ledger,
    validate_report_contract,
    validate_semantic_snapshot,
)


def _feature(family: str, window: str = "GAME"):
    return {"feature_family": family, "feature_window": window}


def _markers():
    return {
        k: True
        for k in (
            "DAILY_HEADER",
            "EXECUTION_SUMMARY",
            "SLATE_LEDGER",
            "SLATE_STATISTICAL_SUMMARY",
            "F1_F5_SYNTHESIS",
            "GAME_BLOCKS",
            "CROSS_GAME_FINDINGS",
            "DATA_GAPS_AND_LIMITATIONS",
            "SOURCE_AND_EVIDENCE_LEDGER",
            "AUDIT_TRAIL",
            "DAILY_CLOSURE",
        )
    }


class InvestigacionNRFISemanticCompletenessTests(unittest.TestCase):
    def test_feature_contract_requires_every_family_and_sequence_window(self):
        features = [
            _feature("RESULTS"), _feature("EXPOSURE"), _feature("OUT_CREATION"),
            _feature("TRAFFIC"), _feature("DAMAGE"), _feature("PITCHER_PROCESS"),
            _feature("TOP_ORDER"), _feature("CONTEXT"),
        ]
        features += [_feature("SEQUENCE", w) for w in ("L3", "L5", "L10", "L15", "SEASON", "CAREER")]
        with self.assertRaisesRegex(InvestigacionNRFIProtocolViolation, "FEATURE_CONTRACT_INCOMPLETE"):
            validate_feature_contract(features)

    def test_feature_contract_passes_all_nine_families_and_seven_windows(self):
        features = [
            _feature("RESULTS"), _feature("EXPOSURE"), _feature("OUT_CREATION"),
            _feature("TRAFFIC"), _feature("DAMAGE"), _feature("PITCHER_PROCESS"),
            _feature("TOP_ORDER"), _feature("CONTEXT"),
        ]
        features += [_feature("SEQUENCE", w) for w in ("L3", "L5", "L10", "L15", "L20", "SEASON", "CAREER")]
        validate_feature_contract(features)

    def test_evidence_packet_cannot_be_summary_only(self):
        with self.assertRaisesRegex(InvestigacionNRFIProtocolViolation, "EVIDENCE_PACKET_REQUIRED_KEYS_MISSING"):
            validate_evidence_packet({"PITCHER_HISTORY": {}, "EVENT_PATHS": {}})

    def test_full_slate_cannot_silently_omit_a_game(self):
        with self.assertRaisesRegex(InvestigacionNRFIProtocolViolation, "OFFICIAL_SLATE_LEDGER_COUNT_MISMATCH"):
            validate_full_slate_ledger(
                official_slate_count=15,
                ledger_count=14,
                pending_count=0,
                nonfinal_unexcluded_count=0,
            )

    def test_full_slate_cannot_close_with_pending_game(self):
        with self.assertRaisesRegex(InvestigacionNRFIProtocolViolation, "DAILY_SLATE_HAS_PENDING_GAMES"):
            validate_full_slate_ledger(
                official_slate_count=15,
                ledger_count=15,
                pending_count=1,
                nonfinal_unexcluded_count=1,
            )

    def test_semantic_snapshot_false_or_incomplete_slate_cannot_close(self):
        snapshot = {
            "official_slate_count": 15,
            "slate_complete": False,
            "f1_pass": True,
            "f2_pass": True,
            "f3_pass": True,
            "f4_pass": True,
            "f5_pass": True,
            "report_contract_pass": True,
            "pass": False,
        }
        with self.assertRaisesRegex(InvestigacionNRFIProtocolViolation, "FULL_SLATE_NOT_COMPLETE"):
            validate_semantic_snapshot(snapshot)

    def test_report_contract_blocks_missing_slate_row_or_game_block(self):
        markers = _markers()
        with self.assertRaisesRegex(InvestigacionNRFIProtocolViolation, "REPORT_SLATE_LEDGER_COUNT_MISMATCH"):
            validate_report_contract(
                official_slate_count=15,
                nonexcluded_games=15,
                excluded_games=0,
                slate_row_count=14,
                excluded_game_summary_count=0,
                game_block_count=15,
                phase_section_count=5,
                daily_block_character_count=50000,
                markers=markers,
                report_contract_verified=True,
                delivery_contract_version=REPORT_CONTRACT_VERSION,
            )
        with self.assertRaisesRegex(InvestigacionNRFIProtocolViolation, "REPORT_GAME_BLOCK_COUNT_MISMATCH"):
            validate_report_contract(
                official_slate_count=15,
                nonexcluded_games=15,
                excluded_games=0,
                slate_row_count=15,
                excluded_game_summary_count=0,
                game_block_count=14,
                phase_section_count=5,
                daily_block_character_count=50000,
                markers=markers,
                report_contract_verified=True,
                delivery_contract_version=REPORT_CONTRACT_VERSION,
            )

    def test_report_contract_blocks_short_or_disorganized_report(self):
        with self.assertRaisesRegex(InvestigacionNRFIProtocolViolation, "REPORT_BLOCK_ANTI_EMPTY_FLOOR_FAIL"):
            validate_report_contract(
                official_slate_count=15,
                nonexcluded_games=15,
                excluded_games=0,
                slate_row_count=15,
                excluded_game_summary_count=0,
                game_block_count=15,
                phase_section_count=5,
                daily_block_character_count=30000,
                markers=_markers(),
                report_contract_verified=True,
                delivery_contract_version=REPORT_CONTRACT_VERSION,
            )
        bad_markers = _markers()
        bad_markers["SLATE_LEDGER"] = False
        with self.assertRaisesRegex(InvestigacionNRFIProtocolViolation, "REPORT_REQUIRED_MARKERS_MISSING"):
            validate_report_contract(
                official_slate_count=15,
                nonexcluded_games=15,
                excluded_games=0,
                slate_row_count=15,
                excluded_game_summary_count=0,
                game_block_count=15,
                phase_section_count=5,
                daily_block_character_count=50000,
                markers=bad_markers,
                report_contract_verified=True,
                delivery_contract_version=REPORT_CONTRACT_VERSION,
            )


if __name__ == "__main__":
    unittest.main()
