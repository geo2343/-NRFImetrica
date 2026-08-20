import unittest

import api.iainvestigadora as api_module
from kernel.iainvestigadora import (
    AGENT_ID, PROTOCOL_ID, IAInvestigadoraViolation,
    forbid_decision_fields, validate_conditional_phase, validate_f5_sentinel,
    validate_f12_payload, validate_phase_submission, validate_receipt,
    validate_target_binding,
)


def receipt(phase, status="EXECUTED"):
    return {
        "PHASE_ID": phase, "STATUS": status,
        "START_AS_OF": "2026-08-20T10:00:00Z", "END_AS_OF": "2026-08-20T10:01:00Z",
        "INPUT_OBJECTS": ["INPUT"], "OPERATIONS_PERFORMED": ["CHECK"],
        "OUTPUT_OBJECTS": ["OUTPUT"], "SOURCES_OR_EVIDENCE": ["E1"],
        "AUDITOR_RESULT": "PASS", "NEXT_PHASE": "NEXT",
        "UNRESOLVED_GOVERNING_OBJECTS": [], "REOPEN_TRIGGER": "MATERIAL_DELTA",
    }


def slots():
    return [{"slot": i, "player_state": "PROJECTED"} for i in range(1, 10)]


class IAInvestigadoraV14Tests(unittest.TestCase):
    def test_identity_constants(self):
        self.assertEqual(AGENT_ID, "@iainvestigadora")
        self.assertEqual(PROTOCOL_ID, "IAINVESTIGADORA_MLB_V14")
        self.assertEqual(api_module.app.version, "1.4")

    def test_target_binding_rejects_other_game(self):
        with self.assertRaisesRegex(IAInvestigadoraViolation, "TARGET_BINDING_MISMATCH"):
            validate_target_binding({"target_binding": {"game_id": "B"}}, "A")

    def test_receipt_is_mandatory_and_phase_bound(self):
        bad = receipt("F2")
        with self.assertRaisesRegex(IAInvestigadoraViolation, "E1_RECEIPT_PHASE_MISMATCH"):
            validate_receipt("F1", "COMPLETE", bad)

    def test_conditional_skip_requires_real_reason(self):
        with self.assertRaisesRegex(IAInvestigadoraViolation, "CONDITIONAL_SKIP_REASON_TOO_WEAK"):
            validate_conditional_phase("F6", "SKIPPED_NOT_TRIGGERED", {"trigger_material_evaluation": {"trigger_material": False, "why_not_applicable": "no"}})

    def test_conditional_cannot_skip_when_trigger_true(self):
        with self.assertRaisesRegex(IAInvestigadoraViolation, "CONDITIONAL_SKIP_REQUIRES_TRIGGER_FALSE"):
            validate_conditional_phase("F8", "SKIPPED_NOT_TRIGGERED", {"trigger_material_evaluation": {"trigger_material": True, "why_not_applicable": "This explanation is deliberately long enough."}})

    def test_f5_requires_both_lineups_slots_1_to_9(self):
        validate_f5_sentinel({"sentinel_coverage": {"away": slots(), "home": slots()}})
        bad = slots()[:-1]
        with self.assertRaisesRegex(IAInvestigadoraViolation, "F5_HOME_SENTINEL_1_9_REQUIRED"):
            validate_f5_sentinel({"sentinel_coverage": {"away": slots(), "home": bad}})

    def test_forbidden_decision_fields_are_recursive(self):
        with self.assertRaisesRegex(IAInvestigadoraViolation, "FORBIDDEN_DECISION_FIELDS"):
            forbid_decision_fields({"research": {"nested": {"pick": "NRFI"}}})

    def test_f12_requires_real_delivery_state(self):
        with self.assertRaisesRegex(IAInvestigadoraViolation, "F12_DRIVE_REPORT_INCOMPLETE"):
            validate_f12_payload({"mandatory_phases_not_run":"NONE","core_mission_complete":True,"drive_report_complete":"FAIL","chat_report_complete":"PASS","ready_for_handoff":True,"final_sports_store":{"ok":True}})

    def test_valid_f5_submission_passes_pure_kernel(self):
        payload = {
            "target_binding": {"game_id": "G1"},
            "sentinel_coverage": {"away": slots(), "home": slots()},
            "matchups": {"state":"COVERED"},
            "deep_dive_justification": "Selective depth based on material evidence.",
            "phase_execution_receipt": receipt("F5"),
        }
        validate_phase_submission(phase_id="F5", status="COMPLETE", game_id="G1", payload=payload, completed={"F1","F2","F3","F4"})


if __name__ == "__main__":
    unittest.main()
