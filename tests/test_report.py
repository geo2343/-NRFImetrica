import unittest

from kernel.report import ReportViolation, validate_final_report


class FinalReportGateTest(unittest.TestCase):
    def setUp(self):
        self.games = [
            {"game_id": "G1", "status": "READY"},
            {"game_id": "G2", "status": "READY"},
            {"game_id": "G3", "status": "AUDIT_ONLY"},
        ]
        self.decisions = [
            {
                "game_id": "G1",
                "decision": "NRFI_CANDIDATE",
                "raw_p_nrfi": None,
                "calibration_status": "NOT_CERTIFIED",
            },
            {
                "game_id": "G2",
                "decision": "NRFI_REJECTED",
                "raw_p_nrfi": None,
                "calibration_status": "NOT_CERTIFIED",
            },
        ]
        self.recoveries = [{"issue_id": "I1"}]

    def valid_report(self):
        return {
            "summary": {
                "total_games": 3,
                "processed": 3,
                "audit_only": 1,
                "candidates": 1,
                "rejected": 1,
                "research_only": 0,
                "local_failures": 0,
                "recoveries": 1,
            },
            "ranking_nrfi": [{
                "game_id": "G1",
                "decision": "NRFI_CANDIDATE",
                "independent_causal_reasons": ["mechanism A", "mechanism B"],
                "best_yrfi_rival": "power route",
                "principal_risk": "early HR",
                "what_would_change": "starter scratch",
                "detailed_verdict": "NRFI case remains stronger after rival-route comparison",
            }],
            "final_verdict": {
                "best_candidate_game_id": "G1",
                "decision": "NRFI_CANDIDATE",
                "central_reason": "strongest causal NRFI route",
                "central_risk": "power damage",
            },
        }

    def test_valid_report_passes(self):
        expected = validate_final_report(
            report=self.valid_report(),
            games=self.games,
            decisions=self.decisions,
            recoveries=self.recoveries,
        )
        self.assertEqual(expected["candidates"], 1)

    def test_wrong_summary_count_is_blocked(self):
        report = self.valid_report()
        report["summary"]["candidates"] = 0
        with self.assertRaisesRegex(ReportViolation, "SUMMARY_MISMATCH:candidates"):
            validate_final_report(report=report, games=self.games, decisions=self.decisions, recoveries=self.recoveries)

    def test_missing_real_candidate_is_blocked(self):
        report = self.valid_report()
        report["ranking_nrfi"] = []
        with self.assertRaisesRegex(ReportViolation, "RANKING_CANDIDATE_SET_MISMATCH"):
            validate_final_report(report=report, games=self.games, decisions=self.decisions, recoveries=self.recoveries)

    def test_invented_probability_is_blocked(self):
        report = self.valid_report()
        report["ranking_nrfi"][0]["p_nrfi"] = 0.68
        with self.assertRaisesRegex(ReportViolation, "UNAUTHORIZED_P_NRFI_IN_REPORT"):
            validate_final_report(report=report, games=self.games, decisions=self.decisions, recoveries=self.recoveries)

    def test_unprocessed_game_blocks_zero_candidate_claim(self):
        decisions = [self.decisions[1]]
        report = {
            "summary": {
                "total_games": 3,
                "processed": 2,
                "audit_only": 1,
                "candidates": 0,
                "rejected": 1,
                "research_only": 0,
                "local_failures": 0,
                "recoveries": 1,
            },
            "ranking_nrfi": [],
            "final_verdict": {
                "best_candidate_game_id": None,
                "decision": "ZERO_CANDIDATES",
                "central_reason": "none qualified",
                "central_risk": "incomplete slate",
            },
        }
        with self.assertRaisesRegex(ReportViolation, "RUN_INCOMPLETE:G1"):
            validate_final_report(report=report, games=self.games, decisions=decisions, recoveries=self.recoveries)


if __name__ == "__main__":
    unittest.main()
