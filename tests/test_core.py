import unittest

from kernel.core import (
    AGENT_VERSION,
    INDEPENDENT_AUDITOR_STATUS,
    KERNEL_VERSION,
    MOTHER_PROTOCOL_ID,
    NUMERIC_ENGINE_STATUS,
    REAL_MONEY_AUTHORITY,
    RUNTIME_PLATFORM,
    SYSTEM_STATE,
    classify_game_status,
    validate_decision,
)


class CoreRulesTest(unittest.TestCase):
    def test_mother_protocol_is_active_authority(self):
        self.assertEqual(MOTHER_PROTOCOL_ID, "NRFIMETRICA_MOTHER_V3_AUTONOMOUS")
        self.assertEqual(AGENT_VERSION, "MOTHER-V3-AGENT-1.14")
        self.assertEqual(KERNEL_VERSION, "NRFIM-KERNEL-1.8.1-SUPABASE-EDGE-RUNTIME")
        self.assertEqual(SYSTEM_STATE, "ACTIVE_RESEARCH_ECONOMIC_FIREWALL")
        self.assertEqual(RUNTIME_PLATFORM, "SUPABASE_EDGE_FUNCTIONS")
        self.assertEqual(NUMERIC_ENGINE_STATUS, "NO_ACTIVE_TRUSTED_GAME_SPECIFIC_ENGINE")
        self.assertEqual(INDEPENDENT_AUDITOR_STATUS, "NO_ACTIVE_TRUSTED_AUDITOR")
        self.assertFalse(REAL_MONEY_AUTHORITY)

    def test_started_game_is_audit_only(self):
        self.assertEqual(classify_game_status("Live", "In Progress"), "AUDIT_ONLY")
        self.assertEqual(classify_game_status("Final", "Final"), "AUDIT_ONLY")

    def test_postponed_game_is_local_block(self):
        self.assertEqual(classify_game_status("Preview", "Postponed"), "LOCAL_DATA_BLOCK")

    def test_legacy_competitive_decision_endpoint_is_superseded(self):
        with self.assertRaisesRegex(ValueError, "LEGACY_DECISION_ENDPOINT_SUPERSEDED_BY_MOTHER_A1_A8"):
            validate_decision(
                decision="NRFI_CANDIDATE",
                central_nrfi_case={"case": "x"},
                best_yrfi_rival={"case": "y"},
                decisive_factor="material",
                materiality="high",
                what_would_change="starter scratched",
                numeric_status="NOT_EXECUTED",
                raw_p_nrfi=None,
                model_version="NOT_INTEGRATED",
                calibration_status="NOT_CERTIFIED",
            )

    def test_legacy_audit_only_remains_available_for_started_games(self):
        validate_decision(
            decision="AUDIT_ONLY",
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

    def test_legacy_audit_only_cannot_carry_probability(self):
        with self.assertRaisesRegex(ValueError, "LEGACY_DECISION_CANNOT_CARRY_PROBABILITY"):
            validate_decision(
                decision="AUDIT_ONLY",
                central_nrfi_case={},
                best_yrfi_rival={},
                decisive_factor="",
                materiality="",
                what_would_change="",
                numeric_status="EXECUTED",
                raw_p_nrfi=.60,
                model_version="NOT_INTEGRATED",
                calibration_status="NOT_CERTIFIED",
            )


if __name__ == "__main__":
    unittest.main()
