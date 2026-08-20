import unittest

from kernel.core import (
    ADAPTIVE_FAMILY_FLOOR_MATERIAL_CONTRADICTION,
    ADAPTIVE_FAMILY_FLOOR_NO_CONTRADICTION,
    ADAPTIVE_RESEARCH_DEPTH_VERSION,
    EVIDENCE_ID_KERNEL_GENERATED,
    FULL_GAME_DATA_ROLE,
    INDEPENDENT_AUDITOR_STATUS,
    KERNEL_QUERY_REQUIRED_BEFORE_RESEARCH_EVENT,
    KERNEL_VERSION,
    MOTHER_PROTOCOL_ID,
    NRFI_PRENSA_BRIDGE_STATUS,
    NUMERIC_ENGINE_STATUS,
    PROCESS_AUDITOR_ID,
    PROJECTED_CONFIRMED_ANALYSIS_SEPARATION_REQUIRED,
    REAL_MONEY_AUTHORITY,
    SEMANTIC_CUSTODY_VERSION,
    SOURCE_FAMILY_KERNEL_DERIVED,
    SPORTS_EVIDENCE_REQUIRES_KERNEL_ATTESTED_EXTRACTION,
    SYSTEM_STATE,
    TOOL_EVENT_ID_KERNEL_GENERATED,
    WHAT_WOULD_CHANGE_MUST_BE_OBSERVABLE_TIME_BOUND,
    YRFI_MATERIALIZATION_PATH_REQUIRED,
    classify_game_status,
    validate_decision,
)


class CoreRulesTest(unittest.TestCase):
    def test_mother_protocol_is_active_authority(self):
        self.assertEqual(MOTHER_PROTOCOL_ID, "NRFIMETRICA_MOTHER_V3_AUTONOMOUS")
        self.assertEqual(KERNEL_VERSION, "NRFIM-KERNEL-1.4-DETERMINISTIC-SEMANTIC-CUSTODY")
        self.assertEqual(SYSTEM_STATE, "TRADING_HALT_RESEARCH")
        self.assertEqual(NUMERIC_ENGINE_STATUS, "NO_ACTIVE_TRUSTED_ENGINE")
        self.assertEqual(INDEPENDENT_AUDITOR_STATUS, "KERNEL_PROCESS_AUDITOR_0.3_PROCESS_ONLY")
        self.assertEqual(NRFI_PRENSA_BRIDGE_STATUS, "SEPARATE_AGENT_POST_FREEZE_ONLY")
        self.assertFalse(REAL_MONEY_AUTHORITY)

    def test_semantic_custody_constants(self):
        self.assertEqual(SEMANTIC_CUSTODY_VERSION, "SEMANTIC-CUSTODY-1.0")
        self.assertEqual(PROCESS_AUDITOR_ID, "KERNEL_PROCESS_AUDITOR_0.3")
        self.assertTrue(KERNEL_QUERY_REQUIRED_BEFORE_RESEARCH_EVENT)
        self.assertTrue(SPORTS_EVIDENCE_REQUIRES_KERNEL_ATTESTED_EXTRACTION)
        self.assertTrue(EVIDENCE_ID_KERNEL_GENERATED)
        self.assertTrue(TOOL_EVENT_ID_KERNEL_GENERATED)
        self.assertTrue(SOURCE_FAMILY_KERNEL_DERIVED)

    def test_adaptive_research_is_process_control_not_fixed_legacy_floor(self):
        self.assertEqual(ADAPTIVE_RESEARCH_DEPTH_VERSION, "ADAPTIVE-CONTRADICTION-1.0")
        self.assertEqual(ADAPTIVE_FAMILY_FLOOR_NO_CONTRADICTION, 2)
        self.assertEqual(ADAPTIVE_FAMILY_FLOOR_MATERIAL_CONTRADICTION, 4)

    def test_first_inning_and_falsifiability_contract(self):
        self.assertTrue(YRFI_MATERIALIZATION_PATH_REQUIRED)
        self.assertTrue(PROJECTED_CONFIRMED_ANALYSIS_SEPARATION_REQUIRED)
        self.assertTrue(WHAT_WOULD_CHANGE_MUST_BE_OBSERVABLE_TIME_BOUND)
        self.assertEqual(FULL_GAME_DATA_ROLE, "MODIFIER_WITH_EXPLICIT_FIRST_INNING_LINK_ONLY")

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
