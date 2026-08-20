import unittest

from kernel.analistaa_nrfi import (
    AnalistaaNRFIViolation,
    AGENT_VERSION,
    KERNEL_VERSION,
    validate_a2_a3,
    validate_a4,
    validate_a5,
    validate_a6,
    validate_a8,
    validate_a9_game_packet,
    validate_a9_outputs,
    validate_finalization,
    validate_phase_order,
)


class AnalistaaNRFIKernelTests(unittest.TestCase):
    def test_versions(self):
        self.assertEqual(AGENT_VERSION, "ANALISTAANRFI-AGENT-2.2")
        self.assertEqual(KERNEL_VERSION, "MLB-V2-KERNEL-0.3-HARDENED")

    def test_phase_order_blocks_skip(self):
        with self.assertRaisesRegex(AnalistaaNRFIViolation, "PHASE_PREREQUISITES_INCOMPLETE"):
            validate_phase_order({"A1"}, "A3")

    def test_a2_premature_verdict(self):
        output = {
            "away_starter_causal_packet": {}, "current_version": {}, "three_out_architecture": {},
            "traffic_architecture": {}, "material_failure_routes": [{}], "best_supported_rival": {},
            "second_analytical_pass": {}, "sports_state": "NRFI_STRONG",
        }
        with self.assertRaisesRegex(AnalistaaNRFIViolation, "A2_PREMATURE_VERDICT"):
            validate_a2_a3("A2", output)

    @staticmethod
    def top_output():
        return {
            "top_half_causal_packet": {"ok": True}, "b1_b5": [1, 2, 3, 4, 5],
            "material_run_routes": [{"route": "BB->XBH"}], "best_supported_rival": {"case": "YRFI"},
            "positive_containment_case": {"case": "NRFI"}, "red_team_result": {"result": "PASS"},
            "second_analytical_pass": {"ok": True},
            "top_half_seal": {
                "game_id": "G", "run_id": "R", "lineup_version": "V1", "starter_version": "V1",
                "evidence_as_of": "T", "evidence_hash": "E", "causal_packet_hash": "C",
                "top_half_status": "TOP_HALF_PASS", "material_route_open": False,
                "contradiction_open": False, "red_team_pass": True, "seal_state": "FINAL",
            },
        }

    @staticmethod
    def bottom_output():
        return {
            "bottom_half_causal_packet": {"ok": True}, "b1_b5": [1, 2, 3, 4, 5],
            "material_run_routes": [{"route": "BB->HR"}], "best_supported_rival": {"case": "YRFI"},
            "positive_containment_case": {"case": "NRFI"}, "red_team_result": {"result": "PASS"},
            "second_analytical_pass": {"ok": True},
            "bottom_half_seal": {
                "game_id": "G", "run_id": "R", "lineup_version": "V1", "starter_version": "V1",
                "evidence_as_of": "T", "evidence_hash": "E", "causal_packet_hash": "C",
                "bottom_half_status": "BOTTOM_HALF_PASS", "material_route_open": False,
                "material_contradiction_open": False, "red_team_result": "PASS", "seal_state": "FINAL",
            },
        }

    def test_a4_b1_b5_exactly_five(self):
        output = self.top_output(); output["b1_b5"] = [1, 2, 3, 4]
        with self.assertRaisesRegex(AnalistaaNRFIViolation, "A4_B1_B5_EXACTLY_5"):
            validate_a4(output, "R", "G")

    def test_a4_material_open_blocks_pass(self):
        output = self.top_output(); output["top_half_seal"]["material_route_open"] = True
        with self.assertRaisesRegex(AnalistaaNRFIViolation, "A4_PASS_ILLEGAL_OPEN_ROUTE"):
            validate_a4(output, "R", "G")

    def test_a5_contradiction_blocks_pass(self):
        output = self.bottom_output(); output["bottom_half_seal"]["material_contradiction_open"] = True
        with self.assertRaisesRegex(AnalistaaNRFIViolation, "A5_PASS_ILLEGAL_OPEN_ROUTE"):
            validate_a5(output, "R", "G")

    def test_a6_material_change_requires_reopen(self):
        output = {
            "context_packet": {}, "context_delta": {"material_change": True},
            "revalidation": {"selective_reopen_performed": False}, "top_half_seal_v2": {},
            "bottom_half_seal_v2": {}, "second_contextual_pass": {}, "red_team_contextual": {},
        }
        with self.assertRaisesRegex(AnalistaaNRFIViolation, "A6_MATERIAL_CHANGE_REQUIRES_SELECTIVE_REOPEN"):
            validate_a6(output)

    def test_a8_market_firewall(self):
        output = {
            "a8_final_sports_packet": {}, "sports_state": "NRFI_STRONG", "top_state": "PASS",
            "bottom_state": "PASS", "what_really_governs": "causal", "best_argument_for_nrfi": "case",
            "best_argument_against_nrfi": "rival", "governing_uncertainty": "bounded",
            "sports_analysis_frozen": True, "sportsbook": "forbidden",
        }
        with self.assertRaisesRegex(AnalistaaNRFIViolation, "A8_MARKET_OR_NUMERIC_FIELD_FORBIDDEN"):
            validate_a8(output)

    def test_a8_freeze_required(self):
        output = {
            "a8_final_sports_packet": {}, "sports_state": "NRFI_STRONG", "top_state": "PASS",
            "bottom_state": "PASS", "what_really_governs": "causal", "best_argument_for_nrfi": "case",
            "best_argument_against_nrfi": "rival", "governing_uncertainty": "bounded",
            "sports_analysis_frozen": False,
        }
        with self.assertRaisesRegex(AnalistaaNRFIViolation, "A8_FREEZE_REQUIRED"):
            validate_a8(output)

    def test_a9_cannot_rewrite_a8(self):
        packet = {"analyst_run_id": "R", "game_id": "G", "sports_state": "NRFI_PLAYABLE", "sports_freeze_hash": "H", "betting_verdict": "NO_BET"}
        with self.assertRaisesRegex(AnalistaaNRFIViolation, "A9_CANNOT_REWRITE_A8"):
            validate_a9_game_packet(packet, "NRFI_STRONG", "H")

    def test_a9_numeric_firewall(self):
        packet = {"analyst_run_id": "R", "game_id": "G", "sports_state": "NRFI_STRONG", "sports_freeze_hash": "H", "betting_verdict": "NO_BET", "p_nrfi": 0.70}
        with self.assertRaisesRegex(AnalistaaNRFIViolation, "A9_UNCERTIFIED_NUMERIC"):
            validate_a9_game_packet(packet, "NRFI_STRONG", "H")

    def test_a9_zero_no_fabrication(self):
        with self.assertRaisesRegex(AnalistaaNRFIViolation, "A9_ZERO_AVAILABLE_NO_FABRICATION"):
            validate_a9_outputs(game_packets=[{}], eligible_count=1, qualified_bets_count=0, recommendations=[{"fake": True}])

    def test_final_readback_required(self):
        with self.assertRaisesRegex(AnalistaaNRFIViolation, "FINAL_MASTER_REPORT_READBACK_REQUIRED"):
            validate_finalization(master_report_readback=False, a9_terminal=True, drive_report_complete=True, chat_report_complete=True, report_verdict_hash="H", chat_verdict_hash="H", pending_games=0)

    def test_final_drive_chat_match(self):
        with self.assertRaisesRegex(AnalistaaNRFIViolation, "FINAL_DRIVE_CHAT_VERDICT_MISMATCH"):
            validate_finalization(master_report_readback=True, a9_terminal=True, drive_report_complete=True, chat_report_complete=True, report_verdict_hash="A", chat_verdict_hash="B", pending_games=0)


if __name__ == "__main__":
    unittest.main()
