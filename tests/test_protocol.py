import unittest

from kernel.protocol import ProtocolViolation, validate_phase_submission


class ProtocolStraightjacketTest(unittest.TestCase):
    def test_29_of_30_real_sources_cannot_advance(self):
        manifest = {
            "phases": [{
                "phase_id": "F1",
                "prerequisites": [],
                "required_fields": ["analysis"],
                "min_source_calls": 30,
            }]
        }
        calls = [
            {"source_ref": f"source-{i}", "evidence_id": f"E-{i}", "retrieved_at": "2026-08-19T10:00:00Z"}
            for i in range(29)
        ]
        with self.assertRaisesRegex(ProtocolViolation, "MIN_SOURCE_CALLS_NOT_MET:29/30"):
            validate_phase_submission(
                manifest=manifest,
                phase_id="F1",
                completed_phase_ids=set(),
                payload={"analysis": "done"},
                evidence_ids=[],
                source_calls=calls,
                documents_analyzed=[],
                output_text="",
            )

    def test_reusing_same_evidence_does_not_fake_30_sources(self):
        manifest = {
            "phases": [{
                "phase_id": "F1",
                "prerequisites": [],
                "required_fields": ["analysis"],
                "min_source_calls": 30,
            }]
        }
        calls = [
            {"source_ref": f"source-{i}", "evidence_id": "SAME-EVIDENCE", "retrieved_at": "2026-08-19T10:00:00Z"}
            for i in range(30)
        ]
        with self.assertRaisesRegex(ProtocolViolation, "MIN_SOURCE_CALLS_NOT_MET:1/30"):
            validate_phase_submission(
                manifest=manifest,
                phase_id="F1",
                completed_phase_ids=set(),
                payload={"analysis": "done"},
                evidence_ids=[],
                source_calls=calls,
                documents_analyzed=[],
                output_text="",
            )

    def test_30_of_30_unique_real_sources_can_advance(self):
        manifest = {
            "phases": [{
                "phase_id": "F1",
                "prerequisites": [],
                "required_fields": ["analysis"],
                "min_source_calls": 30,
            }]
        }
        calls = [
            {"source_ref": f"source-{i}", "evidence_id": f"E-{i}", "retrieved_at": "2026-08-19T10:00:00Z"}
            for i in range(30)
        ]
        result = validate_phase_submission(
            manifest=manifest,
            phase_id="F1",
            completed_phase_ids=set(),
            payload={"analysis": "done"},
            evidence_ids=[],
            source_calls=calls,
            documents_analyzed=[],
            output_text="",
        )
        self.assertEqual(result["status"], "COMPLETE")

    def test_required_t100_document_is_enforced(self):
        manifest = {
            "phases": [{
                "phase_id": "F2",
                "prerequisites": [],
                "required_fields": [],
                "required_documents": ["T100"],
            }]
        }
        with self.assertRaisesRegex(ProtocolViolation, "REQUIRED_DOCUMENTS_MISSING:T100"):
            validate_phase_submission(
                manifest=manifest,
                phase_id="F2",
                completed_phase_ids=set(),
                payload={},
                evidence_ids=[],
                source_calls=[],
                documents_analyzed=[],
                output_text="",
            )

    def test_claiming_t100_without_real_trace_is_rejected(self):
        manifest = {
            "phases": [{
                "phase_id": "F2",
                "prerequisites": [],
                "required_fields": [],
                "required_documents": ["T100"],
            }]
        }
        with self.assertRaisesRegex(ProtocolViolation, "REQUIRED_DOCUMENTS_WITHOUT_REAL_TRACE:T100"):
            validate_phase_submission(
                manifest=manifest,
                phase_id="F2",
                completed_phase_ids=set(),
                payload={},
                evidence_ids=[],
                source_calls=[],
                documents_analyzed=["T100"],
                output_text="",
            )

    def test_t100_with_real_trace_can_pass(self):
        manifest = {
            "phases": [{
                "phase_id": "F2",
                "prerequisites": [],
                "required_fields": [],
                "required_documents": ["T100"],
            }]
        }
        result = validate_phase_submission(
            manifest=manifest,
            phase_id="F2",
            completed_phase_ids=set(),
            payload={},
            evidence_ids=["E-T100"],
            source_calls=[{
                "source_ref": "drive://t100",
                "evidence_id": "E-T100",
                "retrieved_at": "2026-08-19T10:00:00Z",
                "document": "T100",
            }],
            documents_analyzed=["T100"],
            output_text="",
        )
        self.assertEqual(result["status"], "COMPLETE")

    def test_required_phrase_is_enforced(self):
        manifest = {
            "phases": [{
                "phase_id": "F3",
                "prerequisites": [],
                "required_fields": [],
                "required_phrases": ["T100 ANALIZADO"],
            }]
        }
        with self.assertRaisesRegex(ProtocolViolation, "REQUIRED_PHRASE_MISSING"):
            validate_phase_submission(
                manifest=manifest,
                phase_id="F3",
                completed_phase_ids=set(),
                payload={},
                evidence_ids=[],
                source_calls=[],
                documents_analyzed=[],
                output_text="T100 revisado parcialmente",
            )

    def test_cannot_jump_prerequisite(self):
        manifest = {
            "phases": [{
                "phase_id": "F4",
                "prerequisites": ["F1", "F2"],
                "required_fields": [],
            }]
        }
        with self.assertRaisesRegex(ProtocolViolation, "PREREQUISITES_INCOMPLETE:F2"):
            validate_phase_submission(
                manifest=manifest,
                phase_id="F4",
                completed_phase_ids={"F1"},
                payload={},
                evidence_ids=[],
                source_calls=[],
                documents_analyzed=[],
                output_text="",
            )

    def test_ai_estimate_is_judgment_not_calibrated_probability(self):
        manifest = {
            "phases": [{
                "phase_id": "F5",
                "prerequisites": [],
                "required_fields": ["ai_estimate"],
            }]
        }
        result = validate_phase_submission(
            manifest=manifest,
            phase_id="F5",
            completed_phase_ids=set(),
            payload={"ai_estimate": {"kind": "AI_JUDGMENT_UNCALIBRATED", "percent": 68}},
            evidence_ids=[],
            source_calls=[],
            documents_analyzed=[],
            output_text="",
        )
        self.assertEqual(result["status"], "COMPLETE")

        with self.assertRaisesRegex(ProtocolViolation, "AI_PERCENT_MUST_BE_LABELED"):
            validate_phase_submission(
                manifest=manifest,
                phase_id="F5",
                completed_phase_ids=set(),
                payload={"ai_estimate": {"kind": "CALIBRATED_PROBABILITY", "percent": 68}},
                evidence_ids=[],
                source_calls=[],
                documents_analyzed=[],
                output_text="",
            )


if __name__ == "__main__":
    unittest.main()
