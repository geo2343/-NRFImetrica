import unittest

from kernel.core import classify_game_status, validate_decision


class CoreRulesTest(unittest.TestCase):
    def test_started_game_is_audit_only(self):
        self.assertEqual(classify_game_status("Live", "In Progress"), "AUDIT_ONLY")
        self.assertEqual(classify_game_status("Final", "Final"), "AUDIT_ONLY")

    def test_postponed_game_is_local_block(self):
        self.assertEqual(classify_game_status("Preview", "Postponed"), "LOCAL_DATA_BLOCK")

    def test_numeric_probability_is_blocked_without_engine(self):
        with self.assertRaisesRegex(ValueError, "NUMERIC_ENGINE_NOT_INTEGRATED"):
            validate_decision(
                decision="NRFI_CANDIDATE",
                central_nrfi_case={"case": "x"},
                best_yrfi_rival={"case": "y"},
                decisive_factor="material",
                materiality="high",
                what_would_change="starter scratched",
                numeric_status="EXECUTED",
                raw_p_nrfi=0.62,
                model_version="m1",
                calibration_status="CERTIFIED",
            )

    def test_rejection_requires_full_burden(self):
        with self.assertRaisesRegex(ValueError, "COMPETITIVE_DECISION_MISSING"):
            validate_decision(
                decision="NRFI_REJECTED",
                central_nrfi_case={},
                best_yrfi_rival={},
                decisive_factor="",
                materiality="",
                what_would_change="",
                numeric_status="NOT_EXECUTED",
                raw_p_nrfi=None,
                model_version="NOT_INTEGRATED",
                calibration_status="NOT_CERTIFIED",
            )

    def test_rejection_with_burden_is_valid(self):
        validate_decision(
            decision="NRFI_REJECTED",
            central_nrfi_case={"pro": ["starter command"]},
            best_yrfi_rival={"contra": ["top-order damage"]},
            decisive_factor="YRFI mechanism is materially stronger",
            materiality="Direct first-inning run mechanism",
            what_would_change="Confirmed lineup removes the top-order damage cluster",
            numeric_status="NOT_EXECUTED",
            raw_p_nrfi=None,
            model_version="NOT_INTEGRATED",
            calibration_status="NOT_CERTIFIED",
        )

    def test_research_only_cannot_be_empty_escape(self):
        with self.assertRaisesRegex(ValueError, "NONCOMPETITIVE_EXIT_MISSING"):
            validate_decision(
                decision="RESEARCH_ONLY_DATA",
                central_nrfi_case={},
                best_yrfi_rival={},
                decisive_factor="",
                materiality="",
                what_would_change="",
                numeric_status="NOT_EXECUTED",
                raw_p_nrfi=None,
                model_version="NOT_INTEGRATED",
                calibration_status="NOT_CERTIFIED",
            )

    def test_research_only_with_specific_burden_is_valid_at_core_layer(self):
        validate_decision(
            decision="RESEARCH_ONLY_DATA",
            central_nrfi_case={},
            best_yrfi_rival={},
            decisive_factor="Confirmed lineup remains unavailable after material recheck",
            materiality="Top-order identities govern the platoon and damage route",
            what_would_change="Confirmed lineup becomes available before cutoff",
            numeric_status="NOT_EXECUTED",
            raw_p_nrfi=None,
            model_version="NOT_INTEGRATED",
            calibration_status="NOT_CERTIFIED",
        )


if __name__ == "__main__":
    unittest.main()
