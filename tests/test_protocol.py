import unittest

from kernel.protocol import ProtocolViolation, validate_phase_submission


def run_phase(phase_id, payload, *, output_text="", source_calls=None, evidence_ids=None):
    manifest = {"phases": [{"phase_id": phase_id, "prerequisites": [], "required_fields": []}]}
    return validate_phase_submission(
        manifest=manifest,
        phase_id=phase_id,
        completed_phase_ids=set(),
        payload=payload,
        evidence_ids=evidence_ids or [],
        source_calls=source_calls or [],
        documents_analyzed=[],
        output_text=output_text,
    )


class MotherProtocolTest(unittest.TestCase):
    def test_29_of_30_real_sources_cannot_advance(self):
        manifest = {"phases": [{
            "phase_id": "GENERIC",
            "prerequisites": [],
            "required_fields": ["analysis"],
            "min_source_calls": 30,
        }]}
        calls = [
            {"source_ref": f"source-{i}", "evidence_id": f"E-{i}", "retrieved_at": "2026-08-19T10:00:00Z"}
            for i in range(29)
        ]
        with self.assertRaisesRegex(ProtocolViolation, "MIN_SOURCE_CALLS_NOT_MET:29/30"):
            validate_phase_submission(
                manifest=manifest,
                phase_id="GENERIC",
                completed_phase_ids=set(),
                payload={"analysis": "done"},
                evidence_ids=[],
                source_calls=calls,
                documents_analyzed=[],
                output_text="",
            )

    def test_reused_evidence_does_not_fake_source_count(self):
        manifest = {"phases": [{
            "phase_id": "GENERIC",
            "prerequisites": [],
            "required_fields": [],
            "min_source_calls": 30,
        }]}
        calls = [
            {"source_ref": f"source-{i}", "evidence_id": "SAME", "retrieved_at": "2026-08-19T10:00:00Z"}
            for i in range(30)
        ]
        with self.assertRaisesRegex(ProtocolViolation, "MIN_SOURCE_CALLS_NOT_MET:1/30"):
            validate_phase_submission(
                manifest=manifest,
                phase_id="GENERIC",
                completed_phase_ids=set(),
                payload={}, evidence_ids=[], source_calls=calls,
                documents_analyzed=[], output_text="",
            )

    def test_ai_probability_is_forbidden(self):
        with self.assertRaisesRegex(ProtocolViolation, "MOTHER_DOCUMENT_FORBIDS_AI_PROBABILITY_FABRICATION"):
            run_phase("A3_CURRENT_VERSION_MATCHUP", {"ai_estimate": {"percent": 68}})

    def test_a4_probability_mass_must_equal_one(self):
        payload = {
            "numeric_engine": {"provenance_status": "PASS", "transformation_status": "PASS", "engine_mode": "BOOTSTRAP"},
            "top": {"p0": .70, "p1": .20, "p2": .05, "p3plus": .04},
            "bottom": {"p0": .70, "p1": .20, "p2": .05, "p3plus": .05},
            "mass_conservation_check": "PASS",
            "state_sanity_checks": "PASS",
        }
        with self.assertRaisesRegex(ProtocolViolation, "PROBABILITY_MASS_NOT_ONE:top"):
            run_phase("A4_NUMERIC_STATE_ENGINE", payload)

    def test_a5_contract_distribution_is_derived_not_narrated(self):
        payload = {
            "joint": {"p0": .60, "p1": .22, "p2": .10, "p3plus": .08},
            "contracts": {"p_u0_5": .60, "p_u1_5": .90, "p_u2_5": .92},
            "p_yrfi": .40,
            "same_context_realization_check": "PASS",
            "double_adjustment_check": "PASS",
            "raw_not_calibrated_check": "PASS",
            "market_blindness": "PASS",
        }
        with self.assertRaisesRegex(ProtocolViolation, "A5_U15_DERIVATION_FAIL"):
            run_phase("A5_JOINT_INTEGRATION", payload)

    def test_a6_independent_audit_cannot_be_same_analyst(self):
        payload = {
            "primary_analyst_id": "ANALYST-1",
            "independent_audit": {"auditor_id": "ANALYST-1", "status": "PASS"},
            "sra": {"packet_status": "COMPLETE"},
            "pre_press_verdict": {"frozen": True},
            "sports_seal": {"market_blindness": "PASS"},
        }
        with self.assertRaisesRegex(ProtocolViolation, "A6_INDEPENDENT_AUDIT_NOT_INDEPENDENT"):
            run_phase("A6_CAUSAL_FALSIFICATION_SPORTS_SEAL", payload, output_text="ESPERANDO RESULTADO DE NRFI-PRENSA")

    def test_sra_cannot_be_silently_omitted(self):
        payload = {
            "primary_analyst_id": "ANALYST-1",
            "independent_audit": {"auditor_id": "AUDITOR-2", "status": "PASS"},
            "sra": {"packet_status": "PENDING"},
            "pre_press_verdict": {"frozen": True},
            "sports_seal": {"market_blindness": "PASS"},
        }
        with self.assertRaisesRegex(ProtocolViolation, "SRA_GATE_NOT_EXECUTED"):
            run_phase("A6_CAUSAL_FALSIFICATION_SPORTS_SEAL", payload, output_text="ESPERANDO RESULTADO DE NRFI-PRENSA")

    def test_a7_cannot_issue_release_without_certification(self):
        payload = {
            "target_id": "U0.5",
            "release_token": "ISSUED",
            "calibration_status": "NOT_CERTIFIED",
            "calibration_region_support": "HIGH",
            "oos_validation_status": "PASS",
            "provenance_status": "PASS",
            "absolute_eligibility": "A7_ELIGIBLE",
            "nrfi_prensa": {"effect": "CONFIRM"},
            "contract_calibration": {
                "u0_5": {"status": "NOT_CERTIFIED"}
            },
        }
        with self.assertRaisesRegex(ProtocolViolation, "A7_NOT_CERTIFIED_A8_LOCKED"):
            run_phase("A7_CALIBRATION_ELIGIBILITY_PRESS", payload)

    def test_a7_release_requires_zero_run_contract_calibration(self):
        payload = {
            "target_id": "NRFI",
            "release_token": "ISSUED",
            "calibration_status": "CERTIFIED",
            "calibration_region_support": "HIGH",
            "oos_validation_status": "PASS",
            "provenance_status": "PASS",
            "absolute_eligibility": "A7_ELIGIBLE",
            "nrfi_prensa": {"effect": "CONFIRM"},
            "contract_calibration": {
                "u0_5": {"status": "NOT_CERTIFIED"}
            },
        }
        with self.assertRaisesRegex(ProtocolViolation, "A7_ZERO_RUN_CALIBRATION_REQUIRED_FOR_RELEASE"):
            run_phase("A7_CALIBRATION_ELIGIBILITY_PRESS", payload)

    def test_a8_no_bet_when_edge_and_ev_are_not_positive(self):
        payload = {
            "a7_release_token": "ISSUED",
            "a7_eligibility_status": "A7_ELIGIBLE",
            "calibration_status": "CERTIFIED",
            "probability": {"p0": .50, "p1": .25, "p2": .15, "p3plus": .10},
            "line_recommended": "NRFI",
            "market": {"break_even": .50, "p_conservative": .50, "decimal_odds": 2.0, "edge": 0.0, "ev": 0.0},
            "final_verdict": "APOSTAR",
        }
        with self.assertRaisesRegex(ProtocolViolation, "A8_NONPOSITIVE_EDGE_OR_EV_NO_BET"):
            run_phase("A8_MARKET_VALUE_EXECUTION", payload)


if __name__ == "__main__":
    unittest.main()
